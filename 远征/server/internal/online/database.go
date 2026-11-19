package online

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"fmt"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed migrations/*.sql
var migrations embed.FS

// CheckMigrations is the read-only startup path for a restricted runtime role.
// Unknown migrations also fail closed, so an old gateway cannot silently start
// against a newer database after an application rollback.
func CheckMigrations(ctx context.Context, db *pgxpool.Pool) error {
	tx, err := db.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead, AccessMode: pgx.ReadOnly})
	if err != nil {
		return fmt.Errorf("migration check unavailable")
	}
	defer tx.Rollback(ctx)
	rows, err := tx.Query(ctx, `SELECT name,sha256 FROM schema_migrations ORDER BY name`)
	if err != nil {
		return fmt.Errorf("migration history unavailable; run the separate migrator first")
	}
	applied := map[string]string{}
	for rows.Next() {
		var name, digest string
		if err := rows.Scan(&name, &digest); err != nil {
			rows.Close()
			return fmt.Errorf("migration history unreadable")
		}
		applied[name] = digest
	}
	rows.Close()
	if rows.Err() != nil {
		return fmt.Errorf("migration history unreadable")
	}
	files, err := migrations.ReadDir("migrations")
	if err != nil || len(files) != len(applied) {
		return fmt.Errorf("database migration set does not match this server")
	}
	for _, file := range files {
		body, err := migrations.ReadFile("migrations/" + file.Name())
		if err != nil || applied[file.Name()] != fmt.Sprintf("%x", sha256.Sum256(body)) {
			return fmt.Errorf("database migration checksum does not match this server")
		}
	}
	return tx.Commit(ctx)
}

// CheckRuntimePrivileges rejects ownership and privilege escalation routes.
// This checks the effective login, including memberships usable through SET ROLE.
func CheckRuntimePrivileges(ctx context.Context, db *pgxpool.Pool) error {
	var unsafe bool
	err := db.QueryRow(ctx, `SELECT
        EXISTS(SELECT 1 FROM pg_roles r WHERE
          (r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR r.rolreplication OR r.rolbypassrls OR r.rolname LIKE 'pg\_%')
          AND pg_has_role(current_user,r.oid,'MEMBER'))
        OR has_database_privilege(current_database(),'CREATE,TEMP')
        OR has_schema_privilege(current_schema(),'CREATE')
        OR EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname=current_schema() AND pg_has_role(current_user,c.relowner,'MEMBER'))
        OR has_table_privilege('schema_migrations','INSERT,UPDATE,DELETE,TRUNCATE')
        OR has_table_privilege('wallet_ledger','UPDATE,DELETE,TRUNCATE,TRIGGER')
        OR has_table_privilege('inventory_ledger','DELETE,TRUNCATE,TRIGGER')
        OR has_any_column_privilege('inventory_ledger','UPDATE')
        OR has_table_privilege('quest_events','DELETE,TRUNCATE,TRIGGER')
        OR has_any_column_privilege('quest_events','UPDATE')
        OR has_table_privilege('market_fills','UPDATE,DELETE,TRUNCATE,TRIGGER')
        OR has_table_privilege('guild_audit_logs','UPDATE,DELETE,TRUNCATE,TRIGGER')
        OR has_table_privilege('pvp_honor_ledger','UPDATE,DELETE,TRUNCATE,TRIGGER')
        OR has_table_privilege('inventory_items','DELETE,TRUNCATE,TRIGGER')
        OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=current_schema()
          AND table_name='inventory_items' AND column_name NOT IN ('quantity','equipped_slot','version','updated_at')
          AND has_column_privilege('inventory_items',column_name::text,'UPDATE'))
        OR EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname=current_schema() AND c.relkind IN ('r','p') AND
          has_table_privilege(c.oid,'TRUNCATE,TRIGGER,REFERENCES'))`).Scan(&unsafe)
	if err != nil {
		return fmt.Errorf("runtime database privilege check unavailable")
	}
	if unsafe {
		return fmt.Errorf("runtime database role has ownership or administrative privileges")
	}
	return nil
}

// Migrate serializes deploys and rejects changes to already applied migrations.
func Migrate(ctx context.Context, db *pgxpool.Pool) error {
	tx, err := db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(743012664)`); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, sha256 text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())`); err != nil {
		return err
	}
	files, err := migrations.ReadDir("migrations")
	if err != nil {
		return err
	}
	sort.Slice(files, func(i, j int) bool { return files[i].Name() < files[j].Name() })
	expected := map[string]bool{}
	for _, file := range files {
		expected[file.Name()] = true
	}
	rows, err := tx.Query(ctx, `SELECT name FROM schema_migrations`)
	if err != nil {
		return err
	}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			rows.Close()
			return fmt.Errorf("migration history unreadable")
		}
		if !expected[name] {
			rows.Close()
			return fmt.Errorf("database contains a migration unknown to this server")
		}
	}
	rows.Close()
	if rows.Err() != nil {
		return rows.Err()
	}
	for _, file := range files {
		body, err := migrations.ReadFile("migrations/" + file.Name())
		if err != nil {
			return err
		}
		hash := fmt.Sprintf("%x", sha256.Sum256(body))
		var old string
		rows, err := tx.Query(ctx, `SELECT sha256 FROM schema_migrations WHERE name=$1`, file.Name())
		if err != nil {
			return err
		}
		if rows.Next() {
			err = rows.Scan(&old)
		}
		rows.Close()
		if rows.Err() != nil {
			return rows.Err()
		}
		if err != nil {
			return err
		}
		if old != "" {
			if old != hash {
				return fmt.Errorf("migration %s checksum changed", file.Name())
			}
			continue
		}
		if _, err = tx.Exec(ctx, string(body)); err != nil {
			return fmt.Errorf("migration %s: %w", file.Name(), err)
		}
		if _, err = tx.Exec(ctx, `INSERT INTO schema_migrations(name,sha256) VALUES($1,$2)`, file.Name(), hash); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

func newID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic("OS random source unavailable")
	}
	b[6] = (b[6] & 15) | 64
	b[8] = (b[8] & 63) | 128
	s := hex.EncodeToString(b[:])
	return s[:8] + "-" + s[8:12] + "-" + s[12:16] + "-" + s[16:20] + "-" + s[20:]
}
