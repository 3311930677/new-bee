package dbops

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
	"yuanzheng/online/internal/online"
)

type databaseFixture struct {
	ctx                   context.Context
	cluster, admin        *pgxpool.Pool
	migrator, app, reader *pgxpool.Pool
	name, dsn, backupDSN  string
	roles                 Roles
	databases             []string
	pools                 []*pgxpool.Pool
	passwords             [3]string
	queries               *queryCapture
	extraRoles            []string
}

type queryCapture struct {
	mu         sync.Mutex
	statements []string
}

func (q *queryCapture) TraceQueryStart(ctx context.Context, _ *pgx.Conn, data pgx.TraceQueryStartData) context.Context {
	q.mu.Lock()
	defer q.mu.Unlock()
	q.statements = append(q.statements, data.SQL)
	return ctx
}
func (*queryCapture) TraceQueryEnd(context.Context, *pgx.Conn, pgx.TraceQueryEndData) {}

func randomHex() string {
	var value [16]byte
	if _, err := rand.Read(value[:]); err != nil {
		panic(err)
	}
	return hex.EncodeToString(value[:])
}

func newFixture(t *testing.T) *databaseFixture {
	t.Helper()
	dsn := os.Getenv("YUANZHENG_TEST_DATABASE_URL")
	if dsn == "" {
		t.Fatal("YUANZHENG_TEST_DATABASE_URL is required; offline integration tests never skip")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	f := &databaseFixture{ctx: ctx, name: "yz_ops_" + randomHex()[:20], dsn: dsn}
	var err error
	f.cluster, err = pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatal("test cluster configuration invalid")
	}
	if _, err = f.cluster.Exec(ctx, "CREATE DATABASE "+quote(f.name)+" TEMPLATE template0"); err != nil {
		t.Fatal("disposable test database creation failed")
	}
	f.databases = append(f.databases, f.name)
	rolesCreated := false
	t.Cleanup(func() {
		for _, pool := range f.pools {
			pool.Close()
		}
		// DROP DATABASE can wait for a cluster checkpoint. Use a fresh deadline
		// for each resource so the next drop can still run after a slow one.
		for index := len(f.databases) - 1; index >= 0; index-- {
			name := f.databases[index]
			if !strings.HasPrefix(name, "yz_ops_") && !restoreName.MatchString(name) {
				t.Error("refused unsafe disposable database cleanup")
				continue
			}
			f.dropFixtureResource(t, "DATABASE", name, 2*time.Minute)
		}
		if rolesCreated {
			for _, role := range append([]string{f.roles.Migrator, f.roles.Runtime, f.roles.Backup}, f.extraRoles...) {
				f.dropFixtureResource(t, "ROLE", role, 30*time.Second)
			}
		}
		f.cluster.Close()
		cancel()
	})
	f.queries = &queryCapture{}
	f.admin = f.pool(t, f.name, "", "")
	prefix := "yz_role_" + randomHex()[:16]
	f.roles = Roles{prefix + "_m", prefix + "_r", prefix + "_b"}
	t.Logf("disposable resources: database=%s role_prefix=%s", f.name, prefix)
	passwords := [3]string{randomHex(), randomHex(), randomHex()}
	f.passwords = passwords
	if err = Provision(ctx, f.admin, f.roles, passwords); err != nil {
		t.Fatal(err)
	}
	rolesCreated = true
	f.migrator = f.pool(t, f.name, f.roles.Migrator, passwords[0])
	f.app = f.pool(t, f.name, f.roles.Runtime, passwords[1])
	f.reader = f.pool(t, f.name, f.roles.Backup, passwords[2])
	// Native tools use URL credentials exclusively through their private env.
	config, _ := pgxpool.ParseConfig(dsn)
	address := url.URL{Scheme: "postgres", User: url.UserPassword(f.roles.Backup, passwords[2]), Host: net.JoinHostPort(config.ConnConfig.Host, strconv.Itoa(int(config.ConnConfig.Port))), Path: "/" + f.name, RawQuery: "sslmode=disable"}
	f.backupDSN = address.String()
	if err = online.Migrate(ctx, f.migrator); err != nil {
		t.Fatal("offline migrator could not migrate its owned schema")
	}
	if err = GrantRuntime(ctx, f.admin, f.roles); err != nil {
		t.Fatal(err)
	}
	return f
}

func (f *databaseFixture) dropFixtureResource(t *testing.T, resource, name string, timeout time.Duration) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	statement := "DROP " + resource + " IF EXISTS " + quote(name)
	if resource == "DATABASE" {
		statement += " WITH (FORCE)"
	}
	if _, err := f.cluster.Exec(ctx, statement); err != nil {
		var postgresError *pgconn.PgError
		switch {
		case errors.As(err, &postgresError):
			t.Errorf("disposable %s %s cleanup failed (SQLSTATE %s)", resource, name, postgresError.Code)
		case ctx.Err() != nil:
			t.Errorf("disposable %s %s cleanup timed out after %s", resource, name, timeout)
		default:
			t.Errorf("disposable %s %s cleanup connection failed", resource, name)
		}
	}
}

func TestProvisionRefusesEnumOnlyAndLargeObjectDatabases(t *testing.T) {
	f := newFixture(t)
	name := "yz_ops_" + randomHex()[:20]
	if _, err := f.cluster.Exec(f.ctx, "CREATE DATABASE "+quote(name)+" TEMPLATE template0"); err != nil {
		t.Fatal(err)
	}
	f.databases = append(f.databases, name)
	db := f.pool(t, name, "", "")
	prefix := "yz_role_" + randomHex()[:16]
	roles := Roles{prefix + "_m", prefix + "_r", prefix + "_b"}
	f.extraRoles = append(f.extraRoles, roles.Migrator, roles.Runtime, roles.Backup)
	for _, statement := range []string{`CREATE TYPE public.existing_enum AS ENUM ('existing')`, `DROP TYPE public.existing_enum; SELECT lo_create(0)`} {
		if _, err := db.Exec(f.ctx, statement); err != nil {
			t.Fatal(err)
		}
		if err := Provision(f.ctx, db, roles, [3]string{randomHex(), randomHex(), randomHex()}); err == nil || !strings.Contains(err.Error(), "new empty") {
			t.Fatal("database with existing non-table content was treated as empty")
		}
		var untouched bool
		if err := db.QueryRow(f.ctx, `SELECT (SELECT datacl IS NULL FROM pg_database WHERE datname=current_database())
          AND NOT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='game')
          AND NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=$1)`, roles.Migrator).Scan(&untouched); err != nil || !untouched {
			t.Fatal("refused provisioning changed existing content or access")
		}
	}
	t.Log("enum-only and large-object-only databases refused before role/schema/ACL changes")
}

func (f *databaseFixture) pool(t *testing.T, database, user, password string) *pgxpool.Pool {
	t.Helper()
	config, err := pgxpool.ParseConfig(f.dsn)
	if err != nil {
		t.Fatal("test connection configuration invalid")
	}
	config.ConnConfig.Database = database
	if user != "" {
		config.ConnConfig.User, config.ConnConfig.Password = user, password
	}
	config.ConnConfig.RuntimeParams["search_path"] = Schema
	if user == "" {
		config.ConnConfig.Tracer = f.queries
	}
	config.ConnConfig.RuntimeParams["timezone"] = "UTC"
	config.MaxConns = 6
	pool, err := pgxpool.NewWithConfig(f.ctx, config)
	if err != nil {
		t.Fatal("test database pool unavailable")
	}
	f.pools = append(f.pools, pool)
	return pool
}

func denied(t *testing.T, db *pgxpool.Pool, statement string) {
	rejectCode(t, db, statement, "42501")
}

func rejectCode(t *testing.T, db *pgxpool.Pool, statement, code string) {
	t.Helper()
	_, err := db.Exec(context.Background(), statement)
	var pgError *pgconn.PgError
	if !errors.As(err, &pgError) || pgError.Code != code {
		t.Fatalf("expected PostgreSQL %s for %s", code, strings.Fields(statement)[0])
	}
}

func TestRuntimeAndBackupCannotOwnMigrateOrRewriteLedger(t *testing.T) {
	f := newFixture(t)
	f.queries.mu.Lock()
	statements := strings.Join(f.queries.statements, "\n")
	f.queries.mu.Unlock()
	for _, value := range f.passwords {
		if strings.Contains(statements, value) {
			t.Fatal("plaintext role password was sent in an SQL statement")
		}
	}
	if strings.Count(statements, "SCRAM-SHA-256$4096:") != 3 {
		t.Fatal("all three roles require client-generated SCRAM verifiers")
	}
	if err := online.CheckMigrations(f.ctx, f.app); err != nil {
		t.Fatal(err)
	}
	if err := online.CheckRuntimePrivileges(f.ctx, f.app); err != nil {
		t.Fatal(err)
	}
	for _, pool := range []*pgxpool.Pool{f.migrator, f.admin} {
		if online.CheckRuntimePrivileges(f.ctx, pool) == nil {
			t.Fatal("owning or administrative identity passed runtime guard")
		}
	}
	for _, statement := range []string{
		"CREATE TABLE game.unauthorized(id int)", "CREATE SCHEMA unauthorized", "CREATE TEMP TABLE unauthorized(id int)",
		"DROP TABLE game.wallets", "ALTER TABLE game.wallet_ledger DISABLE TRIGGER ALL", "TRUNCATE game.wallet_ledger",
		"UPDATE game.wallet_ledger SET delta=delta", "DELETE FROM game.wallet_ledger", "UPDATE game.schema_migrations SET sha256=sha256",
		"UPDATE game.inventory_ledger SET delta=delta", "DELETE FROM game.inventory_ledger", "TRUNCATE game.inventory_ledger",
		"UPDATE game.quest_events SET target_id='changed'", "DELETE FROM game.quest_events", "TRUNCATE game.quest_events",
		"DELETE FROM game.inventory_items", "UPDATE game.inventory_items SET template_id=template_id", "UPDATE game.inventory_items SET bound=bound",
		"DELETE FROM game.npc_interactions", "TRUNCATE game.npc_interactions",
		"UPDATE game.player_reports SET reason='changed'", "DELETE FROM game.player_reports", "TRUNCATE game.player_reports",
		"UPDATE game.chat_messages SET content='changed'", "DELETE FROM game.chat_messages", "TRUNCATE game.chat_messages",
		"DELETE FROM game.friend_requests", "DELETE FROM game.party_invites",
		"DELETE FROM game.coop_instance_drops", "DELETE FROM game.world_boss_participations",
		"UPDATE game.market_fills SET unit_price=1", "DELETE FROM game.market_fills", "TRUNCATE game.market_fills",
		"DELETE FROM game.market_orders", "DELETE FROM game.market_payouts", "DELETE FROM game.trade_sessions", "DELETE FROM game.economy_alerts",
		"SET ROLE " + quote(f.roles.Migrator),
		"CREATE ROLE yz_unauthorized", "SELECT pg_read_file('postgresql.conf')",
	} {
		denied(t, f.app, statement)
	}
	// PostgreSQL may return only a warning for GRANT without grant option.
	// Verify the actual ACL instead of treating a successful command as a grant.
	_, _ = f.app.Exec(f.ctx, "GRANT SELECT ON game.accounts TO PUBLIC")
	var publicRead bool
	if err := f.admin.QueryRow(f.ctx, `SELECT EXISTS(SELECT 1 FROM pg_class c,aclexplode(c.relacl) a WHERE c.oid='game.accounts'::regclass AND a.grantee=0 AND a.privilege_type='SELECT')`).Scan(&publicRead); err != nil || publicRead {
		t.Fatal("runtime granted public access to accounts")
	}
	for _, statement := range []string{"UPDATE game.wallets SET gold=gold", "DELETE FROM game.accounts", "TRUNCATE game.wallet_ledger", "CREATE TABLE game.unauthorized(id int)", "SELECT nextval('game.audit_events_id_seq')"} {
		denied(t, f.reader, statement)
	}
	if err := Provision(f.ctx, f.admin, f.roles, [3]string{randomHex(), randomHex(), randomHex()}); err == nil {
		t.Fatal("provisioning changed an existing application database")
	}
	if _, err := f.admin.Exec(f.ctx, "GRANT "+quote(f.roles.Migrator)+" TO "+quote(f.roles.Runtime)); err != nil {
		t.Fatal(err)
	}
	if online.CheckRuntimePrivileges(f.ctx, f.app) == nil || GrantRuntime(f.ctx, f.admin, f.roles) == nil {
		t.Fatal("role membership could bypass runtime startup or offline grant guard")
	}
	if _, err := f.admin.Exec(f.ctx, "REVOKE "+quote(f.roles.Migrator)+" FROM "+quote(f.roles.Runtime)); err != nil {
		t.Fatal(err)
	}
	t.Log("restricted runtime and backup identities denied 18 actual SQL escalation/write attempts")
}

func TestReadOnlyMigrationGateRejectsDriftAndFutureSchema(t *testing.T) {
	f := newFixture(t)
	var digest string
	if err := f.admin.QueryRow(f.ctx, `SELECT sha256 FROM schema_migrations WHERE name='001_initial.sql'`).Scan(&digest); err != nil {
		t.Fatal(err)
	}
	for _, statement := range []string{
		`UPDATE schema_migrations SET sha256='changed' WHERE name='001_initial.sql'`,
		`UPDATE schema_migrations SET sha256='` + digest + `' WHERE name='001_initial.sql'; INSERT INTO schema_migrations(name,sha256) VALUES('999_future.sql','future')`,
		`DELETE FROM schema_migrations WHERE name IN ('999_future.sql','001_initial.sql')`,
	} {
		if _, err := f.admin.Exec(f.ctx, statement); err != nil {
			t.Fatal(err)
		}
		if err := online.CheckMigrations(f.ctx, f.app); err == nil {
			t.Fatal("changed, extra or missing migration passed read-only startup")
		}
	}
	t.Log("read-only startup rejected changed checksum, future migration and missing history")
}

type testAPI struct {
	t      *testing.T
	server *httptest.Server
}

func newAPI(t *testing.T, db *pgxpool.Pool) *testAPI {
	t.Helper()
	var logs bytes.Buffer
	app, err := online.NewServer(db, online.Config{ContentVersion: "dbops-v1", PasswordCost: bcrypt.MinCost, Logger: slog.New(slog.NewTextHandler(&logs, nil))})
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(app)
	t.Cleanup(func() {
		server.Close()
		if t.Failed() && logs.Len() > 0 {
			t.Log(logs.String())
		}
	})
	return &testAPI{t, server}
}

func (a *testAPI) request(status int, method, path, token, key string, body any) map[string]any {
	a.t.Helper()
	data, _ := json.Marshal(body)
	request, _ := http.NewRequest(method, a.server.URL+path, bytes.NewReader(data))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Content-Version", "dbops-v1")
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	if key != "" {
		request.Header.Set("Idempotency-Key", key)
	}
	response, err := a.server.Client().Do(request)
	if err != nil {
		a.t.Fatal("test HTTP request failed")
	}
	defer response.Body.Close()
	var envelope struct {
		Data map[string]any `json:"data"`
	}
	if err := json.NewDecoder(response.Body).Decode(&envelope); err != nil {
		a.t.Fatal("test HTTP reply invalid")
	}
	if response.StatusCode != status {
		a.t.Fatalf("%s %s: expected %d, got %d", method, path, status, response.StatusCode)
	}
	return envelope.Data
}

func createTestCharacter(t *testing.T, db *pgxpool.Pool) (*testAPI, map[string]any, string) {
	a := newAPI(t, db)
	pair := a.request(201, "POST", "/v1/auth/register", "", "", map[string]any{"username": "backup_account", "password": "test-password-long"})
	token := pair["access_token"].(string)
	created := a.request(201, "POST", "/v1/characters", token, "backup-create-001", map[string]any{"nickname": "恢复旅人", "role_id": "zs", "appearance_id": "default"})
	id := created["character"].(map[string]any)["id"].(string)
	a.request(200, "POST", "/v1/characters/"+id+"/select", token, "backup-select-001", map[string]any{})
	return a, pair, id
}

func TestRestrictedRoleServesAccountRecoveryAndCharacterTransactions(t *testing.T) {
	f := newFixture(t)
	a, pair, id := createTestCharacter(t, f.app)
	token := pair["access_token"].(string)
	a.request(201, "POST", "/v1/characters", token, "backup-create-001", map[string]any{"nickname": "恢复旅人", "role_id": "zs", "appearance_id": "default"})
	a.request(200, "DELETE", "/v1/characters/"+id, token, "backup-delete-001", map[string]any{"confirm_nickname": "恢复旅人"})
	a.request(200, "POST", "/v1/characters/"+id+"/restore", token, "backup-restore-001", map[string]any{})
	a.request(200, "POST", "/v1/auth/recover", "", "", map[string]any{"username": "backup_account", "recovery_code": pair["recovery_code"], "password": "new-password-long"})
	a.request(401, "GET", "/v1/session", token, "", nil)
	login := a.request(200, "POST", "/v1/auth/login", "", "", map[string]any{"username": "backup_account", "password": "new-password-long"})
	a.request(200, "POST", "/v1/auth/logout", login["access_token"].(string), "", map[string]any{})
	var gold, ledger, events int
	if err := f.admin.QueryRow(f.ctx, `SELECT (SELECT gold FROM wallets),(SELECT count(*) FROM wallet_ledger),(SELECT count(*) FROM audit_events)`).Scan(&gold, &ledger, &events); err != nil || gold != 100 || ledger != 1 || events != 4 {
		t.Fatal("restricted API transaction assets or audit count mismatch")
	}
	t.Log("real restricted-role HTTP register/create/idempotent retry/select/delete/restore/password recovery/logout preserved one starter ledger")
}

func pgBin(t *testing.T) string {
	t.Helper()
	if path := os.Getenv("YUANZHENG_TEST_PG_BIN"); path != "" {
		return path
	}
	root, err := filepath.Abs(filepath.Join("..", "..", "..", "..", "tools", "online-runtime", "pgsql", "bin"))
	if err != nil {
		t.Fatal(err)
	}
	return root
}
