package online

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"

	"golang.org/x/crypto/bcrypt"
)

func setupL1World(t *testing.T, capacity int) *harness {
	t.Helper()
	var rules OnlineRules
	raw := []byte(`{
		"version": "online-0.1",
		"town": {"map_id": "lorin_wilds", "capacity": 2, "spawn": [600, 1520], "speed": 192},
		"maps": {
			"lorin_wilds": {"name": "昭元边城", "capacity": 2, "spawn": [600, 1520], "speed": 192, "arrivals": {"from_maple_road": [600, 300]}},
			"maple_road": {"name": "枫林古道", "capacity": 2, "spawn": [480, 1860], "speed": 192, "arrivals": {"from_city": [480, 1860]}}
		},
		"portals": {
			"north_gate": {"from_map": "lorin_wilds", "position": [616, 140], "radius": 130, "to_map": "maple_road", "arrival": "from_city", "label": "北门"},
			"south_gate": {"from_map": "maple_road", "position": [480, 1990], "radius": 130, "to_map": "lorin_wilds", "arrival": "from_maple_road", "label": "南口"}
		},
		"npcs": {
			"npc_warden": {"map_id": "lorin_wilds", "name": "守备官", "position": [698, 1580], "radius": 112, "greeting": "城防稳固。", "after_patrol_greeting": "已有通行印信。"},
			"npc_maple_scout": {"map_id": "maple_road", "name": "古道斥候", "position": [480, 1660], "radius": 112, "greeting": "前面有野狼。", "after_patrol_greeting": "带着碑窟印信去吧。"}
		},
		"encounters": {
			"training_wolf": {"map_id": "lorin_wilds", "monster_id": "mon_wolf", "position": [600, 1520], "radius": 112, "gold": 10, "experience": 5, "reward_policy": "once"},
			"maple_wolf": {"map_id": "maple_road", "monster_id": "mon_wolf", "position": [480, 1860], "radius": 112, "gold": 12, "experience": 8, "reward_policy": "per_battle"}
		}
	}`)
	if err := json.Unmarshal(raw, &rules); err != nil {
		t.Fatal(err)
	}
	rules.Town.Capacity = capacity
	lorin := rules.Maps["lorin_wilds"]
	lorin.Capacity = capacity
	rules.Maps["lorin_wilds"] = lorin
	return setupWithConfig(t, Config{
		ContentVersion: "integration-v1",
		PasswordCost:   bcrypt.MinCost,
		Rules:          rules,
		Authority:      &scriptedAuthority{"11111111111111111111111111111111"},
	})
}

func TestChannelsListSwitchAndOverflowIsolation(t *testing.T) {
	h := setupL1World(t, 2)
	tokenA, charA, leaseA := h.townRole("ch_alpha")
	tokenB, charB, leaseB := h.townRole("ch_bravo")
	tokenC, charC, leaseC := h.townRole("ch_charlie")
	if leaseA.RoomID != leaseB.RoomID || leaseC.RoomID == leaseA.RoomID {
		t.Fatalf("expected A&B in channel 1 and C in channel 2: a=%s b=%s c=%s", leaseA.RoomID, leaseB.RoomID, leaseC.RoomID)
	}

	chResp := h.request("GET", "/v1/rooms/channels", tokenB, "", nil)
	requireStatus(t, chResp, http.StatusOK)
	var channels []channelInfo
	if err := json.Unmarshal(chResp.data["channels"], &channels); err != nil || len(channels) != 2 {
		t.Fatalf("expected 2 channels, got %s err=%v", string(chResp.data["channels"]), err)
	}
	if !channels[0].Current || channels[0].PlayerCount != 2 || channels[1].Current || channels[1].PlayerCount != 1 {
		t.Fatalf("unexpected channel summary: %+v", channels)
	}

	// Channel 1 is full (2/2), so C cannot switch into it.
	full := h.request("POST", "/v1/rooms/channels/switch", tokenC, "ch-full-001", map[string]any{"channel": 1})
	requireStatus(t, full, http.StatusConflict)
	if full.code != "channel_full" {
		t.Fatalf("expected channel_full, got %s", full.code)
	}

	// B switches to channel 2 cleanly; A & B no longer share entity view, while B & C do.
	switched := h.request("POST", "/v1/rooms/channels/switch", tokenB, "ch-switch-001", map[string]any{"channel": 2})
	requireStatus(t, switched, http.StatusOK)
	var newLease roomLease
	if err := json.Unmarshal(switched.data["lease"], &newLease); err != nil {
		t.Fatal(err)
	}
	if newLease.RoomID != leaseC.RoomID || newLease.Generation != leaseB.Generation+1 || newLease.Sequence != 0 {
		t.Fatalf("unexpected switched lease: %+v vs c=%s", newLease, leaseC.RoomID)
	}

	snapA := h.request("GET", "/v1/rooms/current", tokenA, "", nil)
	requireStatus(t, snapA, http.StatusOK)
	var viewA []worldEntity
	if err := json.Unmarshal(snapA.data["entities"], &viewA); err != nil || len(viewA) != 1 || viewA[0].ID != charA {
		t.Fatalf("channel 1 should only see A (%s), got %+v", charA, viewA)
	}
	snapB := h.request("GET", "/v1/rooms/current", tokenB, "", nil)
	requireStatus(t, snapB, http.StatusOK)
	var viewB []worldEntity
	if err := json.Unmarshal(snapB.data["entities"], &viewB); err != nil || len(viewB) != 2 {
		t.Fatalf("channel 2 should see B and C, got %+v", viewB)
	}
	if viewB[0].ID != charB && viewB[1].ID != charB && viewB[0].ID != charC && viewB[1].ID != charC {
		t.Fatalf("channel 2 missing B or C: %+v", viewB)
	}
}

func TestCrossMapTravelPortalDistanceAndBattleIsolation(t *testing.T) {
	h := setupL1World(t, 4)
	tokenA, charA, leaseA := h.townRole("map_alpha")
	tokenB, charB, _ := h.townRole("map_bravo")

	// Too far from north_gate ([616, 140]).
	tooFar := h.request("POST", "/v1/rooms/travel", tokenA, "travel-far-001", map[string]any{"portal_id": "north_gate"})
	requireStatus(t, tooFar, http.StatusBadRequest)
	if tooFar.code != "too_far" {
		t.Fatalf("expected too_far, got %s", tooFar.code)
	}

	if _, err := h.db.Exec(context.Background(), `UPDATE room_leases SET x=616,y=140 WHERE character_id=$1`, charA); err != nil {
		t.Fatal(err)
	}
	traveled := h.request("POST", "/v1/rooms/travel", tokenA, "travel-north-001", map[string]any{"portal_id": "north_gate"})
	requireStatus(t, traveled, http.StatusOK)
	var mapleLease roomLease
	if err := json.Unmarshal(traveled.data["lease"], &mapleLease); err != nil {
		t.Fatal(err)
	}
	if mapleLease.MapID != "maple_road" || mapleLease.X != 480 || mapleLease.Y != 1860 || mapleLease.Generation != leaseA.Generation+1 {
		t.Fatalf("unexpected maple lease: %+v", mapleLease)
	}
	var npcs []npcView
	if err := json.Unmarshal(traveled.data["npcs"], &npcs); err != nil || len(npcs) != 1 || npcs[0].ID != "npc_maple_scout" {
		t.Fatalf("expected only maple scout NPC on maple_road, got %+v", npcs)
	}

	// Wrong-map encounter must be rejected even at valid position.
	wrongBattle := h.request("POST", "/v1/battles", tokenA, "wrong-map-battle-001", map[string]any{"encounter_id": "training_wolf"})
	requireStatus(t, wrongBattle, http.StatusConflict)
	if wrongBattle.code != "wrong_map" {
		t.Fatalf("expected wrong_map, got %s", wrongBattle.code)
	}

	// Valid maple_road encounter succeeds.
	mapleBattle := h.request("POST", "/v1/battles", tokenA, "maple-battle-001", map[string]any{"encounter_id": "maple_wolf"})
	requireStatus(t, mapleBattle, http.StatusCreated)
	var battlePayload struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(mapleBattle.data["battle"], &battlePayload)
	requireStatus(t, h.request("POST", "/v1/battles/"+battlePayload.ID+"/commands", tokenA, "maple-flee-001", map[string]any{"action": "flee"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/battles/"+battlePayload.ID+"/acknowledge", tokenA, "maple-ack-001", map[string]any{}), http.StatusOK)

	// Player B in lorin_wilds sees only B (A is on maple_road).
	snapB := h.request("GET", "/v1/rooms/current", tokenB, "", nil)
	requireStatus(t, snapB, http.StatusOK)
	var viewB []worldEntity
	if err := json.Unmarshal(snapB.data["entities"], &viewB); err != nil || len(viewB) != 1 || viewB[0].ID != charB {
		t.Fatalf("lorin_wilds should only show B (%s), got %+v", charB, viewB)
	}

	// Re-login as A resumes on maple_road rather than dropping back to lorin_wilds spawn.
	relog := h.request("POST", "/v1/auth/login", "", "", credentials{"map_alpha", "long-test-password"})
	requireStatus(t, relog, http.StatusOK)
	var newTokenA string
	_ = json.Unmarshal(relog.data["access_token"], &newTokenA)
	requireStatus(t, h.request("POST", "/v1/characters/"+charA+"/select", newTokenA, "relog-sel-001", map[string]any{}), http.StatusOK)
	rejoined := h.request("POST", "/v1/rooms/join", newTokenA, "relog-join-001", map[string]any{})
	requireStatus(t, rejoined, http.StatusOK)
	var rejoinedLease roomLease
	_ = json.Unmarshal(rejoined.data["lease"], &rejoinedLease)
	if rejoinedLease.MapID != "maple_road" || rejoinedLease.X != 480 || rejoinedLease.Y != 1860 {
		t.Fatalf("expected relog resume on maple_road, got %+v", rejoinedLease)
	}

	// Move near south_gate ([480, 1990]) and travel back to lorin_wilds ([600, 300]).
	if _, err := h.db.Exec(context.Background(), `UPDATE room_leases SET x=480,y=1990 WHERE character_id=$1`, charA); err != nil {
		t.Fatal(err)
	}
	returned := h.request("POST", "/v1/rooms/travel", newTokenA, "travel-south-001", map[string]any{"portal_id": "south_gate"})
	requireStatus(t, returned, http.StatusOK)
	_ = json.Unmarshal(returned.data["lease"], &rejoinedLease)
	if rejoinedLease.MapID != "lorin_wilds" || rejoinedLease.X != 600 || rejoinedLease.Y != 300 {
		t.Fatalf("expected arrival from_maple_road [600,300], got %+v", rejoinedLease)
	}
}

func TestNPCIsolationPerCharacterAndMap(t *testing.T) {
	h := setupL1World(t, 4)
	tokenA, charA, _ := h.townRole("npc_alpha")
	tokenB, _, _ := h.townRole("npc_bravo")

	// Far from npc_warden ([698, 1580]) -> too_far; wrong map NPC -> wrong_map.
	requireStatus(t, h.request("POST", "/v1/npcs/npc_warden/interact", tokenA, "npc-far-001", map[string]any{}), http.StatusBadRequest)
	wrongMap := h.request("POST", "/v1/npcs/npc_maple_scout/interact", tokenA, "npc-wrong-001", map[string]any{})
	requireStatus(t, wrongMap, http.StatusConflict)

	if _, err := h.db.Exec(context.Background(), `UPDATE room_leases SET x=698,y=1580 WHERE character_id=$1`, charA); err != nil {
		t.Fatal(err)
	}
	// Mark A as having completed the patrol/stele qualification, while B has not.
	if _, err := h.db.Exec(context.Background(), `INSERT INTO quest_events(character_id,step_id,next_step_id,event,target_id) VALUES($1,'old_rubbing','complete','interact','npc_scribe')`, charA); err != nil {
		t.Fatal(err)
	}
	talked := h.request("POST", "/v1/npcs/npc_warden/interact", tokenA, "npc-talk-001", map[string]any{})
	requireStatus(t, talked, http.StatusOK)
	var npcA npcView
	if err := json.Unmarshal(talked.data["npc"], &npcA); err != nil {
		t.Fatal(err)
	}
	if !npcA.Interacted || npcA.InteractionCount != 1 || npcA.Dialogue != "已有通行印信。" {
		t.Fatalf("expected isolated post-complete dialogue for A, got %+v", npcA)
	}

	// B checks room snapshot: npc_warden stays untouched (interacted=false, count=0, initial greeting).
	snapB := h.request("GET", "/v1/rooms/current", tokenB, "", nil)
	requireStatus(t, snapB, http.StatusOK)
	var npcsB []npcView
	if err := json.Unmarshal(snapB.data["npcs"], &npcsB); err != nil || len(npcsB) != 1 {
		t.Fatalf("expected 1 lorin_wilds NPC for B, got %+v", npcsB)
	}
	if npcsB[0].ID != "npc_warden" || npcsB[0].Interacted || npcsB[0].InteractionCount != 0 || npcsB[0].Dialogue != "城防稳固。" {
		t.Fatalf("expected isolated untouched NPC state for B, got %+v", npcsB[0])
	}
}
