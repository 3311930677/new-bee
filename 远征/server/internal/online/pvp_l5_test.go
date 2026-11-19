package online

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"testing"

	"golang.org/x/crypto/bcrypt"
)

type pvpScriptedAuthority struct {
	epoch   string
	inner   coopScriptedAuthority
}

func (a *pvpScriptedAuthority) Call(ctx context.Context, method string, args, out any) error {
	raw, _ := json.Marshal(args)
	var v map[string]json.RawMessage
	_ = json.Unmarshal(raw, &v)
	var mode string
	_ = json.Unmarshal(v["mode"], &mode)

	if mode != "pvp" && method != "battle.replay" {
		return a.inner.Call(ctx, method, args, out)
	}

	var reply any
	switch method {
	case "ping":
		reply = map[string]any{"epoch": a.epoch}
	case "world.validate_move":
		var x, y float64
		_ = json.Unmarshal(v["x"], &x)
		_ = json.Unmarshal(v["y"], &y)
		reply = map[string]any{"x": x, "y": y}
	case "battle.sync", "battle.replay":
		var inputs []coopBattleInput
		var tick int
		var maxTicks int
		_ = json.Unmarshal(v["inputs"], &inputs)
		_ = json.Unmarshal(v["target_tick"], &tick)
		_ = json.Unmarshal(v["pvp_max_ticks"], &maxTicks)
		if maxTicks <= 0 {
			maxTicks = 5400
		}
		var teamA, teamB []struct {
			CharacterID string `json:"character_id"`
			RoleID      string `json:"role_id"`
			Nickname    string `json:"name"`
		}
		_ = json.Unmarshal(v["team_a"], &teamA)
		_ = json.Unmarshal(v["team_b"], &teamB)

		sideOf := map[string]string{}
		coopMembers := map[string]map[string]any{}
		units := []map[string]any{}
		uidSeq := 1
		addSide := func(side string, list []struct {
			CharacterID string `json:"character_id"`
			RoleID      string `json:"role_id"`
			Nickname    string `json:"name"`
		}) {
			for _, m := range list {
				uid := uidSeq
				uidSeq++
				sideOf[m.CharacterID] = side
				coopMembers[m.CharacterID] = map[string]any{
					"uid": uid, "side": side, "hp": 1200, "max_hp": 1200,
					"alive": true, "energy": 30, "potions": 1, "damage_dealt": 0, "actions": 0, "safe_defend": false,
				}
				units = append(units, map[string]any{
					"uid": uid, "kind": "role", "side": side, "coop_slot": m.CharacterID,
					"name": m.Nickname, "hp": 1200, "max_hp": 1200, "alive": true, "energy": 30, "buffs": []any{},
				})
			}
		}
		addSide("ally", teamA)
		addSide("enemy", teamB)

		finished := false
		result := ""
		winnerSide := ""
		attackCount := 0

		for i := range inputs {
			act, _ := inputs[i].Action["action"].(string)
			cid, _ := inputs[i].Action["character_id"].(string)
			accepted := true
			reason := "attacked"
			if finished {
				accepted = false
				reason = "finished"
			} else {
				st := coopMembers[cid]
				switch act {
				case "attack":
					attackCount++
					if st != nil {
						st["actions"] = st["actions"].(int) + 1
						st["damage_dealt"] = st["damage_dealt"].(int) + 150
					}
					if attackCount >= 2 {
						finished = true
						if sideOf[cid] == "enemy" {
							winnerSide = "enemy"
							result = "defeat"
						} else {
							winnerSide = "ally"
							result = "victory"
						}
					}
				case "skill":
					if st != nil {
						st["actions"] = st["actions"].(int) + 1
						st["damage_dealt"] = st["damage_dealt"].(int) + 210
					}
					reason = "cast"
				case "potion":
					if st != nil && st["potions"].(int) > 0 {
						st["potions"] = st["potions"].(int) - 1
						reason = "used"
					} else {
						accepted = false
						reason = "unavailable"
					}
				case "focus":
					reason = "focused"
				case "timeout_default":
					if st != nil {
						st["safe_defend"] = true
					}
					reason = "timeout_defend"
				case "safe_defend":
					if st != nil {
						st["safe_defend"] = inputs[i].Action["enabled"] == true
					}
					reason = "updated"
				case "forfeit":
					finished = true
					if sideOf[cid] == "ally" {
						winnerSide = "enemy"
						result = "defeat"
					} else {
						winnerSide = "ally"
						result = "victory"
					}
					reason = "forfeited"
				default:
					accepted = false
					reason = "invalid_action"
				}
			}
			applied := inputs[i].Tick
			inputs[i].Accepted = &accepted
			inputs[i].Reason = reason
			inputs[i].AppliedTick = &applied
		}

		if !finished && tick >= maxTicks {
			finished = true
			result = "draw"
			winnerSide = "draw"
		}

		statePayload := map[string]any{
			"tick": tick, "finished": finished, "result": result, "winner_side": winnerSide,
			"pvp": true, "coop": true, "coop_members": coopMembers, "units": units,
		}
		sb, _ := json.Marshal(statePayload)
		hSum := sha256.Sum256(sb)
		statePayload["state_hash"] = hex.EncodeToString(hSum[:])
		if method == "battle.replay" {
			reply = map[string]any{"ok": true, "state": statePayload}
		} else {
			reply = map[string]any{"ok": true, "epoch": a.epoch, "state": statePayload, "inputs": inputs}
		}
	default:
		return errors.New("unknown_method: " + method)
	}
	b, _ := json.Marshal(reply)
	return json.Unmarshal(b, out)
}

func setupL5PvPWorld(t *testing.T) *harness {
	t.Helper()
	return setupWithConfig(t, Config{
		ContentVersion: "integration-v1",
		PasswordCost:   bcrypt.MinCost,
		Rules:          loadRealOnlineRules(t),
		Authority: &pvpScriptedAuthority{
			epoch: "55555555555555555555555555555555",
			inner: coopScriptedAuthority{epoch: "55555555555555555555555555555555"},
		},
	})
}

func makeFriendsTx(t *testing.T, h *harness, charA, charB string) {
	t.Helper()
	if charA > charB {
		charA, charB = charB, charA
	}
	if _, err := h.db.Exec(context.Background(), `INSERT INTO friendships(character_a,character_b) VALUES($1,$2) ON CONFLICT DO NOTHING`, charA, charB); err != nil {
		t.Fatal(err)
	}
}

func formPartyHelper(t *testing.T, h *harness, tag, leaderTok, leaderChar string, members []struct{ tok, cid string }) string {
	t.Helper()
	res := h.request("POST", "/v1/parties", leaderTok, "l5p-p-"+tag+"-"+leaderChar[:4], map[string]any{})
	requireStatus(t, res, http.StatusOK)
	var created struct{ ID string `json:"id"` }
	_ = json.Unmarshal(res.data["party"], &created)
	for idx, m := range members {
		inv := h.request("POST", "/v1/parties/invite", leaderTok, "l5p-i-"+tag+"-"+leaderChar[:4]+string(rune('a'+idx)), map[string]any{"target_character_id": m.cid})
		requireStatus(t, inv, http.StatusOK)
		soc := h.request("GET", "/v1/social/state", m.tok, "", nil)
		requireStatus(t, soc, http.StatusOK)
		var invs []struct {
			ID string `json:"id"`
		}
		_ = json.Unmarshal(soc.data["invitations"], &invs)
		if len(invs) == 0 {
			t.Fatalf("expected party invite for %s", m.cid)
		}
		acc := h.request("POST", "/v1/parties/invites/"+invs[0].ID+"/respond", m.tok, "l5p-acc-"+m.cid[:6], map[string]any{"accept": true})
		requireStatus(t, acc, http.StatusOK)
	}
	return created.ID
}

func TestL5PvPAllThreeModesSparringRankedFillAndIndependentRatings(t *testing.T) {
	h := setupL5PvPWorld(t)
	toks := make([]string, 6)
	chars := make([]string, 6)
	roles := []string{"zs", "fs", "ck", "fz", "zs", "fs"}
	for i := 0; i < 6; i++ {
		toks[i], chars[i], _ = h.townCharacterWithRole(t, "l5p"+string(rune('a'+i))+"1", roles[i], 10, true)
	}

	// 1. 1v1 Friend Sparring -> Zero MMR / rating change.
	makeFriendsTx(t, h, chars[0], chars[1])
	chRes := h.request("POST", "/v1/pvp/challenges", toks[0], "l5-spar-1v1", map[string]any{"mode": "1v1", "target_character_id": chars[1]})
	requireStatus(t, chRes, http.StatusOK)
	chID, _ := decodeVal[string](t, chRes.data["challenge_id"])
	accRes := h.request("POST", "/v1/pvp/challenges/"+chID+"/respond", toks[1], "l5-spar-acc1", map[string]any{"accept": true})
	requireStatus(t, accRes, http.StatusOK)
	sparMatchID, _ := decodeVal[string](t, accRes.data["match_id"])

	for i := 0; i < 2; i++ {
		r := h.request("POST", "/v1/pvp/matches/"+sparMatchID+"/ready", toks[i], "l5-spar-r"+string(rune('a'+i)), map[string]any{"ready": true})
		requireStatus(t, r, http.StatusOK)
	}
	c1 := h.request("POST", "/v1/pvp/matches/"+sparMatchID+"/command", toks[0], "l5-spar-cmd1", map[string]any{"sequence": 1, "action": "attack"})
	requireStatus(t, c1, http.StatusOK)
	c2 := h.request("POST", "/v1/pvp/matches/"+sparMatchID+"/command", toks[0], "l5-spar-cmd2", map[string]any{"sequence": 2, "action": "attack"})
	requireStatus(t, c2, http.StatusOK)
	ov0 := h.request("GET", "/v1/pvp/overview?mode=1v1", toks[0], "", nil)
	requireStatus(t, ov0, http.StatusOK)
	var ratings0 map[string]struct{ Rating, Wins int }
	_ = json.Unmarshal(ov0.data["ratings"], &ratings0)
	if ratings0["1v1"].Rating != 1000 || ratings0["1v1"].Wins != 0 {
		t.Fatalf("sparring must not mutate ranked rating or wins, got %+v", ratings0["1v1"])
	}

	// 2. 1v1 Ranked Queue -> Updates ONLY 1v1 rating, leaving 2v2 and 3v3 at 1000.
	q0 := h.request("POST", "/v1/pvp/queue/join", toks[0], "l5-1v1-q0", map[string]any{"mode": "1v1", "allow_random_fill": false})
	requireStatus(t, q0, http.StatusOK)
	q1 := h.request("POST", "/v1/pvp/queue/join", toks[1], "l5-1v1-q1", map[string]any{"mode": "1v1", "allow_random_fill": false})
	requireStatus(t, q1, http.StatusOK)
	rMatch1v1, _ := decodeVal[string](t, q1.data["match_id"])
	if rMatch1v1 == "" {
		t.Fatalf("expected 1v1 ranked match to form immediately")
	}
	for i := 0; i < 2; i++ {
		requireStatus(t, h.request("POST", "/v1/pvp/matches/"+rMatch1v1+"/ready", toks[i], "l5-1v1-ready-"+string(rune('a'+i)), map[string]any{"ready": true}), http.StatusOK)
	}
	requireStatus(t, h.request("POST", "/v1/pvp/matches/"+rMatch1v1+"/command", toks[0], "l5-1v1-cmd1", map[string]any{"sequence": 1, "action": "attack"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/pvp/matches/"+rMatch1v1+"/command", toks[0], "l5-1v1-cmd2", map[string]any{"sequence": 2, "action": "attack"}), http.StatusOK)

	ovAfter1v1 := h.request("GET", "/v1/pvp/overview?mode=1v1", toks[0], "", nil)
	_ = json.Unmarshal(ovAfter1v1.data["ratings"], &ratings0)
	if ratings0["1v1"].Rating <= 1000 || ratings0["1v1"].Wins != 1 || ratings0["2v2"].Rating != 1000 || ratings0["3v3"].Rating != 1000 {
		t.Fatalf("1v1 ranked must only update 1v1 rating, got %+v", ratings0)
	}

	// 3. 2v2 Ranked: Rejects solo without random fill; matches 2-player premade vs 2 random-fill solos!
	noFill := h.request("POST", "/v1/pvp/queue/join", toks[2], "l5-2v2-nofill", map[string]any{"mode": "2v2", "allow_random_fill": false})
	requireStatus(t, noFill, http.StatusBadRequest)

	formPartyHelper(t, h, "2v2a", toks[0], chars[0], []struct{ tok, cid string }{{toks[1], chars[1]}})
	requireStatus(t, h.request("POST", "/v1/pvp/queue/join", toks[0], "l5-2v2-premade", map[string]any{"mode": "2v2", "allow_random_fill": false}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/pvp/queue/join", toks[2], "l5-2v2-fill1", map[string]any{"mode": "2v2", "allow_random_fill": true}), http.StatusOK)
	q2Match := h.request("POST", "/v1/pvp/queue/join", toks[3], "l5-2v2-fill2", map[string]any{"mode": "2v2", "allow_random_fill": true})
	requireStatus(t, q2Match, http.StatusOK)
	rMatch2v2, _ := decodeVal[string](t, q2Match.data["match_id"])
	if rMatch2v2 == "" {
		t.Fatalf("expected 2v2 ranked premade vs 2 random fills to match")
	}
	for i := 0; i < 4; i++ {
		requireStatus(t, h.request("POST", "/v1/pvp/matches/"+rMatch2v2+"/ready", toks[i], "l5-2v2-ready-"+string(rune('a'+i)), map[string]any{"ready": true}), http.StatusOK)
	}
	requireStatus(t, h.request("POST", "/v1/pvp/matches/"+rMatch2v2+"/command", toks[0], "l5-2v2-cmd1", map[string]any{"sequence": 1, "action": "attack"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/pvp/matches/"+rMatch2v2+"/command", toks[1], "l5-2v2-cmd2", map[string]any{"sequence": 2, "action": "attack"}), http.StatusOK)

	ovAfter2v2 := h.request("GET", "/v1/pvp/overview?mode=2v2", toks[0], "", nil)
	_ = json.Unmarshal(ovAfter2v2.data["ratings"], &ratings0)
	if ratings0["2v2"].Rating <= 1000 || ratings0["3v3"].Rating != 1000 {
		t.Fatalf("expected 2v2 update leaving 3v3 untouched, got %+v", ratings0)
	}

	// Leave parties & test 3v3 premade 3 vs (premade 2 + 1 random fill solo)
	for i := 0; i < 6; i++ {
		_ = h.request("POST", "/v1/parties/leave", toks[i], "l5p-lv-"+chars[i][:6], map[string]any{})
	}
	formPartyHelper(t, h, "3v3a", toks[0], chars[0], []struct{ tok, cid string }{{toks[1], chars[1]}, {toks[2], chars[2]}})
	formPartyHelper(t, h, "3v3b", toks[3], chars[3], []struct{ tok, cid string }{{toks[4], chars[4]}})

	requireStatus(t, h.request("POST", "/v1/pvp/queue/join", toks[0], "l5-3v3-a", map[string]any{"mode": "3v3", "allow_random_fill": false}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/pvp/queue/join", toks[3], "l5-3v3-b", map[string]any{"mode": "3v3", "allow_random_fill": true}), http.StatusOK)
	q3Match := h.request("POST", "/v1/pvp/queue/join", toks[5], "l5-3v3-c", map[string]any{"mode": "3v3", "allow_random_fill": true})
	requireStatus(t, q3Match, http.StatusOK)
	rMatch3v3, _ := decodeVal[string](t, q3Match.data["match_id"])
	if rMatch3v3 == "" {
		t.Fatalf("expected 3v3 ranked 3v(2+1) to match")
	}
	for i := 0; i < 6; i++ {
		requireStatus(t, h.request("POST", "/v1/pvp/matches/"+rMatch3v3+"/ready", toks[i], "l5-3v3-ready-"+string(rune('a'+i)), map[string]any{"ready": true}), http.StatusOK)
	}
	requireStatus(t, h.request("POST", "/v1/pvp/matches/"+rMatch3v3+"/command", toks[0], "l5-3v3-cmd1", map[string]any{"sequence": 1, "action": "attack"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/pvp/matches/"+rMatch3v3+"/command", toks[2], "l5-3v3-cmd2", map[string]any{"sequence": 2, "action": "attack"}), http.StatusOK)

	ovAfter3v3 := h.request("GET", "/v1/pvp/overview?mode=3v3", toks[0], "", nil)
	_ = json.Unmarshal(ovAfter3v3.data["ratings"], &ratings0)
	if ratings0["3v3"].Rating <= 1000 || ratings0["3v3"].Wins != 1 {
		t.Fatalf("expected 3v3 win and rating gain, got %+v", ratings0)
	}
}

func TestL5PvPTimeoutDefaultReconnectReplayHonorShopAndSeasonRollover(t *testing.T) {
	h := setupL5PvPWorld(t)
	tokA, charA, _ := h.townCharacterWithRole(t, "l5ta1", "zs", 10, true)
	tokB, charB, _ := h.townCharacterWithRole(t, "l5tb1", "fs", 10, true)
	tokC, charC, _ := h.townCharacterWithRole(t, "l5tc1", "ck", 10, true)
	tokD, charD, _ := h.townCharacterWithRole(t, "l5td1", "fz", 10, true)
	_ = charB
	_ = charD

	// 2v2 all random fill so we can test: timeout default, disconnect -> safe_defend -> reconnect,
	// leaver forfeit granting rating protection to innocent random-fill teammate, replay, honor shop & season rollover!
	requireStatus(t, h.request("POST", "/v1/pvp/queue/join", tokA, "l5t-queue-1", map[string]any{"mode": "2v2", "allow_random_fill": true}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/pvp/queue/join", tokB, "l5t-queue-2", map[string]any{"mode": "2v2", "allow_random_fill": true}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/pvp/queue/join", tokC, "l5t-queue-3", map[string]any{"mode": "2v2", "allow_random_fill": true}), http.StatusOK)
	q4 := h.request("POST", "/v1/pvp/queue/join", tokD, "l5t-queue-4", map[string]any{"mode": "2v2", "allow_random_fill": true})
	requireStatus(t, q4, http.StatusOK)
	mid, _ := decodeVal[string](t, q4.data["match_id"])

	for idx, tk := range []string{tokA, tokB, tokC, tokD} {
		requireStatus(t, h.request("POST", "/v1/pvp/matches/"+mid+"/ready", tk, "l5t-ready-"+string(rune('a'+idx)), map[string]any{"ready": true}), http.StatusOK)
	}

	// Advance past turn_timeout_ticks (450) -> automatic timeout_default actions applied!
	tickRes := h.request("POST", "/v1/pvp/matches/"+mid+"/tick", tokA, "", map[string]any{"advance_ticks": 460})
	requireStatus(t, tickRes, http.StatusOK)
	appliedCnt, _ := decodeVal[int](t, tickRes.data["timeout_defaults_applied"])
	if appliedCnt < 1 {
		t.Fatalf("expected timeout_defaults_applied >= 1 after 460 ticks, got %d", appliedCnt)
	}

	// Disconnect and reconnect tokC cleanly
	discRes := h.request("POST", "/v1/pvp/matches/"+mid+"/connection", tokC, "", map[string]any{"status": "disconnected"})
	requireStatus(t, discRes, http.StatusOK)
	recRes := h.request("POST", "/v1/pvp/matches/"+mid+"/connection", tokC, "", map[string]any{"status": "reconnected"})
	requireStatus(t, recRes, http.StatusOK)

	// tokA deliberately forfeits -> tokB (innocent random-fill teammate) must retain 1000 rating!
	forf := h.request("POST", "/v1/pvp/matches/"+mid+"/forfeit", tokA, "l5t-forfeit-1", map[string]any{})
	requireStatus(t, forf, http.StatusOK)

	ovA := h.request("GET", "/v1/pvp/overview?mode=2v2", tokA, "", nil)
	ovB := h.request("GET", "/v1/pvp/overview?mode=2v2", tokB, "", nil)
	var rA, rB map[string]struct{ Rating int }
	_ = json.Unmarshal(ovA.data["ratings"], &rA)
	_ = json.Unmarshal(ovB.data["ratings"], &rB)
	if rA["2v2"].Rating >= 1000 || rB["2v2"].Rating != 1000 {
		t.Fatalf("expected forfeiter rating < 1000 and protected teammate == 1000, got A=%d B=%d", rA["2v2"].Rating, rB["2v2"].Rating)
	}

	// Authoritative Replay verification
	rep := h.request("GET", "/v1/pvp/matches/"+mid+"/replay", tokC, "", nil)
	requireStatus(t, rep, http.StatusOK)
	verified, _ := decodeVal[bool](t, rep.data["replay_verified"])
	if !verified {
		t.Fatalf("expected replay_verified=true")
	}

	// Claim season reward + buy honor item
	claimRes := h.request("POST", "/v1/pvp/season/claim", tokC, "l5t-sclaim", map[string]any{})
	requireStatus(t, claimRes, http.StatusOK)
	shopRes := h.request("POST", "/v1/pvp/honor-shop/buy", tokC, "l5t-shop1", map[string]any{"item_id": "itm_potion_hp_s"})
	requireStatus(t, shopRes, http.StatusOK)
	var itemCount int
	_ = h.db.QueryRow(context.Background(), `SELECT coalesce(sum(quantity),0) FROM inventory_items WHERE character_id=$1 AND template_id='itm_potion_hp_s'`, charC).Scan(&itemCount)
	if itemCount < 1 {
		t.Fatalf("expected honor shop itm_potion_hp_s in pack for charC=%s", charC)
	}

	// Season Rollover soft reset verification
	rules := loadRealOnlineRules(t)
	tx, err := h.db.Begin(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if err = RolloverPvPSeasonTx(context.Background(), tx, rules.PvP, "S2", "第二赛季·赤沙争锋"); err != nil {
		tx.Rollback(context.Background())
		t.Fatal(err)
	}
	if err = tx.Commit(context.Background()); err != nil {
		t.Fatal(err)
	}
	ovS2 := h.request("GET", "/v1/pvp/overview?mode=2v2", tokA, "", nil)
	requireStatus(t, ovS2, http.StatusOK)
	var sObj struct{ ID string `json:"id"` }
	_ = json.Unmarshal(ovS2.data["season"], &sObj)
	if sObj.ID != "S2" {
		t.Fatalf("expected active season S2 after rollover, got %s", sObj.ID)
	}
	_ = charA
}
