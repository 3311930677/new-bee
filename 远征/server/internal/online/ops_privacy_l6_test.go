package online

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestL6PrivacySummaryExportAndErasure(t *testing.T) {
	h := setup(t)
	reg := h.register("l6privuser")
	tok := reg.value("access_token")
	ref := reg.value("refresh_token")
	recoveryCode := reg.value("recovery_code")

	createRes := h.request("POST", "/v1/characters", tok, "l6char01", testCharacterBody("隐风侠", "zs", "default"))
	requireStatus(t, createRes, http.StatusCreated)
	charID := createRes.characterID()

	sumRes := h.request("GET", "/v1/account/privacy/summary", tok, "", nil)
	requireStatus(t, sumRes, http.StatusOK)
	if sumRes.value("status") != "active" || sumRes.value("username") != "l6privuser" {
		t.Fatalf("unexpected privacy summary: %s", sumRes.body)
	}

	expRes := h.request("GET", "/v1/account/privacy/export", tok, "", nil)
	requireStatus(t, expRes, http.StatusOK)
	rawExport := string(expRes.body)
	if !strings.Contains(rawExport, "l6privuser") || !strings.Contains(rawExport, "隐风侠") || !strings.Contains(rawExport, charID) {
		t.Fatalf("privacy export missing expected account/character fields: %s", rawExport)
	}
	for _, secretField := range []string{"password_hash", "recovery_salt", "recovery_hash"} {
		if strings.Contains(rawExport, secretField) {
			t.Fatalf("privacy export leaked internal credential field %q", secretField)
		}
	}

	badConf := h.request("POST", "/v1/account/privacy/delete", tok, "", map[string]string{
		"password":     "long-test-password",
		"confirmation": "NOPE",
	})
	requireStatus(t, badConf, http.StatusBadRequest)

	badPass := h.request("POST", "/v1/account/privacy/delete", tok, "", map[string]string{
		"password":     "wrong-password-attempt",
		"confirmation": "DELETE",
	})
	requireStatus(t, badPass, http.StatusUnauthorized)

	delRes := h.request("POST", "/v1/account/privacy/delete", tok, "", map[string]string{
		"password":     "long-test-password",
		"confirmation": "DELETE",
	})
	requireStatus(t, delRes, http.StatusOK)
	if delRes.value("status") != "erased" {
		t.Fatalf("expected erased status, got %s", delRes.body)
	}

	// Revoked session, erased login, recovery, and refresh must all fail cleanly.
	requireStatus(t, h.request("GET", "/v1/account/privacy/summary", tok, "", nil), http.StatusUnauthorized)
	requireStatus(t, h.request("POST", "/v1/auth/login", "", "", credentials{"l6privuser", "long-test-password"}), http.StatusUnauthorized)
	requireStatus(t, h.request("POST", "/v1/auth/recover", "", "", map[string]string{
		"username":      "l6privuser",
		"recovery_code": recoveryCode,
		"password":      "new-long-test-password",
	}), http.StatusUnauthorized)
	requireStatus(t, h.request("POST", "/v1/auth/refresh", "", "", map[string]string{"refresh_token": ref}), http.StatusUnauthorized)

	var acctStatus, dbUsername string
	var hasRecovery bool
	if err := h.db.QueryRow(context.Background(), `SELECT status, username, recovery_hash IS NOT NULL FROM accounts`).Scan(&acctStatus, &dbUsername, &hasRecovery); err != nil {
		t.Fatal(err)
	}
	if acctStatus != "erased" || !strings.HasPrefix(dbUsername, "erased_") || hasRecovery {
		t.Fatalf("unexpected erased account state: status=%s username=%s hasRecovery=%v", acctStatus, dbUsername, hasRecovery)
	}
	var charNickname string
	var charDeleted bool
	if err := h.db.QueryRow(context.Background(), `SELECT nickname, deleted_at IS NOT NULL FROM characters WHERE id=$1`, charID).Scan(&charNickname, &charDeleted); err != nil {
		t.Fatal(err)
	}
	if !charDeleted || !strings.HasPrefix(charNickname, "已注销_") {
		t.Fatalf("expected anonymized soft-deleted character, got nickname=%s deleted=%v", charNickname, charDeleted)
	}
	if h.count(`SELECT count(*) FROM account_privacy_requests WHERE request_type='export'`) != 1 ||
		h.count(`SELECT count(*) FROM account_privacy_requests WHERE request_type='erasure'`) != 1 {
		t.Fatalf("expected 1 export and 1 erasure audit row")
	}
}

func TestL6LoopbackOpsModerationCapacityAndMarketPause(t *testing.T) {
	h := setupL2World(t)
	tokA, _, _ := h.townCharacterWithRole(t, "l6opsa", "zs", 1, false)
	_, charB, _ := h.townCharacterWithRole(t, "l6opsb", "fs", 1, false)

	reportRes := h.request("POST", "/v1/social/reports", tokA, "l6rep001", map[string]any{
		"target_character_id": charB,
		"category":            "spam",
		"reason":              "刷屏广告测试举报",
	})
	requireStatus(t, reportRes, http.StatusCreated)
	reportID := reportRes.value("report_id")

	app := h.server.Config.Handler.(*Server)
	adminToken := strings.Repeat("A", 32)
	adminHandler, err := app.AdminHandler(adminToken)
	if err != nil {
		t.Fatal(err)
	}
	adminSrv := httptest.NewServer(adminHandler)
	t.Cleanup(adminSrv.Close)

	opsReq := func(method, path, token string, body any) (int, map[string]json.RawMessage, string) {
		var reader io.Reader
		if body != nil {
			raw, _ := json.Marshal(body)
			reader = bytes.NewReader(raw)
		}
		req, err := http.NewRequest(method, adminSrv.URL+path, reader)
		if err != nil {
			t.Fatal(err)
		}
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		res, err := adminSrv.Client().Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer res.Body.Close()
		raw, _ := io.ReadAll(res.Body)
		var env struct {
			Data map[string]json.RawMessage `json:"data"`
		}
		_ = json.Unmarshal(raw, &env)
		return res.StatusCode, env.Data, string(raw)
	}

	// Unauthorized access rejected.
	if st, _, _ := opsReq("GET", "/ops/capacity", "", nil); st != http.StatusUnauthorized {
		t.Fatalf("expected 401 for unauthenticated /ops/capacity, got %d", st)
	}
	if st, _, _ := opsReq("GET", "/ops/reports", "wrong-token", nil); st != http.StatusUnauthorized {
		t.Fatalf("expected 401 for bad admin token, got %d", st)
	}

	// Open reports list contains the report.
	st, data, raw := opsReq("GET", "/ops/reports?status=open", adminToken, nil)
	if st != http.StatusOK || !strings.Contains(raw, reportID) {
		t.Fatalf("expected report %s in open list, got %d %s", reportID, st, raw)
	}

	// Resolve report via append-only moderation_actions.
	st, _, raw = opsReq("POST", "/ops/reports/"+reportID+"/resolve", adminToken, map[string]any{
		"operator": "oncall_admin",
		"decision": "warned",
		"note":     "已核实并记录警告",
	})
	if st != http.StatusOK || !strings.Contains(raw, `"decision":"warned"`) {
		t.Fatalf("resolve failed: %d %s", st, raw)
	}

	// Open filter now empty; resolved filter shows warned.
	st, _, raw = opsReq("GET", "/ops/reports?status=open", adminToken, nil)
	if st != http.StatusOK || strings.Contains(raw, reportID) {
		t.Fatalf("resolved report remained in open queue: %d %s", st, raw)
	}
	st, _, raw = opsReq("GET", "/ops/reports?status=resolved", adminToken, nil)
	if st != http.StatusOK || !strings.Contains(raw, reportID) || !strings.Contains(raw, `"warned"`) {
		t.Fatalf("resolved report missing from resolved list: %d %s", st, raw)
	}

	// Trigger blocks UPDATE on moderation_actions.
	if _, err := h.db.Exec(context.Background(), `UPDATE moderation_actions SET decision='dismissed' WHERE report_id=$1`, reportID); err == nil {
		t.Fatal("moderation_actions allowed update despite append-only trigger")
	}

	// Toggle market pause via loopback ops and verify public traffic reacts immediately.
	st, _, raw = opsReq("POST", "/ops/config/market-pause", adminToken, map[string]any{
		"paused": true,
		"reason": "emergency_l6_drill",
	})
	if st != http.StatusOK || !strings.Contains(raw, `"market_paused":true`) {
		t.Fatalf("market pause toggle failed: %d %s", st, raw)
	}
	pausedBuy := h.request("POST", "/v1/market/npc/trade", tokA, "l6pausebuy1", map[string]any{
		"action": "buy", "template_id": "mat_grain", "quantity": 1,
	})
	if pausedBuy.status != http.StatusServiceUnavailable || pausedBuy.code != "market_paused" {
		t.Fatalf("expected 503 market_paused, got %d %s", pausedBuy.status, pausedBuy.body)
	}

	// Capacity snapshot reflects leases and paused state cleanly.
	st, data, raw = opsReq("GET", "/ops/capacity", adminToken, nil)
	if st != http.StatusOK || !strings.Contains(raw, `"market_paused":true`) {
		t.Fatalf("capacity failed: %d %s", st, raw)
	}
	var leases int64
	_ = json.Unmarshal(data["active_room_leases"], &leases)
	if leases < 2 {
		t.Fatalf("expected at least 2 active room leases in capacity output, got %s", raw)
	}

	st, _, raw = opsReq("POST", "/ops/config/market-pause", adminToken, map[string]any{
		"paused": false,
		"reason": "drill_complete",
	})
	if st != http.StatusOK || !strings.Contains(raw, `"market_paused":false`) {
		t.Fatalf("market resume toggle failed: %d %s", st, raw)
	}
}

func TestL6SchemaRollbackFailClosed(t *testing.T) {
	h := setup(t)
	if _, err := h.db.Exec(context.Background(), `INSERT INTO schema_migrations(name,sha256) VALUES('999_future_l7.sql',repeat('f',64))`); err != nil {
		t.Fatal(err)
	}
	if err := CheckMigrations(context.Background(), h.db); err == nil {
		t.Fatal("older binary accepted database with unknown forward migration")
	}
}
