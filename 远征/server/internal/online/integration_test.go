package online

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

type harness struct {
	db     *pgxpool.Pool
	server *httptest.Server
	t      *testing.T
}
type answer struct {
	status int
	data   map[string]json.RawMessage
	code   string
	body   []byte
}

func (a answer) value(key string) string {
	var value string
	_ = json.Unmarshal(a.data[key], &value)
	return value
}
func (a answer) characterID() string {
	var c Character
	_ = json.Unmarshal(a.data["character"], &c)
	return c.ID
}

func setup(t *testing.T) *harness {
	return setupWithConfig(t, Config{ContentVersion: "integration-v1", PasswordCost: bcrypt.MinCost})
}
func setupWithConfig(t *testing.T, appConfig Config) *harness {
	t.Helper()
	dsn := os.Getenv("YUANZHENG_TEST_DATABASE_URL")
	if dsn == "" {
		t.Fatal("YUANZHENG_TEST_DATABASE_URL is required: integration tests never silently skip PostgreSQL")
	}
	ctx := context.Background()
	admin, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	schema := "test_" + strings.ReplaceAll(newID(), "-", "")
	if _, err = admin.Exec(ctx, "CREATE SCHEMA "+pgx.Identifier{schema}.Sanitize()); err != nil {
		t.Fatal(err)
	}
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		t.Fatal(err)
	}
	cfg.ConnConfig.RuntimeParams["search_path"] = schema
	cfg.MaxConns = 20
	db, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		db.Close()
		_, _ = admin.Exec(ctx, "DROP SCHEMA "+pgx.Identifier{schema}.Sanitize()+" CASCADE")
		admin.Close()
	})
	if err = Migrate(ctx, db); err != nil {
		t.Fatal(err)
	}
	if err = Migrate(ctx, db); err != nil {
		t.Fatalf("migration replay: %v", err)
	}
	app, err := NewServer(db, appConfig)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(app)
	t.Cleanup(server.Close)
	return &harness{db, server, t}
}
func (h *harness) request(method, path, token, key string, body any) answer {
	h.t.Helper()
	var data []byte
	if body != nil {
		data, _ = json.Marshal(body)
	}
	req, err := http.NewRequest(method, h.server.URL+path, bytes.NewReader(data))
	if err != nil {
		h.t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Content-Version", "integration-v1")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if key != "" {
		req.Header.Set("Idempotency-Key", key)
	}
	res, err := h.server.Client().Do(req)
	if err != nil {
		h.t.Fatal(err)
	}
	defer res.Body.Close()
	raw, err := io.ReadAll(res.Body)
	if err != nil {
		h.t.Fatal(err)
	}
	var envelope struct {
		Data  map[string]json.RawMessage `json:"data"`
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err = json.Unmarshal(raw, &envelope); err != nil {
		h.t.Fatalf("invalid response: %s", raw)
	}
	return answer{res.StatusCode, envelope.Data, envelope.Error.Code, raw}
}
func (h *harness) register(name string) answer {
	h.t.Helper()
	a := h.request("POST", "/v1/auth/register", "", "", credentials{name, "long-test-password"})
	if a.status != 201 {
		h.t.Fatalf("register: %d %s", a.status, a.body)
	}
	return a
}
func requireStatus(t *testing.T, a answer, status int) {
	t.Helper()
	if a.status != status {
		t.Fatalf("expected %d, got %d: %s", status, a.status, a.body)
	}
}
func (h *harness) count(query string) int {
	h.t.Helper()
	var n int
	if err := h.db.QueryRow(context.Background(), query).Scan(&n); err != nil {
		h.t.Fatal(err)
	}
	return n
}

func TestAccountsSessionsAndRevocation(t *testing.T) {
	h := setup(t)
	first := h.register("first_account")
	token := first.value("access_token")
	var stored []byte
	if err := h.db.QueryRow(context.Background(), `SELECT password_hash FROM accounts`).Scan(&stored); err != nil {
		t.Fatal(err)
	}
	if string(stored) == "long-test-password" || bcrypt.CompareHashAndPassword(stored, []byte("long-test-password")) != nil {
		t.Fatal("password must be bcrypt hashed")
	}
	requireStatus(t, h.request("GET", "/v1/session", token, "", nil), 200)
	requireStatus(t, h.request("POST", "/v1/auth/login", "", "", credentials{"first_account", "wrong"}), 401)
	requireStatus(t, h.request("POST", "/v1/auth/login", "", "", credentials{"missing_user", "wrong"}), 401)
	second := h.request("POST", "/v1/auth/login", "", "", credentials{"FIRST_ACCOUNT", "long-test-password"})
	requireStatus(t, second, 200)
	requireStatus(t, h.request("GET", "/v1/session", token, "", nil), 401)
	requireStatus(t, h.request("POST", "/v1/auth/refresh", "", "", map[string]string{"refresh_token": first.value("refresh_token")}), 401)
	rotated := h.request("POST", "/v1/auth/refresh", "", "", map[string]string{"refresh_token": second.value("refresh_token")})
	requireStatus(t, rotated, 200)
	requireStatus(t, h.request("GET", "/v1/session", second.value("access_token"), "", nil), 401)
	requireStatus(t, h.request("GET", "/v1/session", rotated.value("access_token"), "", nil), 200)
	requireStatus(t, h.request("POST", "/v1/auth/refresh", "", "", map[string]string{"refresh_token": second.value("refresh_token")}), 401)
	requireStatus(t, h.request("POST", "/v1/auth/logout", rotated.value("access_token"), "", map[string]any{}), 200)
	requireStatus(t, h.request("GET", "/v1/session", rotated.value("access_token"), "", nil), 401)
	requireStatus(t, h.request("POST", "/v1/auth/refresh", "", "", map[string]string{"refresh_token": rotated.value("refresh_token")}), 401)
}

func TestConcurrentCreateAndReceiptSurvivesRestart(t *testing.T) {
	h := setup(t)
	account := h.register("creator_account")
	token := account.value("access_token")
	body := createCharacterBody{"并肩旅人", "zs", "default"}
	const workers = 16
	answers := make(chan answer, workers)
	var wg sync.WaitGroup
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			answers <- h.request("POST", "/v1/characters", token, "same-request-001", body)
		}()
	}
	wg.Wait()
	close(answers)
	id := ""
	for a := range answers {
		requireStatus(t, a, 201)
		if id == "" {
			id = a.characterID()
		}
		if a.characterID() != id {
			t.Fatal("duplicate request created a different role")
		}
	}
	for _, table := range []string{"characters", "wallets", "wallet_ledger", "command_receipts", "character_progress", "audit_events"} {
		if n := h.count("SELECT count(*) FROM " + table); n != 1 {
			t.Fatalf("%s has %d rows, expected one", table, n)
		}
	}
	if n := h.count("SELECT gold FROM wallets"); n != 100 {
		t.Fatalf("starter gold %d", n)
	}
	body.Nickname = "别的旅人"
	a := h.request("POST", "/v1/characters", token, "same-request-001", body)
	requireStatus(t, a, 409)
	if a.code != "request_id_conflict" {
		t.Fatal(a.code)
	}
	app, err := NewServer(h.db, Config{ContentVersion: "integration-v1", PasswordCost: bcrypt.MinCost})
	if err != nil {
		t.Fatal(err)
	}
	h.server.Close()
	h.server = httptest.NewServer(app)
	t.Cleanup(h.server.Close)
	body.Nickname = "并肩旅人"
	a = h.request("POST", "/v1/characters", token, "same-request-001", body)
	requireStatus(t, a, 201)
	if a.characterID() != id {
		t.Fatal("restart lost persisted command receipt")
	}
}

func TestCharacterLimitOwnershipAndUntrustedAssets(t *testing.T) {
	h := setup(t)
	first := h.register("owner_account")
	token := first.value("access_token")
	a := h.request("POST", "/v1/characters", token, "create-first-001", createCharacterBody{"归路旅人", "fs", "default"})
	requireStatus(t, a, 201)
	id := a.characterID()
	requireStatus(t, h.request("POST", "/v1/characters", token, "injected-assets-01", map[string]any{"nickname": "改档旅人", "role_id": "zs", "wallet": map[string]int{"gold": 999999}}), 400)
	requireStatus(t, h.request("POST", "/v1/characters", token, "bad-appearance-01", createCharacterBody{"稀有旅人", "zs", "unapproved"}), 400)
	requireStatus(t, h.request("POST", "/v1/characters", token, "bad-role-0000001", createCharacterBody{"无效旅人", "gm", "default"}), 400)
	requireStatus(t, h.request("POST", "/v1/characters", token, "", createCharacterBody{"无标旅人", "zs", "default"}), 400)
	second := h.register("other_account")
	other := second.value("access_token")
	requireStatus(t, h.request("GET", "/v1/characters/"+id, other, "", nil), 404)
	requireStatus(t, h.request("POST", "/v1/characters/"+id+"/select", other, "select-other-001", map[string]any{}), 404)
	requireStatus(t, h.request("POST", "/v1/characters", other, "duplicate-name-001", createCharacterBody{"归路旅人", "ck", "default"}), 409)
	for _, entry := range []struct{ name, key string }{{"第二旅人", "create-second-01"}, {"第三旅人", "create-third-001"}} {
		requireStatus(t, h.request("POST", "/v1/characters", token, entry.key, createCharacterBody{entry.name, "ck", "default"}), 201)
	}
	requireStatus(t, h.request("POST", "/v1/characters", token, "create-fourth-01", createCharacterBody{"第四旅人", "fz", "default"}), 409)
	requireStatus(t, h.request("POST", "/v1/characters/"+id+"/select", token, "select-first-01", map[string]any{}), 200)
	current := h.request("GET", "/v1/session", token, "", nil)
	requireStatus(t, current, 200)
	if current.value("active_character_id") != id {
		t.Fatal("selection not saved on authoritative session")
	}
	if n := h.count("SELECT count(*) FROM wallets WHERE gold<>100"); n != 0 {
		t.Fatal("untrusted state changed a wallet")
	}
}

func TestRollbackOnLedgerFailureAndRetry(t *testing.T) {
	h := setup(t)
	token := h.register("rollback_account").value("access_token")
	_, err := h.db.Exec(context.Background(), `CREATE FUNCTION reject_ledger() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'injected write failure'; END $$; CREATE TRIGGER fail_ledger BEFORE INSERT ON wallet_ledger FOR EACH ROW EXECUTE FUNCTION reject_ledger()`)
	if err != nil {
		t.Fatal(err)
	}
	body := createCharacterBody{"重试旅人", "fz", "default"}
	requireStatus(t, h.request("POST", "/v1/characters", token, "rollback-request-01", body), 500)
	for _, table := range []string{"characters", "wallets", "wallet_ledger", "command_receipts", "character_progress"} {
		if n := h.count("SELECT count(*) FROM " + table); n != 0 {
			t.Fatalf("failed transaction left %s rows", table)
		}
	}
	if _, err = h.db.Exec(context.Background(), `DROP TRIGGER fail_ledger ON wallet_ledger`); err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.request("POST", "/v1/characters", token, "rollback-request-01", body), 201)
	if n := h.count("SELECT count(*) FROM wallet_ledger"); n != 1 {
		t.Fatal("retry did not produce exactly one ledger entry")
	}
}

func TestExpiredTokensAndConcurrentRefresh(t *testing.T) {
	h := setup(t)
	account := h.register("refresh_account")
	if _, err := h.db.Exec(context.Background(), `UPDATE sessions SET access_expires_at=now()-interval '1 second'`); err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.request("GET", "/v1/session", account.value("access_token"), "", nil), 401)
	results := make(chan answer, 2)
	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results <- h.request("POST", "/v1/auth/refresh", "", "", map[string]string{"refresh_token": account.value("refresh_token")})
		}()
	}
	wg.Wait()
	close(results)
	success, failure := 0, 0
	for a := range results {
		if a.status == 200 {
			success++
		} else if a.status == 401 {
			failure++
		} else {
			t.Fatalf("unexpected %d", a.status)
		}
	}
	if success != 1 || failure != 1 {
		t.Fatalf("refresh rotation allowed %d successes/%d rejects", success, failure)
	}
}

func TestVersionGateAndLimits(t *testing.T) {
	h := setup(t)
	token := h.register("version_account").value("access_token")
	req, _ := http.NewRequest("POST", h.server.URL+"/v1/characters", strings.NewReader(`{"nickname":"旧版旅人","role_id":"zs"}`))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Idempotency-Key", "version-test-001")
	response, err := h.server.Client().Do(req)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 409 {
		t.Fatal("missing content version was accepted")
	}
	if n := h.count("SELECT count(*) FROM characters"); n != 0 {
		t.Fatal("version mismatch mutated state")
	}
	var limiter rateLimiter
	for i := 0; i < 30; i++ {
		if !limiter.allow("address", 30, time.Minute) {
			t.Fatal("limit rejected early")
		}
	}
	if limiter.allow("address", 30, time.Minute) {
		t.Fatal("limit did not reject flood")
	}
}

func TestDeleteRecoveryAndImmutableLedger(t *testing.T) {
	h := setup(t)
	token := h.register("recovery_account").value("access_token")
	created := h.request("POST", "/v1/characters", token, "recovery-create-01", createCharacterBody{"待归旅人", "zs", "default"})
	requireStatus(t, created, 201)
	id := created.characterID()
	requireStatus(t, h.request("POST", "/v1/characters/"+id+"/select", token, "recovery-select-01", map[string]any{}), 200)
	requireStatus(t, h.request("DELETE", "/v1/characters/"+id, token, "bad-delete-00001", map[string]string{"confirm_nickname": "wrong"}), 400)
	requireStatus(t, h.request("DELETE", "/v1/characters/"+id, token, "recovery-delete-01", map[string]string{"confirm_nickname": "待归旅人"}), 200)
	requireStatus(t, h.request("DELETE", "/v1/characters/"+id, token, "recovery-delete-01", map[string]string{"confirm_nickname": "待归旅人"}), 200)
	requireStatus(t, h.request("GET", "/v1/characters/"+id, token, "", nil), 404)
	if current := h.request("GET", "/v1/session", token, "", nil); current.value("active_character_id") != "" {
		t.Fatal("deleted character remained selected")
	}
	if h.count("SELECT gold FROM wallets") != 100 {
		t.Fatal("soft delete lost assets")
	}
	requireStatus(t, h.request("POST", "/v1/characters/"+id+"/restore", token, "recovery-restore-01", map[string]any{}), 200)
	requireStatus(t, h.request("GET", "/v1/characters/"+id, token, "", nil), 200)
	if _, err := h.db.Exec(context.Background(), `UPDATE wallet_ledger SET delta=9999`); err == nil {
		t.Fatal("ledger update allowed")
	}
	if _, err := h.db.Exec(context.Background(), `DELETE FROM wallet_ledger`); err == nil {
		t.Fatal("ledger delete allowed")
	}
	if h.count("SELECT delta FROM wallet_ledger") != 100 {
		t.Fatal("immutable ledger changed")
	}
	if _, err := h.db.Exec(context.Background(), `UPDATE characters SET deleted_at=now()-interval '8 days'`); err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.request("POST", "/v1/characters/"+id+"/restore", token, "expired-restore-01", map[string]any{}), 404)
}

func TestConcurrentDistinctCharacterLimit(t *testing.T) {
	h := setup(t)
	token := h.register("limit_account").value("access_token")
	results := make(chan answer, 8)
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			suffix := string(rune('a' + index))
			results <- h.request("POST", "/v1/characters", token, "distinct-create-"+suffix, createCharacterBody{"并发旅人" + suffix, "zs", "default"})
		}(i)
	}
	wg.Wait()
	close(results)
	created, rejected := 0, 0
	for answer := range results {
		if answer.status == 201 {
			created++
		} else if answer.status == 409 && answer.code == "character_limit" {
			rejected++
		} else {
			t.Fatalf("unexpected status: %d %s", answer.status, answer.body)
		}
	}
	if created != 3 || rejected != 5 || h.count("SELECT count(*) FROM characters") != 3 || h.count("SELECT sum(gold) FROM wallets") != 300 {
		t.Fatalf("concurrent limit failed: %d created, %d rejected", created, rejected)
	}
}
