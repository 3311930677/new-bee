package online

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"testing"

	"golang.org/x/crypto/bcrypt"
)

func setupJourney(t *testing.T) *harness {
	t.Helper()
	data, err := os.ReadFile("../../../data/online_rules.json")
	if err != nil {
		t.Fatal(err)
	}
	var rules OnlineRules
	if err := json.Unmarshal(data, &rules); err != nil {
		t.Fatal(err)
	}
	return setupWithConfig(t, Config{ContentVersion: "integration-v1", PasswordCost: bcrypt.MinCost, Rules: rules, Authority: &scriptedAuthority{"11111111111111111111111111111111"}})
}

func journeyID(t *testing.T, reply answer, want string) {
	t.Helper()
	var progress struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(reply.data["journey"], &progress); err != nil || progress.ID != want {
		t.Fatalf("journey step = %q, want %q", progress.ID, want)
	}
}

func packItems(t *testing.T, reply answer) map[string]inventoryView {
	t.Helper()
	var pack struct {
		Items []inventoryView `json:"items"`
	}
	if err := json.Unmarshal(reply.data["pack"], &pack); err != nil {
		t.Fatal(err)
	}
	items := make(map[string]inventoryView)
	for _, item := range pack.Items {
		items[item.Template] = item
	}
	return items
}

func (h *harness) setJourneyPosition(id string, x, y float64) {
	h.t.Helper()
	if _, err := h.db.Exec(context.Background(), `UPDATE room_leases SET x=$2,y=$3 WHERE character_id=$1`, id, x, y); err != nil {
		h.t.Fatal(err)
	}
}

func (h *harness) journeyInteract(token, id, key, step, target string) answer {
	return h.request("POST", "/v1/characters/"+id+"/journey/interact", token, key, map[string]string{"step_id": step, "target_id": target})
}

func (h *harness) equipItem(token, id, key, item string, equip bool) answer {
	return h.request("POST", "/v1/characters/"+id+"/pack/equipment", token, key, map[string]any{"item_uid": item, "equipped": equip})
}

func TestJourneyGrantsAndEquipmentAreExclusiveAndIdempotent(t *testing.T) {
	h := setupJourney(t)
	a, aid, _ := h.townRole("journala")
	b, bid, _ := h.townRole("journalb")
	requireStatus(t, h.request("GET", "/v1/characters/"+aid+"/journey", b, "", nil), 404)
	requireStatus(t, h.journeyInteract(a, aid, "distance-fixture", "s01", "npc_steward"), 400)
	requireStatus(t, h.journeyInteract(a, aid, "wrong-stage-fixture", "old_rubbing", "npc_scribe"), 409)
	requireStatus(t, h.request("POST", "/v1/characters/"+aid+"/journey/interact", a, "forged-fixture", map[string]any{"step_id": "s01", "target_id": "npc_steward", "gold": 9000}), 400)
	h.setJourneyPosition(aid, 418, 1325)
	results := make(chan answer, 6)
	var group sync.WaitGroup
	for i := 0; i < 6; i++ {
		group.Go(func() { results <- h.journeyInteract(a, aid, "concurrent-supplies", "s01", "npc_steward") })
	}
	group.Wait()
	close(results)
	weapon, armor := "", ""
	for result := range results {
		requireStatus(t, result, 200)
		journeyID(t, result, "gear_up")
		items := packItems(t, result)
		w, ar := items["tpl_sword_basic"], items["tpl_armor_basic"]
		if len(items) != 3 || items["itm_potion_hp_s"].Quantity != 3 || !w.Bound || !ar.Bound || (weapon != "" && (weapon != w.ID || armor != ar.ID)) {
			t.Fatal("same request must return its original three starter item instances")
		}
		weapon, armor = w.ID, ar.ID
	}
	if h.count("SELECT count(*) FROM inventory_items") != 3 || h.count("SELECT count(*) FROM inventory_ledger") != 3 || h.count("SELECT count(*) FROM quest_events") != 1 {
		t.Fatal("concurrent starter grant duplicated assets or history")
	}
	requireStatus(t, h.equipItem(b, bid, "stolen-weapon-fixture", weapon, true), 404)
	requireStatus(t, h.journeyInteract(a, aid, "concurrent-supplies", "south_check", "south_signpost"), 409)
	requireStatus(t, h.journeyInteract(a, aid, "duplicate-supplies", "s01", "npc_steward"), 409)
	first := h.equipItem(a, aid, "equip-first-fixture", weapon, true)
	requireStatus(t, first, 200)
	journeyID(t, first, "gear_up")
	second := h.equipItem(a, aid, "equip-second-fixture", armor, true)
	requireStatus(t, second, 200)
	journeyID(t, second, "south_check")
	if h.count("SELECT count(*) FROM inventory_ledger WHERE operation='equip'") != 2 || h.count("SELECT count(*) FROM inventory_items WHERE equipped_slot IS NOT NULL") != 2 {
		t.Fatal("equipped items are not reflected in immutable inventory history")
	}
	if _, err := h.db.Exec(context.Background(), "UPDATE quest_events SET target_id='changed'"); err == nil {
		t.Fatal("quest history can be rewritten")
	}
	if _, err := h.db.Exec(context.Background(), "DELETE FROM inventory_ledger"); err == nil {
		t.Fatal("inventory history can be deleted")
	}
}

func TestJourneyPackCapacityAndFailedGrantLeaveNoPartialProgress(t *testing.T) {
	h := setupJourney(t)
	a, id, _ := h.townRole("packcap")
	h.setJourneyPosition(id, 418, 1325)
	ctx := context.Background()
	_, err := h.db.Exec(ctx, `INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,source_transaction)
		SELECT gen_random_uuid(),$1,'fixture',1,'full_fixture' FROM generate_series(1,30)`, id)
	if err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.journeyInteract(a, id, "capacity-supplies", "s01", "npc_steward"), 409)
	if h.count("SELECT count(*) FROM inventory_items") != 30 || h.count("SELECT count(*) FROM quest_events") != 0 {
		t.Fatal("full pack changed before the starter grant fit")
	}
	_, err = h.db.Exec(ctx, `DELETE FROM inventory_items WHERE source_transaction='full_fixture';
		CREATE FUNCTION reject_starter_history() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
			IF NEW.operation='grant' THEN RAISE EXCEPTION 'fixture interrupted grant'; END IF; RETURN NEW;
		END $$;
		CREATE TRIGGER reject_starter_history BEFORE INSERT ON inventory_ledger FOR EACH ROW EXECUTE FUNCTION reject_starter_history()`)
	if err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.journeyInteract(a, id, "capacity-supplies", "s01", "npc_steward"), 500)
	if h.count("SELECT count(*) FROM inventory_items") != 0 || h.count("SELECT count(*) FROM quest_events") != 0 || h.count("SELECT count(*) FROM command_receipts WHERE operation LIKE 'journey.interact:%'") != 0 {
		t.Fatal("failed starter transaction left an item, quest event or receipt")
	}
	if _, err = h.db.Exec(ctx, "DROP TRIGGER reject_starter_history ON inventory_ledger"); err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.journeyInteract(a, id, "capacity-supplies", "s01", "npc_steward"), 200)
	if h.count("SELECT count(*) FROM inventory_items") != 3 || h.count("SELECT count(*) FROM quest_events") != 1 {
		t.Fatal("the same request could not complete exactly once after repair")
	}
}

func TestJourneyBattleMedicineAndVictoryAdvanceCommitWithTheirHistory(t *testing.T) {
	h := setupJourney(t)
	token, id, _ := h.townRole("journeyfight")
	h.setJourneyPosition(id, 418, 1325)
	supplies := h.journeyInteract(token, id, "battle-supply", "s01", "npc_steward")
	requireStatus(t, supplies, 200)
	items := packItems(t, supplies)
	for i, template := range []string{"tpl_sword_basic", "tpl_armor_basic"} {
		requireStatus(t, h.equipItem(token, id, fmt.Sprintf("battle-equip-%d", i), items[template].ID, true), 200)
	}
	h.setJourneyPosition(id, 600, 1588)
	requireStatus(t, h.journeyInteract(token, id, "read-road-sign", "south_check", "south_signpost"), 200)
	h.setJourneyPosition(id, 752, 1850)
	requireStatus(t, h.request("POST", "/v1/battles", token, "early-patrol", map[string]string{"encounter_id": "southern_patrol"}), 409)
	h.setJourneyPosition(id, 600, 1740)
	start := h.request("POST", "/v1/battles", token, "new-wolf-trial", map[string]string{"encounter_id": "training_wolf"})
	requireStatus(t, start, 201)
	battle := battleID(t, start)
	requireStatus(t, h.equipItem(token, id, "unequip-midfight", items["tpl_sword_basic"].ID, false), 409)
	ctx := context.Background()
	var loadout battleLoadout
	if err := h.db.QueryRow(ctx, "SELECT loadout FROM battles WHERE id=$1", battle).Scan(&loadout); err != nil || loadout.Health != 50 || loadout.Attack != 10 || loadout.Potions != 3 {
		t.Fatalf("unexpected persisted battle loadout: %+v, %v", loadout, err)
	}
	_, err := h.db.Exec(ctx, `CREATE FUNCTION deny_inventory_consumption() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
		IF NEW.operation='consume' THEN RAISE EXCEPTION 'fixture interrupted consumption'; END IF; RETURN NEW;
	END $$;
	CREATE TRIGGER deny_inventory_consumption BEFORE INSERT ON inventory_ledger FOR EACH ROW EXECUTE FUNCTION deny_inventory_consumption();
	CREATE FUNCTION deny_quest_victory() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
		IF NEW.event='victory' THEN RAISE EXCEPTION 'fixture interrupted quest victory'; END IF; RETURN NEW;
	END $$;
	CREATE TRIGGER deny_quest_victory BEFORE INSERT ON quest_events FOR EACH ROW EXECUTE FUNCTION deny_quest_victory()`)
	if err != nil {
		t.Fatal(err)
	}
	commandPath := "/v1/battles/" + battle + "/commands"
	potion := battleAction{Action: "potion"}
	requireStatus(t, h.request("POST", commandPath, token, "drink-potion-once", potion), 500)
	if h.count("SELECT quantity FROM inventory_items WHERE template_id='itm_potion_hp_s'") != 3 || h.count("SELECT count(*) FROM battle_inputs") != 0 {
		t.Fatal("rolled back consumption changed stock or authoritative inputs")
	}
	if _, err = h.db.Exec(ctx, "DROP TRIGGER deny_inventory_consumption ON inventory_ledger"); err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.request("POST", commandPath, token, "drink-potion-once", potion), 200)
	requireStatus(t, h.request("POST", commandPath, token, "drink-potion-once", potion), 200)
	h.server.Config.Handler.(*Server).cfg.Authority = &scriptedAuthority{"22222222222222222222222222222222"}
	requireStatus(t, h.request("GET", "/v1/battles/"+battle, token, "", nil), 200)
	if h.count("SELECT quantity FROM inventory_items WHERE template_id='itm_potion_hp_s'") != 2 || h.count("SELECT count(*) FROM inventory_ledger WHERE operation='consume'") != 1 {
		t.Fatal("duplicate or rebuilt battle consumed another potion")
	}
	attack := battleAction{Action: "attack"}
	requireStatus(t, h.request("POST", commandPath, token, "win-and-advance", attack), 500)
	if h.count("SELECT count(*) FROM battle_results") != 0 || h.count("SELECT count(*) FROM battle_reward_claims") != 0 || h.count("SELECT gold FROM wallets") != 100 ||
		h.count("SELECT count(*) FROM character_progress WHERE story_step='wolf_trial'") != 1 || h.count("SELECT count(*) FROM battle_inputs") != 1 {
		t.Fatal("fault during quest completion left battle reward or progress partially committed")
	}
	if _, err = h.db.Exec(ctx, "DROP TRIGGER deny_quest_victory ON quest_events"); err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.request("POST", commandPath, token, "win-and-advance", attack), 200)
	requireStatus(t, h.request("POST", commandPath, token, "win-and-advance", attack), 200)
	view := h.request("GET", "/v1/characters/"+id+"/journey", token, "", nil)
	requireStatus(t, view, 200)
	journeyID(t, view, "report_back")
	if h.count("SELECT gold FROM wallets") != 110 || h.count("SELECT count(*) FROM quest_events WHERE event='victory'") != 1 {
		t.Fatal("victory reward and quest completion must each apply once")
	}
}
