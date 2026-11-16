package online

// These tests use real PostgreSQL transactions and a scripted private authority
// to isolate persistence failures. verify_world.py separately runs the real
// Go gateway, Godot authority and Godot clients together.
import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"sync"
	"testing"

	"golang.org/x/crypto/bcrypt"
	"yuanzheng/online/internal/authority"
)

type scriptedAuthority struct{ epoch string }

func (a *scriptedAuthority) Call(_ context.Context, method string, args, out any) error {
	raw, _ := json.Marshal(args)
	var v map[string]json.RawMessage
	_ = json.Unmarshal(raw, &v)
	var reply any
	switch method {
	case "ping":
		reply = map[string]any{"epoch": a.epoch}
	case "world.validate_move":
		var m map[string]float64
		// map_id is deliberately ignored by this transaction-only test double.
		m = map[string]float64{}
		for _, k := range []string{"x", "y", "from_x", "from_y", "elapsed", "speed"} {
			var n float64
			_ = json.Unmarshal(v[k], &n)
			m[k] = n
		}
		if math.Hypot(m["x"]-m["from_x"], m["y"]-m["from_y"]) > m["speed"]*math.Min(m["elapsed"], 0.5)+5 {
			return &authority.RPCError{Code: "invalid_speed"}
		}
		reply = map[string]any{"x": m["x"], "y": m["y"]}
	case "battle.sync":
		var inputs []battleInput
		var tick, checkpointTick int
		var seed int64
		_ = json.Unmarshal(v["inputs"], &inputs)
		_ = json.Unmarshal(v["target_tick"], &tick)
		_ = json.Unmarshal(v["confirmed_tick"], &checkpointTick)
		_ = json.Unmarshal(v["seed"], &seed)
		result := ""
		for i := range inputs {
			accepted := true
			reason := "attacked"
			if result != "" {
				accepted = false
				reason = "finished"
			} else if inputs[i].Action.Action == "flee" {
				result = "flee"
				reason = "fled"
			} else if inputs[i].Action.Action == "attack" {
				result = "victory"
			} else {
				accepted = false
				reason = "unavailable"
			}
			applied := inputs[i].Tick
			inputs[i].Accepted = &accepted
			inputs[i].Reason = reason
			inputs[i].AppliedTick = &applied
		}
		if len(inputs) > 0 && result != "" {
			tick = inputs[len(inputs)-1].Tick
		}
		if tick < checkpointTick {
			tick = checkpointTick
		}
		journal, _ := json.Marshal(inputs)
		digest := sha256.Sum256([]byte(fmt.Sprintf("%d:%d:%s", seed, tick, journal)))
		reply = map[string]any{"epoch": a.epoch, "inputs": inputs, "state": map[string]any{"tick": tick, "finished": result != "", "result": result, "state_hash": hex.EncodeToString(digest[:]), "units": []any{map[string]any{"hp": 100}}}}
	default:
		return fmt.Errorf("unsupported scripted method")
	}
	raw, _ = json.Marshal(reply)
	return json.Unmarshal(raw, out)
}

func setupTown(t *testing.T, capacity int) *harness {
	var rules OnlineRules
	if err := json.Unmarshal([]byte(fmt.Sprintf(`{"version":"online-0.1","town":{"map_id":"lorin_wilds","capacity":%d,"spawn":[600,1520],"speed":192},"encounters":{"training_wolf":{"monster_id":"mon_wolf","position":[600,1520],"radius":112,"gold":10,"experience":5,"reward_policy":"once"}}}`, capacity)), &rules); err != nil {
		t.Fatal(err)
	}
	return setupWithConfig(t, Config{ContentVersion: "integration-v1", PasswordCost: bcrypt.MinCost, Rules: rules, Authority: &scriptedAuthority{"11111111111111111111111111111111"}})
}
func (h *harness) townRole(name string) (string, string, roomLease) {
	h.t.Helper()
	token := h.register(name).value("access_token")
	created := h.request("POST", "/v1/characters", token, "create-role-"+name, createCharacterBody{strings.ReplaceAll(name, "_", ""), "zs", "default"})
	requireStatus(h.t, created, 201)
	id := created.characterID()
	requireStatus(h.t, h.request("POST", "/v1/characters/"+id+"/select", token, "select-role-"+name, map[string]any{}), 200)
	joined := h.request("POST", "/v1/rooms/join", token, "join-room-"+name, map[string]any{})
	requireStatus(h.t, joined, 200)
	var lease roomLease
	if err := json.Unmarshal(joined.data["lease"], &lease); err != nil {
		h.t.Fatal(err)
	}
	return token, id, lease
}
func battleID(t *testing.T, a answer) string {
	t.Helper()
	var b struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(a.data["battle"], &b); err != nil || b.ID == "" {
		t.Fatalf("missing battle: %s", a.body)
	}
	return b.ID
}

func TestTownCapacityLeaseRotationAndMovementOwnership(t *testing.T) {
	h := setupTown(t, 2)
	a, aid, la := h.townRole("town_one")
	b, _, lb := h.townRole("town_two")
	_, _, lc := h.townRole("town_three")
	if la.RoomID != lb.RoomID || la.RoomID == lc.RoomID {
		t.Fatal("channel capacity was not enforced")
	}
	snapshot := h.request("GET", "/v1/rooms/current", a, "", nil)
	requireStatus(t, snapshot, 200)
	var entities []any
	_ = json.Unmarshal(snapshot.data["entities"], &entities)
	if len(entities) != 2 {
		t.Fatalf("entities: %d", len(entities))
	}
	if _, err := h.db.Exec(context.Background(), `UPDATE room_leases SET position_updated_at=now()-interval '1 second'`); err != nil {
		t.Fatal(err)
	}
	move := moveBody{lb.Token, lb.Generation, 1, 620, 1520}
	requireStatus(t, h.request("POST", "/v1/rooms/move", b, "move-once-0001", move), 200)
	requireStatus(t, h.request("POST", "/v1/rooms/move", b, "move-once-0001", move), 200)
	requireStatus(t, h.request("POST", "/v1/rooms/move", a, "stolen-lease-01", move), 409)
	move.X = 10000
	move.Sequence = 2
	requireStatus(t, h.request("POST", "/v1/rooms/move", b, "move-teleport-01", move), 400)
	if _, err := h.db.Exec(context.Background(), `UPDATE room_leases SET expires_at=now()-interval '1 second' WHERE token=$1`, lb.Token); err != nil {
		t.Fatal(err)
	}
	renewed := h.request("POST", "/v1/rooms/join", b, "renew-lease-001", map[string]any{})
	requireStatus(t, renewed, 200)
	var next roomLease
	_ = json.Unmarshal(renewed.data["lease"], &next)
	if next.Token == lb.Token || next.Generation != lb.Generation+1 || next.X != 620 {
		t.Fatal("reconnect lost trusted position or reused stale lease")
	}
	login := h.request("POST", "/v1/auth/login", "", "", credentials{"town_one", "long-test-password"})
	requireStatus(t, login, 200)
	requireStatus(t, h.request("GET", "/v1/rooms/current", a, "", nil), 401)
	a = login.value("access_token")
	requireStatus(t, h.request("POST", "/v1/characters/"+aid+"/select", a, "relogin-select-01", map[string]any{}), 200)
	joined := h.request("POST", "/v1/rooms/join", a, "relogin-join-001", map[string]any{})
	requireStatus(t, joined, 200)
	_ = json.Unmarshal(joined.data["lease"], &next)
	if next.Token == la.Token || next.Generation != la.Generation+1 {
		t.Fatal("new session failed to rotate lease")
	}
}

func TestConcurrentRoomJoinHasOneExclusiveLease(t *testing.T) {
	h := setupTown(t, 24)
	token, _, _ := h.townRole("lease_race")
	var wg sync.WaitGroup
	results := make(chan answer, 12)
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			results <- h.request("POST", "/v1/rooms/join", token, fmt.Sprintf("join-concurrent-%03d", i), map[string]any{})
		}(i)
	}
	wg.Wait()
	close(results)
	for a := range results {
		requireStatus(t, a, 200)
	}
	if h.count("SELECT count(*) FROM room_leases") != 1 || h.count("SELECT generation FROM room_leases") != 1 {
		t.Fatal("concurrent joins created multiple lease generations")
	}
}

func TestBattleSettlementRollbackRetryAndOnceReward(t *testing.T) {
	h := setupTown(t, 24)
	token, charID, _ := h.townRole("battle_owner")
	other, _, _ := h.townRole("battle_other")
	start := h.request("POST", "/v1/battles", token, "battle-start-001", map[string]string{"encounter_id": "training_wolf"})
	requireStatus(t, start, 201)
	id := battleID(t, start)
	requireStatus(t, h.request("GET", "/v1/battles/"+id, other, "", nil), 404)
	requireStatus(t, h.request("POST", "/v1/battles/"+id+"/acknowledge", token, "early-ack-0001", map[string]any{}), 409)
	requireStatus(t, h.request("DELETE", "/v1/characters/"+charID, token, "delete-busy-01", map[string]string{"confirm_nickname": "battleowner"}), 409)
	second := h.request("POST", "/v1/characters", token, "second-role-01", createCharacterBody{"secondrole", "ck", "default"})
	requireStatus(t, second, 201)
	requireStatus(t, h.request("POST", "/v1/characters/"+second.characterID()+"/select", token, "switch-busy-01", map[string]any{}), 409)
	// Fail after the authority has accepted an attack, during the wallet ledger write.
	_, err := h.db.Exec(context.Background(), `CREATE FUNCTION reject_reward() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.reason='battle_reward' THEN RAISE EXCEPTION 'injected'; END IF; RETURN NEW; END $$; CREATE TRIGGER reject_reward BEFORE INSERT ON wallet_ledger FOR EACH ROW EXECUTE FUNCTION reject_reward()`)
	if err != nil {
		t.Fatal(err)
	}
	path := "/v1/battles/" + id + "/commands"
	requireStatus(t, h.request("POST", path, token, "reward-retry-01", battleAction{Action: "attack"}), 500)
	if h.count("SELECT count(*) FROM battle_inputs") != 0 || h.count("SELECT count(*) FROM battle_results") != 0 || h.count("SELECT count(*) FROM battle_reward_claims") != 0 || h.count("SELECT gold FROM wallets WHERE character_id='"+charID+"'") != 100 {
		t.Fatal("failed settlement leaked a partial reward or input")
	}
	if _, err = h.db.Exec(context.Background(), `DROP TRIGGER reject_reward ON wallet_ledger`); err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	results := make(chan answer, 8)
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			results <- h.request("POST", path, token, "reward-retry-01", battleAction{Action: "attack"})
		}()
	}
	wg.Wait()
	close(results)
	var receipt string
	for a := range results {
		requireStatus(t, a, 200)
		var b struct {
			Receipt struct {
				ID string `json:"result_id"`
			} `json:"receipt"`
		}
		_ = json.Unmarshal(a.data["battle"], &b)
		if receipt == "" {
			receipt = b.Receipt.ID
		}
		if receipt == "" || receipt != b.Receipt.ID {
			t.Fatal("concurrent settlement changed receipt")
		}
	}
	if h.count("SELECT count(*) FROM battle_results") != 1 || h.count("SELECT count(*) FROM wallet_ledger WHERE reason='battle_reward'") != 1 || h.count("SELECT gold FROM wallets WHERE character_id='"+charID+"'") != 110 || h.count("SELECT experience FROM characters WHERE id='"+charID+"'") != 5 {
		t.Fatal("reward was lost or duplicated")
	}
	requireStatus(t, h.request("POST", "/v1/battles", token, "before-ack-001", map[string]string{"encounter_id": "training_wolf"}), 409)
	active := h.request("GET", "/v1/battles/active", token, "", nil)
	requireStatus(t, active, 200)
	if battleID(t, active) != id {
		t.Fatal("lost final response was not recoverable")
	}
	requireStatus(t, h.request("POST", "/v1/battles/"+id+"/acknowledge", token, "battle-ack-001", map[string]any{}), 200)
	start = h.request("POST", "/v1/battles", token, "battle-start-002", map[string]string{"encounter_id": "training_wolf"})
	requireStatus(t, start, 201)
	secondID := battleID(t, start)
	requireStatus(t, h.request("POST", "/v1/battles/"+secondID+"/commands", token, "second-victory-01", battleAction{Action: "attack"}), 200)
	if h.count("SELECT count(*) FROM battle_results") != 2 || h.count("SELECT count(*) FROM wallet_ledger WHERE reason='battle_reward'") != 1 || h.count("SELECT gold FROM wallets WHERE character_id='"+charID+"'") != 110 {
		t.Fatal("once-only encounter paid twice")
	}
}
