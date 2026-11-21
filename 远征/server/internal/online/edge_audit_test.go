package online

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
)

func TestEdgeAuditBoundaries(t *testing.T) {
	h := setupL2World(t)
	tokA, charA, _ := h.townCharacterWithRole(t, "edgealpha", "zs", 5, true)
	tokB, charB, _ := h.townCharacterWithRole(t, "edgebravo", "fz", 5, true)

	// 1. Market quantity / unit_price bounds & double-cancel rejection.
	grainUID := seedTradeableItem(t, h, charA, "mat_grain", 3, false, `{}`)
	for _, badOrder := range []map[string]any{
		{"item_uid": grainUID, "quantity": 0, "unit_price": 15},
		{"item_uid": grainUID, "quantity": -1, "unit_price": 15},
		{"item_uid": grainUID, "quantity": 100, "unit_price": 15},
		{"item_uid": grainUID, "quantity": 1, "unit_price": 0},
		{"item_uid": grainUID, "quantity": 1, "unit_price": -10},
		{"item_uid": grainUID, "quantity": 1, "unit_price": 10000001},
	} {
		r := h.request("POST", "/v1/market/orders", tokA, "", badOrder)
		if r.status != http.StatusBadRequest || r.code != "invalid_order" {
			t.Fatalf("expected 400 invalid_order for %+v, got %d %s", badOrder, r.status, r.body)
		}
	}
	ord := h.request("POST", "/v1/market/orders", tokA, "edge-ord-1", map[string]any{
		"item_uid": grainUID, "quantity": 1, "unit_price": 15,
	})
	requireStatus(t, ord, http.StatusOK)
	orderID, _ := decodeVal[string](t, ord.data["order_id"])
	requireStatus(t, h.request("POST", "/v1/market/orders/"+orderID+"/cancel", tokA, "edge-cancel-01", map[string]any{}), http.StatusOK)
	reCancel := h.request("POST", "/v1/market/orders/"+orderID+"/cancel", tokA, "edge-cancel-02", map[string]any{})
	if reCancel.status != http.StatusConflict || reCancel.code != "order_already_closed" {
		t.Fatalf("expected 409 order_already_closed on second cancel, got %d %s", reCancel.status, reCancel.body)
	}
	for _, badNPC := range []map[string]any{
		{"action": "buy", "template_id": "mat_grain", "quantity": 0},
		{"action": "buy", "template_id": "mat_grain", "quantity": 31},
		{"action": "buy", "template_id": "unknown_item_id", "quantity": 1},
	} {
		r := h.request("POST", "/v1/market/npc/trade", tokA, "", badNPC)
		if r.status != http.StatusBadRequest || r.code != "invalid_npc_trade" {
			t.Fatalf("expected 400 invalid_npc_trade for %+v, got %d %s", badNPC, r.status, r.body)
		}
	}

	// 2. Social self-target & chat validation.
	if r := h.request("POST", "/v1/social/friends/request", tokA, "edge-self-fr", map[string]any{"target_character_id": charA}); r.status != http.StatusBadRequest || r.code != "invalid_target" {
		t.Fatalf("expected self friend 400 invalid_target, got %d %s", r.status, r.body)
	}
	if r := h.request("POST", "/v1/social/blocks", tokA, "edge-self-blk", map[string]any{"target_character_id": charA}); r.status != http.StatusBadRequest || r.code != "invalid_target" {
		t.Fatalf("expected self block 400 invalid_target, got %d %s", r.status, r.body)
	}
	if r := h.request("POST", "/v1/chat/messages", tokA, "edge-ch-bad", map[string]any{"channel_kind": "global", "content": "hi"}); r.status != http.StatusBadRequest || r.code != "invalid_channel" {
		t.Fatalf("expected 400 invalid_channel, got %d %s", r.status, r.body)
	}
	if r := h.request("POST", "/v1/chat/messages", tokA, "edge-ch-empty", map[string]any{"channel_kind": "room", "content": "   "}); r.status != http.StatusBadRequest || r.code != "invalid_content" {
		t.Fatalf("expected empty chat 400 invalid_content, got %d %s", r.status, r.body)
	}
	if r := h.request("POST", "/v1/chat/messages", tokA, "edge-ch-long", map[string]any{"channel_kind": "room", "content": strings.Repeat("风", 121)}); r.status != http.StatusBadRequest || r.code != "invalid_content" {
		t.Fatalf("expected >120 rune chat 400 invalid_content, got %d %s", r.status, r.body)
	}

	// 3. Trade self & negative/over-limit gold bounds.
	if r := h.request("POST", "/v1/trade/sessions", tokA, "", map[string]any{"target_character_id": charA}); r.status != http.StatusForbidden || r.code != "self_trade_forbidden" {
		t.Fatalf("expected self trade 403 self_trade_forbidden, got %d %s", r.status, r.body)
	}
	requireStatus(t, h.request("POST", "/v1/social/friends/request", tokA, "edge-fr-req", map[string]any{"target_character_id": charB}), http.StatusOK)
	bSoc := h.request("GET", "/v1/social/state", tokB, "", nil)
	var frs []struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(bSoc.data["friend_requests"], &frs)
	if len(frs) != 1 {
		t.Fatalf("expected 1 incoming friend request, got %s", bSoc.body)
	}
	requireStatus(t, h.request("POST", "/v1/social/friends/"+frs[0].ID+"/respond", tokB, "edge-fr-acc", map[string]any{"accept": true}), http.StatusOK)
	tr := h.request("POST", "/v1/trade/sessions", tokA, "", map[string]any{"target_character_id": charB})
	requireStatus(t, tr, http.StatusOK)
	tradeID, _ := decodeVal[string](t, tr.data["trade_id"])
	for _, badGold := range []int64{-1, 10000001} {
		r := h.request("POST", "/v1/trade/sessions/"+tradeID+"/offer", tokA, "", map[string]any{"gold": badGold})
		if r.status != http.StatusBadRequest || r.code != "invalid_gold" {
			t.Fatalf("expected 400 invalid_gold for %d, got %d %s", badGold, r.status, r.body)
		}
	}
	requireStatus(t, h.request("POST", "/v1/trade/sessions/"+tradeID+"/cancel", tokA, "edge-tr-cancel", map[string]any{}), http.StatusOK)

	// 4. Guild name & warehouse quantity bounds.
	for _, badName := range []string{"独", "一二三四五六七八九十一二三四五六七"} {
		r := h.request("POST", "/v1/guilds", tokA, "", map[string]any{"name": badName})
		if r.status != http.StatusBadRequest || r.code != "invalid_guild_name" {
			t.Fatalf("expected 400 invalid_guild_name for %q, got %d %s", badName, r.status, r.body)
		}
	}
	requireStatus(t, h.request("POST", "/v1/guilds", tokA, "edge-g-create", map[string]any{"name": "边界测试帮"}), http.StatusOK)
	timberUID := seedTradeableItem(t, h, charA, "mat_guild_timber", 2, true, `{}`)
	for _, q := range []int{0, -1, 100} {
		r := h.request("POST", "/v1/guilds/warehouse/deposit", tokA, "", map[string]any{"item_uid": timberUID, "quantity": q})
		if r.status != http.StatusBadRequest || r.code != "invalid_item" {
			t.Fatalf("expected deposit qty=%d -> 400 invalid_item, got %d %s", q, r.status, r.body)
		}
		r2 := h.request("POST", "/v1/guilds/warehouse/withdraw", tokA, "", map[string]any{"template_id": "mat_guild_timber", "quantity": q})
		if r2.status != http.StatusBadRequest || r2.code != "invalid_item" {
			t.Fatalf("expected withdraw qty=%d -> 400 invalid_item, got %d %s", q, r2.status, r2.body)
		}
	}
	if r := h.request("POST", "/v1/guilds/warehouse/withdraw", tokA, "", map[string]any{"template_id": "mat_grain", "quantity": 1}); r.status != http.StatusBadRequest || r.code != "invalid_item" {
		t.Fatalf("expected non-warehouse template withdraw -> 400 invalid_item, got %d %s", r.status, r.body)
	}

	// 5. PvP invalid mode, solo fill requirement & self challenge.
	if r := h.request("GET", "/v1/pvp/overview?mode=5v5", tokA, "", nil); r.status != http.StatusBadRequest || r.code != "invalid_pvp_mode" {
		t.Fatalf("expected 400 invalid_pvp_mode on overview, got %d %s", r.status, r.body)
	}
	if r := h.request("POST", "/v1/pvp/queue/join", tokA, "edge-pvp-q1", map[string]any{"mode": "5v5", "allow_random_fill": true}); r.status != http.StatusBadRequest || r.code != "invalid_pvp_mode" {
		t.Fatalf("expected 400 invalid_pvp_mode on queue, got %d %s", r.status, r.body)
	}
	if r := h.request("POST", "/v1/pvp/queue/join", tokA, "edge-pvp-q2", map[string]any{"mode": "2v2", "allow_random_fill": false}); r.status != http.StatusBadRequest || r.code != "random_fill_required" {
		t.Fatalf("expected 400 random_fill_required for solo 2v2 no-fill, got %d %s", r.status, r.body)
	}
	if r := h.request("POST", "/v1/pvp/challenges", tokA, "edge-pvp-self", map[string]any{"mode": "1v1", "target_character_id": charA}); r.status != http.StatusBadRequest || r.code != "invalid_pvp_challenge" {
		t.Fatalf("expected self pvp challenge 400 invalid_pvp_challenge, got %d %s", r.status, r.body)
	}
}
