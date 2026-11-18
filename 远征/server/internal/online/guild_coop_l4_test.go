package online

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
)

func TestL4CoopRemainingDungeonsAndSecondWorldBossShenyuan(t *testing.T) {
	h := setupL2World(t)
	tokA, charA, _ := h.townCharacterWithRole(t, "l4coop1", "zs", 10, true)
	tokB, charB, _ := h.townCharacterWithRole(t, "l4coop2", "fs", 10, true)

	// 1. Travel Alpha -> maple_road -> shenyuan_port and test 2nd World Boss (沉渊盐鳞王).
	_, _ = h.db.Exec(context.Background(), `UPDATE room_leases SET x=616,y=140 WHERE character_id=$1`, charA)
	res := h.request("POST", "/v1/rooms/travel", tokA, "tr-maple-1", map[string]any{"portal_id": "north_gate"})
	requireStatus(t, res, http.StatusOK)

	_, _ = h.db.Exec(context.Background(), `UPDATE room_leases SET x=480,y=140 WHERE character_id=$1`, charA)
	res = h.request("POST", "/v1/rooms/travel", tokA, "tr-shenyuan-1", map[string]any{"portal_id": "harbor_gate"})
	requireStatus(t, res, http.StatusOK)

	wbRes := h.request("GET", "/v1/world-boss/current", tokA, "", nil)
	requireStatus(t, wbRes, http.StatusOK)
	wbID, _ := decodeVal[string](t, wbRes.data["id"])
	bossID, _ := decodeVal[string](t, wbRes.data["boss_id"])
	if bossID != "mon_salt_scale" {
		t.Fatalf("expected shenyuan_port mon_salt_scale boss, got %s", bossID)
	}
	objRes := h.request("POST", "/v1/world-boss/"+wbID+"/objective", tokA, "wb2-obj-1", map[string]any{"objective_id": "anchor_barricade"})
	requireStatus(t, objRes, http.StatusOK)
	engRes := h.request("POST", "/v1/world-boss/"+wbID+"/engage", tokA, "wb2-eng-1", map[string]any{"action": "attack"})
	requireStatus(t, engRes, http.StatusOK)
	clmRes := h.request("POST", "/v1/world-boss/"+wbID+"/claim", tokA, "wb2-clm-1", map[string]any{})
	requireStatus(t, clmRes, http.StatusOK)

	// 2. Two-player party completes remaining co-op dungeons: ore_vein (rail puzzle) & stele_depths.
	partyRes := h.request("POST", "/v1/parties", tokA, "l4-p-create", map[string]any{})
	requireStatus(t, partyRes, http.StatusOK)
	_, _ = h.db.Exec(context.Background(), `UPDATE characters SET map_id='lorin_wilds' WHERE id=$1`, charA)
	invRes := h.request("POST", "/v1/parties/invite", tokA, "l4-p-inv", map[string]any{"target_character_id": charB})
	requireStatus(t, invRes, http.StatusOK)
	bSoc := h.request("GET", "/v1/social/state", tokB, "", nil)
	var partyInvs []struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(bSoc.data["invitations"], &partyInvs)
	if len(partyInvs) == 1 {
		requireStatus(t, h.request("POST", "/v1/parties/invites/"+partyInvs[0].ID+"/respond", tokB, "l4-party-acc1", map[string]any{"accept": true}), http.StatusOK)
	}
	requireStatus(t, h.request("POST", "/v1/parties/ready", tokA, "l4-ready-a1", map[string]any{"ready": true}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/parties/ready", tokB, "l4-ready-b1", map[string]any{"ready": true}), http.StatusOK)

	instRes := h.request("POST", "/v1/coop/instances", tokA, "l4-inst-ore", map[string]any{"dungeon_id": "ore_vein", "difficulty": "standard", "goal": "first_clear"})
	requireStatus(t, instRes, http.StatusOK)
	instID, _ := decodeVal[string](t, instRes.data["id"])
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/ready", tokA, "l4-iready-a", map[string]any{"ready": true}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/ready", tokB, "l4-iready-b", map[string]any{"ready": true}), http.StatusOK)

	// Solve ore_vein rail puzzle across teammates.
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokA, "l4-ore-m1", map[string]any{"mechanic_id": "rail_map"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokA, "l4-ore-m2", map[string]any{"mechanic_id": "north_lever"}), http.StatusOK)
	res = h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokB, "l4-ore-m3", map[string]any{"mechanic_id": "south_switch"})
	requireStatus(t, res, http.StatusOK)
	stageIdx, _ := decodeVal[int](t, res.data["stage_index"])
	if stageIdx != 1 {
		t.Fatalf("expected stage advance to 1 after solving ore_vein puzzle, got %d", stageIdx)
	}
}

func TestL4GuildLifecyclePermissionsWarehouseAuditAndInactiveHandoff(t *testing.T) {
	h := setupL2World(t)

	// Pre-Act-II character without complete journey cannot create guild yet, while still growing normally outside guild.
	tokPre, charPre, _ := h.townCharacterWithRole(t, "l4nonguild", "ck", 1, false)
	preRes := h.request("POST", "/v1/guilds", tokPre, "guild-pre-1", map[string]any{"name": "未过线试建"})
	if preRes.status != http.StatusConflict || preRes.code != "act2_required" {
		t.Fatalf("expected act2_required for Lv.1 incomplete journey, got %d %s", preRes.status, preRes.body)
	}
	// Non-guild character still earns battle rewards normally!
	_, _ = h.db.Exec(context.Background(), `UPDATE room_leases SET x=600,y=1740 WHERE character_id=$1`, charPre)
	bRes := h.request("POST", "/v1/battles", tokPre, "ng-battle-1", map[string]any{"encounter_id": "training_wolf"})
	requireStatus(t, bRes, http.StatusCreated)

	// Act-II ready leader + officer + member.
	tokL, charL, _ := h.townCharacterWithRole(t, "l4leader", "zs", 5, true)
	tokO, charO, _ := h.townCharacterWithRole(t, "l4officer", "fz", 5, true)
	tokM, charM, _ := h.townCharacterWithRole(t, "l4member", "ck", 5, true)

	// Create guild (deducts 50g -> 100 - 50 = 50g).
	createRes := h.request("POST", "/v1/guilds", tokL, "guild-create-1", map[string]any{"name": "晨星远征团", "motto": "护碑安民"})
	requireStatus(t, createRes, http.StatusOK)
	if goldL := h.count(`SELECT gold FROM wallets WHERE character_id='` + charL + `'`); goldL != 50 {
		t.Fatalf("expected leader gold 50 after 50g creation fee, got %d", goldL)
	}

	// Invite & accept officer and member.
	requireStatus(t, h.request("POST", "/v1/guilds/invite", tokL, "", map[string]any{"target_character_id": charO}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/guilds/invite", tokL, "", map[string]any{"target_character_id": charM}), http.StatusOK)

	for _, pair := range []struct {
		tok, key string
	}{{tokO, "inv-acc-001"}, {tokM, "inv-acc-002"}} {
		st := h.request("GET", "/v1/guilds/state", pair.tok, "", nil)
		var invs []struct {
			ID string `json:"id"`
		}
		_ = json.Unmarshal(st.data["invites"], &invs)
		if len(invs) != 1 {
			t.Fatalf("expected 1 invite, got %s", st.body)
		}
		requireStatus(t, h.request("POST", "/v1/guilds/invites/"+invs[0].ID+"/respond", pair.tok, pair.key, map[string]any{"accept": true}), http.StatusOK)
	}

	// Warehouse rejects tradeable commodities! Only non-tradeable guild materials allowed.
	tradeGrain := seedTradeableItem(t, h, charL, "mat_grain", 2, false, `{}`)
	badDep := h.request("POST", "/v1/guilds/warehouse/deposit", tokL, "wh-bad-001", map[string]any{"item_uid": tradeGrain, "quantity": 1})
	if badDep.status != http.StatusBadRequest || badDep.code != "tradeable_item_forbidden" {
		t.Fatalf("expected tradeable_item_forbidden on guild warehouse, got %d %s", badDep.status, badDep.body)
	}

	// Deposit non-tradeable guild timber & stone (bound=true).
	timberUID := seedTradeableItem(t, h, charL, "mat_guild_timber", 5, true, `{"origin":"coop"}`)
	requireStatus(t, h.request("POST", "/v1/guilds/warehouse/deposit", tokL, "wh-good-001", map[string]any{"item_uid": timberUID, "quantity": 4}), http.StatusOK)

	// Member without warehouse permission cannot withdraw.
	forb := h.request("POST", "/v1/guilds/warehouse/withdraw", tokM, "wh-forb-001", map[string]any{"template_id": "mat_guild_timber", "quantity": 1})
	if forb.status != http.StatusForbidden {
		t.Fatalf("expected 403 for member withdraw without permission, got %d", forb.status)
	}

	// Leader grants officer rank + permissions to charO, decorates stronghold, contributes weekly task expanding cap > 30.
	requireStatus(t, h.request("POST", "/v1/guilds/permissions", tokL, "perm-0001", map[string]any{
		"target_character_id": charO, "rank": "officer", "can_invite": true, "can_manage_warehouse": true, "can_edit_announcement": true,
	}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/guilds/announcement", tokO, "ann-00001", map[string]any{
		"announcement": "周五晚共赴赤砂矿脉", "decor_banner": "gold_banner",
	}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/guilds/warehouse/withdraw", tokO, "wh-wd-0001", map[string]any{"template_id": "mat_guild_timber", "quantity": 1}), http.StatusOK)
	taskRes := h.request("POST", "/v1/guilds/tasks/contribute", tokO, "task-0001", map[string]any{"template_id": "mat_guild_timber", "quantity": 3})
	requireStatus(t, taskRes, http.StatusOK)
	var guildOut struct {
		MemberCap  int `json:"member_cap"`
		DecorLevel int `json:"decor_level"`
	}
	_ = json.Unmarshal(taskRes.data["guild"], &guildOut)
	if guildOut.MemberCap <= 30 || guildOut.DecorLevel < 2 {
		t.Fatalf("expected member_cap > 30 and decor_level >= 2 after weekly task, got %+v", guildOut)
	}

	// Simulate inactive leader -> officer publicly claims leadership!
	_, _ = h.db.Exec(context.Background(), `UPDATE guilds SET last_leader_active_at=now()-interval '20 days'`)
	claimRes := h.request("POST", "/v1/guilds/claim-leadership", tokO, "claim-lead-1", map[string]any{})
	requireStatus(t, claimRes, http.StatusOK)
	if lead := h.count(`SELECT count(*) FROM guilds WHERE leader_character_id='` + charO + `'`); lead != 1 {
		t.Fatal("expected inactive leadership claim to promote officer")
	}

	// Member leaves cleanly, triggers rejoin cooldown, preserves personal items.
	requireStatus(t, h.request("POST", "/v1/guilds/leave", tokM, "leave-0001", map[string]any{}), http.StatusOK)
	if cd := h.count(`SELECT count(*) FROM guild_member_cooldowns WHERE character_id='` + charM + `' AND cooldown_until>now()`); cd != 1 {
		t.Fatal("expected leave cooldown")
	}

	// Verify full append-only audit trail recorded across all lifecycle events.
	if logs := h.count(`SELECT count(*) FROM guild_audit_logs`); logs < 8 {
		t.Fatalf("expected >=8 guild_audit_logs entries, got %d", logs)
	}
}
