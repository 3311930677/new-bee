package online

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

type NpcRegionRule struct {
	Label      string `json:"label"`
	BuyMultBps int64  `json:"buy_mult_bps"`
	SellMultBps int64 `json:"sell_mult_bps"`
	Event      string `json:"event"`
}

type MarketRules struct {
	Stage               string                   `json:"stage"`
	SandboxOnly         bool                     `json:"sandbox_only"`
	MaxActiveOrders     int                      `json:"max_active_orders"`
	ListingFeeBps       int64                    `json:"listing_fee_bps"`
	TaxBps              int64                    `json:"tax_bps"`
	OrderTTLHours       int                      `json:"order_ttl_hours"`
	PayoutTTLHours      int                      `json:"payout_ttl_hours"`
	TradeTTLSeconds     int                      `json:"trade_ttl_seconds"`
	PriceFloorRatioBps  int64                    `json:"price_floor_ratio_bps"`
	PriceCeilingRatioBps int64                   `json:"price_ceiling_ratio_bps"`
	AnomalyRatioBps     int64                    `json:"anomaly_ratio_bps"`
	DailyNpcTradeCap    int                      `json:"daily_npc_trade_cap"`
	NpcRegions          map[string]NpcRegionRule `json:"npc_regions"`
	NpcFloorGoods       []string                 `json:"npc_floor_goods"`
}

var marketStageRank = map[string]int{"M0": 0, "M1": 1, "M2": 2, "M3": 3}

func (m MarketRules) allowsStage(stage string) bool {
	return marketStageRank[m.Stage] >= marketStageRank[stage]
}

func (m MarketRules) validate(items map[string]JourneyItem, maps map[string]MapRule) error {
	invalid := errors.New("invalid online market rules")
	if _, ok := marketStageRank[m.Stage]; !ok {
		return invalid
	}
	if m.MaxActiveOrders < 1 || m.MaxActiveOrders > 50 || m.ListingFeeBps < 0 || m.ListingFeeBps > 1000 ||
		m.TaxBps < 0 || m.TaxBps > 1000 || m.OrderTTLHours < 1 || m.OrderTTLHours > 168 ||
		m.PayoutTTLHours < 1 || m.PayoutTTLHours > 720 || m.TradeTTLSeconds < 30 || m.TradeTTLSeconds > 1800 ||
		m.PriceFloorRatioBps < 1000 || m.PriceFloorRatioBps > 10000 || m.PriceCeilingRatioBps < 10000 || m.PriceCeilingRatioBps > 100000 ||
		m.AnomalyRatioBps < 10000 || m.DailyNpcTradeCap < 1 || m.DailyNpcTradeCap > 500 || len(m.NpcRegions) == 0 {
		return invalid
	}
	for id, reg := range m.NpcRegions {
		if _, ok := maps[id]; !ok || reg.Label == "" || reg.BuyMultBps <= 0 || reg.SellMultBps <= 0 {
			return invalid
		}
	}
	for _, tpl := range m.NpcFloorGoods {
		it, ok := items[tpl]
		if !ok || !it.Tradeable || it.MarketCategory != "commodity" || it.NpcBuyPrice <= 0 || it.NpcSellPrice <= 0 || it.NpcSellPrice > it.NpcBuyPrice {
			return invalid
		}
	}
	for _, it := range items {
		if it.Tradeable && it.BasePrice <= 0 {
			return invalid
		}
	}
	return nil
}

func (s *Server) SetMarketPaused(paused bool) {
	s.marketPaused.Store(paused)
}

func requireNotBlocked(ctx context.Context, tx pgx.Tx, acctA, acctB string) error {
	blocked, err := accountsBlocked(ctx, tx, acctA, acctB)
	if err != nil {
		return err
	}
	if blocked {
		return &apiError{403, "blocked_interaction", "因屏蔽关系限制，当前无法进行该交易"}
	}
	return nil
}

func (s *Server) requireMarket(sandboxTest bool) (*MarketRules, *JourneyRules, error) {
	if s.cfg.Rules.Market == nil || s.cfg.Rules.Journey == nil {
		return nil, nil, &apiError{404, "market_unavailable", "市场功能尚未开放"}
	}
	if s.cfg.Rules.Market.SandboxOnly && !sandboxTest {
		return nil, nil, &apiError{403, "market_sandbox_only", "市场目前仅在内部沙盒测试中开放"}
	}
	return s.cfg.Rules.Market, s.cfg.Rules.Journey, nil
}

func (s *Server) recordEconomyAlert(ctx context.Context, alertType, severity, accountID, charID, orderID, tradeID string, details map[string]any) {
	raw, _ := json.Marshal(details)
	if len(raw) == 0 {
		raw = []byte("{}")
	}
	_, _ = s.db.Exec(ctx, `INSERT INTO economy_alerts(alert_type,severity,account_id,character_id,order_id,trade_id,details)
        VALUES($1,$2,nullif($3,'')::uuid,nullif($4,'')::uuid,nullif($5,'')::uuid,nullif($6,'')::uuid,$7::jsonb)`,
		alertType, severity, accountID, charID, orderID, tradeID, string(raw))
}

func adjustGoldTx(ctx context.Context, tx pgx.Tx, charID, transactionID string, delta int64, reason string) (int64, error) {
	if delta == 0 {
		var balance int64
		err := tx.QueryRow(ctx, `SELECT gold FROM wallets WHERE character_id=$1`, charID).Scan(&balance)
		return balance, err
	}
	var balance int64
	if delta < 0 {
		err := tx.QueryRow(ctx, `UPDATE wallets SET gold=gold+$1,version=version+1,updated_at=now() WHERE character_id=$2 AND gold>=$3 RETURNING gold`,
			delta, charID, -delta).Scan(&balance)
		if errors.Is(err, pgx.ErrNoRows) {
			return 0, &apiError{409, "insufficient_gold", "金币不足"}
		}
		if err != nil {
			return 0, err
		}
	} else {
		err := tx.QueryRow(ctx, `UPDATE wallets SET gold=gold+$1,version=version+1,updated_at=now() WHERE character_id=$2 RETURNING gold`,
			delta, charID).Scan(&balance)
		if err != nil {
			return 0, err
		}
	}
	if _, err := tx.Exec(ctx, `INSERT INTO wallet_ledger(id,character_id,transaction_id,currency,delta,balance_after,reason)
        VALUES($1,$2,$3,'gold',$4,$5,$6)`, newID(), charID, transactionID, delta, balance, reason); err != nil {
		return 0, err
	}
	return balance, nil
}

func consumePackItemTx(ctx context.Context, tx pgx.Tx, charID, itemUID, txID string, qty int, rules *JourneyRules) (template string, propsRaw []byte, origin string, err error) {
	var have int
	var bound bool
	var slot string
	err = tx.QueryRow(ctx, `SELECT template_id,quantity,bound,coalesce(equipped_slot,''),properties,source_transaction
        FROM inventory_items WHERE character_id=$1 AND item_uid=$2 AND quantity>0 FOR UPDATE`, charID, itemUID).
		Scan(&template, &have, &bound, &slot, &propsRaw, &origin)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil, "", &apiError{404, "item_not_found", "找不到该行囊物品"}
	}
	if err != nil {
		return "", nil, "", err
	}
	if bound {
		return "", nil, "", bad("item_bound", "已绑定物品不可交易或寄售")
	}
	if slot != "" {
		return "", nil, "", bad("item_equipped", "已装备或出战的物品需先卸下才能上架或交易")
	}
	it, ok := rules.Items[template]
	if !ok || !it.Tradeable {
		return "", nil, "", bad("item_not_tradeable", "该物品暂不可交易")
	}
	if qty <= 0 || qty > have {
		return "", nil, "", bad("invalid_quantity", "可用物品数量不足")
	}
	var after int
	if err = tx.QueryRow(ctx, `UPDATE inventory_items SET quantity=quantity-$1,version=version+1,updated_at=now()
        WHERE character_id=$2 AND item_uid=$3 RETURNING quantity`, qty, charID, itemUID).Scan(&after); err != nil {
		return "", nil, "", err
	}
	if err = appendInventoryLedger(ctx, tx, charID, itemUID, txID, "consume", -qty, after, ""); err != nil {
		return "", nil, "", err
	}
	return template, propsRaw, origin, nil
}

func grantCustomPackItemTx(ctx context.Context, tx pgx.Tx, charID, txID string, capacity int, template string, qty int, bound bool, propsRaw []byte) (string, error) {
	var occupied int
	if err := tx.QueryRow(ctx, `SELECT count(*) FROM inventory_items WHERE character_id=$1 AND quantity>0`, charID).Scan(&occupied); err != nil {
		return "", err
	}
	if occupied+1 > capacity {
		return "", &apiError{409, "pack_full", "行囊空间不足"}
	}
	if len(propsRaw) == 0 {
		propsRaw = []byte("{}")
	}
	uid := newID()
	if _, err := tx.Exec(ctx, `INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,bound,source_transaction,properties)
        VALUES($1,$2,$3,$4,$5,$6,$7::jsonb)`, uid, charID, template, qty, bound, txID, string(propsRaw)); err != nil {
		return "", err
	}
	if err := appendInventoryLedger(ctx, tx, charID, uid, txID, "grant", qty, qty, ""); err != nil {
		return "", err
	}
	return uid, nil
}

func insertMarketPayoutTx(ctx context.Context, tx pgx.Tx, charID, accountID, orderID, fillID, kind string, gold int64, template string, qty int, propsRaw []byte, origin string, ttlHours int) (string, error) {
	if len(propsRaw) == 0 {
		propsRaw = []byte("{}")
	}
	payoutID := newID()
	expiresAt := time.Now().UTC().Add(time.Duration(ttlHours) * time.Hour)
	_, err := tx.Exec(ctx, `INSERT INTO market_payouts(payout_id,character_id,account_id,order_id,fill_id,kind,gold_amount,template_id,quantity,item_properties,item_origin,status,expires_at)
        VALUES($1,$2,$3,nullif($4,'')::uuid,nullif($5,'')::uuid,$6,$7,$8,$9,$10::jsonb,$11,'pending',$12)`,
		payoutID, charID, accountID, orderID, fillID, kind, gold, template, qty, string(propsRaw), origin, expiresAt)
	return payoutID, err
}

func computeMarketTax(gross, taxBps int64) int64 {
	if gross <= 1 || taxBps <= 0 {
		return 0
	}
	tax := (gross * taxBps) / 10000
	if tax < 1 {
		tax = 1
	}
	if tax >= gross {
		tax = gross - 1
	}
	return tax
}

func computeListingFee(totalPrice, feeBps int64) int64 {
	fee := (totalPrice * feeBps) / 10000
	if fee < 1 {
		fee = 1
	}
	return fee
}

func (m *MarketRules) npcPricesFor(mapID string, item JourneyItem) (buyPrice int64, sellPrice int64, reg NpcRegionRule) {
	reg, ok := m.NpcRegions[mapID]
	if !ok {
		reg = NpcRegionRule{Label: "昭元集市", BuyMultBps: 10000, SellMultBps: 10000}
	}
	buyPrice = (item.NpcBuyPrice*reg.BuyMultBps + 5000) / 10000
	if buyPrice < 1 {
		buyPrice = 1
	}
	sellPrice = (item.NpcSellPrice*reg.SellMultBps + 5000) / 10000
	if sellPrice < 1 {
		sellPrice = 1
	}
	if sellPrice >= buyPrice {
		sellPrice = buyPrice - 1
		if sellPrice < 1 {
			sellPrice = 1
		}
	}
	return buyPrice, sellPrice, reg
}

func (s *Server) marketSummary(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	tx, err := s.db.BeginTx(r.Context(), pgx.TxOptions{AccessMode: pgx.ReadOnly})
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	c, err := s.activeCharacter(r.Context(), tx, who)
	if err != nil {
		s.fail(w, err)
		return
	}
	var gold int64
	if err = tx.QueryRow(r.Context(), `SELECT gold FROM wallets WHERE character_id=$1`, c.ID).Scan(&gold); err != nil {
		s.fail(w, err)
		return
	}
	mapID := c.MapID
	if mapID == "" {
		mapID = s.cfg.Rules.Town.MapID
	}
	reg := rules.NpcRegions[mapID]

	// Recent fills stats + open listing supply per template
	npcGoods := []map[string]any{}
	for _, tpl := range rules.NpcFloorGoods {
		it := journey.Items[tpl]
		buyP, sellP, _ := rules.npcPricesFor(mapID, it)
		var openQty, minFill, maxFill int64
		_ = tx.QueryRow(r.Context(), `SELECT coalesce(sum(remaining_qty),0) FROM market_orders WHERE status IN ('open','partial') AND expires_at>now() AND template_id=$1`, tpl).Scan(&openQty)
		_ = tx.QueryRow(r.Context(), `SELECT coalesce(min(unit_price),0),coalesce(max(unit_price),0) FROM market_fills WHERE template_id=$1 AND created_at>now()-interval '24 hours'`, tpl).Scan(&minFill, &maxFill)
		npcGoods = append(npcGoods, map[string]any{
			"template_id":    tpl,
			"name":           it.Name,
			"base_price":     it.BasePrice,
			"npc_buy_price":  buyP,
			"npc_sell_price": sellP,
			"open_qty":       openQty,
			"recent_min":     minFill,
			"recent_max":     maxFill,
		})
	}
	recentFills := []map[string]any{}
	rows, err := tx.Query(r.Context(), `SELECT fill_id::text,template_id,quantity,unit_price,gross_gold,tax_gold,seller_net_gold,created_at
        FROM market_fills ORDER BY created_at DESC LIMIT 12`)
	if err != nil {
		s.fail(w, err)
		return
	}
	for rows.Next() {
		var fillID, tpl string
		var qty int
		var price, gross, tax, net int64
		var ts time.Time
		if err = rows.Scan(&fillID, &tpl, &qty, &price, &gross, &tax, &net, &ts); err != nil {
			rows.Close()
			s.fail(w, err)
			return
		}
		recentFills = append(recentFills, map[string]any{
			"fill_id": fillID, "template_id": tpl, "name": journey.Items[tpl].Name,
			"quantity": qty, "unit_price": price, "gross_gold": gross, "tax_gold": tax, "seller_net_gold": net,
			"created_at": ts.UTC().Format(time.RFC3339),
		})
	}
	rows.Close()

	var pendingPayouts, openAlerts, myActiveOrders int
	_ = tx.QueryRow(r.Context(), `SELECT count(*) FROM market_payouts WHERE character_id=$1 AND status='pending'`, c.ID).Scan(&pendingPayouts)
	_ = tx.QueryRow(r.Context(), `SELECT count(*) FROM economy_alerts WHERE (account_id=$1 OR account_id IS NULL) AND reviewed=false`, who.AccountID).Scan(&openAlerts)
	_ = tx.QueryRow(r.Context(), `SELECT count(*) FROM market_orders WHERE seller_character_id=$1 AND status IN ('open','partial')`, c.ID).Scan(&myActiveOrders)

	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{
		"stage":              rules.Stage,
		"sandbox_only":       rules.SandboxOnly,
		"paused":             s.marketPaused.Load(),
		"gold":               gold,
		"map_id":             mapID,
		"region_label":       reg.Label,
		"region_event":       reg.Event,
		"listing_fee_bps":    rules.ListingFeeBps,
		"tax_bps":            rules.TaxBps,
		"max_active_orders":  rules.MaxActiveOrders,
		"my_active_orders":   myActiveOrders,
		"pending_payouts":    pendingPayouts,
		"open_alerts":        openAlerts,
		"npc_goods":          npcGoods,
		"recent_fills":       recentFills,
	})
}

func (s *Server) listMarketOrders(w http.ResponseWriter, r *http.Request, who identity) {
	_, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	category := strings.TrimSpace(r.URL.Query().Get("category"))
	tx, err := s.db.BeginTx(r.Context(), pgx.TxOptions{AccessMode: pgx.ReadOnly})
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	c, err := s.activeCharacter(r.Context(), tx, who)
	if err != nil {
		s.fail(w, err)
		return
	}
	rows, err := tx.Query(r.Context(), `SELECT o.order_id::text,o.seller_character_id::text,ch.nickname,o.category,o.template_id,
        o.item_properties,o.item_origin,o.unit_price,o.initial_qty,o.remaining_qty,o.listing_fee,o.tax_bps,o.status,o.expires_at
        FROM market_orders o JOIN characters ch ON ch.id=o.seller_character_id
        WHERE ((o.status IN ('open','partial') AND o.expires_at>now()) OR o.seller_character_id=$1)
          AND ($2='' OR o.category=$2)
        ORDER BY o.created_at DESC LIMIT 80`, c.ID, category)
	if err != nil {
		s.fail(w, err)
		return
	}
	orders := []map[string]any{}
	for rows.Next() {
		var orderID, sellerID, sellerName, cat, tpl, origin, status string
		var propsRaw []byte
		var price, fee int64
		var initQty, remQty, taxBps int
		var exp time.Time
		if err = rows.Scan(&orderID, &sellerID, &sellerName, &cat, &tpl, &propsRaw, &origin, &price, &initQty, &remQty, &fee, &taxBps, &status, &exp); err != nil {
			rows.Close()
			s.fail(w, err)
			return
		}
		var props any = map[string]any{}
		_ = json.Unmarshal(propsRaw, &props)
		it := journey.Items[tpl]
		orders = append(orders, map[string]any{
			"order_id":        orderID,
			"seller_id":       sellerID,
			"seller_name":     sellerName,
			"mine":            sellerID == c.ID,
			"category":        cat,
			"template_id":     tpl,
			"name":            it.Name,
			"kind":            it.Kind,
			"attack":          it.Attack,
			"defense":         it.Defense,
			"health":          it.Health,
			"item_properties": props,
			"item_origin":     origin,
			"unit_price":      price,
			"initial_qty":     initQty,
			"remaining_qty":   remQty,
			"listing_fee":     fee,
			"tax_bps":         taxBps,
			"status":          status,
			"expires_at":      exp.UTC().Format(time.RFC3339),
		})
	}
	rows.Close()
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{"orders": orders})
}

func (s *Server) createMarketOrder(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	if s.marketPaused.Load() {
		s.fail(w, &apiError{503, "market_paused", "市场当前暂停新增挂单，已有托管与撤单照常可用"})
		return
	}
	var body struct {
		ItemUID   string `json:"item_uid"`
		Quantity  int    `json:"quantity"`
		UnitPrice int64  `json:"unit_price"`
		Sandbox   bool   `json:"sandbox,omitempty"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if !validID(body.ItemUID) || body.Quantity <= 0 || body.Quantity > 99 || body.UnitPrice <= 0 || body.UnitPrice > 10000000 {
		s.fail(w, bad("invalid_order", "寄售数量或单价格式不正确"))
		return
	}
	if !s.limiter.allow("market:"+who.AccountID, 15, time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "操作过于频繁，请稍后重试"})
		return
	}

	outlierDetail := map[string]any{}
	outlierChar := ""
	outlierOrder := ""

	data, err := s.command(r, who, "market.order.create", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if err = requireOutsideBattle(ctx, tx, c.ID); err != nil {
			return nil, err
		}
		var activeOrders int
		if err = tx.QueryRow(ctx, `SELECT count(*) FROM market_orders WHERE seller_character_id=$1 AND status IN ('open','partial')`, c.ID).Scan(&activeOrders); err != nil {
			return nil, err
		}
		if activeOrders >= rules.MaxActiveOrders {
			return nil, &apiError{409, "order_limit_reached", "已达到最大同时寄售挂单上限"}
		}
		orderID := newID()
		tpl, propsRaw, origin, err := consumePackItemTx(ctx, tx, c.ID, body.ItemUID, "market_list:"+orderID, body.Quantity, journey)
		if err != nil {
			return nil, err
		}
		it := journey.Items[tpl]
		if it.MarketCategory == "commodity" && !rules.allowsStage("M1") {
			return nil, bad("market_stage_locked", "当前市场阶段未开放材料寄售")
		}
		if it.MarketCategory == "equipment" {
			if !rules.allowsStage("M2") {
				return nil, bad("market_stage_locked", "当前市场阶段未开放装备寄售")
			}
			if body.Quantity != 1 {
				return nil, bad("invalid_quantity", "装备实例每次只能上架 1 件")
			}
		}
		minPrice := (it.BasePrice * rules.PriceFloorRatioBps) / 10000
		if minPrice < 1 {
			minPrice = 1
		}
		maxPrice := (it.BasePrice * rules.PriceCeilingRatioBps) / 10000
		if maxPrice < minPrice {
			maxPrice = minPrice
		}
		if body.UnitPrice < minPrice || body.UnitPrice > maxPrice {
			return nil, bad("price_out_of_bounds", "寄售单价超出市场指导价格区间")
		}
		gross := body.UnitPrice * int64(body.Quantity)
		fee := computeListingFee(gross, rules.ListingFeeBps)
		balance, err := adjustGoldTx(ctx, tx, c.ID, "market_fee:"+orderID, -fee, "market_listing_fee")
		if err != nil {
			return nil, err
		}
		expiresAt := time.Now().UTC().Add(time.Duration(rules.OrderTTLHours) * time.Hour)
		if _, err = tx.Exec(ctx, `INSERT INTO market_orders(order_id,seller_character_id,seller_account_id,category,template_id,source_item_uid,item_bound,item_properties,item_origin,unit_price,initial_qty,remaining_qty,listing_fee,tax_bps,status,expires_at)
            VALUES($1,$2,$3,$4,$5,$6::uuid,false,$7::jsonb,$8,$9,$10,$10,$11,$12,'open',$13)`,
			orderID, c.ID, who.AccountID, it.MarketCategory, tpl, body.ItemUID, string(propsRaw), origin, body.UnitPrice, body.Quantity, fee, rules.TaxBps, expiresAt); err != nil {
			return nil, err
		}
		anomalyLimit := (it.BasePrice * rules.AnomalyRatioBps) / 10000
		if anomalyLimit > 0 && body.UnitPrice > anomalyLimit {
			outlierChar = c.ID
			outlierOrder = orderID
			outlierDetail = map[string]any{"template_id": tpl, "unit_price": body.UnitPrice, "base_price": it.BasePrice}
		}
		return map[string]any{
			"order_id":        orderID,
			"category":        it.MarketCategory,
			"template_id":     tpl,
			"quantity":        body.Quantity,
			"unit_price":      body.UnitPrice,
			"listing_fee":     fee,
			"tax_bps":         rules.TaxBps,
			"estimated_net":   gross - computeMarketTax(gross, rules.TaxBps),
			"wallet_balance":  balance,
			"price_warning":   len(outlierDetail) > 0,
		}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	if len(outlierDetail) > 0 {
		s.recordEconomyAlert(r.Context(), "price_outlier", "warn", who.AccountID, outlierChar, outlierOrder, "", outlierDetail)
	}
	respond(w, 200, data)
}

func (s *Server) buyMarketOrder(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	if s.marketPaused.Load() {
		s.fail(w, &apiError{503, "market_paused", "市场当前暂停新增成交，已有托管与撤单照常可用"})
		return
	}
	orderID := r.PathValue("id")
	if !validID(orderID) {
		s.fail(w, bad("invalid_order", "挂单编号格式无效"))
		return
	}
	var body struct {
		Quantity int `json:"quantity"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.Quantity <= 0 || body.Quantity > 99 {
		s.fail(w, bad("invalid_quantity", "购买数量不正确"))
		return
	}

	var selfAttemptChar, washSellerAcc, washBuyerChar string
	var washCount int

	data, err := s.command(r, who, "market.order.buy:"+orderID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if err = requireOutsideBattle(ctx, tx, c.ID); err != nil {
			return nil, err
		}
		var sellerChar, sellerAcc, cat, tpl, origin, status string
		var propsRaw []byte
		var price int64
		var remQty, taxBps int
		var expiresAt time.Time
		err = tx.QueryRow(ctx, `SELECT seller_character_id::text,seller_account_id::text,category,template_id,item_properties,item_origin,unit_price,remaining_qty,tax_bps,status,expires_at
            FROM market_orders WHERE order_id=$1 FOR UPDATE`, orderID).
			Scan(&sellerChar, &sellerAcc, &cat, &tpl, &propsRaw, &origin, &price, &remQty, &taxBps, &status, &expiresAt)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &apiError{404, "order_not_found", "找不到该寄售挂单"}
		}
		if err != nil {
			return nil, err
		}
		if sellerAcc == who.AccountID {
			selfAttemptChar = c.ID
			return nil, &apiError{403, "self_trade_forbidden", "禁止同账号自买自卖刷单"}
		}
		if (status != "open" && status != "partial") || !expiresAt.After(time.Now()) || remQty <= 0 {
			return nil, &apiError{409, "order_unavailable", "该挂单已成交、撤单或过期"}
		}
		if body.Quantity > remQty {
			return nil, &apiError{409, "insufficient_order_quantity", "挂单剩余数量不足"}
		}
		if err = requireNotBlocked(ctx, tx, who.AccountID, sellerAcc); err != nil {
			return nil, err
		}
		gross := price * int64(body.Quantity)
		tax := computeMarketTax(gross, int64(taxBps))
		sellerNet := gross - tax

		fillID := newID()
		buyerItemUID, err := grantCustomPackItemTx(ctx, tx, c.ID, "market_fill:"+fillID, journey.PackSlots, tpl, body.Quantity, false, propsRaw)
		if err != nil {
			return nil, err
		}
		balance, err := adjustGoldTx(ctx, tx, c.ID, "market_buy:"+fillID, -gross, "market_purchase")
		if err != nil {
			return nil, err
		}
		newRem := remQty - body.Quantity
		newStatus := "partial"
		if newRem == 0 {
			newStatus = "filled"
		}
		if _, err = tx.Exec(ctx, `UPDATE market_orders SET remaining_qty=$2,status=$3,updated_at=now() WHERE order_id=$1`, orderID, newRem, newStatus); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO market_fills(fill_id,order_id,buyer_character_id,buyer_account_id,seller_character_id,seller_account_id,template_id,quantity,unit_price,gross_gold,tax_gold,seller_net_gold,buyer_item_uid)
            VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
			fillID, orderID, c.ID, who.AccountID, sellerChar, sellerAcc, tpl, body.Quantity, price, gross, tax, sellerNet, buyerItemUID); err != nil {
			return nil, err
		}
		payoutID, err := insertMarketPayoutTx(ctx, tx, sellerChar, sellerAcc, orderID, fillID, "sale_proceeds", sellerNet, "", 0, nil, origin, rules.PayoutTTLHours)
		if err != nil {
			return nil, err
		}
		_ = tx.QueryRow(ctx, `SELECT count(*) FROM market_fills WHERE buyer_account_id=$1 AND seller_account_id=$2 AND created_at>now()-interval '10 minutes'`,
			who.AccountID, sellerAcc).Scan(&washCount)
		if washCount >= 3 {
			washSellerAcc = sellerAcc
			washBuyerChar = c.ID
		}
		return map[string]any{
			"fill_id":        fillID,
			"order_id":       orderID,
			"category":       cat,
			"template_id":    tpl,
			"quantity":       body.Quantity,
			"gross_gold":     gross,
			"tax_gold":       tax,
			"seller_net":     sellerNet,
			"payout_id":      payoutID,
			"buyer_item_uid": buyerItemUID,
			"remaining_qty":  newRem,
			"order_status":   newStatus,
			"wallet_balance": balance,
		}, nil
	})
	if err != nil {
		if selfAttemptChar != "" {
			s.recordEconomyAlert(r.Context(), "self_trade_attempt", "high", who.AccountID, selfAttemptChar, orderID, "", map[string]any{"order_id": orderID})
		}
		s.fail(w, err)
		return
	}
	if washSellerAcc != "" {
		s.recordEconomyAlert(r.Context(), "wash_volume", "warn", who.AccountID, washBuyerChar, orderID, "", map[string]any{"seller_account_id": washSellerAcc, "recent_fills": washCount})
	}
	respond(w, 200, data)
}

func (s *Server) cancelMarketOrder(w http.ResponseWriter, r *http.Request, who identity) {
	rules, _, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	orderID := r.PathValue("id")
	if !validID(orderID) {
		s.fail(w, bad("invalid_order", "挂单编号格式无效"))
		return
	}
	data, err := s.command(r, who, "market.order.cancel:"+orderID, struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var sellerChar, tpl, origin, status string
		var propsRaw []byte
		var remQty int
		err = tx.QueryRow(ctx, `SELECT seller_character_id::text,template_id,item_properties,item_origin,remaining_qty,status
            FROM market_orders WHERE order_id=$1 FOR UPDATE`, orderID).
			Scan(&sellerChar, &tpl, &propsRaw, &origin, &remQty, &status)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &apiError{404, "order_not_found", "找不到该寄售挂单"}
		}
		if err != nil {
			return nil, err
		}
		if sellerChar != c.ID {
			return nil, &apiError{403, "forbidden", "只能撤回自己角色的挂单"}
		}
		if (status != "open" && status != "partial" && status != "paused") || remQty <= 0 {
			return nil, &apiError{409, "order_already_closed", "挂单已全部成交或早已撤销"}
		}
		if _, err = tx.Exec(ctx, `UPDATE market_orders SET remaining_qty=0,status='cancelled',updated_at=now() WHERE order_id=$1`, orderID); err != nil {
			return nil, err
		}
		payoutID, err := insertMarketPayoutTx(ctx, tx, c.ID, who.AccountID, orderID, "", "order_return", 0, tpl, remQty, propsRaw, origin, rules.PayoutTTLHours)
		if err != nil {
			return nil, err
		}
		return map[string]any{
			"order_id":    orderID,
			"status":      "cancelled",
			"payout_id":   payoutID,
			"template_id": tpl,
			"returned_qty": remQty,
		}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) listMarketPayouts(w http.ResponseWriter, r *http.Request, who identity) {
	_, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	tx, err := s.db.BeginTx(r.Context(), pgx.TxOptions{AccessMode: pgx.ReadOnly})
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	c, err := s.activeCharacter(r.Context(), tx, who)
	if err != nil {
		s.fail(w, err)
		return
	}
	rows, err := tx.Query(r.Context(), `SELECT payout_id::text,kind,gold_amount,template_id,quantity,item_properties,item_origin,status,expires_at
        FROM market_payouts WHERE character_id=$1 ORDER BY created_at DESC LIMIT 60`, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	payouts := []map[string]any{}
	for rows.Next() {
		var payoutID, kind, tpl, origin, status string
		var gold int64
		var qty int
		var propsRaw []byte
		var exp time.Time
		if err = rows.Scan(&payoutID, &kind, &gold, &tpl, &qty, &propsRaw, &origin, &status, &exp); err != nil {
			rows.Close()
			s.fail(w, err)
			return
		}
		var props any = map[string]any{}
		_ = json.Unmarshal(propsRaw, &props)
		payouts = append(payouts, map[string]any{
			"payout_id":       payoutID,
			"kind":            kind,
			"gold_amount":     gold,
			"template_id":     tpl,
			"name":            journey.Items[tpl].Name,
			"quantity":        qty,
			"item_properties": props,
			"item_origin":     origin,
			"status":          status,
			"expires_at":      exp.UTC().Format(time.RFC3339),
		})
	}
	rows.Close()
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{"payouts": payouts})
}

func (s *Server) claimMarketPayout(w http.ResponseWriter, r *http.Request, who identity) {
	_, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	payoutID := r.PathValue("id")
	if !validID(payoutID) {
		s.fail(w, bad("invalid_payout", "领取编号格式无效"))
		return
	}
	data, err := s.command(r, who, "market.payout.claim:"+payoutID, struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var charID, kind, tpl, origin, status string
		var gold int64
		var qty int
		var propsRaw []byte
		var expiresAt time.Time
		err = tx.QueryRow(ctx, `SELECT character_id::text,kind,gold_amount,template_id,quantity,item_properties,item_origin,status,expires_at
            FROM market_payouts WHERE payout_id=$1 FOR UPDATE`, payoutID).
			Scan(&charID, &kind, &gold, &tpl, &qty, &propsRaw, &origin, &status, &expiresAt)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &apiError{404, "payout_not_found", "找不到该交易邮件附件"}
		}
		if err != nil {
			return nil, err
		}
		if charID != c.ID {
			return nil, &apiError{403, "forbidden", "不能领取其他角色的交易附件"}
		}
		if status != "pending" || !expiresAt.After(time.Now()) {
			return nil, &apiError{409, "payout_already_claimed", "该附件已领取或已过期"}
		}
		var itemUID string
		if qty > 0 && tpl != "" {
			itemUID, err = grantCustomPackItemTx(ctx, tx, c.ID, "payout:"+payoutID, journey.PackSlots, tpl, qty, false, propsRaw)
			if err != nil {
				return nil, err
			}
		}
		balance, err := adjustGoldTx(ctx, tx, c.ID, "payout_gold:"+payoutID, gold, "market_sale_proceeds")
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE market_payouts SET status='claimed',claimed_at=now() WHERE payout_id=$1`, payoutID); err != nil {
			return nil, err
		}
		return map[string]any{
			"payout_id":      payoutID,
			"kind":           kind,
			"gold_claimed":   gold,
			"template_id":    tpl,
			"quantity":       qty,
			"item_uid":       itemUID,
			"wallet_balance": balance,
		}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) npcMarketTrade(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		Action   string `json:"action"`
		Template string `json:"template_id"`
		ItemUID  string `json:"item_uid,omitempty"`
		Quantity int    `json:"quantity"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if (body.Action != "buy" && body.Action != "sell") || body.Quantity <= 0 || body.Quantity > 30 {
		s.fail(w, bad("invalid_npc_trade", "NPC 集市买卖参数不正确"))
		return
	}
	allowedGood := false
	for _, tpl := range rules.NpcFloorGoods {
		if tpl == body.Template {
			allowedGood = true
			break
		}
	}
	if !allowedGood {
		s.fail(w, bad("invalid_npc_trade", "该货物不在当地行商收购/出售名录内"))
		return
	}
	data, err := s.command(r, who, "market.npc.trade", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if err = requireOutsideBattle(ctx, tx, c.ID); err != nil {
			return nil, err
		}
		var dailyCount int
		_ = tx.QueryRow(ctx, `SELECT count(*) FROM wallet_ledger WHERE character_id=$1 AND reason IN ('npc_shop_buy','npc_shop_sell') AND created_at>date_trunc('day', now())`, c.ID).Scan(&dailyCount)
		if dailyCount >= rules.DailyNpcTradeCap {
			return nil, &apiError{409, "npc_daily_cap_reached", "今日 NPC 行商交易次数已达上限"}
		}
		mapID := c.MapID
		if mapID == "" {
			mapID = s.cfg.Rules.Town.MapID
		}
		it := journey.Items[body.Template]
		buyPrice, sellPrice, reg := rules.npcPricesFor(mapID, it)
		tradeTx := "npc:" + newID()
		if body.Action == "buy" {
			if s.marketPaused.Load() {
				return nil, &apiError{503, "market_paused", "市场维护期间暂不出售行商货物"}
			}
			total := buyPrice * int64(body.Quantity)
			itemUID, err := grantCustomPackItemTx(ctx, tx, c.ID, tradeTx, journey.PackSlots, body.Template, body.Quantity, false, []byte(`{"origin":"npc_floor"}`))
			if err != nil {
				return nil, err
			}
			balance, err := adjustGoldTx(ctx, tx, c.ID, tradeTx, -total, "npc_shop_buy")
			if err != nil {
				return nil, err
			}
			return map[string]any{
				"action":         "buy",
				"region_label":   reg.Label,
				"template_id":    body.Template,
				"quantity":       body.Quantity,
				"unit_price":     buyPrice,
				"gold_delta":     -total,
				"item_uid":       itemUID,
				"wallet_balance": balance,
			}, nil
		}
		if !validID(body.ItemUID) {
			return nil, bad("invalid_item", "出售给行商需指定有效的行囊物品")
		}
		tpl, _, _, err := consumePackItemTx(ctx, tx, c.ID, body.ItemUID, tradeTx, body.Quantity, journey)
		if err != nil {
			return nil, err
		}
		if tpl != body.Template {
			return nil, bad("invalid_item", "选中行囊物品与货物模板不一致")
		}
		total := sellPrice * int64(body.Quantity)
		balance, err := adjustGoldTx(ctx, tx, c.ID, tradeTx, total, "npc_shop_sell")
		if err != nil {
			return nil, err
		}
		return map[string]any{
			"action":         "sell",
			"region_label":   reg.Label,
			"template_id":    body.Template,
			"quantity":       body.Quantity,
			"unit_price":     sellPrice,
			"gold_delta":     total,
			"wallet_balance": balance,
		}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
