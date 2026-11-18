package online

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
)

type WorldBossRules struct {
	EventKeyPrefix  string                          `json:"event_key_prefix"`
	MapID           string                          `json:"map_id"`
	BossID          string                          `json:"boss_id"`
	Name            string                          `json:"name"`
	Position        [2]float64                      `json:"position"`
	Radius          float64                         `json:"radius"`
	MaxHP           int64                           `json:"max_hp"`
	DurationSeconds int                             `json:"duration_seconds"`
	MinLevel        int                             `json:"min_level"`
	Objectives      []string                        `json:"objectives"`
	Rewards         map[string]CoopRewardBundle     `json:"rewards"`
}

var (
	errWorldBossUnavailable = &apiError{409, "world_boss_unavailable", "当前服务器尚未开放地区公共首领"}
	errWorldBossClosed      = &apiError{409, "world_boss_closed", "本届公共首领事件已关闭"}
)

func (w WorldBossRules) validate(items map[string]JourneyItem, maps map[string]MapRule) error {
	invalid := errors.New("invalid world boss rules")
	if w.EventKeyPrefix == "" || w.MapID == "" || w.BossID == "" || w.Name == "" ||
		w.Radius <= 0 || w.MaxHP <= 0 || w.DurationSeconds < 30 || w.MinLevel < 1 || len(w.Objectives) == 0 {
		return invalid
	}
	if len(maps) > 0 {
		if _, ok := maps[w.MapID]; !ok {
			return invalid
		}
	}
	for _, tier := range []string{"assist", "stage", "defeat"} {
		b, ok := w.Rewards[tier]
		if !ok || b.Gold < 0 || b.Experience < 0 || b.Quantity <= 0 {
			return invalid
		}
		if _, known := items[b.ItemID]; !known {
			return invalid
		}
	}
	return nil
}

func (s *Server) ensureActiveWorldBossTx(ctx context.Context, tx pgx.Tx, rules *WorldBossRules, roomID string) (string, error) {
	var id string
	err := tx.QueryRow(ctx, `SELECT id::text FROM world_boss_events WHERE map_id=$1 AND state IN ('scheduled','active','defeated','closed') ORDER BY starts_at DESC LIMIT 1`, rules.MapID).Scan(&id)
	if err == nil && id != "" {
		return id, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return "", err
	}
	id = newID()
	key := rules.EventKeyPrefix + ":" + time.Now().UTC().Format("2006010215")
	starts := time.Now().UTC()
	ends := starts.Add(time.Duration(rules.DurationSeconds) * time.Second)
	if _, err = tx.Exec(ctx, `INSERT INTO world_boss_events(id,event_key,boss_id,map_id,room_id,state,max_hp,current_hp,stage,starts_at,ends_at)
		VALUES($1,$2,$3,$4,nullif($5,'')::uuid,'active',$6,$6,0,$7,$8)`,
		id, key, rules.BossID, rules.MapID, roomID, rules.MaxHP, starts, ends); err != nil {
		return "", err
	}
	return id, nil
}

func computeWorldBossTier(steps int, damage, support int64, defeated bool) string {
	switch {
	case defeated && (damage > 0 || steps >= 1):
		return "defeat"
	case steps >= 2 || damage >= 120:
		return "stage"
	case steps >= 1 || damage > 0 || support > 0:
		return "assist"
	default:
		return "none"
	}
}

func (s *Server) worldBossViewTx(ctx context.Context, tx pgx.Tx, rules *WorldBossRules, eventID, charID, accountID string) (map[string]any, error) {
	var eventKey, bossID, mapID, state, closedReason string
	var maxHP, currentHP int64
	var stage int
	var startsAt, endsAt time.Time
	err := tx.QueryRow(ctx, `SELECT event_key,boss_id,map_id,state,max_hp,current_hp,stage,starts_at,ends_at,coalesce(closed_reason,'') FROM world_boss_events WHERE id=$1`, eventID).
		Scan(&eventKey, &bossID, &mapID, &state, &maxHP, &currentHP, &stage, &startsAt, &endsAt, &closedReason)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, errNotFound
	}
	if err != nil {
		return nil, err
	}
	var objSteps int
	var damage, support int64
	var tier string
	var rewardedAt *time.Time
	err = tx.QueryRow(ctx, `SELECT objective_steps,damage_dealt,support_score,reward_tier,rewarded_at FROM world_boss_participations WHERE event_id=$1 AND character_id=$2`, eventID, charID).
		Scan(&objSteps, &damage, &support, &tier, &rewardedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		objSteps, damage, support, tier = 0, 0, 0, "none"
	} else if err != nil {
		return nil, err
	}
	var accountRewarded bool
	_ = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM world_boss_participations WHERE event_id=$1 AND account_id=$2 AND rewarded_at IS NOT NULL)`, eventID, accountID).Scan(&accountRewarded)
	return map[string]any{
		"id":            eventID,
		"event_key":     eventKey,
		"boss_id":       bossID,
		"name":          rules.Name,
		"map_id":        mapID,
		"position":      rules.Position,
		"radius":        rules.Radius,
		"state":         state,
		"max_hp":        maxHP,
		"current_hp":    currentHP,
		"stage":         stage,
		"starts_at":     startsAt,
		"ends_at":       endsAt,
		"closed_reason": closedReason,
		"objectives":    rules.Objectives,
		"rewards":       rules.Rewards,
		"participation": map[string]any{
			"objective_steps":  objSteps,
			"damage_dealt":     damage,
			"support_score":    support,
			"reward_tier":      tier,
			"rewarded_at":      rewardedAt,
			"account_rewarded": accountRewarded,
		},
	}, nil
}

func (s *Server) currentWorldBoss(w http.ResponseWriter, r *http.Request, who identity) {
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	if s.cfg.Rules.WorldBoss == nil || s.cfg.Authority == nil {
		s.fail(w, errWorldBossUnavailable)
		return
	}
	var roomID string
	_ = tx.QueryRow(r.Context(), `SELECT room_id::text FROM room_leases WHERE character_id=$1 AND expires_at>now()`, c.ID).Scan(&roomID)
	eventID, err := s.ensureActiveWorldBossTx(r.Context(), tx, s.cfg.Rules.WorldBoss, roomID)
	if err != nil {
		s.fail(w, err)
		return
	}
	view, err := s.worldBossViewTx(r.Context(), tx, s.cfg.Rules.WorldBoss, eventID, c.ID, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, view)
}

func (s *Server) worldBossObjective(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	eventID := r.PathValue("id")
	if !validID(eventID) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		ObjectiveID string `json:"objective_id"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "worldboss.objective:"+eventID+":"+body.ObjectiveID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules := s.cfg.Rules.WorldBoss
		if rules == nil {
			return nil, errWorldBossUnavailable
		}
		validObj := false
		for _, o := range rules.Objectives {
			if o == body.ObjectiveID {
				validObj = true
				break
			}
		}
		if !validObj {
			return nil, bad("invalid_objective", "未知的公共首领阶段目标")
		}
		var state string
		if err = tx.QueryRow(ctx, `SELECT state FROM world_boss_events WHERE id=$1 FOR UPDATE`, eventID).Scan(&state); err != nil {
			return nil, errNotFound
		}
		if state == "closed" {
			return nil, errWorldBossClosed
		}
		if err = s.upsertWorldBossContributionTx(ctx, tx, eventID, c.ID, who.AccountID, 1, 0, 10, state == "defeated"); err != nil {
			return nil, err
		}
		_, _ = tx.Exec(ctx, `UPDATE world_boss_events SET stage=LEAST(stage+1,2),version=version+1 WHERE id=$1`, eventID)
		return s.worldBossViewTx(ctx, tx, rules, eventID, c.ID, who.AccountID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) upsertWorldBossContributionTx(ctx context.Context, tx pgx.Tx, eventID, charID, accountID string, addSteps int, addDamage, addSupport int64, defeated bool) error {
	var otherChar string
	err := tx.QueryRow(ctx, `SELECT character_id::text FROM world_boss_participations WHERE event_id=$1 AND account_id=$2`, eventID, accountID).Scan(&otherChar)
	if err == nil && otherChar != charID {
		return &apiError{409, "account_already_participated", "同一账号每次公共首领窗口仅限一名角色计奖"}
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	var curSteps int
	var curDmg, curSup int64
	err = tx.QueryRow(ctx, `SELECT objective_steps,damage_dealt,support_score FROM world_boss_participations WHERE event_id=$1 AND character_id=$2 FOR UPDATE`, eventID, charID).
		Scan(&curSteps, &curDmg, &curSup)
	if errors.Is(err, pgx.ErrNoRows) {
		tier := computeWorldBossTier(addSteps, addDamage, addSupport, defeated)
		_, err = tx.Exec(ctx, `INSERT INTO world_boss_participations(event_id,character_id,account_id,objective_steps,damage_dealt,support_score,reward_tier)
			VALUES($1,$2,$3,$4,$5,$6,$7)`, eventID, charID, accountID, addSteps, addDamage, addSupport, tier)
		return err
	}
	if err != nil {
		return err
	}
	newSteps := curSteps + addSteps
	newDmg := curDmg + addDamage
	newSup := curSup + addSupport
	tier := computeWorldBossTier(newSteps, newDmg, newSup, defeated)
	_, err = tx.Exec(ctx, `UPDATE world_boss_participations SET objective_steps=$3,damage_dealt=$4,support_score=$5,reward_tier=$6,updated_at=now() WHERE event_id=$1 AND character_id=$2`,
		eventID, charID, newSteps, newDmg, newSup, tier)
	return err
}

func (s *Server) worldBossEngage(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	eventID := r.PathValue("id")
	if !validID(eventID) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		Action string `json:"action"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.Action == "" {
		body.Action = "attack"
	}
	data, err := s.command(r, who, "worldboss.engage:"+eventID+":"+r.Header.Get("Idempotency-Key"), body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules := s.cfg.Rules.WorldBoss
		journey := s.cfg.Rules.Journey
		if rules == nil || journey == nil || s.cfg.Authority == nil {
			return nil, errWorldBossUnavailable
		}
		if c.Level < rules.MinLevel {
			return nil, &apiError{409, "level_too_low", "角色等级未达到公共首领要求"}
		}
		var state string
		var currentHP int64
		if err = tx.QueryRow(ctx, `SELECT state,current_hp FROM world_boss_events WHERE id=$1 FOR UPDATE`, eventID).Scan(&state, &currentHP); err != nil {
			return nil, errNotFound
		}
		if state == "closed" {
			return nil, errWorldBossClosed
		}
		if state == "defeated" || currentHP <= 0 {
			return s.worldBossViewTx(ctx, tx, rules, eventID, c.ID, who.AccountID)
		}
		lo, err := loadoutForBattle(ctx, tx, c, journey)
		if err != nil {
			return nil, err
		}
		var response struct {
			State json.RawMessage `json:"state"`
		}
		members := []map[string]any{{"character_id": c.ID, "name": c.Nickname, "role_id": c.RoleID, "level": c.Level, "loadout": lo}}
		inputs := []map[string]any{
			{"sequence": 1, "tick": 65, "action": map[string]any{"character_id": c.ID, "action": "attack"}},
			{"sequence": 2, "tick": 130, "action": map[string]any{"character_id": c.ID, "action": "attack"}},
		}
		if err = s.cfg.Authority.Call(ctx, "battle.sync", map[string]any{
			"battle_id":   newID(),
			"monster_id":  rules.BossID,
			"seed":        randomSeed63(),
			"members":     members,
			"inputs":      inputs,
			"target_tick": 180,
		}, &response); err != nil {
			return nil, errAuthority
		}
		var parsed struct {
			CoopMembers map[string]struct {
				DamageDealt int64 `json:"damage_dealt"`
				HealingDone int64 `json:"healing_done"`
			} `json:"coop_members"`
		}
		if err = json.Unmarshal(response.State, &parsed); err != nil {
			return nil, errAuthority
		}
		dmg := parsed.CoopMembers[c.ID].DamageDealt
		sup := parsed.CoopMembers[c.ID].HealingDone
		if dmg <= 0 {
			dmg = 25
		}
		nextHP := currentHP - dmg
		if nextHP < 0 {
			nextHP = 0
		}
		nextState := state
		defeated := false
		if nextHP == 0 {
			nextState = "defeated"
			defeated = true
		}
		if _, err = tx.Exec(ctx, `UPDATE world_boss_events SET current_hp=$2,state=$3,version=version+1 WHERE id=$1`, eventID, nextHP, nextState); err != nil {
			return nil, err
		}
		if err = s.upsertWorldBossContributionTx(ctx, tx, eventID, c.ID, who.AccountID, 0, dmg, sup+5, defeated); err != nil {
			return nil, err
		}
		if defeated {
			_, _ = tx.Exec(ctx, `UPDATE world_boss_participations SET reward_tier='defeat' WHERE event_id=$1 AND (damage_dealt>0 OR objective_steps>0) AND rewarded_at IS NULL`, eventID)
		}
		view, err := s.worldBossViewTx(ctx, tx, rules, eventID, c.ID, who.AccountID)
		if err != nil {
			return nil, err
		}
		view["authoritative_strike_damage"] = dmg
		return view, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) claimWorldBossReward(w http.ResponseWriter, r *http.Request, who identity) {
	eventID := r.PathValue("id")
	if !validID(eventID) {
		s.fail(w, errNotFound)
		return
	}
	data, err := s.command(r, who, "worldboss.claim:"+eventID, struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules := s.cfg.Rules.WorldBoss
		journey := s.cfg.Rules.Journey
		if rules == nil || journey == nil {
			return nil, errWorldBossUnavailable
		}
		var state string
		if err = tx.QueryRow(ctx, `SELECT state FROM world_boss_events WHERE id=$1`, eventID).Scan(&state); err != nil {
			return nil, errNotFound
		}
		var tier string
		var rewardedAt *time.Time
		err = tx.QueryRow(ctx, `SELECT reward_tier,rewarded_at FROM world_boss_participations WHERE event_id=$1 AND character_id=$2 FOR UPDATE`, eventID, c.ID).Scan(&tier, &rewardedAt)
		if errors.Is(err, pgx.ErrNoRows) || tier == "none" {
			return nil, bad("no_participation", "尚未完成公共首领参与目标，暂不可领奖")
		}
		if err != nil {
			return nil, err
		}
		if rewardedAt != nil {
			return nil, &apiError{409, "reward_already_claimed", "该角色已领取本届公共首领奖励"}
		}
		var otherClaimed bool
		_ = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM world_boss_participations WHERE event_id=$1 AND account_id=$2 AND rewarded_at IS NOT NULL)`, eventID, who.AccountID).Scan(&otherClaimed)
		if otherClaimed {
			return nil, &apiError{409, "account_reward_already_claimed", "本账号已领取本届公共首领奖励"}
		}
		bundle := rules.Rewards[tier]
		if state == "defeated" && tier != "defeat" {
			tier = "defeat"
			bundle = rules.Rewards["defeat"]
		}
		txID := "worldboss:" + eventID + ":" + who.AccountID
		if journey.Items[bundle.ItemID].Tradeable {
			if _, err = grantCustomPackItemTx(ctx, tx, c.ID, txID, journey.PackSlots, bundle.ItemID, bundle.Quantity, false, []byte(`{"origin":"world_boss"}`)); err != nil {
				return nil, err
			}
		} else if err = grantPackItems(ctx, tx, c.ID, txID, journey.PackSlots, []itemGrant{{bundle.ItemID, bundle.Quantity}}); err != nil {
			return nil, err
		}
		var goldBalance int64
		if err = tx.QueryRow(ctx, `UPDATE wallets SET gold=gold+$2,version=version+1,updated_at=now() WHERE character_id=$1 RETURNING gold`, c.ID, bundle.Gold).Scan(&goldBalance); err != nil {
			return nil, err
		}
		if bundle.Gold > 0 {
			if _, err = tx.Exec(ctx, `INSERT INTO wallet_ledger(id,character_id,transaction_id,currency,delta,balance_after,reason) VALUES($1,$2,$3,'gold',$4,$5,'world_boss')`,
				newID(), c.ID, txID, bundle.Gold, goldBalance); err != nil {
				return nil, err
			}
		}
		if bundle.Experience > 0 {
			if _, err = tx.Exec(ctx, `UPDATE characters SET experience=experience+$1,version=version+1,updated_at=now() WHERE id=$2`, bundle.Experience, c.ID); err != nil {
				return nil, err
			}
		}
		if _, err = tx.Exec(ctx, `UPDATE world_boss_participations SET reward_tier=$3,reward_gold=$4,reward_exp=$5,reward_item_id=$6,reward_qty=$7,rewarded_at=now(),request_id=$8 WHERE event_id=$1 AND character_id=$2`,
			eventID, c.ID, tier, bundle.Gold, bundle.Experience, bundle.ItemID, bundle.Quantity, r.Header.Get("Idempotency-Key")); err != nil {
			return nil, err
		}
		view, err := s.worldBossViewTx(ctx, tx, rules, eventID, c.ID, who.AccountID)
		if err != nil {
			return nil, err
		}
		view["claimed_tier"] = tier
		view["gold_balance"] = goldBalance
		return view, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

// closeWorldBossOnFault closes an active event window while keeping confirmed participation rewards claimable.
func (s *Server) closeWorldBossOnFault(ctx context.Context, eventID, reason string) error {
	_, err := s.db.Exec(ctx, `UPDATE world_boss_events SET state='closed',closed_reason=$2,version=version+1 WHERE id=$1 AND state IN ('scheduled','active')`, eventID, reason)
	return err
}

var _ = strconv.Itoa
