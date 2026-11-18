package online

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
)

func requireFriendshipTx(ctx context.Context, tx pgx.Tx, charA, charB string) error {
	left, right := orderedFriendPair(charA, charB)
	var exists bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM friendships WHERE character_a=$1 AND character_b=$2)`, left, right).Scan(&exists); err != nil {
		return err
	}
	if !exists {
		return &apiError{403, "friendship_required", "面对面交换只对好友开放"}
	}
	return nil
}

func (s *Server) buildTradeViewTx(ctx context.Context, tx pgx.Tx, journey *JourneyRules, tradeID string) (map[string]any, error) {
	var initChar, partnerChar, initName, partnerName, status string
	var initGold, partnerGold, rev int64
	var initConf, partnerConf bool
	var expiresAt time.Time
	err := tx.QueryRow(ctx, `SELECT t.initiator_character_id::text,t.partner_character_id::text,c1.nickname,c2.nickname,
        t.initiator_gold,t.partner_gold,t.initiator_confirmed,t.partner_confirmed,t.revision,t.status,t.expires_at
        FROM trade_sessions t JOIN characters c1 ON c1.id=t.initiator_character_id JOIN characters c2 ON c2.id=t.partner_character_id
        WHERE t.trade_id=$1`, tradeID).
		Scan(&initChar, &partnerChar, &initName, &partnerName, &initGold, &partnerGold, &initConf, &partnerConf, &rev, &status, &expiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, &apiError{404, "trade_not_found", "找不到该面对面交易"}
	}
	if err != nil {
		return nil, err
	}
	rows, err := tx.Query(ctx, `SELECT offer_id::text,character_id::text,template_id,quantity,item_properties,item_origin
        FROM trade_offers WHERE trade_id=$1 ORDER BY created_at`, tradeID)
	if err != nil {
		return nil, err
	}
	initItems := []map[string]any{}
	partnerItems := []map[string]any{}
	for rows.Next() {
		var offerID, ownerID, tpl, origin string
		var qty int
		var propsRaw []byte
		if err = rows.Scan(&offerID, &ownerID, &tpl, &qty, &propsRaw, &origin); err != nil {
			rows.Close()
			return nil, err
		}
		var props any = map[string]any{}
		_ = json.Unmarshal(propsRaw, &props)
		entry := map[string]any{
			"offer_id":        offerID,
			"template_id":     tpl,
			"name":            journey.Items[tpl].Name,
			"quantity":        qty,
			"item_properties": props,
			"item_origin":     origin,
		}
		if ownerID == initChar {
			initItems = append(initItems, entry)
		} else {
			partnerItems = append(partnerItems, entry)
		}
	}
	rows.Close()
	return map[string]any{
		"trade_id":               tradeID,
		"initiator_id":           initChar,
		"initiator_name":         initName,
		"partner_id":             partnerChar,
		"partner_name":           partnerName,
		"initiator_gold":         initGold,
		"partner_gold":           partnerGold,
		"initiator_confirmed":    initConf,
		"partner_confirmed":      partnerConf,
		"initiator_items":        initItems,
		"partner_items":          partnerItems,
		"revision":               rev,
		"status":                 status,
		"expires_at":             expiresAt.UTC().Format(time.RFC3339),
	}, nil
}

func (s *Server) listTradeSessions(w http.ResponseWriter, r *http.Request, who identity) {
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
	rows, err := tx.Query(r.Context(), `SELECT trade_id::text FROM trade_sessions
        WHERE (initiator_character_id=$1 OR partner_character_id=$1) ORDER BY created_at DESC LIMIT 20`, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	ids := []string{}
	for rows.Next() {
		var tid string
		if err = rows.Scan(&tid); err != nil {
			rows.Close()
			s.fail(w, err)
			return
		}
		ids = append(ids, tid)
	}
	rows.Close()
	sessions := []map[string]any{}
	for _, tid := range ids {
		view, err := s.buildTradeViewTx(r.Context(), tx, journey, tid)
		if err != nil {
			s.fail(w, err)
			return
		}
		sessions = append(sessions, view)
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{"sessions": sessions})
}

func (s *Server) startTradeSession(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	if !rules.allowsStage("M3") {
		s.fail(w, bad("market_stage_locked", "当前阶段尚未开放面对面交换"))
		return
	}
	if s.marketPaused.Load() {
		s.fail(w, &apiError{503, "market_paused", "市场维护期间暂不能发起新交易"})
		return
	}
	var body struct {
		TargetCharacterID string `json:"target_character_id"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if !validID(body.TargetCharacterID) {
		s.fail(w, bad("invalid_character", "交易对象角色无效"))
		return
	}
	var view map[string]any
	err = pgx.BeginFunc(r.Context(), s.db, func(tx pgx.Tx) error {
		c, err := s.activeCharacter(r.Context(), tx, who)
		if err != nil {
			return err
		}
		if err = requireOutsideBattle(r.Context(), tx, c.ID); err != nil {
			return err
		}
		var partnerAcc, partnerMap string
		err = tx.QueryRow(r.Context(), `SELECT account_id::text,map_id FROM characters WHERE id=$1 AND deleted_at IS NULL`, body.TargetCharacterID).Scan(&partnerAcc, &partnerMap)
		if errors.Is(err, pgx.ErrNoRows) {
			return &apiError{404, "not_found", "找不到交易对象角色"}
		}
		if err != nil {
			return err
		}
		if partnerAcc == who.AccountID {
			return &apiError{403, "self_trade_forbidden", "禁止同账号之间发起交易"}
		}
		if partnerMap != c.MapID {
			return &apiError{409, "not_nearby", "请先与好友处于同一张地图后再发起面对面交换"}
		}
		if err = requireNotBlocked(r.Context(), tx, who.AccountID, partnerAcc); err != nil {
			return err
		}
		if err = requireFriendshipTx(r.Context(), tx, c.ID, body.TargetCharacterID); err != nil {
			return err
		}
		var activeExists bool
		if err = tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM trade_sessions WHERE status='active'
            AND (initiator_character_id IN ($1,$2) OR partner_character_id IN ($1,$2)))`, c.ID, body.TargetCharacterID).Scan(&activeExists); err != nil {
			return err
		}
		if activeExists {
			return &apiError{409, "trade_already_active", "当前已有正在进行的面对面交易"}
		}
		tradeID := newID()
		expiresAt := time.Now().UTC().Add(time.Duration(rules.TradeTTLSeconds) * time.Second)
		if _, err = tx.Exec(r.Context(), `INSERT INTO trade_sessions(trade_id,initiator_character_id,initiator_account_id,partner_character_id,partner_account_id,status,expires_at)
            VALUES($1,$2,$3,$4,$5,'active',$6)`, tradeID, c.ID, who.AccountID, body.TargetCharacterID, partnerAcc, expiresAt); err != nil {
			return err
		}
		view, err = s.buildTradeViewTx(r.Context(), tx, journey, tradeID)
		return err
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, view)
}

func (s *Server) updateTradeOffer(w http.ResponseWriter, r *http.Request, who identity) {
	_, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	if s.marketPaused.Load() {
		s.fail(w, &apiError{503, "market_paused", "市场维护期间暂不能修改交易报价"})
		return
	}
	tradeID := r.PathValue("id")
	if !validID(tradeID) {
		s.fail(w, bad("invalid_trade", "交易编号格式无效"))
		return
	}
	var body struct {
		Gold          *int64 `json:"gold,omitempty"`
		AddItemUID    string `json:"add_item_uid,omitempty"`
		AddQuantity   int    `json:"add_quantity,omitempty"`
		RemoveOfferID string `json:"remove_offer_id,omitempty"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	var view map[string]any
	err = pgx.BeginFunc(r.Context(), s.db, func(tx pgx.Tx) error {
		c, err := s.activeCharacter(r.Context(), tx, who)
		if err != nil {
			return err
		}
		if err = requireOutsideBattle(r.Context(), tx, c.ID); err != nil {
			return err
		}
		var initChar, partnerChar, status string
		var initGold, partnerGold, rev int64
		var expiresAt time.Time
		err = tx.QueryRow(r.Context(), `SELECT initiator_character_id::text,partner_character_id::text,initiator_gold,partner_gold,revision,status,expires_at
            FROM trade_sessions WHERE trade_id=$1 FOR UPDATE`, tradeID).
			Scan(&initChar, &partnerChar, &initGold, &partnerGold, &rev, &status, &expiresAt)
		if errors.Is(err, pgx.ErrNoRows) {
			return &apiError{404, "trade_not_found", "找不到该面对面交易"}
		}
		if err != nil {
			return err
		}
		if c.ID != initChar && c.ID != partnerChar {
			return &apiError{403, "forbidden", "不是该场交易的参与方"}
		}
		if status != "active" || !expiresAt.After(time.Now()) {
			return &apiError{409, "trade_closed", "该场交易已结束或过期"}
		}
		nextRev := rev + 1
		if body.Gold != nil {
			if *body.Gold < 0 || *body.Gold > 10000000 {
				return bad("invalid_gold", "交易金币数额无效")
			}
			oldGold := partnerGold
			if c.ID == initChar {
				oldGold = initGold
				initGold = *body.Gold
			} else {
				partnerGold = *body.Gold
			}
			delta := *body.Gold - oldGold
			if delta != 0 {
				reason := "trade_escrow"
				if delta > 0 {
					delta = -delta // deduct from wallet into escrow
				} else {
					delta = -delta // refund from escrow back to wallet
					reason = "trade_escrow_return"
				}
				if _, err = adjustGoldTx(r.Context(), tx, c.ID, "trade_gold:"+tradeID+":"+newID(), delta, reason); err != nil {
					return err
				}
			}
		}
		if body.AddItemUID != "" {
			if !validID(body.AddItemUID) || body.AddQuantity <= 0 || body.AddQuantity > 99 {
				return bad("invalid_item", "放入交易栏的物品或数量无效")
			}
			offerID := newID()
			tpl, propsRaw, origin, err := consumePackItemTx(r.Context(), tx, c.ID, body.AddItemUID, "trade_offer:"+offerID, body.AddQuantity, journey)
			if err != nil {
				return err
			}
			if journey.Items[tpl].MarketCategory == "equipment" && body.AddQuantity != 1 {
				return bad("invalid_quantity", "装备实例每次只能放入 1 件")
			}
			if _, err = tx.Exec(r.Context(), `INSERT INTO trade_offers(offer_id,trade_id,character_id,source_item_uid,template_id,quantity,item_properties,item_origin)
                VALUES($1,$2,$3,$4,$5,$6,$7::jsonb,$8)`,
				offerID, tradeID, c.ID, body.AddItemUID, tpl, body.AddQuantity, string(propsRaw), origin); err != nil {
				return err
			}
		}
		if body.RemoveOfferID != "" {
			if !validID(body.RemoveOfferID) {
				return bad("invalid_offer", "撤销报价编号无效")
			}
			var tpl, origin string
			var qty int
			var propsRaw []byte
			err = tx.QueryRow(r.Context(), `DELETE FROM trade_offers WHERE offer_id=$1 AND trade_id=$2 AND character_id=$3
                RETURNING template_id,quantity,item_properties,item_origin`, body.RemoveOfferID, tradeID, c.ID).
				Scan(&tpl, &qty, &propsRaw, &origin)
			if errors.Is(err, pgx.ErrNoRows) {
				return &apiError{404, "offer_not_found", "找不到该交易栏物品"}
			}
			if err != nil {
				return err
			}
			if _, err = grantCustomPackItemTx(r.Context(), tx, c.ID, "trade_remove:"+body.RemoveOfferID, journey.PackSlots, tpl, qty, false, propsRaw); err != nil {
				return err
			}
		}
		// Editing ANY offer clears BOTH confirmations!
		if _, err = tx.Exec(r.Context(), `UPDATE trade_sessions SET initiator_gold=$2,partner_gold=$3,initiator_confirmed=false,partner_confirmed=false,revision=$4,updated_at=now() WHERE trade_id=$1`,
			tradeID, initGold, partnerGold, nextRev); err != nil {
			return err
		}
		view, err = s.buildTradeViewTx(r.Context(), tx, journey, tradeID)
		return err
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, view)
}

func (s *Server) confirmTradeSession(w http.ResponseWriter, r *http.Request, who identity) {
	_, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	tradeID := r.PathValue("id")
	if !validID(tradeID) {
		s.fail(w, bad("invalid_trade", "交易编号格式无效"))
		return
	}
	var body struct {
		Revision int64 `json:"revision"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "trade.confirm:"+tradeID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var initChar, partnerChar, status string
		var initGold, partnerGold, rev int64
		var initConf, partnerConf bool
		var expiresAt time.Time
		err = tx.QueryRow(ctx, `SELECT initiator_character_id::text,partner_character_id::text,initiator_gold,partner_gold,initiator_confirmed,partner_confirmed,revision,status,expires_at
            FROM trade_sessions WHERE trade_id=$1 FOR UPDATE`, tradeID).
			Scan(&initChar, &partnerChar, &initGold, &partnerGold, &initConf, &partnerConf, &rev, &status, &expiresAt)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &apiError{404, "trade_not_found", "找不到该面对面交易"}
		}
		if err != nil {
			return nil, err
		}
		if c.ID != initChar && c.ID != partnerChar {
			return nil, &apiError{403, "forbidden", "不是该场交易的参与方"}
		}
		if status != "active" || !expiresAt.After(time.Now()) {
			return nil, &apiError{409, "trade_closed", "该场交易已结束或过期"}
		}
		if body.Revision != rev {
			return nil, &apiError{409, "trade_changed_reconfirm_required", "交易报价已变动，双方确认已重置，请重新核对确认"}
		}
		if c.ID == initChar {
			initConf = true
		} else {
			partnerConf = true
		}
		if initConf && partnerConf {
			type offerRow struct {
				offerID, owner, tpl, origin string
				qty                         int
				props                       []byte
			}
			rows, err := tx.Query(ctx, `SELECT offer_id::text,character_id::text,template_id,quantity,item_properties,item_origin FROM trade_offers WHERE trade_id=$1`, tradeID)
			if err != nil {
				return nil, err
			}
			var offers []offerRow
			for rows.Next() {
				var o offerRow
				if err = rows.Scan(&o.offerID, &o.owner, &o.tpl, &o.qty, &o.props, &o.origin); err != nil {
					rows.Close()
					return nil, err
				}
				offers = append(offers, o)
			}
			rows.Close()
			if initGold == 0 && partnerGold == 0 && len(offers) == 0 {
				return nil, bad("empty_trade", "双方均未放入物品或金币，无法成交")
			}
			for _, o := range offers {
				recipient := initChar
				if o.owner == initChar {
					recipient = partnerChar
				}
				if _, err = grantCustomPackItemTx(ctx, tx, recipient, "trade_settle:"+tradeID+":"+o.offerID, journey.PackSlots, o.tpl, o.qty, false, o.props); err != nil {
					return nil, err
				}
			}
			if partnerGold > 0 {
				if _, err = adjustGoldTx(ctx, tx, initChar, "trade_settle_gold:"+tradeID, partnerGold, "trade_settle"); err != nil {
					return nil, err
				}
			}
			if initGold > 0 {
				if _, err = adjustGoldTx(ctx, tx, partnerChar, "trade_settle_gold:"+tradeID, initGold, "trade_settle"); err != nil {
					return nil, err
				}
			}
			if _, err = tx.Exec(ctx, `UPDATE trade_sessions SET initiator_confirmed=true,partner_confirmed=true,status='completed',completed_at=now(),updated_at=now() WHERE trade_id=$1`, tradeID); err != nil {
				return nil, err
			}
		} else {
			if _, err = tx.Exec(ctx, `UPDATE trade_sessions SET initiator_confirmed=$2,partner_confirmed=$3,updated_at=now() WHERE trade_id=$1`,
				tradeID, initConf, partnerConf); err != nil {
				return nil, err
			}
		}
		return s.buildTradeViewTx(ctx, tx, journey, tradeID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) cancelTradeSession(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireMarket(true)
	if err != nil {
		s.fail(w, err)
		return
	}
	tradeID := r.PathValue("id")
	if !validID(tradeID) {
		s.fail(w, bad("invalid_trade", "交易编号格式无效"))
		return
	}
	data, err := s.command(r, who, "trade.cancel:"+tradeID, struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var initChar, initAcc, partnerChar, partnerAcc, status string
		var initGold, partnerGold int64
		err = tx.QueryRow(ctx, `SELECT initiator_character_id::text,initiator_account_id::text,partner_character_id::text,partner_account_id::text,initiator_gold,partner_gold,status
            FROM trade_sessions WHERE trade_id=$1 FOR UPDATE`, tradeID).
			Scan(&initChar, &initAcc, &partnerChar, &partnerAcc, &initGold, &partnerGold, &status)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &apiError{404, "trade_not_found", "找不到该面对面交易"}
		}
		if err != nil {
			return nil, err
		}
		if c.ID != initChar && c.ID != partnerChar {
			return nil, &apiError{403, "forbidden", "不是该场交易的参与方"}
		}
		if status != "active" {
			return nil, &apiError{409, "trade_already_closed", "该场交易早已结束"}
		}
		if initGold > 0 {
			if _, err = adjustGoldTx(ctx, tx, initChar, "trade_refund:"+tradeID, initGold, "trade_cancel_refund"); err != nil {
				return nil, err
			}
		}
		if partnerGold > 0 {
			if _, err = adjustGoldTx(ctx, tx, partnerChar, "trade_refund:"+tradeID, partnerGold, "trade_cancel_refund"); err != nil {
				return nil, err
			}
		}
		rows, err := tx.Query(ctx, `SELECT offer_id::text,character_id::text,template_id,quantity,item_properties,item_origin FROM trade_offers WHERE trade_id=$1`, tradeID)
		if err != nil {
			return nil, err
		}
		type offerReturn struct {
			offerID, owner, tpl, origin string
			qty                         int
			props                       []byte
		}
		var returns []offerReturn
		for rows.Next() {
			var o offerReturn
			if err = rows.Scan(&o.offerID, &o.owner, &o.tpl, &o.qty, &o.props, &o.origin); err != nil {
				rows.Close()
				return nil, err
			}
			returns = append(returns, o)
		}
		rows.Close()
		for _, o := range returns {
			accID := initAcc
			if o.owner == partnerChar {
				accID = partnerAcc
			}
			if _, gerr := grantCustomPackItemTx(ctx, tx, o.owner, "trade_cancel_item:"+tradeID+":"+o.offerID, journey.PackSlots, o.tpl, o.qty, false, o.props); gerr != nil {
				if _, perr := insertMarketPayoutTx(ctx, tx, o.owner, accID, "", "", "trade_return", 0, o.tpl, o.qty, o.props, o.origin, rules.PayoutTTLHours); perr != nil {
					return nil, perr
				}
			}
		}
		if _, err = tx.Exec(ctx, `DELETE FROM trade_offers WHERE trade_id=$1`, tradeID); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE trade_sessions SET status='cancelled',initiator_confirmed=false,partner_confirmed=false,updated_at=now() WHERE trade_id=$1`, tradeID); err != nil {
			return nil, err
		}
		return s.buildTradeViewTx(ctx, tx, journey, tradeID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
