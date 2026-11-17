package online

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"sync"
	"testing"
)

func decodedCharacter(t *testing.T, a answer) Character {
	t.Helper()
	var character Character
	if err := json.Unmarshal(a.data["character"], &character); err != nil {
		t.Fatal("character response is unreadable")
	}
	return character
}

func TestCharacterIdentityWhitelistRecoveryAndPublicRoom(t *testing.T) {
	h := setupTown(t, 24)
	a := h.register("identity_first").value("access_token")
	for i, fields := range []map[string]any{
		{"gender_id": "administrator"}, {"gender_id": "女"}, {"avatar_id": "user://avatars/private.png"},
		{"avatar_id": "https://example.com/avatar.png"}, {"avatar_id": "../../private"}, {"avatar_custom": "private.png"}, {"gold": 999999},
	} {
		fields["nickname"], fields["role_id"], fields["appearance_id"] = "拒绝旅人", "zs", "default"
		requireStatus(t, h.request("POST", "/v1/characters", a, "invalid-identity-"+string(rune('a'+i)), fields), 400)
	}
	if h.count("SELECT count(*) FROM characters") != 0 || h.count("SELECT count(*) FROM wallet_ledger") != 0 {
		t.Fatal("invalid identity mutated characters or assets")
	}
	created := h.request("POST", "/v1/characters", a, "identity-create-a", createCharacterBody{Nickname: "同行小像甲", RoleID: "zs", AppearanceID: "default", GenderID: "female", AvatarID: "role_fs"})
	requireStatus(t, created, 201)
	id := created.characterID()
	character := decodedCharacter(t, created)
	if character.GenderID != "female" || character.AvatarID != "role_fs" || character.RoleID != "zs" {
		t.Fatal("display identity changed profession or was not persisted")
	}
	requireStatus(t, h.request("DELETE", "/v1/characters/"+id, a, "identity-delete-a", map[string]string{"confirm_nickname": "同行小像甲"}), 200)
	deleted := h.request("GET", "/v1/characters/deleted", a, "", nil)
	var recoverable []Character
	if err := json.Unmarshal(deleted.data["characters"], &recoverable); err != nil || len(recoverable) != 1 || recoverable[0].GenderID != "female" || recoverable[0].AvatarID != "role_fs" {
		t.Fatal("recovery list lost display identity")
	}
	restored := h.request("POST", "/v1/characters/"+id+"/restore", a, "identity-restore-a", map[string]any{})
	requireStatus(t, restored, 200)
	if restoredCharacter := decodedCharacter(t, restored); restoredCharacter.ID != id || restoredCharacter.AvatarID != "role_fs" || restoredCharacter.GenderID != "female" {
		t.Fatal("restore replaced character identity")
	}
	requireStatus(t, h.request("POST", "/v1/characters/"+id+"/select", a, "identity-select-a", map[string]any{}), 200)
	requireStatus(t, h.request("POST", "/v1/rooms/join", a, "identity-join-a", map[string]any{}), 200)
	b, _, _ := h.townRole("id_other")
	snapshot := h.request("GET", "/v1/rooms/current", b, "", nil)
	requireStatus(t, snapshot, 200)
	var entities []map[string]any
	if err := json.Unmarshal(snapshot.data["entities"], &entities); err != nil || len(entities) != 2 {
		t.Fatal("public identity snapshot missing real room occupants")
	}
	found := false
	for _, entity := range entities {
		if _, exists := entity["account_id"]; exists {
			t.Fatal("private account identity exposed in room")
		}
		if entity["id"] == id {
			found = entity["gender_id"] == "female" && entity["avatar_id"] == "role_fs" && entity["role_id"] == "zs" && entity["level"] == float64(1)
		}
	}
	if !found || h.count("SELECT sum(gold) FROM wallets") != 200 || h.count("SELECT count(*) FROM wallet_ledger") != 2 {
		t.Fatal("room display identity or independent asset boundary failed")
	}
	manifest := h.request("GET", "/v1/manifest", "", "", nil)
	var genders, avatars []string
	if json.Unmarshal(manifest.data["gender_ids"], &genders) != nil || json.Unmarshal(manifest.data["avatar_ids"], &avatars) != nil || len(genders) != 3 || len(avatars) != 5 {
		t.Fatal("manifest did not publish the display whitelist")
	}
}

func TestCharacterIdentityMigrationPreservesLegacyReceiptAndAssets(t *testing.T) {
	h := setup(t)
	token := h.register("identity_legacy").value("access_token")
	ctx := context.Background()
	// This isolated schema is returned to the actual 003 column/history shape.
	// No production migration is edited or rolled back by the application.
	if _, err := h.db.Exec(ctx, `ALTER TABLE characters DROP COLUMN gender_id, DROP COLUMN avatar_id; DELETE FROM schema_migrations WHERE name='004_character_identity.sql'`); err != nil {
		t.Fatal(err)
	}
	var account string
	if err := h.db.QueryRow(ctx, `SELECT id::text FROM accounts WHERE username='identity_legacy'`).Scan(&account); err != nil {
		t.Fatal(err)
	}
	id := newID()
	body := testCharacterBody("旧日旅人", "zs", "default")
	canonical, _ := json.Marshal(body)
	if string(canonical) != `{"nickname":"旧日旅人","role_id":"zs","appearance_id":"default"}` {
		t.Fatal("legacy request canonical bytes changed")
	}
	digest := sha256.Sum256(canonical)
	legacyResponse, _ := json.Marshal(map[string]any{"character": map[string]any{"id": id, "nickname": "旧日旅人", "role_id": "zs", "appearance_id": "default", "level": 7, "experience": 650, "map_id": "lorin_wilds", "version": 1}, "imported_assets": false})
	statements := []struct {
		sql  string
		args []any
	}{
		{`INSERT INTO characters(id,account_id,nickname,nickname_key,role_id,level,experience) VALUES($1,$2,'旧日旅人','旧日旅人','zs',7,650)`, []any{id, account}},
		{`INSERT INTO wallets(character_id,gold) VALUES($1,237)`, []any{id}},
		{`INSERT INTO character_progress(character_id) VALUES($1)`, []any{id}},
		{`INSERT INTO wallet_ledger(id,character_id,transaction_id,currency,delta,balance_after,reason) VALUES($1,$2,'legacy-starter','gold',100,100,'online_starter'),($3,$2,'legacy-reward','gold',137,237,'legacy_fixture_reward')`, []any{newID(), id, newID()}},
		{`INSERT INTO command_receipts(account_id,operation,request_id,payload_hash,response) VALUES($1,'character.create','identity-legacy-key',$2,$3)`, []any{account, digest[:], legacyResponse}},
	}
	for _, statement := range statements {
		if _, err := h.db.Exec(ctx, statement.sql, statement.args...); err != nil {
			t.Fatal(err)
		}
	}
	if err := Migrate(ctx, h.db); err != nil {
		t.Fatal(err)
	}
	if err := CheckMigrations(ctx, h.db); err != nil {
		t.Fatal(err)
	}
	detail := h.request("GET", "/v1/characters/"+id, token, "", nil)
	requireStatus(t, detail, 200)
	character := decodedCharacter(t, detail)
	if character.GenderID != "unspecified" || character.AvatarID != "role_default" || character.Level != 7 || character.Experience != 650 {
		t.Fatal("migration inferred or reset legacy identity/growth")
	}
	for _, request := range []any{body, map[string]any{"nickname": "旧日旅人", "role_id": "zs", "appearance_id": "default", "gender_id": "unspecified", "avatar_id": "role_default"}} {
		replayed := h.request("POST", "/v1/characters", token, "identity-legacy-key", request)
		requireStatus(t, replayed, 201)
		var raw map[string]any
		_ = json.Unmarshal(replayed.data["character"], &raw)
		if raw["id"] != id || raw["gender_id"] != nil || raw["avatar_id"] != nil {
			t.Fatal("legacy receipt was replaced instead of replayed unchanged")
		}
	}
	requireStatus(t, h.request("POST", "/v1/characters", token, "identity-legacy-key", createCharacterBody{Nickname: "旧日旅人", RoleID: "zs", AppearanceID: "default", GenderID: "male"}), 409)
	if h.count("SELECT count(*) FROM characters") != 1 || h.count("SELECT gold FROM wallets") != 237 || h.count("SELECT count(*) FROM wallet_ledger") != 2 {
		t.Fatal("legacy retry or migration duplicated/reset assets")
	}
	for _, statement := range []string{`UPDATE characters SET gender_id='unapproved'`, `UPDATE characters SET avatar_id='user://private.png'`} {
		if _, err := h.db.Exec(ctx, statement); err == nil {
			t.Fatal("database identity whitelist bypassed")
		}
	}
}

func TestCharacterIdentityConcurrentReceiptAndDefaultAliases(t *testing.T) {
	h := setup(t)
	token := h.register("identity_retry").value("access_token")
	body := createCharacterBody{Nickname: "同心旅人", RoleID: "ck", AppearanceID: "default", GenderID: "male", AvatarID: "role_fz"}
	results := make(chan answer, 8)
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results <- h.request("POST", "/v1/characters", token, "identity-concurrent", body)
		}()
	}
	wg.Wait()
	close(results)
	id := ""
	for result := range results {
		requireStatus(t, result, 201)
		if id == "" {
			id = result.characterID()
		}
		if result.characterID() != id {
			t.Fatal("identity retry created distinct characters")
		}
	}
	body.AvatarID = "role_fs"
	requireStatus(t, h.request("POST", "/v1/characters", token, "identity-concurrent", body), 409)
	defaultBody := testCharacterBody("默认旅人", "fs", "default")
	first := h.request("POST", "/v1/characters", token, "identity-defaults", defaultBody)
	requireStatus(t, first, 201)
	defaultBody.GenderID, defaultBody.AvatarID = "unspecified", "role_default"
	again := h.request("POST", "/v1/characters", token, "identity-defaults", defaultBody)
	requireStatus(t, again, 201)
	if again.characterID() != first.characterID() || h.count("SELECT count(*) FROM characters") != 2 || h.count("SELECT count(*) FROM wallet_ledger") != 2 || h.count("SELECT sum(gold) FROM wallets") != 200 {
		t.Fatal("default identity alias changed idempotency or assets")
	}
}
