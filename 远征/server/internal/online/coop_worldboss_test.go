package online

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"testing"

	"golang.org/x/crypto/bcrypt"
	"yuanzheng/online/internal/authority"
)

type coopScriptedAuthority struct{ epoch string }

func (a *coopScriptedAuthority) Call(_ context.Context, method string, args, out any) error {
	raw, _ := json.Marshal(args)
	var v map[string]json.RawMessage
	_ = json.Unmarshal(raw, &v)
	var reply any
	switch method {
	case "ping":
		reply = map[string]any{"epoch": a.epoch}
	case "world.validate_move":
		var x, y float64
		_ = json.Unmarshal(v["x"], &x)
		_ = json.Unmarshal(v["y"], &y)
		reply = map[string]any{"x": x, "y": y}
	case "battle.sync":
		var inputs []coopBattleInput
		var tick int
		_ = json.Unmarshal(v["inputs"], &inputs)
		_ = json.Unmarshal(v["target_tick"], &tick)
		var members []struct {
			CharacterID string        `json:"character_id"`
			Loadout     battleLoadout `json:"loadout"`
		}
		_ = json.Unmarshal(v["members"], &members)
		var singleLoadout battleLoadout
		_ = json.Unmarshal(v["loadout"], &singleLoadout)

		pots := map[string]int{}
		for _, m := range members {
			pots[m.CharacterID] = m.Loadout.Potions
		}
		coopStats := map[string]map[string]any{}
		for _, m := range members {
			coopStats[m.CharacterID] = map[string]any{
				"uid":          1,
				"hp":           100,
				"max_hp":       100,
				"alive":        true,
				"downed":       false,
				"downed_ticks": 0,
				"energy":       20,
				"potions":      pots[m.CharacterID],
				"potion_cd":    0,
				"damage_dealt": 0,
				"healing_done": 0,
				"rescues":      0,
				"actions":      0,
				"safe_defend":  false,
			}
		}

		result := ""
		soloPots := singleLoadout.Potions
		for i := range inputs {
			act, _ := inputs[i].Action["action"].(string)
			cid, _ := inputs[i].Action["character_id"].(string)
			accepted := true
			reason := "attacked"
			if result != "" {
				accepted = false
				reason = "finished"
			} else if len(members) > 0 {
				st := coopStats[cid]
				switch act {
				case "attack":
					if inputs[i].Action["finish"] == true || inputs[i].Sequence >= 3 {
						if inputs[i].Action["finish"] == false {
							if st != nil {
								st["damage_dealt"] = st["damage_dealt"].(int) + 95
								st["actions"] = st["actions"].(int) + 1
							}
						} else {
							result = "victory"
							if st != nil {
								st["damage_dealt"] = st["damage_dealt"].(int) + 180
								st["actions"] = st["actions"].(int) + 1
							}
						}
					} else if st != nil {
						st["damage_dealt"] = st["damage_dealt"].(int) + 110
						st["actions"] = st["actions"].(int) + 1
					}
					if inputs[i].Action["kill_boss"] != nil || len(members) == 1 && inputs[i].Sequence >= 2 {
						result = "victory"
					} else if inputs[i].Sequence >= 3 {
						result = "victory"
					}
				case "skill":
					if st != nil {
						st["damage_dealt"] = st["damage_dealt"].(int) + 140
						st["actions"] = st["actions"].(int) + 1
					}
					reason = "cast"
				case "rescue":
					if st != nil && pots[cid] > 0 {
						pots[cid]--
						st["potions"] = pots[cid]
						st["healing_done"] = st["healing_done"].(int) + 45
						st["rescues"] = st["rescues"].(int) + 1
						st["actions"] = st["actions"].(int) + 1
						reason = "rescued"
					} else {
						accepted = false
						reason = "no_rescue_supply"
					}
				case "potion":
					if st != nil && pots[cid] > 0 {
						pots[cid]--
						st["potions"] = pots[cid]
						st["healing_done"] = st["healing_done"].(int) + 40
						st["actions"] = st["actions"].(int) + 1
						reason = "used"
					} else {
						accepted = false
						reason = "unavailable"
					}
				case "safe_defend":
					if st != nil {
						st["safe_defend"] = true
					}
					reason = "updated"
				case "flee":
					result = "flee"
					reason = "fled"
				default:
					accepted = false
					reason = "invalid_action"
				}
			} else {
				switch act {
				case "attack":
					result = "victory"
				case "potion":
					if soloPots > 0 {
						soloPots--
						reason = "used"
					} else {
						accepted = false
						reason = "unavailable"
					}
				case "flee":
					result = "flee"
					reason = "fled"
				default:
					accepted = false
					reason = "unavailable"
				}
			}
			applied := inputs[i].Tick
			inputs[i].Accepted = &accepted
			inputs[i].Reason = reason
			inputs[i].AppliedTick = &applied
		}
		if len(members) > 0 && tick >= 600 && result == "" {
			result = "victory"
		}
		unitList := []map[string]any{
			{"uid": 1, "kind": "role", "side": "ally", "hp": 100, "max_hp": 100, "alive": true, "energy": 40, "buffs": []any{}},
			{"uid": 2, "kind": "monster", "side": "enemy", "hp": func() int { if result == "victory" { return 0 }; return 150 }(), "max_hp": 310, "alive": result != "victory", "energy": 0, "buffs": []any{}},
		}
		hash := sha256.Sum256([]byte(raw))
		state := map[string]any{
			"tick":        tick,
			"finished":    result != "",
			"result":      result,
			"role_uid":    1,
			"units":       unitList,
			"potions":     soloPots,
			"potion_cd":   0,
			"cast_queue":  []any{},
			"last_cast":   map[string]any{},
			"rng_state":   "1",
			"coop_members": coopStats,
			"state_hash":  hex.EncodeToString(hash[:]),
		}
		reply = map[string]any{"state": state, "epoch": a.epoch, "inputs": inputs}
	default:
		return &authority.RPCError{Code: "unknown_method"}
	}
	b, _ := json.Marshal(reply)
	return json.Unmarshal(b, out)
}

func loadRealOnlineRules(t *testing.T) OnlineRules {
	t.Helper()
	path := filepath.Join("..", "..", "..", "data", "online_rules.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var rules OnlineRules
	if err := json.Unmarshal(raw, &rules); err != nil {
		t.Fatal(err)
	}
	if err := rules.Validate(); err != nil {
		t.Fatalf("real online_rules.json invalid: %v", err)
	}
	return rules
}

func setupL2World(t *testing.T) *harness {
	t.Helper()
	return setupWithConfig(t, Config{
		ContentVersion: "integration-v1",
		PasswordCost:   bcrypt.MinCost,
		Rules:          loadRealOnlineRules(t),
		Authority:      &coopScriptedAuthority{"22222222222222222222222222222222"},
	})
}

func decodeVal[T any](t *testing.T, raw json.RawMessage) (T, error) {
	t.Helper()
	var out T
	err := json.Unmarshal(raw, &out)
	return out, err
}

func (h *harness) townCharacterWithRole(t *testing.T, name, roleID string, level int, completeJourney bool) (string, string, string) {
	t.Helper()
	reg := h.register(name)
	token, _ := decodeVal[string](t, reg.data["access_token"])
	create := h.request("POST", "/v1/characters", token, "char-"+name, map[string]any{
		"nickname": name, "role_id": roleID, "appearance_id": "default", "gender_id": "unspecified", "avatar_id": "role_" + roleID,
	})
	requireStatus(t, create, http.StatusCreated)
	var created struct {
		Character Character `json:"character"`
	}
	_ = json.Unmarshal(mustMarshal(t, create.data), &created)
	charID := created.Character.ID
	var accID string
	if err := h.db.QueryRow(context.Background(), `SELECT account_id::text FROM characters WHERE id=$1`, charID).Scan(&accID); err != nil {
		t.Fatal(err)
	}
	if level > 1 {
		if _, err := h.db.Exec(context.Background(), `UPDATE characters SET level=$2 WHERE id=$1`, charID, level); err != nil {
			t.Fatal(err)
		}
	}
	if completeJourney {
		if _, err := h.db.Exec(context.Background(), `UPDATE character_progress SET story_step='complete',version=version+1 WHERE character_id=$1`, charID); err != nil {
			t.Fatal(err)
		}
	}
	requireStatus(t, h.request("POST", "/v1/characters/"+charID+"/select", token, "select-"+name, struct{}{}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/rooms/join", token, "joinroom-"+name, struct{}{}), http.StatusOK)
	return token, charID, accID
}

func TestCoopSteleCavernFourClassMentorRescueAndDrops(t *testing.T) {
	h := setupL2World(t)
	tokA, charA, accA := h.townCharacterWithRole(t, "cLeader", "fz", 18, true)
	tokB, charB, _ := h.townCharacterWithRole(t, "cZs", "zs", 3, true)
	tokC, charC, _ := h.townCharacterWithRole(t, "cCk", "ck", 3, true)
	tokD, charD, _ := h.townCharacterWithRole(t, "cFs", "fs", 3, true)

	// Grant starter potions to B so B can rescue a teammate in battle.
	if _, err := h.db.Exec(context.Background(), `INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,source_transaction) VALUES(gen_random_uuid(),$1,'itm_potion_hp_s',3,'test-pots')`, charB); err != nil {
		t.Fatal(err)
	}
	// Mark A as already cleared stele_cavern once via completed instance record so A gets mentor bonus!
	prevID := newID()
	if _, err := h.db.Exec(context.Background(), `INSERT INTO coop_instances(id,dungeon_id,difficulty,goal,leader_character_id,status,member_count,content_version,ruleset_version) VALUES($1,'stele_cavern','standard','first_clear',$2,'completed',1,'integration-v1','online-0.1')`, prevID, charA); err != nil {
		t.Fatal(err)
	}
	if _, err := h.db.Exec(context.Background(), `INSERT INTO coop_instance_members(instance_id,character_id,account_id,character_name,role_id,character_level,synced_level,ready,status) VALUES($1,$2,$3,'cLeader','fz',18,18,true,'completed')`, prevID, charA, accA); err != nil {
		t.Fatal(err)
	}

	// Build 4-player party.
	requireStatus(t, h.request("POST", "/v1/parties", tokA, "p-create-1", struct{}{}), http.StatusOK)
	for i, target := range []struct {
		cid string
		tok string
	}{{charB, tokB}, {charC, tokC}, {charD, tokD}} {
		inv := h.request("POST", "/v1/parties/invite", tokA, "p-inv-"+target.cid[:6], map[string]any{"target_character_id": target.cid})
		requireStatus(t, inv, http.StatusOK)
		cur := h.request("GET", "/v1/parties/current", target.tok, "", nil)
		requireStatus(t, cur, http.StatusOK)
		var pView partyView
		_ = json.Unmarshal(mustMarshal(t, cur.data), &pView)
		requireStatus(t, h.request("POST", "/v1/parties/invites/"+pView.Invitations[0].ID+"/respond", target.tok, "p-accept-"+string(rune('0'+i)), map[string]any{"accept": true}), http.StatusOK)
	}

	// Verify locked character cannot join stele_cavern before journey completion.
	tokLocked, _, _ := h.townCharacterWithRole(t, "cLocked", "zs", 5, false)
	lockedRes := h.request("POST", "/v1/coop/instances", tokLocked, "coop-locked-1", map[string]any{"dungeon_id": "stele_cavern", "allow_solo": true})
	requireStatus(t, lockedRes, http.StatusConflict)
	if lockedRes.code != "coop_locked" {
		t.Fatalf("expected coop_locked, got %+v", lockedRes)
	}

	// Create 4-player co-op stele_cavern instance.
	created := h.request("POST", "/v1/coop/instances", tokA, "coop-create-1", map[string]any{"dungeon_id": "stele_cavern", "difficulty": "standard", "goal": "first_clear"})
	requireStatus(t, created, http.StatusOK)
	instID, _ := decodeVal[string](t, created.data["id"])
	if status, _ := decodeVal[string](t, created.data["status"]); status != "ready" {
		t.Fatalf("expected ready before all confirm, got %s", status)
	}

	// Verify mentor synced level: min(3) + delta(5) = 8 for A!
	var members []coopMemberPayload
	_ = json.Unmarshal(created.data["members"], &members)
	if len(members) != 4 || !members[0].IsMentor || members[0].SyncedLevel != 8 {
		t.Fatalf("expected 4 members with mentor capped at level 8, got %+v", members)
	}

	// Cannot interact before everyone readies up.
	preInteract := h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokA, "coop-int-pre", map[string]any{"mechanic_id": "echo_clue"})
	requireStatus(t, preInteract, http.StatusConflict)

	for i, tok := range []string{tokA, tokB, tokC, tokD} {
		requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/ready", tok, "coop-rdy-"+string(rune('a'+i)), map[string]any{"ready": true}), http.StatusOK)
	}

	// Cooperative puzzle solving by different teammates!
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokC, "coop-clue-1", map[string]any{"mechanic_id": "echo_clue"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokD, "coop-west-1", map[string]any{"mechanic_id": "west_stele", "choice": "old"}), http.StatusOK)
	east := h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokA, "coop-east-1", map[string]any{"mechanic_id": "east_stele", "choice": "heart"})
	requireStatus(t, east, http.StatusOK)
	if st, _ := decodeVal[int](t, east.data["stage_index"]); st != 1 {
		t.Fatalf("expected puzzle completion to advance to stage 1, got %d", st)
	}

	// Stage 1: corridor_guard battle -> 3 attacks clear battle and advance to stage 2!
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/battle/start", tokA, "coop-bat1-start", struct{}{}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/battle/command", tokB, "coop-bat1-1", map[string]any{"sequence": 1, "action": "attack", "advance_ticks": 60}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/battle/command", tokC, "coop-bat1-2", map[string]any{"sequence": 2, "action": "skill", "skill_id": "s1", "advance_ticks": 90}), http.StatusOK)
	bat1End := h.request("POST", "/v1/coop/instances/"+instID+"/battle/command", tokA, "coop-bat1-3", map[string]any{"sequence": 3, "action": "attack", "advance_ticks": 120})
	requireStatus(t, bat1End, http.StatusOK)
	if st, _ := decodeVal[int](t, bat1End.data["stage_index"]); st != 2 {
		t.Fatalf("expected victory to advance to boss stage 2, got %d", st)
	}

	// Stage 2: Boss + Rescue + Clear!
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/battle/start", tokA, "coop-bat2-start", struct{}{}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/battle/command", tokB, "coop-bat2-1", map[string]any{"sequence": 1, "action": "rescue", "target_uid": 1, "advance_ticks": 40}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/battle/command", tokD, "coop-bat2-2", map[string]any{"sequence": 2, "action": "attack", "advance_ticks": 80}), http.StatusOK)
	bat2End := h.request("POST", "/v1/coop/instances/"+instID+"/battle/command", tokA, "coop-bat2-3", map[string]any{"sequence": 3, "action": "attack", "advance_ticks": 140})
	requireStatus(t, bat2End, http.StatusOK)
	if st, _ := decodeVal[string](t, bat2End.data["status"]); st != "completed" {
		t.Fatalf("expected dungeon completed, got %s", st)
	}
	if h.count("SELECT count(*) FROM coop_instance_drops WHERE instance_id='"+instID+"'") != 4 {
		t.Fatalf("expected 4 personal drops (one per active participant), got %d", h.count("SELECT count(*) FROM coop_instance_drops WHERE instance_id='"+instID+"'"))
	}

	// Verify A got mentor drop (mat_mentor_seal), while B got first_clear drop (tpl_armor_stele)!
	dropsA := h.request("GET", "/v1/coop/drops", tokA, "", nil)
	requireStatus(t, dropsA, http.StatusOK)
	var aDrops []coopDropPayload
	_ = json.Unmarshal(dropsA.data["drops"], &aDrops)
	if len(aDrops) != 1 || !aDrops[0].MentorBonus || aDrops[0].ItemID != "mat_mentor_seal" {
		t.Fatalf("expected A mentor bonus mat_mentor_seal, got %+v", aDrops)
	}

	dropsB := h.request("GET", "/v1/coop/drops", tokB, "", nil)
	requireStatus(t, dropsB, http.StatusOK)
	var bDrops []coopDropPayload
	_ = json.Unmarshal(dropsB.data["drops"], &bDrops)
	if len(bDrops) != 1 || !bDrops[0].FirstClear || bDrops[0].ItemID != "tpl_armor_stele" {
		t.Fatalf("expected B first_clear tpl_armor_stele, got %+v", bDrops)
	}

	// Pack full safety: fill B's pack slots (32 total, B has 1 item -> insert 31) and verify claim fails 409 pack_full without losing drop!
	for i := 0; i < 31; i++ {
		if _, err := h.db.Exec(context.Background(), `INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,source_transaction) VALUES(gen_random_uuid(),$1,'mat_stele_shard',1,'fill')`, charB); err != nil {
			t.Fatal(err)
		}
	}
	packFull := h.request("POST", "/v1/coop/drops/"+bDrops[0].ID+"/claim", tokB, "claim-full-1", struct{}{})
	requireStatus(t, packFull, http.StatusConflict)
	if packFull.code != "pack_full" {
		t.Fatalf("expected pack_full, got %+v", packFull)
	}
	// Clear 1 filler slot, claim cleanly + repeat claim idempotency!
	if _, err := h.db.Exec(context.Background(), `UPDATE inventory_items SET quantity=0 WHERE item_uid=(SELECT item_uid FROM inventory_items WHERE character_id=$1 AND template_id='mat_stele_shard' LIMIT 1)`, charB); err != nil {
		t.Fatal(err)
	}
	claimOK := h.request("POST", "/v1/coop/drops/"+bDrops[0].ID+"/claim", tokB, "claim-b-ok-1", struct{}{})
	requireStatus(t, claimOK, http.StatusOK)
	repeatSame := h.request("POST", "/v1/coop/drops/"+bDrops[0].ID+"/claim", tokB, "claim-b-ok-1", struct{}{})
	requireStatus(t, repeatSame, http.StatusOK)
	repeatDiffKey := h.request("POST", "/v1/coop/drops/"+bDrops[0].ID+"/claim", tokB, "claim-b-dup-2", struct{}{})
	requireStatus(t, repeatDiffKey, http.StatusConflict)
}

func TestCoopMatchmakingBlockFilterDisconnectLeaveAndRetreat(t *testing.T) {
	h := setupL2World(t)
	tokA, charA, _ := h.townCharacterWithRole(t, "qAlpha", "zs", 10, true)
	tokB, _, _ := h.townCharacterWithRole(t, "qBravo", "ck", 10, true)
	tokC, _, _ := h.townCharacterWithRole(t, "qCharlie", "fz", 10, true)

	// B blocks A -> A & B cannot queue together!
	requireStatus(t, h.request("POST", "/v1/social/blocks", tokB, "blk-ab-1", map[string]any{"target_character_id": charA}), http.StatusOK)
	qB := h.request("POST", "/v1/coop/queue/join", tokB, "q-join-b", map[string]any{"dungeon_id": "tidal_gate", "difficulty": "standard", "goal": "materials"})
	requireStatus(t, qB, http.StatusOK)
	qA := h.request("POST", "/v1/coop/queue/join", tokA, "q-join-a", map[string]any{"dungeon_id": "tidal_gate", "difficulty": "standard", "goal": "materials"})
	requireStatus(t, qA, http.StatusOK)
	if st, _ := decodeVal[string](t, qA.data["status"]); st != "queued" {
		t.Fatalf("expected blocked pair NOT to match, got %+v", qA.data)
	}
	// C joins queue -> matches with B (since B was queued first and C isn't blocked)!
	qC := h.request("POST", "/v1/coop/queue/join", tokC, "q-join-c", map[string]any{"dungeon_id": "tidal_gate", "difficulty": "standard", "goal": "materials"})
	requireStatus(t, qC, http.StatusOK)
	if st, _ := decodeVal[string](t, qC.data["status"]); st != "matched" {
		t.Fatalf("expected C to match with B into tidal_gate, got %+v", qC.data)
	}
	var instPayload map[string]json.RawMessage
	_ = json.Unmarshal(qC.data["instance"], &instPayload)
	instID, _ := decodeVal[string](t, instPayload["id"])
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/ready", tokB, "tg-rdy-b", map[string]any{"ready": true}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/ready", tokC, "tg-rdy-c", map[string]any{"ready": true}), http.StatusOK)

	// Solve stage 0 sluices + bonus cargo!
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokB, "tg-rec-01", map[string]any{"mechanic_id": "tide_record"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokC, "tg-up-001", map[string]any{"mechanic_id": "upper_sluice", "choice": "old"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokB, "tg-cargo-1", map[string]any{"mechanic_id": "cargo_rescue"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/interact", tokC, "tg-br-001", map[string]any{"mechanic_id": "bridge_sluice", "choice": "bridge"}), http.StatusOK)

	// Start stage 1 battle, disconnect C (safe_defend), then reconnect C via GET!
	requireStatus(t, h.request("POST", "/v1/coop/instances/"+instID+"/battle/start", tokB, "tg-bat-1", struct{}{}), http.StatusOK)
	disc := h.request("POST", "/v1/coop/instances/"+instID+"/disconnect", tokC, "tg-disc-c", struct{}{})
	requireStatus(t, disc, http.StatusOK)
	rejoin := h.request("GET", "/v1/coop/instances/"+instID, tokC, "", nil)
	requireStatus(t, rejoin, http.StatusOK)

	// Leader B leaves -> C inherits leadership and instance shrinks to 1!
	left := h.request("POST", "/v1/coop/instances/"+instID+"/leave", tokB, "tg-leave-b", struct{}{})
	requireStatus(t, left, http.StatusOK)
	checkC := h.request("GET", "/v1/coop/instances/"+instID, tokC, "", nil)
	requireStatus(t, checkC, http.StatusOK)
	if lid, _ := decodeVal[string](t, checkC.data["leader_id"]); lid != "" && lid == charA {
		t.Fatalf("unexpected leader %s", lid)
	}
	if mc, _ := decodeVal[int](t, checkC.data["member_count"]); mc != 1 {
		t.Fatalf("expected scaled member_count=1 after B left, got %d", mc)
	}
	// Remaining C votes retreat -> returns cleanly to retreated at checkpoint!
	ret := h.request("POST", "/v1/coop/instances/"+instID+"/retreat", tokC, "tg-ret-c", map[string]any{"vote": true})
	requireStatus(t, ret, http.StatusOK)
	if st, _ := decodeVal[string](t, ret.data["status"]); st != "retreated" {
		t.Fatalf("expected retreated status, got %s", st)
	}
}

func TestWorldBossObjectivesSingleAccountRewardAndFaultClosure(t *testing.T) {
	h := setupL2World(t)
	tokA1, _, _ := h.townCharacterWithRole(t, "wbMain", "zs", 12, true)
	// Second character on a different account vs same account.
	_, charA2, _ := func() (string, string, string) {
		create := h.request("POST", "/v1/characters", tokA1, "char-wb-alt", map[string]any{
			"nickname": "wbAlt", "role_id": "fs", "appearance_id": "default", "gender_id": "unspecified", "avatar_id": "role_fs",
		})
		requireStatus(t, create, http.StatusCreated)
		var out struct{ Character Character `json:"character"` }
		_ = json.Unmarshal(mustMarshal(t, create.data), &out)
		return tokA1, out.Character.ID, ""
	}()
	tokB, _, _ := h.townCharacterWithRole(t, "wbHelper", "ck", 10, true)

	cur := h.request("GET", "/v1/world-boss/current", tokA1, "", nil)
	requireStatus(t, cur, http.StatusOK)
	eventID, _ := decodeVal[string](t, cur.data["id"])

	// Char A1 completes objective + authoritative engage damage!
	requireStatus(t, h.request("POST", "/v1/world-boss/"+eventID+"/objective", tokA1, "wb-obj-1", map[string]any{"objective_id": "inspect_trail"}), http.StatusOK)
	eng := h.request("POST", "/v1/world-boss/"+eventID+"/engage", tokA1, "wb-eng-1", map[string]any{"action": "attack"})
	requireStatus(t, eng, http.StatusOK)

	// Switch same account to char A2 -> participating on same event window must be rejected!
	requireStatus(t, h.request("POST", "/v1/characters/"+charA2+"/select", tokA1, "sel-wb-alt", struct{}{}), http.StatusOK)
	dupAcc := h.request("POST", "/v1/world-boss/"+eventID+"/objective", tokA1, "wb-obj-alt", map[string]any{"objective_id": "disrupt_howl"})
	requireStatus(t, dupAcc, http.StatusConflict)
	if dupAcc.code != "account_already_participated" {
		t.Fatalf("expected account_already_participated, got %+v", dupAcc)
	}

	// Switch back to main A1 and claim reward once!
	var mainCharID string
	_ = h.db.QueryRow(context.Background(), `SELECT character_id::text FROM world_boss_participations WHERE event_id=$1 LIMIT 1`, eventID).Scan(&mainCharID)
	requireStatus(t, h.request("POST", "/v1/characters/"+mainCharID+"/select", tokA1, "sel-wb-main2", struct{}{}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/world-boss/"+eventID+"/claim", tokA1, "wb-claim-a1", struct{}{}), http.StatusOK)

	// Helper B records participation, then server closes event due to fault -> B can STILL claim confirmed reward, new engage rejected!
	requireStatus(t, h.request("POST", "/v1/world-boss/"+eventID+"/objective", tokB, "wb-obj-b1", map[string]any{"objective_id": "inspect_trail"}), http.StatusOK)
	if err := (&Server{db: h.db}).closeWorldBossOnFault(context.Background(), eventID, "maintenance_toggle"); err != nil {
		t.Fatal(err)
	}
	blockedEngage := h.request("POST", "/v1/world-boss/"+eventID+"/engage", tokB, "wb-eng-closed", map[string]any{"action": "attack"})
	requireStatus(t, blockedEngage, http.StatusConflict)
	if blockedEngage.code != "world_boss_closed" {
		t.Fatalf("expected world_boss_closed, got %+v", blockedEngage)
	}
	requireStatus(t, h.request("POST", "/v1/world-boss/"+eventID+"/claim", tokB, "wb-claim-b1", struct{}{}), http.StatusOK)
}
