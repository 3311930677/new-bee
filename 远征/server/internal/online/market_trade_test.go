package online

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"testing"

	"golang.org/x/crypto/bcrypt"
)

func seedTradeableItem(t *testing.T, h *harness, charID, tpl string, qty int, bound bool, props string) string {
	t.Helper()
	uid := newID()
	txID := "seed:" + uid
	if props == "" {
		props = "{}"
	}
	if _, err := h.db.Exec(context.Background(), `INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,bound,source_transaction,properties)
        VALUES($1,$2,$3,$4,$5,$6,$7::jsonb)`, uid, charID, tpl, qty, bound, txID, props); err != nil {
		t.Fatal(err)
	}
	if _, err := h.db.Exec(context.Background(), `INSERT INTO inventory_ledger(id,character_id,item_uid,transaction_id,operation,delta,quantity_after,equipped_slot)
        VALUES($1,$2,$3,$4,'grant',$5,$5,NULL)`, newID(), charID, uid, txID, qty); err != nil {
		t.Fatal(err)
	}
	return uid
}

func assertMarketConservation(t *testing.T, h *harness, expectedMinted map[string]int) {
	t.Helper()
	ctx := context.Background()

	var walletSum, payoutGold, tradeEscrow, ledgerNet int64
	if err := h.db.QueryRow(ctx, `SELECT coalesce(sum(gold),0) FROM wallets`).Scan(&walletSum); err != nil {
		t.Fatal(err)
	}
	if err := h.db.QueryRow(ctx, `SELECT coalesce(sum(gold_amount),0) FROM market_payouts WHERE status='pending'`).Scan(&payoutGold); err != nil {
		t.Fatal(err)
	}
	if err := h.db.QueryRow(ctx, `SELECT coalesce(sum(initiator_gold+partner_gold),0) FROM trade_sessions WHERE status='active'`).Scan(&tradeEscrow); err != nil {
		t.Fatal(err)
	}
	if err := h.db.QueryRow(ctx, `SELECT coalesce(sum(delta),0) FROM wallet_ledger WHERE currency='gold'`).Scan(&ledgerNet); err != nil {
		t.Fatal(err)
	}
	if walletSum != ledgerNet {
		t.Fatalf("wallet sum mismatch ledger net: wallets=%d ledger=%d", walletSum, ledgerNet)
	}

	var taxSum, feeSum, grossSum, payoutPaidSum int64
	_ = h.db.QueryRow(ctx, `SELECT coalesce(sum(tax_gold),0),coalesce(sum(gross_gold),0) FROM market_fills`).Scan(&taxSum, &grossSum)
	_ = h.db.QueryRow(ctx, `SELECT coalesce(sum(-delta),0) FROM wallet_ledger WHERE reason='market_listing_fee'`).Scan(&feeSum)
	_ = h.db.QueryRow(ctx, `SELECT coalesce(sum(delta),0) FROM wallet_ledger WHERE reason='market_sale_proceeds'`).Scan(&payoutPaidSum)

	var initialAndExternalNet int64
	_ = h.db.QueryRow(ctx, `SELECT coalesce(sum(delta),0) FROM wallet_ledger WHERE reason IN ('online_starter','npc_shop_buy','npc_shop_sell')`).Scan(&initialAndExternalNet)
	accounted := walletSum + payoutGold + tradeEscrow + feeSum + taxSum
	if accounted != initialAndExternalNet {
		t.Fatalf("GLOBAL GOLD CONSERVATION BROKEN: accounted(wallets=%d + payout=%d + trade=%d + fees=%d + tax=%d = %d) != minted_external(%d); gross=%d paid=%d",
			walletSum, payoutGold, tradeEscrow, feeSum, taxSum, accounted, initialAndExternalNet, grossSum, payoutPaidSum)
	}

	for tpl, want := range expectedMinted {
		var inPack, inOrders, inPayouts, inTrades int
		_ = h.db.QueryRow(ctx, `SELECT coalesce(sum(quantity),0) FROM inventory_items WHERE template_id=$1`, tpl).Scan(&inPack)
		_ = h.db.QueryRow(ctx, `SELECT coalesce(sum(remaining_qty),0) FROM market_orders WHERE template_id=$1 AND status IN ('open','partial')`, tpl).Scan(&inOrders)
		_ = h.db.QueryRow(ctx, `SELECT coalesce(sum(quantity),0) FROM market_payouts WHERE template_id=$1 AND status='pending'`, tpl).Scan(&inPayouts)
		_ = h.db.QueryRow(ctx, `SELECT coalesce(sum(t.quantity),0) FROM trade_offers t JOIN trade_sessions s ON s.trade_id=t.trade_id WHERE t.template_id=$1 AND s.status='active'`, tpl).Scan(&inTrades)
		total := inPack + inOrders + inPayouts + inTrades
		if total != want {
			t.Fatalf("ITEM CONSERVATION BROKEN for %s: pack=%d orders=%d payouts=%d trades=%d sum=%d want=%d",
				tpl, inPack, inOrders, inPayouts, inTrades, total, want)
		}
	}
}

func TestMarketM0SandboxGating(t *testing.T) {
	rules := loadRealOnlineRules(t)
	sandboxMarket := *rules.Market
	sandboxMarket.Stage = "M0"
	rules.Market = &sandboxMarket
	h := setupWithConfig(t, Config{
		ContentVersion: "integration-v1",
		PasswordCost:   bcrypt.MinCost,
		Rules:          rules,
		Authority:      &coopScriptedAuthority{"22222222222222222222222222222222"},
	})
	tok, charID, _ := h.townCharacterWithRole(t, "l3sandbox1", "zs", 1, false)
	grainUID := seedTradeableItem(t, h, charID, "mat_grain", 2, false, `{}`)
	res := h.request("POST", "/v1/market/orders", tok, "m0-block-1", map[string]any{
		"item_uid": grainUID, "quantity": 1, "unit_price": 12,
	})
	if res.status != http.StatusBadRequest || res.code != "market_stage_locked" {
		t.Fatalf("expected market_stage_locked in M0, got %d %s", res.status, res.body)
	}
}

func TestMarketM1M2ConsignmentConcurrencyCancelAndPayouts(t *testing.T) {
	h := setupL2World(t)

	sellerTok, sellerChar, _ := h.townCharacterWithRole(t, "l3seller1", "zs", 1, false)
	buyer1Tok, buyer1Char, _ := h.townCharacterWithRole(t, "l3buyer1", "ck", 1, false)
	buyer2Tok, _, _ := h.townCharacterWithRole(t, "l3buyer2", "fs", 1, false)

	minted := map[string]int{}
	boundSword := seedTradeableItem(t, h, sellerChar, "tpl_sword_basic", 1, true, `{}`)
	grainUID := seedTradeableItem(t, h, sellerChar, "mat_grain", 5, false, `{"origin":"sandbox"}`)
	minted["mat_grain"] = 5
	forgedUID := seedTradeableItem(t, h, sellerChar, "tpl_sword_forged", 1, false, `{"affix":"连斩+2","enhance":3}`)
	minted["tpl_sword_forged"] = 1

	res := h.request("POST", "/v1/market/orders", sellerTok, "bad-bound-1", map[string]any{
		"item_uid": boundSword, "quantity": 1, "unit_price": 20,
	})
	if res.status != http.StatusBadRequest || res.code != "item_bound" {
		t.Fatalf("expected item_bound rejection, got %d %s", res.status, res.body)
	}

	res = h.request("POST", "/v1/market/orders", sellerTok, "bad-price-1", map[string]any{
		"item_uid": grainUID, "quantity": 1, "unit_price": 9999,
	})
	if res.status != http.StatusBadRequest || res.code != "price_out_of_bounds" {
		t.Fatalf("expected price bounds rejection, got %d %s", res.status, res.body)
	}

	res = h.request("POST", "/v1/market/orders", sellerTok, "list-grain-1", map[string]any{
		"item_uid": grainUID, "quantity": 5, "unit_price": 18,
	})
	requireStatus(t, res, http.StatusOK)
	orderID, _ := decodeVal[string](t, res.data["order_id"])

	res = h.request("POST", "/v1/market/orders/"+orderID+"/buy", sellerTok, "self-buy-1", map[string]any{"quantity": 1})
	if res.status != http.StatusForbidden || res.code != "self_trade_forbidden" {
		t.Fatalf("expected self_trade_forbidden, got %d %s", res.status, res.body)
	}
	if n := h.count(`SELECT count(*) FROM economy_alerts WHERE alert_type='self_trade_attempt'`); n != 1 {
		t.Fatalf("expected self_trade_attempt alert, got %d", n)
	}

	res = h.request("POST", "/v1/market/orders/"+orderID+"/buy", buyer1Tok, "buy-part-1", map[string]any{"quantity": 2})
	requireStatus(t, res, http.StatusOK)
	payoutID1, _ := decodeVal[string](t, res.data["payout_id"])
	fillID1, _ := decodeVal[string](t, res.data["fill_id"])

	res2 := h.request("POST", "/v1/market/orders/"+orderID+"/buy", buyer1Tok, "buy-part-1", map[string]any{"quantity": 2})
	requireStatus(t, res2, http.StatusOK)
	fillID2, _ := decodeVal[string](t, res2.data["fill_id"])
	if fillID1 != fillID2 {
		t.Fatal("idempotent buy retry created different fill")
	}

	var wg sync.WaitGroup
	var buyStatus, cancelStatus int
	var cancelPayoutID string
	wg.Add(2)
	go func() {
		defer wg.Done()
		r := h.request("POST", "/v1/market/orders/"+orderID+"/buy", buyer2Tok, "race-buy-1", map[string]any{"quantity": 3})
		buyStatus = r.status
	}()
	go func() {
		defer wg.Done()
		r := h.request("POST", "/v1/market/orders/"+orderID+"/cancel", sellerTok, "race-cancel-1", map[string]any{})
		cancelStatus = r.status
		if r.status == http.StatusOK {
			cancelPayoutID, _ = decodeVal[string](t, r.data["payout_id"])
		}
	}()
	wg.Wait()
	if (buyStatus == http.StatusOK) == (cancelStatus == http.StatusOK) {
		t.Fatalf("concurrent buy vs cancel must let strictly one win: buy=%d cancel=%d", buyStatus, cancelStatus)
	}

	res = h.request("POST", "/v1/market/payouts/"+payoutID1+"/claim", sellerTok, "claim-p1", map[string]any{})
	requireStatus(t, res, http.StatusOK)

	if cancelPayoutID != "" {
		var fillerUIDs []string
		for i := 0; i < 30; i++ {
			fillerUIDs = append(fillerUIDs, seedTradeableItem(t, h, sellerChar, "mat_salt", 1, false, `{}`))
			minted["mat_salt"]++
		}
		res = h.request("POST", "/v1/market/payouts/"+cancelPayoutID+"/claim", sellerTok, "claim-full-1", map[string]any{})
		if res.status != http.StatusConflict || res.code != "pack_full" {
			t.Fatalf("expected pack_full claiming returned item, got %d %s", res.status, res.body)
		}
		npcRes := h.request("POST", "/v1/market/npc/trade", sellerTok, "npc-sell-space", map[string]any{
			"action": "sell", "template_id": "mat_salt", "item_uid": fillerUIDs[0], "quantity": 1,
		})
		requireStatus(t, npcRes, http.StatusOK)
		minted["mat_salt"]--
		res = h.request("POST", "/v1/market/payouts/"+cancelPayoutID+"/claim", sellerTok, "claim-full-retry", map[string]any{})
		requireStatus(t, res, http.StatusOK)
	}

	res = h.request("POST", "/v1/market/orders", sellerTok, "list-sword-1", map[string]any{
		"item_uid": forgedUID, "quantity": 1, "unit_price": 350,
	})
	requireStatus(t, res, http.StatusOK)
	swordOrderID, _ := decodeVal[string](t, res.data["order_id"])
	if n := h.count(`SELECT count(*) FROM economy_alerts WHERE alert_type='price_outlier'`); n != 1 {
		t.Fatalf("expected price_outlier alert, got %d", n)
	}

	res = h.request("POST", "/v1/characters/"+sellerChar+"/pack/equipment", sellerTok, "equip-escrowed", map[string]any{
		"item_uid": forgedUID, "equipped": true,
	})
	if res.status != http.StatusNotFound {
		t.Fatalf("escrowed sword should not be equippable, got %d", res.status)
	}

	for i := 0; i < 20; i++ {
		uid := seedTradeableItem(t, h, buyer1Char, "mat_iron", 1, false, `{}`)
		minted["mat_iron"]++
		r := h.request("POST", "/v1/market/npc/trade", buyer1Tok, fmt.Sprintf("b1-npc-%d", i), map[string]any{
			"action": "sell", "template_id": "mat_iron", "item_uid": uid, "quantity": 1,
		})
		requireStatus(t, r, http.StatusOK)
		minted["mat_iron"]--
	}

	res = h.request("POST", "/v1/market/orders/"+swordOrderID+"/buy", buyer1Tok, "buy-sword-1", map[string]any{"quantity": 1})
	requireStatus(t, res, http.StatusOK)
	boughtUID, _ := decodeVal[string](t, res.data["buyer_item_uid"])
	var propsText string
	if err := h.db.QueryRow(context.Background(), `SELECT properties::text FROM inventory_items WHERE item_uid=$1`, boughtUID).Scan(&propsText); err != nil {
		t.Fatal(err)
	}
	var parsed map[string]any
	_ = json.Unmarshal([]byte(propsText), &parsed)
	if parsed["affix"] != "连斩+2" {
		t.Fatalf("expected preserved affixes, got %s", propsText)
	}

	h.server.Config.Handler.(*Server).SetMarketPaused(true)
	res = h.request("POST", "/v1/market/npc/trade", buyer1Tok, "paused-buy", map[string]any{
		"action": "buy", "template_id": "mat_grain", "quantity": 1,
	})
	if res.status != http.StatusServiceUnavailable || res.code != "market_paused" {
		t.Fatalf("expected 503 market_paused, got %d %s", res.status, res.body)
	}
	sumRes := h.request("GET", "/v1/market/summary", buyer1Tok, "", nil)
	requireStatus(t, sumRes, http.StatusOK)
	h.server.Config.Handler.(*Server).SetMarketPaused(false)

	assertMarketConservation(t, h, minted)
}

func TestMarketM3FaceToFaceTradeReconfirmCancelAndConservation(t *testing.T) {
	h := setupL2World(t)
	tokA, charA, _ := h.townCharacterWithRole(t, "l3tradea", "zs", 1, false)
	tokB, charB, _ := h.townCharacterWithRole(t, "l3tradeb", "fz", 1, false)

	res := h.request("POST", "/v1/trade/sessions", tokA, "", map[string]any{"target_character_id": charB})
	if res.status != http.StatusForbidden || res.code != "friendship_required" {
		t.Fatalf("expected friendship_required, got %d %s", res.status, res.body)
	}

	reqRes := h.request("POST", "/v1/social/friends/request", tokA, "fr-req-1", map[string]any{"target_character_id": charB})
	requireStatus(t, reqRes, http.StatusOK)
	stateB := h.request("GET", "/v1/social/state", tokB, "", nil)
	requireStatus(t, stateB, http.StatusOK)
	var reqs []struct {
		ID        string `json:"id"`
		Direction string `json:"direction"`
	}
	_ = json.Unmarshal(stateB.data["friend_requests"], &reqs)
	if len(reqs) != 1 || reqs[0].Direction != "incoming" {
		t.Fatalf("expected 1 incoming friend request, got %s", stateB.body)
	}
	respRes := h.request("POST", "/v1/social/friends/"+reqs[0].ID+"/respond", tokB, "fr-resp-1", map[string]any{"accept": true})
	requireStatus(t, respRes, http.StatusOK)

	minted := map[string]int{}
	herbUID := seedTradeableItem(t, h, charA, "mat_herbs", 3, false, `{"origin":"gather"}`)
	minted["mat_herbs"] = 3
	armorUID := seedTradeableItem(t, h, charB, "tpl_armor_forged", 1, false, `{"enhance":2}`)
	minted["tpl_armor_forged"] = 1

	res = h.request("POST", "/v1/trade/sessions", tokA, "", map[string]any{"target_character_id": charB})
	requireStatus(t, res, http.StatusOK)
	tid1, _ := decodeVal[string](t, res.data["trade_id"])
	res = h.request("POST", "/v1/trade/sessions/"+tid1+"/offer", tokA, "", map[string]any{"gold": 20, "add_item_uid": herbUID, "add_quantity": 2})
	requireStatus(t, res, http.StatusOK)
	res = h.request("POST", "/v1/trade/sessions/"+tid1+"/cancel", tokB, "cancel-trade-1", map[string]any{})
	requireStatus(t, res, http.StatusOK)

	res = h.request("POST", "/v1/trade/sessions", tokA, "", map[string]any{"target_character_id": charB})
	requireStatus(t, res, http.StatusOK)
	tid2, _ := decodeVal[string](t, res.data["trade_id"])

	res = h.request("POST", "/v1/trade/sessions/"+tid2+"/offer", tokA, "", map[string]any{"gold": 15})
	requireStatus(t, res, http.StatusOK)
	res = h.request("POST", "/v1/trade/sessions/"+tid2+"/offer", tokB, "", map[string]any{"add_item_uid": armorUID, "add_quantity": 1})
	requireStatus(t, res, http.StatusOK)
	rev2, _ := decodeVal[int64](t, res.data["revision"])

	res = h.request("POST", "/v1/trade/sessions/"+tid2+"/confirm", tokB, "conf-b-1", map[string]any{"revision": rev2})
	requireStatus(t, res, http.StatusOK)

	res = h.request("POST", "/v1/trade/sessions/"+tid2+"/offer", tokA, "", map[string]any{"gold": 25})
	requireStatus(t, res, http.StatusOK)
	partnerConf, _ := decodeVal[bool](t, res.data["partner_confirmed"])
	initConf, _ := decodeVal[bool](t, res.data["initiator_confirmed"])
	if partnerConf || initConf {
		t.Fatal("editing trade offer did not clear both confirmations")
	}
	rev3, _ := decodeVal[int64](t, res.data["revision"])
	if rev3 <= rev2 {
		t.Fatalf("expected revision increment, got %d -> %d", rev2, rev3)
	}

	res = h.request("POST", "/v1/trade/sessions/"+tid2+"/confirm", tokB, "conf-b-stale", map[string]any{"revision": rev2})
	if res.status != http.StatusConflict || res.code != "trade_changed_reconfirm_required" {
		t.Fatalf("expected stale confirm rejection, got %d %s", res.status, res.body)
	}

	res = h.request("POST", "/v1/trade/sessions/"+tid2+"/confirm", tokA, "conf-a-final", map[string]any{"revision": rev3})
	requireStatus(t, res, http.StatusOK)
	res = h.request("POST", "/v1/trade/sessions/"+tid2+"/confirm", tokB, "conf-b-final", map[string]any{"revision": rev3})
	requireStatus(t, res, http.StatusOK)
	st, _ := decodeVal[string](t, res.data["status"])
	if st != "completed" {
		t.Fatalf("expected completed trade, got %s", st)
	}

	if goldA := h.count(`SELECT gold FROM wallets WHERE character_id='` + charA + `'`); goldA != 75 {
		t.Fatalf("expected A gold 75, got %d", goldA)
	}
	if goldB := h.count(`SELECT gold FROM wallets WHERE character_id='` + charB + `'`); goldB != 125 {
		t.Fatalf("expected B gold 125, got %d", goldB)
	}
	if armorA := h.count(`SELECT count(*) FROM inventory_items WHERE character_id='` + charA + `' AND template_id='tpl_armor_forged' AND quantity=1`); armorA != 1 {
		t.Fatalf("expected A received forged armor, got %d", armorA)
	}

	assertMarketConservation(t, h, minted)
}
