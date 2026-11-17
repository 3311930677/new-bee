package online

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"
)

func TestRecoveryCodeHashedRotatedAndRevokesSessions(t *testing.T) {
	h := setup(t)
	registered := h.register("recover_user")
	token, code := registered.value("access_token"), registered.value("recovery_code")
	if len(code) != 47 {
		t.Fatal("registration must issue a printable 256-bit recovery code")
	}
	var salt, hash []byte
	if err := h.db.QueryRow(context.Background(), `SELECT recovery_salt,recovery_hash FROM accounts`).Scan(&salt, &hash); err != nil {
		t.Fatal(err)
	}
	if len(salt) != 32 || len(hash) != 32 || string(hash) == code || !recoveryCodeValid(code, salt, hash) {
		t.Fatal("recovery code was not salted and hashed")
	}
	wrong := h.request("POST", "/v1/auth/recover", "", "", map[string]string{"username": "recover_user", "recovery_code": "wrong-code", "password": "replacement-password"})
	missing := h.request("POST", "/v1/auth/recover", "", "", map[string]string{"username": "no_such_user", "recovery_code": "wrong-code", "password": "replacement-password"})
	requireStatus(t, wrong, 401)
	requireStatus(t, missing, 401)
	if wrong.code != missing.code {
		t.Fatal("recovery enumerates account existence")
	}
	requireStatus(t, h.request("GET", "/v1/session", token, "", nil), 200)
	reset := h.request("POST", "/v1/auth/recover", "", "", map[string]string{"username": "RECOVER_USER", "recovery_code": code, "password": "replacement-password"})
	requireStatus(t, reset, 200)
	newCode := reset.value("recovery_code")
	if len(newCode) != 47 || newCode == code || reset.value("access_token") != "" {
		t.Fatal("reset must rotate recovery code and require ordinary login")
	}
	requireStatus(t, h.request("GET", "/v1/session", token, "", nil), 401)
	requireStatus(t, h.request("POST", "/v1/auth/refresh", "", "", map[string]string{"refresh_token": registered.value("refresh_token")}), 401)
	requireStatus(t, h.request("POST", "/v1/auth/recover", "", "", map[string]string{"username": "recover_user", "recovery_code": code, "password": "another-password"}), 401)
	requireStatus(t, h.request("POST", "/v1/auth/login", "", "", credentials{"recover_user", "long-test-password"}), 401)
	login := h.request("POST", "/v1/auth/login", "", "", credentials{"recover_user", "replacement-password"})
	requireStatus(t, login, 200)
	token = login.value("access_token")
	notices := h.request("GET", "/v1/account/notifications", token, "", nil)
	requireStatus(t, notices, 200)
	var list []struct {
		ID   string `json:"id"`
		Kind string `json:"kind"`
	}
	_ = json.Unmarshal(notices.data["notifications"], &list)
	if len(list) != 1 || list[0].Kind != "password_reset" {
		t.Fatal("reset security notification missing")
	}
	requireStatus(t, h.request("POST", "/v1/account/notifications/"+list[0].ID+"/acknowledge", token, "ack-security-001", map[string]any{}), 200)
	requireStatus(t, h.request("POST", "/v1/account/recovery-code", token, "", map[string]string{"password": "wrong-password"}), 401)
	replaced := h.request("POST", "/v1/account/recovery-code", token, "", map[string]string{"password": "replacement-password"})
	requireStatus(t, replaced, 200)
	if replaced.value("recovery_code") == newCode || len(replaced.value("recovery_code")) != 47 {
		t.Fatal("authenticated replacement failed")
	}
	requireStatus(t, h.request("POST", "/v1/auth/recover", "", "", map[string]string{"username": "recover_user", "recovery_code": newCode, "password": "another-password"}), 401)
	if h.count("SELECT count(*) FROM security_notifications") != 2 || h.count("SELECT count(*) FROM audit_events WHERE action LIKE 'account.%'") != 2 {
		t.Fatal("recovery audit records missing")
	}
}

func TestRecoveryTransactionRollbackAndConcurrentSingleUse(t *testing.T) {
	h := setup(t)
	a := h.register("recover_race")
	code := a.value("recovery_code")
	_, err := h.db.Exec(context.Background(), `CREATE FUNCTION reject_security_event() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'injected notification failure'; END $$; CREATE TRIGGER reject_security_event BEFORE INSERT ON security_notifications FOR EACH ROW EXECUTE FUNCTION reject_security_event()`)
	if err != nil {
		t.Fatal(err)
	}
	body := map[string]string{"username": "recover_race", "recovery_code": code, "password": "recovered-password"}
	requireStatus(t, h.request("POST", "/v1/auth/recover", "", "", body), 500)
	requireStatus(t, h.request("GET", "/v1/session", a.value("access_token"), "", nil), 200)
	if _, err = h.db.Exec(context.Background(), `DROP TRIGGER reject_security_event ON security_notifications`); err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	results := make(chan answer, 3)
	for i := 0; i < 3; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); results <- h.request("POST", "/v1/auth/recover", "", "", body) }()
	}
	wg.Wait()
	close(results)
	success, rejected := 0, 0
	for a := range results {
		if a.status == 200 {
			success++
		} else if a.status == 401 && a.code == "invalid_recovery" {
			rejected++
		} else {
			t.Fatalf("unexpected recovery status: %d", a.status)
		}
	}
	if success != 1 || rejected != 2 || h.count("SELECT count(*) FROM security_notifications") != 1 {
		t.Fatal("concurrent recovery used the same code more than once")
	}
}

func TestCharacterManagementListsOwnershipAndSuggestions(t *testing.T) {
	h := setup(t)
	first := h.register("manager_one").value("access_token")
	second := h.register("manager_two").value("access_token")
	created := h.request("POST", "/v1/characters", first, "management-create", testCharacterBody("远行旅人甲乙丙丁戊己庚辛", "zs", "default"))
	requireStatus(t, created, 201)
	id := created.characterID()
	suggestions := h.request("GET", "/v1/nicknames/suggestions?nickname="+"远行旅人甲乙丙丁戊己庚辛", first, "", nil)
	requireStatus(t, suggestions, 200)
	var names []string
	_ = json.Unmarshal(suggestions.data["suggestions"], &names)
	if len(names) != 3 {
		t.Fatal("expected three available nickname suggestions")
	}
	for _, name := range names {
		if _, _, err := normalizeNickname(name); err != nil {
			t.Fatal("suggestion violates nickname rules")
		}
	}
	requireStatus(t, h.request("DELETE", "/v1/characters/"+id, first, "management-delete", map[string]string{"confirm_nickname": "远行旅人甲乙丙丁戊己庚辛"}), 200)
	for index, token := range []string{first, second} {
		deleted := h.request("GET", "/v1/characters/deleted", token, "", nil)
		requireStatus(t, deleted, 200)
		var list []map[string]any
		_ = json.Unmarshal(deleted.data["characters"], &list)
		if (index == 0 && (len(list) != 1 || list[0]["id"] != id || list[0]["recover_until"] == nil)) || (index == 1 && len(list) != 0) {
			t.Fatal("recoverable list leaked ownership or omitted deadline")
		}
	}
	if _, err := h.db.Exec(context.Background(), `UPDATE characters SET deleted_at=now()-interval '8 days' WHERE id=$1`, id); err != nil {
		t.Fatal(err)
	}
	deleted := h.request("GET", "/v1/characters/deleted", first, "", nil)
	if strings.TrimSpace(string(deleted.data["characters"])) != "[]" {
		t.Fatal("expired recovery appeared in list")
	}
	for i := 0; i < 2; i++ {
		requireStatus(t, h.request("GET", "/v1/nicknames/suggestions?nickname=x", first, "", nil), 400)
	}
}

func TestRecoveryLimitsAndNotificationOwnership(t *testing.T) {
	h := setup(t)
	a := h.register("limited_recovery")
	other := h.register("notice_other").value("access_token")
	for i := 0; i < 5; i++ {
		requireStatus(t, h.request("POST", "/v1/auth/recover", "", "", map[string]string{"username": "limited_recovery", "recovery_code": fmt.Sprintf("bad-code-%d", i), "password": "replacement-password"}), 401)
	}
	requireStatus(t, h.request("POST", "/v1/auth/recover", "", "", map[string]string{"username": "limited_recovery", "recovery_code": a.value("recovery_code"), "password": "replacement-password"}), 429)
	rotated := h.request("POST", "/v1/account/recovery-code", a.value("access_token"), "", map[string]string{"password": "long-test-password"})
	requireStatus(t, rotated, 200)
	var id string
	if err := h.db.QueryRow(context.Background(), `SELECT id::text FROM security_notifications`).Scan(&id); err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.request("POST", "/v1/account/notifications/"+id+"/acknowledge", other, "stolen-notice-001", map[string]any{}), 404)
	requireStatus(t, h.request("POST", "/v1/account/recovery-code", other, "", nil), 400)
	for _, raw := range []string{"null", "[]", "\"not an object\""} {
		requireStatus(t, h.request("POST", "/v1/account/recovery-code", other, "", json.RawMessage(raw)), 400)
	}
	if _, err := h.db.Exec(context.Background(), `UPDATE accounts SET recovery_salt=NULL WHERE username='limited_recovery'`); err == nil {
		t.Fatal("partial recovery digest shape was allowed")
	}
}

func TestPasswordChangeCannotRaceOldPasswordLogin(t *testing.T) {
	h := setup(t)
	h.register("password_race")
	ctx := context.Background()
	tx, err := h.db.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback(ctx)
	var account string
	if err = tx.QueryRow(ctx, `SELECT id::text FROM accounts WHERE username='password_race' FOR UPDATE`).Scan(&account); err != nil {
		t.Fatal(err)
	}
	var blocker int
	if err = tx.QueryRow(ctx, `SELECT pg_backend_pid()`).Scan(&blocker); err != nil {
		t.Fatal(err)
	}
	passwordHash, err := bcrypt.GenerateFromPassword([]byte("new-race-password"), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = tx.Exec(ctx, `UPDATE accounts SET password_hash=$1 WHERE id=$2`, passwordHash, account); err != nil {
		t.Fatal(err)
	}
	result := make(chan answer, 1)
	go func() {
		result <- h.request("POST", "/v1/auth/login", "", "", credentials{"password_race", "long-test-password"})
	}()
	blocked := false
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if err = h.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE $1=ANY(pg_blocking_pids(pid)))`, blocker).Scan(&blocked); err != nil {
			t.Fatal(err)
		}
		if blocked {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if !blocked {
		t.Fatal("login did not reach the concurrent password-change barrier")
	}
	if err = tx.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	requireStatus(t, <-result, 401)
	requireStatus(t, h.request("POST", "/v1/auth/login", "", "", credentials{"password_race", "new-race-password"}), 200)
}

func TestNicknameSuggestionsSurviveExhaustedShortSuffixes(t *testing.T) {
	h := setup(t)
	token := h.register("crowded_nickname").value("access_token")
	// All 10,000 short suffixes are occupied by another account. Insert only
	// this test's fixtures; the public three-role cap remains separately tested.
	if _, err := h.db.Exec(context.Background(), `INSERT INTO characters(id,account_id,nickname,nickname_key,role_id)
		SELECT gen_random_uuid(),id,'同行旅人'||lpad(n::text,4,'0'),'同行旅人'||lpad(n::text,4,'0'),'zs'
		FROM accounts CROSS JOIN generate_series(0,9999) n WHERE username='crowded_nickname'`); err != nil {
		t.Fatal(err)
	}
	answer := h.request("GET", "/v1/nicknames/suggestions?nickname=同行旅人", token, "", nil)
	requireStatus(t, answer, 200)
	var names []string
	if err := json.Unmarshal(answer.data["suggestions"], &names); err != nil {
		t.Fatal(err)
	}
	if len(names) != 3 {
		t.Fatal("crowded prefix did not return three alternatives")
	}
	seen := map[string]bool{}
	for _, name := range names {
		if _, _, err := normalizeNickname(name); err != nil || seen[name] || len([]rune(name)) != 12 {
			t.Fatal("crowded-prefix suggestion is invalid or duplicated")
		}
		seen[name] = true
		var count int
		if err := h.db.QueryRow(context.Background(), `SELECT count(*) FROM characters WHERE nickname_key=$1`, strings.ToLower(name)).Scan(&count); err != nil || count != 0 {
			t.Fatal("suggestion is already occupied")
		}
	}
}

func TestErrorClassificationExcludesDatabaseDetails(t *testing.T) {
	for _, item := range []struct {
		err  error
		want string
	}{
		{fmt.Errorf("wrapped: %w", &pgconn.PgError{Code: "P0001", Message: "secret password", Detail: "private user payload"}), "database_P0001"},
		{&pgconn.PgError{Code: "unsafe user text", Message: "private data"}, "database_error"},
		{&pgconn.ConnectError{}, "database_connection"},
		{pgconn.ErrConnClosed, "database_connection"},
		{context.DeadlineExceeded, "timeout"},
		{errors.New("private internal detail"), "internal"},
	} {
		if got := errorType(item.err); got != item.want {
			t.Fatalf("classification=%q; want %q", got, item.want)
		}
	}
}
