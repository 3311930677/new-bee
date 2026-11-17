package dbops

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"regexp"
	"runtime"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TableDigest struct {
	Name   string `json:"name"`
	Rows   int64  `json:"rows"`
	SHA256 string `json:"sha256"`
}

type BackupManifest struct {
	Format        int           `json:"format"`
	Database      string        `json:"database"`
	Schema        string        `json:"schema"`
	ServerVersion int           `json:"server_version"`
	Started       time.Time     `json:"started_utc"`
	Finished      time.Time     `json:"finished_utc"`
	DumpSHA256    string        `json:"dump_sha256"`
	DumpBytes     int64         `json:"dump_bytes"`
	Tables        []TableDigest `json:"tables"`
}

// snapshotTables hashes rows in a repeatable-read snapshot. Raw rows, including
// password/token hashes, stay in memory and are never written to the manifest.
// This intentionally scans the whole schema; it is an L0 logical restore check,
// not a demonstrated large-production backup throughput strategy.
func snapshotTables(ctx context.Context, tx pgx.Tx) ([]TableDigest, error) {
	rows, err := tx.Query(ctx, `SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname=$1 AND c.relkind IN ('r','p') ORDER BY c.relname`, Schema)
	if err != nil {
		return nil, fmt.Errorf("backup table list unavailable")
	}
	var names []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			rows.Close()
			return nil, fmt.Errorf("backup table list unreadable")
		}
		names = append(names, name)
	}
	rows.Close()
	if rows.Err() != nil || len(names) == 0 {
		return nil, fmt.Errorf("backup requires a migrated game schema")
	}
	tables := make([]TableDigest, 0, len(names))
	for _, name := range names {
		rows, err := tx.Query(ctx, "SELECT to_jsonb(t)::text FROM "+pgx.Identifier{Schema, name}.Sanitize()+" t ORDER BY to_jsonb(t)::text COLLATE \"C\"")
		if err != nil {
			return nil, fmt.Errorf("backup table scan unavailable")
		}
		hash, count := sha256.New(), int64(0)
		for rows.Next() {
			var value string
			if err := rows.Scan(&value); err != nil {
				rows.Close()
				return nil, fmt.Errorf("backup table scan unreadable")
			}
			_ = binary.Write(hash, binary.BigEndian, uint64(len(value)))
			hash.Write([]byte(value))
			count++
		}
		rows.Close()
		if rows.Err() != nil {
			return nil, fmt.Errorf("backup table scan incomplete")
		}
		tables = append(tables, TableDigest{name, count, hex.EncodeToString(hash.Sum(nil))})
	}
	return tables, nil
}

func privatePGEnvironment(dsn string) ([]string, error) {
	address, err := url.Parse(dsn)
	if err != nil || (address.Scheme != "postgres" && address.Scheme != "postgresql") || address.User == nil || address.Hostname() == "" {
		return nil, fmt.Errorf("native backup tools require a PostgreSQL URL")
	}
	values := map[string]string{"PGHOST": address.Hostname(), "PGPORT": address.Port(), "PGUSER": address.User.Username(), "PGDATABASE": strings.TrimPrefix(address.Path, "/"),
		"PGCONNECT_TIMEOUT": "10", "PGAPPNAME": "yuanzheng-offline-dbops", "PGCLIENTENCODING": "UTF8", "PGTZ": "UTC", "PGDATESTYLE": "ISO, YMD"}
	values["PGPASSWORD"], _ = address.User.Password()
	if values["PGPORT"] == "" {
		values["PGPORT"] = "5432"
	}
	options := map[string]string{"sslmode": "PGSSLMODE", "sslrootcert": "PGSSLROOTCERT", "sslcert": "PGSSLCERT", "sslkey": "PGSSLKEY", "sslcrl": "PGSSLCRL", "channel_binding": "PGCHANNELBINDING", "connect_timeout": "PGCONNECT_TIMEOUT"}
	for key, list := range address.Query() {
		name, ok := options[key]
		if !ok || len(list) != 1 {
			return nil, fmt.Errorf("unsupported or repeated native database URL option")
		}
		values[name] = list[0]
	}
	var env []string
	for _, item := range os.Environ() {
		key, _, _ := strings.Cut(item, "=")
		upper := strings.ToUpper(key)
		if !strings.HasPrefix(upper, "PG") && !strings.HasPrefix(upper, "YUANZHENG_") {
			env = append(env, item)
		}
	}
	for key, value := range values {
		env = append(env, key+"="+value)
	}
	return env, nil
}

func pgCommand(ctx context.Context, pgBin, tool, dsn string, arguments ...string) error {
	if runtime.GOOS == "windows" {
		tool += ".exe"
	}
	path := filepath.Join(pgBin, tool)
	if !filepath.IsAbs(path) {
		return fmt.Errorf("PostgreSQL tool directory must be absolute")
	}
	command := exec.CommandContext(ctx, path, arguments...)
	var err error
	command.Env, err = privatePGEnvironment(dsn)
	if err != nil {
		return err
	}
	// Native tools can include connection details in errors. Do not forward their
	// output or the private environment to a console/report or a game process.
	if err := command.Run(); err != nil {
		return fmt.Errorf("PostgreSQL offline tool failed; database credentials were not logged")
	}
	return nil
}

func digestFile(path string) (string, int64, error) {
	file, err := os.Open(path)
	if err != nil {
		return "", 0, fmt.Errorf("backup archive unavailable")
	}
	defer file.Close()
	hash := sha256.New()
	size, err := io.Copy(hash, file)
	if err != nil {
		return "", 0, fmt.Errorf("backup archive incomplete")
	}
	return hex.EncodeToString(hash.Sum(nil)), size, nil
}

func writeJSONNew(path string, value any) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return fmt.Errorf("offline report serialization failed")
	}
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return fmt.Errorf("offline report already exists or cannot be created")
	}
	_, writeErr := file.Write(append(data, '\n'))
	closeErr := file.Close()
	if writeErr != nil || closeErr != nil {
		return fmt.Errorf("offline report could not be completed")
	}
	return nil
}

// Backup exports a custom archive and table digests from the exact same exported
// snapshot. The shared advisory lock excludes the application's migrator until
// pg_dump completes. A manifest is published only for a complete successful dump.
func Backup(ctx context.Context, db *pgxpool.Pool, dsn, pgBin, folder string) (*BackupManifest, error) {
	if !filepath.IsAbs(folder) {
		return nil, fmt.Errorf("backup directory must be absolute")
	}
	if err := os.Mkdir(folder, 0700); err != nil {
		return nil, fmt.Errorf("backup directory must be new")
	}
	manifest := &BackupManifest{Format: 1, Schema: Schema, Started: time.Now().UTC()}
	connection, err := db.Acquire(ctx)
	if err != nil {
		return nil, fmt.Errorf("backup connection unavailable")
	}
	defer func() {
		// Closing this dedicated pooled connection releases the session lock even
		// on cancellation; it must never return a locked session to the pool.
		end, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = connection.Conn().Close(end)
		connection.Release()
	}()
	// Acquire the lock before the repeatable-read snapshot is established.
	if _, err = connection.Exec(ctx, `SELECT pg_advisory_lock_shared(743012664)`); err != nil {
		return nil, fmt.Errorf("backup migration lock unavailable")
	}
	tx, err := connection.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead, AccessMode: pgx.ReadOnly})
	if err != nil {
		return nil, fmt.Errorf("backup snapshot unavailable")
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SET LOCAL timezone='UTC'; SET LOCAL datestyle='ISO, YMD'`); err != nil {
		return nil, fmt.Errorf("backup session configuration unavailable")
	}
	var snapshot string
	if err = tx.QueryRow(ctx, `SELECT current_database(),current_setting('server_version_num')::int,pg_export_snapshot()`).Scan(&manifest.Database, &manifest.ServerVersion, &snapshot); err != nil {
		return nil, fmt.Errorf("backup exported snapshot unavailable")
	}
	manifest.Tables, err = snapshotTables(ctx, tx)
	if err != nil {
		return nil, err
	}
	dump := filepath.Join(folder, "database.dump")
	if err = pgCommand(ctx, pgBin, "pg_dump", dsn, "--no-password", "--format=custom", "--no-owner", "--no-acl", "--lock-wait-timeout=5s", "--snapshot="+snapshot, "--file="+dump); err != nil {
		return nil, err
	}
	if err = os.Chmod(dump, 0600); err != nil {
		return nil, fmt.Errorf("backup file permissions unavailable")
	}
	manifest.DumpSHA256, manifest.DumpBytes, err = digestFile(dump)
	if err != nil {
		return nil, err
	}
	if err = tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("backup snapshot completion failed")
	}
	manifest.Finished = time.Now().UTC()
	if err = writeJSONNew(filepath.Join(folder, "manifest.json"), manifest); err != nil {
		return nil, err
	}
	return manifest, nil
}

var restoreName = regexp.MustCompile(`^yz_restore_[a-z0-9_]{1,36}$`)
var digestShape = regexp.MustCompile(`^[0-9a-f]{64}$`)

func readManifest(folder string) (*BackupManifest, error) {
	data, err := os.ReadFile(filepath.Join(folder, "manifest.json"))
	if err != nil || len(data) > 1<<20 {
		return nil, fmt.Errorf("backup manifest unavailable or oversized")
	}
	var manifest BackupManifest
	if err = json.Unmarshal(data, &manifest); err != nil || manifest.Format != 1 || manifest.Schema != Schema || !digestShape.MatchString(manifest.DumpSHA256) || manifest.DumpBytes <= 0 || len(manifest.Tables) == 0 {
		return nil, fmt.Errorf("backup manifest is invalid")
	}
	seen := map[string]bool{}
	for _, table := range manifest.Tables {
		if !identifier.MatchString(table.Name) || !digestShape.MatchString(table.SHA256) || table.Rows < 0 || seen[table.Name] {
			return nil, fmt.Errorf("backup table manifest is invalid")
		}
		seen[table.Name] = true
	}
	if !seen["schema_migrations"] || !seen["sessions"] || !seen["room_leases"] || !seen["wallet_ledger"] || !seen["battle_results"] {
		return nil, fmt.Errorf("backup is missing required game tables")
	}
	digest, size, err := digestFile(filepath.Join(folder, "database.dump"))
	if err != nil || digest != manifest.DumpSHA256 || size != manifest.DumpBytes {
		return nil, fmt.Errorf("backup archive checksum mismatch")
	}
	return &manifest, nil
}

type RestoreReport struct {
	Target            string        `json:"target_database"`
	Started           time.Time     `json:"started_utc"`
	Finished          time.Time     `json:"finished_utc"`
	DumpSHA256        string        `json:"dump_sha256"`
	TablesMatched     []TableDigest `json:"tables_matched_before_session_invalidation"`
	SessionsRevoked   int64         `json:"sessions_revoked"`
	LeasesInvalidated int64         `json:"leases_invalidated"`
	ReadyForReview    bool          `json:"ready_for_review"`
}

// Restore never targets an existing DB and never switches a live endpoint. A
// failed new database is retained without runtime CONNECT for investigation.
// Restore only trusted self-produced archives; checksums detect corruption,
// not an attacker able to replace both the manifest and the archive.
func Restore(ctx context.Context, admin *pgxpool.Pool, adminDSN, pgBin, folder, target string, roles Roles) (report *RestoreReport, err error) {
	if err = roles.Validate(); err != nil {
		return nil, err
	}
	if !restoreName.MatchString(target) {
		return nil, fmt.Errorf("new restore database name must start with yz_restore_")
	}
	manifest, err := readManifest(folder)
	if err != nil {
		return nil, err
	}
	var exists bool
	var version int
	if err = admin.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname=$1),current_setting('server_version_num')::int`, target).Scan(&exists, &version); err != nil || exists || target == manifest.Database {
		return nil, fmt.Errorf("restore target must be a different, nonexistent database")
	}
	if version/10000 != manifest.ServerVersion/10000 {
		return nil, fmt.Errorf("restore drill requires matching PostgreSQL major versions")
	}
	for _, role := range []string{roles.Migrator, roles.Runtime, roles.Backup} {
		var safe bool
		if err = admin.QueryRow(ctx, `SELECT NOT(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)
          AND NOT EXISTS(SELECT 1 FROM pg_auth_members WHERE member=r.oid) FROM pg_roles r WHERE rolname=$1`, role).Scan(&safe); err != nil || !safe {
			return nil, fmt.Errorf("restore requires existing restricted application roles")
		}
	}
	config, err := pgxpool.ParseConfig(adminDSN)
	if err != nil {
		return nil, fmt.Errorf("restore connection configuration invalid")
	}
	config.ConnConfig.Database = target
	config.ConnConfig.RuntimeParams["search_path"] = Schema
	config.ConnConfig.RuntimeParams["timezone"] = "UTC"
	config.ConnConfig.RuntimeParams["datestyle"] = "ISO, YMD"
	report = &RestoreReport{Target: target, Started: time.Now().UTC(), DumpSHA256: manifest.DumpSHA256}
	if _, err = admin.Exec(ctx, "CREATE DATABASE "+quote(target)+" OWNER "+quote(roles.Migrator)+" TEMPLATE template0"); err != nil {
		return nil, fmt.Errorf("new restore database could not be created; existing databases are not changed")
	}
	defer func() {
		if err != nil {
			cleanup, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			// This database was created above; no pre-existing DB is changed.
			_, _ = admin.Exec(cleanup, "REVOKE CONNECT ON DATABASE "+quote(target)+" FROM PUBLIC,"+quote(roles.Runtime)+","+quote(roles.Backup))
		}
	}()
	if _, err = admin.Exec(ctx, "REVOKE ALL ON DATABASE "+quote(target)+" FROM PUBLIC"); err != nil {
		return nil, fmt.Errorf("new restore database could not be isolated")
	}
	if err = pgCommand(ctx, pgBin, "pg_restore", adminDSN, "--no-password", "--dbname="+target, "--role="+roles.Migrator, "--no-owner", "--no-acl", "--single-transaction", "--exit-on-error", filepath.Join(folder, "database.dump")); err != nil {
		return nil, err
	}
	db, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("new restore database unavailable")
	}
	defer db.Close()
	tx, err := db.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead})
	if err != nil {
		return nil, fmt.Errorf("restored data validation unavailable")
	}
	defer tx.Rollback(ctx)
	report.TablesMatched, err = snapshotTables(ctx, tx)
	if err != nil || !reflect.DeepEqual(report.TablesMatched, manifest.Tables) {
		return nil, fmt.Errorf("restored table rows do not match the backup snapshot")
	}
	command, err := tx.Exec(ctx, `UPDATE sessions SET revoked_at=now(),updated_at=now(),version=version+1 WHERE revoked_at IS NULL`)
	if err != nil {
		return nil, fmt.Errorf("restored sessions could not be revoked")
	}
	report.SessionsRevoked = command.RowsAffected()
	command, err = tx.Exec(ctx, `UPDATE room_leases SET expires_at=now(),token=gen_random_uuid(),generation=generation+1,updated_at=now()`)
	if err != nil {
		return nil, fmt.Errorf("restored room leases could not be invalidated")
	}
	report.LeasesInvalidated = command.RowsAffected()
	if err = tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("restored session invalidation commit failed")
	}
	if err = GrantRuntime(ctx, db, roles); err != nil {
		return nil, err
	}
	report.Finished, report.ReadyForReview = time.Now().UTC(), true
	if err = writeJSONNew(filepath.Join(folder, target+"-restore.json"), report); err != nil {
		return nil, err
	}
	return report, nil
}
