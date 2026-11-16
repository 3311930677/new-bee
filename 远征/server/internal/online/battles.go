package online

import (
	"context"
	"crypto/rand"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
)

type persistedBattle struct {
	ID                string
	CharacterID       string
	RoomID            string
	EncounterID       string
	RoleID            string
	Level             int
	MonsterID         string
	Seed              int64
	ContentVersion    string
	RulesetVersion    string
	AuthorityEpoch    string
	Gold              int64
	Experience        int64
	RewardPolicy      string
	Status            string
	Snapshot          json.RawMessage
	Tick              int
	ConfirmedSequence int
	Acknowledged      bool
	Result            string
	Started           time.Time
}
type battleInput struct {
	Sequence    int          `json:"sequence"`
	Tick        int          `json:"tick"`
	Action      battleAction `json:"action"`
	Accepted    *bool        `json:"accepted,omitempty"`
	Reason      string       `json:"reason,omitempty"`
	AppliedTick *int         `json:"applied_tick,omitempty"`
}
type battleAction struct {
	Action    string `json:"action"`
	SkillID   string `json:"skill_id,omitempty"`
	TargetUID int    `json:"target_uid,omitempty"`
}
type authorityState struct {
	Tick      int               `json:"tick"`
	Finished  bool              `json:"finished"`
	Result    string            `json:"result"`
	StateHash string            `json:"state_hash"`
	Units     []json.RawMessage `json:"units"`
}

func loadBattle(ctx context.Context, tx pgx.Tx, id, account, charID string) (persistedBattle, error) {
	var b persistedBattle
	err := tx.QueryRow(ctx, `SELECT id::text,character_id::text,room_id::text,encounter_id,role_id,level,monster_id,seed,content_version,ruleset_version,authority_epoch,reward_gold,reward_experience,reward_policy,status,snapshot,simulation_tick,confirmed_sequence,acknowledged_at IS NOT NULL,result,started_at FROM battles WHERE id=$1 AND account_id=$2 AND character_id=$3 FOR UPDATE`, id, account, charID).Scan(&b.ID, &b.CharacterID, &b.RoomID, &b.EncounterID, &b.RoleID, &b.Level, &b.MonsterID, &b.Seed, &b.ContentVersion, &b.RulesetVersion, &b.AuthorityEpoch, &b.Gold, &b.Experience, &b.RewardPolicy, &b.Status, &b.Snapshot, &b.Tick, &b.ConfirmedSequence, &b.Acknowledged, &b.Result, &b.Started)
	if errors.Is(err, pgx.ErrNoRows) {
		return b, &apiError{404, "battle_not_found", "找不到这场战斗"}
	}
	return b, err
}
func (s *Server) startBattle(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
	var body struct {
		EncounterID string `json:"encounter_id"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	e, ok := s.cfg.Rules.Encounters[body.EncounterID]
	if !ok {
		s.fail(w, bad("encounter_unavailable", "此目标暂不可挑战"))
		return
	}
	data, err := s.command(r, who, "battle.start", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		l, err := s.lease(ctx, tx, who, c.ID)
		if err != nil {
			return nil, err
		}
		if math.Hypot(l.X-e.Position[0], l.Y-e.Position[1]) > e.Radius {
			return nil, bad("too_far", "请先靠近挑战目标")
		}
		var exists bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM battles WHERE character_id=$1 AND (status='active' OR (status='settled' AND acknowledged_at IS NULL)))`, c.ID).Scan(&exists); err != nil {
			return nil, err
		}
		if exists {
			return nil, &apiError{409, "battle_active", "请先完成当前战斗并确认结算"}
		}
		var seedBytes [8]byte
		if _, err = rand.Read(seedBytes[:]); err != nil {
			return nil, err
		}
		id := newID()
		seed := int64(binary.BigEndian.Uint64(seedBytes[:]) & ((1 << 53) - 1))
		_, err = tx.Exec(ctx, `INSERT INTO battles(id,account_id,character_id,room_id,encounter_id,role_id,level,monster_id,seed,content_version,ruleset_version,reward_gold,reward_experience,reward_policy) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`, id, who.AccountID, c.ID, l.RoomID, body.EncounterID, c.RoleID, c.Level, e.MonsterID, seed, s.cfg.ContentVersion, RulesetVersion, e.Gold, e.Experience, e.RewardPolicy)
		if err != nil {
			return nil, err
		}
		b, err := loadBattle(ctx, tx, id, who.AccountID, c.ID)
		if err != nil {
			return nil, err
		}
		if err = s.syncBattle(ctx, tx, &b); err != nil {
			return nil, err
		}
		return battleView(ctx, tx, b)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 201, data)
}
func (s *Server) activeBattle(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	var id string
	err = tx.QueryRow(r.Context(), `SELECT id::text FROM battles WHERE character_id=$1 AND (status='active' OR (status='settled' AND acknowledged_at IS NULL)) ORDER BY started_at DESC LIMIT 1`, c.ID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		respond(w, 200, map[string]any{"battle": nil})
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	s.respondBattle(w, r, tx, who, c.ID, id)
}
func (s *Server) battleSnapshot(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	id := r.PathValue("id")
	if !validID(id) {
		s.fail(w, &apiError{404, "battle_not_found", "找不到这场战斗"})
		return
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	s.respondBattle(w, r, tx, who, c.ID, id)
}
func (s *Server) respondBattle(w http.ResponseWriter, r *http.Request, tx pgx.Tx, who identity, charID, id string) {
	b, err := loadBattle(r.Context(), tx, id, who.AccountID, charID)
	if err == nil {
		err = s.syncBattle(r.Context(), tx, &b)
	}
	var data any
	if err == nil {
		data, err = battleView(r.Context(), tx, b)
	}
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
func (s *Server) battleCommand(w http.ResponseWriter, r *http.Request, who identity) {
	id := r.PathValue("id")
	if !validID(id) {
		s.fail(w, &apiError{404, "battle_not_found", "找不到这场战斗"})
		return
	}
	if !s.limiter.allow("battle:"+who.AccountID, 20, time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "指令过于频繁，请稍后重试"})
		return
	}
	var action battleAction
	if err := decode(r, &action); err != nil {
		s.fail(w, err)
		return
	}
	if action.Action != "attack" && action.Action != "skill" && action.Action != "potion" && action.Action != "flee" {
		s.fail(w, bad("invalid_action", "请选择攻、技、物或逃"))
		return
	}
	if len(action.SkillID) > 64 || action.TargetUID < 0 || action.TargetUID > 10000 {
		s.fail(w, bad("invalid_action", "战斗目标或技能无效"))
		return
	}
	data, err := s.command(r, who, "battle.command:"+id, action, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		b, err := loadBattle(ctx, tx, id, who.AccountID, c.ID)
		if err != nil {
			return nil, err
		}
		if b.Status != "active" {
			return battleView(ctx, tx, b)
		}
		if err = s.recoverAuthority(ctx, tx, &b); err != nil {
			return nil, err
		}
		var count int
		if err = tx.QueryRow(ctx, `SELECT count(*) FROM battle_inputs WHERE battle_id=$1`, id).Scan(&count); err != nil {
			return nil, err
		}
		if count >= 6000 {
			return nil, &apiError{409, "input_limit", "本场指令达到上限，请等待结算"}
		}
		tick := battleTargetTick(b)
		payload, err := json.Marshal(action)
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO battle_inputs(battle_id,sequence,tick,action) VALUES($1,$2,$3,$4)`, id, count+1, tick, payload); err != nil {
			return nil, err
		}
		if err = s.syncBattle(ctx, tx, &b); err != nil {
			return nil, err
		}
		return battleView(ctx, tx, b)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
func battleTargetTick(b persistedBattle) int {
	tick := int(time.Since(b.Started).Seconds() * 30)
	if tick < b.Tick {
		tick = b.Tick
	}
	if tick > 9000 {
		tick = 9000
	}
	if tick < 0 {
		tick = 0
	}
	return tick
}

func (s *Server) acknowledgeBattle(w http.ResponseWriter, r *http.Request, who identity) {
	id := r.PathValue("id")
	if !validID(id) {
		s.fail(w, &apiError{404, "battle_not_found", "找不到这场战斗"})
		return
	}
	var body struct{}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "battle.acknowledge:"+id, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		b, err := loadBattle(ctx, tx, id, who.AccountID, c.ID)
		if err != nil {
			return nil, err
		}
		if b.Status != "settled" {
			return nil, &apiError{409, "battle_active", "请先完成当前战斗"}
		}
		if _, err = tx.Exec(ctx, `UPDATE battles SET acknowledged_at=coalesce(acknowledged_at,now()),updated_at=now() WHERE id=$1`, id); err != nil {
			return nil, err
		}
		b.Acknowledged = true
		return battleView(ctx, tx, b)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) syncBattle(ctx context.Context, tx pgx.Tx, b *persistedBattle) error {
	if b.Status != "active" {
		return nil
	}
	if s.cfg.Authority == nil {
		return errAuthority
	}
	if b.ContentVersion != s.cfg.ContentVersion || b.RulesetVersion != RulesetVersion {
		return &apiError{409, "battle_version_mismatch", "此战斗版本不同，请联系测试管理员处理"}
	}
	if err := s.recoverAuthority(ctx, tx, b); err != nil {
		return err
	}
	rows, err := tx.Query(ctx, `SELECT sequence,tick,action,accepted,reason,applied_tick FROM battle_inputs WHERE battle_id=$1 ORDER BY sequence`, b.ID)
	if err != nil {
		return err
	}
	inputs := []battleInput{}
	for rows.Next() {
		var entry battleInput
		var raw []byte
		if err = rows.Scan(&entry.Sequence, &entry.Tick, &raw, &entry.Accepted, &entry.Reason, &entry.AppliedTick); err != nil {
			rows.Close()
			return err
		}
		if err = json.Unmarshal(raw, &entry.Action); err != nil {
			rows.Close()
			return err
		}
		inputs = append(inputs, entry)
	}
	rows.Close()
	if rows.Err() != nil {
		return rows.Err()
	}
	target := battleTargetTick(*b)
	if len(inputs) > 0 && inputs[len(inputs)-1].Tick > target {
		target = inputs[len(inputs)-1].Tick
	}
	var response struct {
		State  json.RawMessage `json:"state"`
		Epoch  string          `json:"epoch"`
		Inputs []battleInput   `json:"inputs"`
	}
	var checkpoint authorityState
	if json.Unmarshal(b.Snapshot, &checkpoint) != nil {
		return errAuthority
	}
	err = s.cfg.Authority.Call(ctx, "battle.sync", map[string]any{"battle_id": b.ID, "role_id": b.RoleID, "level": b.Level, "monster_id": b.MonsterID, "seed": b.Seed, "inputs": inputs, "target_tick": target, "confirmed_sequence": b.ConfirmedSequence, "confirmed_tick": b.Tick, "expected_state_hash": checkpoint.StateHash}, &response)
	if err != nil || response.Epoch != b.AuthorityEpoch {
		return errAuthority
	}
	var state authorityState
	if json.Unmarshal(response.State, &state) != nil || state.Tick < b.Tick || state.Tick > target || len(state.Units) == 0 {
		return errAuthority
	}
	if !state.Finished && state.Tick != target {
		return errAuthority
	}
	if h, err := hex.DecodeString(state.StateHash); err != nil || len(h) != 32 {
		return errAuthority
	}
	if state.Finished && state.Result != "victory" && state.Result != "defeat" && state.Result != "flee" && state.Result != "draw" {
		return errAuthority
	}
	if len(response.Inputs) != len(inputs) || b.ConfirmedSequence > len(inputs) {
		return errAuthority
	}
	for i, received := range response.Inputs {
		original := inputs[i]
		if received.Sequence != i+1 || received.Tick != original.Tick || received.Action != original.Action || received.Accepted == nil || received.AppliedTick == nil || *received.AppliedTick < 0 || *received.AppliedTick > received.Tick || *received.AppliedTick > state.Tick || len(received.Reason) > 80 {
			return errAuthority
		}
		if i < b.ConfirmedSequence {
			if original.Accepted == nil || original.AppliedTick == nil || *received.Accepted != *original.Accepted || *received.AppliedTick != *original.AppliedTick || received.Reason != original.Reason {
				return errAuthority
			}
		} else if _, err = tx.Exec(ctx, `UPDATE battle_inputs SET accepted=$1,reason=$2,applied_tick=$3 WHERE battle_id=$4 AND sequence=$5`, *received.Accepted, received.Reason, *received.AppliedTick, b.ID, received.Sequence); err != nil {
			return err
		}
	}
	b.Snapshot = response.State
	b.Tick = state.Tick
	b.Result = state.Result
	b.ConfirmedSequence = len(inputs)
	if _, err = tx.Exec(ctx, `UPDATE battles SET snapshot=$1,simulation_tick=$2,result=$3,confirmed_sequence=$5,updated_at=now() WHERE id=$4`, response.State, state.Tick, state.Result, b.ID, b.ConfirmedSequence); err != nil {
		return err
	}
	if state.Finished {
		return s.settleBattle(ctx, tx, b, state)
	}
	return nil
}
func (s *Server) recoverAuthority(ctx context.Context, tx pgx.Tx, b *persistedBattle) error {
	if s.cfg.Authority == nil {
		return errAuthority
	}
	var health struct {
		Epoch string `json:"epoch"`
	}
	if err := s.cfg.Authority.Call(ctx, "ping", nil, &health); err != nil || len(health.Epoch) != 32 {
		return errAuthority
	}
	if b.AuthorityEpoch == health.Epoch {
		return nil
	}
	// A fresh worker rebuilds from committed input. Freeze the outage interval;
	// players must not take unanswerable attacks while the room is unavailable.
	if b.AuthorityEpoch != "" {
		b.Started = time.Now().Add(-time.Duration(b.Tick) * time.Second / 30)
	}
	b.AuthorityEpoch = health.Epoch
	_, err := tx.Exec(ctx, `UPDATE battles SET authority_epoch=$1,started_at=$2,updated_at=now() WHERE id=$3`, b.AuthorityEpoch, b.Started, b.ID)
	return err
}
func (s *Server) settleBattle(ctx context.Context, tx pgx.Tx, b *persistedBattle, state authorityState) error {
	resultID := newID()
	gold, experience := int64(0), int64(0)
	if state.Result == "victory" {
		allowed := true
		if b.RewardPolicy == "once" {
			cmd, err := tx.Exec(ctx, `INSERT INTO battle_reward_claims(character_id,encounter_id,result_id) VALUES($1,$2,$3) ON CONFLICT(character_id,encounter_id) DO NOTHING`, b.CharacterID, b.EncounterID, resultID)
			if err != nil {
				return err
			}
			allowed = cmd.RowsAffected() == 1
		}
		if allowed {
			gold = b.Gold
			experience = b.Experience
		}
	}
	var balance int64
	err := tx.QueryRow(ctx, `UPDATE wallets SET gold=gold+$1,version=version+1,updated_at=now() WHERE character_id=$2 RETURNING gold`, gold, b.CharacterID).Scan(&balance)
	if err != nil {
		return err
	}
	if gold > 0 {
		_, err = tx.Exec(ctx, `INSERT INTO wallet_ledger(id,character_id,transaction_id,currency,delta,balance_after,reason) VALUES($1,$2,$3,'gold',$4,$5,'battle_reward')`, newID(), b.CharacterID, "battle:"+b.ID, gold, balance)
		if err != nil {
			return err
		}
	}
	if experience > 0 {
		if _, err = tx.Exec(ctx, `UPDATE characters SET experience=experience+$1,version=version+1,updated_at=now() WHERE id=$2`, experience, b.CharacterID); err != nil {
			return err
		}
	}
	_, err = tx.Exec(ctx, `INSERT INTO battle_results(result_id,battle_id,character_id,result,state_hash,gold,experience,wallet_balance,final_snapshot) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)`, resultID, b.ID, b.CharacterID, state.Result, state.StateHash, gold, experience, balance, b.Snapshot)
	if err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE battles SET status='settled',settled_at=now(),updated_at=now() WHERE id=$1`, b.ID); err != nil {
		return err
	}
	b.Status = "settled"
	return nil
}
func battleView(ctx context.Context, tx pgx.Tx, b persistedBattle) (any, error) {
	view := map[string]any{"id": b.ID, "character_id": b.CharacterID, "encounter_id": b.EncounterID, "status": b.Status, "result": b.Result, "state": b.Snapshot, "acknowledged": b.Acknowledged}
	if b.ConfirmedSequence > 0 {
		var accepted bool
		var reason string
		if err := tx.QueryRow(ctx, `SELECT accepted,reason FROM battle_inputs WHERE battle_id=$1 AND sequence=$2`, b.ID, b.ConfirmedSequence).Scan(&accepted, &reason); err != nil {
			return nil, err
		}
		view["last_input"] = map[string]any{"sequence": b.ConfirmedSequence, "accepted": accepted, "reason": reason}
	}
	if b.Status == "settled" {
		var id string
		var gold, exp, balance int64
		if err := tx.QueryRow(ctx, `SELECT result_id::text,gold,experience,wallet_balance FROM battle_results WHERE battle_id=$1`, b.ID).Scan(&id, &gold, &exp, &balance); err != nil {
			return nil, err
		}
		view["receipt"] = map[string]any{"result_id": id, "gold": gold, "experience": exp, "wallet_balance": balance}
	}
	return map[string]any{"battle": view}, nil
}
