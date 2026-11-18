package online

import (
	"context"
	"crypto/rand"
	"encoding/binary"
	"encoding/json"
	"errors"
	"math"
	"net/http"
	"sort"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
)

type CoopRules struct {
	DisconnectGraceSeconds int                    `json:"disconnect_grace_seconds"`
	AFKWarnSeconds         int                    `json:"afk_warn_seconds"`
	DownedWindowTicks      int                    `json:"downed_window_ticks"`
	MentorLevelDelta       int                    `json:"mentor_level_delta"`
	DropExpiryHours        int                    `json:"drop_expiry_hours"`
	Scaling                map[string]CoopScale   `json:"scaling"`
	Dungeons               map[string]CoopDungeon `json:"dungeons"`
}

type CoopScale struct {
	HPMult       float64 `json:"hp_mult"`
	AtkMult      float64 `json:"atk_mult"`
	DefMult      float64 `json:"def_mult"`
	ExtraAdds    int     `json:"extra_adds"`
	GoldBonusPct int     `json:"gold_bonus_pct"`
}

type CoopDungeon struct {
	Name                  string           `json:"name"`
	Theme                 string           `json:"theme"`
	MinLevel              int              `json:"min_level"`
	RecommendedLevel      int              `json:"recommended_level"`
	RequiresJourneyUnlock bool             `json:"requires_journey_unlock"`
	PetNotice             string           `json:"pet_notice"`
	PotionNotice          string           `json:"potion_notice"`
	FirstClearNotice      string           `json:"first_clear_notice"`
	Stages                []CoopStage      `json:"stages"`
	Rewards               CoopRewardTable  `json:"rewards"`
}

type CoopStage struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Kind         string   `json:"kind"`
	Checkpoint   bool     `json:"checkpoint"`
	Mechanics    []string `json:"mechanics,omitempty"`
	MonsterID    string   `json:"monster_id,omitempty"`
	AddMonsterID string   `json:"add_monster_id,omitempty"`
	Hint         string   `json:"hint,omitempty"`
}

type CoopRewardTable struct {
	FirstClear CoopRewardBundle `json:"first_clear"`
	Repeat     CoopRewardBundle `json:"repeat"`
	Mentor     CoopRewardBundle `json:"mentor"`
}

type CoopRewardBundle struct {
	Gold       int64  `json:"gold"`
	Experience int64  `json:"experience"`
	ItemID     string `json:"item_id"`
	Quantity   int    `json:"quantity"`
}

var (
	errCoopUnavailable = &apiError{409, "coop_unavailable", "当前服务器尚未开放合作副本"}
	errCoopLocked      = &apiError{409, "coop_locked", "请先完成边城旅程取得失声碑窟通行资格"}
	errCoopInstance    = &apiError{404, "coop_instance_not_found", "合作副本实例不存在或已结束"}
	errCoopNotReady    = &apiError{409, "coop_not_ready", "仍有队友未确认准备就绪"}
	errCoopDropClaimed = &apiError{409, "coop_drop_unavailable", "战利品已领取或已过期"}
)

func (c CoopRules) validate(items map[string]JourneyItem) error {
	invalid := errors.New("invalid coop rules")
	finite := func(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) }
	if c.DisconnectGraceSeconds < 10 || c.DisconnectGraceSeconds > 600 ||
		c.AFKWarnSeconds < 10 || c.AFKWarnSeconds > 600 ||
		c.DownedWindowTicks < 0 || c.DownedWindowTicks > 1800 ||
		c.MentorLevelDelta < 1 || c.MentorLevelDelta > 60 ||
		c.DropExpiryHours < 1 || len(c.Dungeons) == 0 {
		return invalid
	}
	for _, k := range []string{"1", "2", "3", "4"} {
		s, ok := c.Scaling[k]
		if !ok || !finite(s.HPMult) || !finite(s.AtkMult) || !finite(s.DefMult) ||
			s.HPMult <= 0 || s.AtkMult <= 0 || s.DefMult <= 0 || s.ExtraAdds < 0 || s.ExtraAdds > 4 || s.GoldBonusPct < 0 {
			return invalid
		}
	}
	for id, d := range c.Dungeons {
		if !journeyIdentifier.MatchString(id) || d.Name == "" || d.Theme == "" ||
			d.MinLevel < 1 || d.RecommendedLevel < d.MinLevel || len(d.Stages) < 2 {
			return invalid
		}
		for _, st := range d.Stages {
			if !journeyIdentifier.MatchString(st.ID) || st.Name == "" {
				return invalid
			}
			switch st.Kind {
			case "puzzle":
				if len(st.Mechanics) == 0 {
					return invalid
				}
			case "battle", "boss":
				if st.MonsterID == "" {
					return invalid
				}
			default:
				return invalid
			}
		}
		for _, b := range []CoopRewardBundle{d.Rewards.FirstClear, d.Rewards.Repeat, d.Rewards.Mentor} {
			if b.Gold < 0 || b.Experience < 0 || b.Quantity <= 0 {
				return invalid
			}
			if _, ok := items[b.ItemID]; !ok {
				return invalid
			}
		}
	}
	return nil
}

func (c CoopRules) scalingFor(count int, difficulty string) CoopScale {
	if count < 1 {
		count = 1
	} else if count > 4 {
		count = 4
	}
	base := c.Scaling[strconv.Itoa(count)]
	if difficulty == "heroic" {
		base.HPMult *= 1.25
		base.AtkMult *= 1.15
		base.DefMult *= 1.10
		base.GoldBonusPct += 25
	}
	return base
}

type coopMemberPayload struct {
	CharacterID        string `json:"character_id"`
	Nickname           string `json:"nickname"`
	RoleID             string `json:"role_id"`
	Level              int    `json:"level"`
	SyncedLevel        int    `json:"synced_level"`
	IsMentor           bool   `json:"is_mentor"`
	Ready              bool   `json:"ready"`
	Status             string `json:"status"`
	MechanicsDone      int    `json:"mechanics_done"`
	StagesParticipated int    `json:"stages_participated"`
	DamageDealt        int64  `json:"damage_dealt"`
	HealingDone        int64  `json:"healing_done"`
	RescuesDone        int    `json:"rescues_done"`
	AFKSeconds         int    `json:"afk_seconds"`
	AFKWarn            bool   `json:"afk_warn"`
	RetreatVote        bool   `json:"retreat_vote"`
}

type coopDropPayload struct {
	ID          string     `json:"id"`
	InstanceID  string     `json:"instance_id"`
	DungeonID   string     `json:"dungeon_id"`
	SourceStage string     `json:"source_stage"`
	ItemID      string     `json:"item_template_id"`
	ItemName    string     `json:"item_name"`
	Quantity    int        `json:"quantity"`
	Gold        int64      `json:"gold_amount"`
	Experience  int64      `json:"experience_amount"`
	FirstClear  bool       `json:"is_first_clear"`
	MentorBonus bool       `json:"is_mentor_bonus"`
	ClaimedAt   *time.Time `json:"claimed_at,omitempty"`
	ExpiresAt   time.Time  `json:"expires_at"`
}

func (s *Server) requireCoop(tx pgx.Tx) (*CoopRules, *JourneyRules, error) {
	if s.cfg.Rules.Coop == nil || s.cfg.Rules.Journey == nil || s.cfg.Authority == nil {
		return nil, nil, errCoopUnavailable
	}
	return s.cfg.Rules.Coop, s.cfg.Rules.Journey, nil
}

func (s *Server) coopDungeons(w http.ResponseWriter, r *http.Request, who identity) {
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	rules, _, err := s.requireCoop(tx)
	if err != nil {
		s.fail(w, err)
		return
	}
	progress, err := readJourney(r.Context(), tx, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	var ids []string
	for id := range rules.Dungeons {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	dungeons := []map[string]any{}
	for _, id := range ids {
		d := rules.Dungeons[id]
		unlocked := !d.RequiresJourneyUnlock || progress.Step == "complete"
		var cleared bool
		_ = tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM coop_instance_members m JOIN coop_instances ci ON ci.id=m.instance_id WHERE m.character_id=$1 AND ci.dungeon_id=$2 AND ci.status='completed' AND m.status='completed')`, c.ID, id).Scan(&cleared)
		dungeons = append(dungeons, map[string]any{
			"id":                    id,
			"name":                  d.Name,
			"recommended_level":     d.RecommendedLevel,
			"min_level":             d.MinLevel,
			"unlocked":              unlocked,
			"first_cleared":         cleared,
			"pet_notice":            d.PetNotice,
			"potion_notice":         d.PotionNotice,
			"first_clear_notice":    d.FirstClearNotice,
			"stages":                d.Stages,
			"rewards":               d.Rewards,
		})
	}
	var queueStatus, queueDungeon, queueDifficulty, queueGoal, matchedID string
	err = tx.QueryRow(r.Context(), `SELECT status,dungeon_id,difficulty,goal,coalesce(matched_instance_id::text,'') FROM coop_queues WHERE character_id=$1`, c.ID).
		Scan(&queueStatus, &queueDungeon, &queueDifficulty, &queueGoal, &matchedID)
	if errors.Is(err, pgx.ErrNoRows) {
		queueStatus = ""
	} else if err != nil {
		s.fail(w, err)
		return
	}
	var activeInstanceID string
	_ = tx.QueryRow(r.Context(), `SELECT ci.id::text FROM coop_instance_members m JOIN coop_instances ci ON ci.id=m.instance_id
		WHERE m.character_id=$1 AND m.status IN ('ready','active','disconnected') AND ci.status IN ('ready','active') ORDER BY ci.created_at DESC LIMIT 1`, c.ID).Scan(&activeInstanceID)
	drops, err := s.readCoopDropsTx(r.Context(), tx, c.ID, false)
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{
		"dungeons":           dungeons,
		"scaling":            rules.Scaling,
		"active_instance_id": activeInstanceID,
		"queue": map[string]any{
			"status":              queueStatus,
			"dungeon_id":          queueDungeon,
			"difficulty":          queueDifficulty,
			"goal":                queueGoal,
			"matched_instance_id": matchedID,
		},
		"unclaimed_drops": drops,
	})
}

func validateDungeonOption(rules *CoopRules, dungeonID, difficulty, goal string) (CoopDungeon, error) {
	d, ok := rules.Dungeons[dungeonID]
	if !ok {
		return CoopDungeon{}, bad("invalid_dungeon", "找不到所选合作副本")
	}
	if difficulty == "" {
		difficulty = "standard"
	}
	if difficulty != "standard" && difficulty != "heroic" {
		return CoopDungeon{}, bad("invalid_difficulty", "无效的副本难度")
	}
	if goal == "" {
		goal = "first_clear"
	}
	if goal != "first_clear" && goal != "materials" && goal != "mentor" {
		return CoopDungeon{}, bad("invalid_goal", "无效的副本目标筛选")
	}
	return d, nil
}

func ensureNoActiveCoop(ctx context.Context, tx pgx.Tx, charID string) error {
	var existing string
	err := tx.QueryRow(ctx, `SELECT ci.id::text FROM coop_instance_members m JOIN coop_instances ci ON ci.id=m.instance_id
		WHERE m.character_id=$1 AND m.status IN ('ready','active','disconnected') AND ci.status IN ('ready','active') LIMIT 1`, charID).Scan(&existing)
	if err == nil && existing != "" {
		return &apiError{409, "coop_already_active", "角色已在另一个进行中的合作副本内"}
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	return nil
}

type coopParticipant struct {
	Character
	AccountID string
}

func buildCoopParticipants(ctx context.Context, tx pgx.Tx, charIDs []string, rules *CoopRules) ([]coopParticipant, map[string]int, map[string]bool, error) {
	if len(charIDs) < 1 || len(charIDs) > 4 {
		return nil, nil, nil, bad("invalid_party_size", "合作副本支持 1 至 4 名角色")
	}
	chars := make([]coopParticipant, 0, len(charIDs))
	minLevel := 999
	for _, cid := range charIDs {
		var accID string
		var c Character
		err := tx.QueryRow(ctx, `SELECT account_id::text,id::text,nickname,role_id,appearance_id,gender_id,avatar_id,level,experience,map_id,version FROM characters WHERE id=$1 AND deleted_at IS NULL FOR UPDATE`, cid).
			Scan(&accID, &c.ID, &c.Nickname, &c.RoleID, &c.AppearanceID, &c.GenderID, &c.AvatarID, &c.Level, &c.Experience, &c.MapID, &c.Version)
		if err != nil {
			return nil, nil, nil, err
		}
		if c.Level < minLevel {
			minLevel = c.Level
		}
		chars = append(chars, coopParticipant{Character: c, AccountID: accID})
	}
	capLevel := minLevel + rules.MentorLevelDelta
	synced := make(map[string]int, len(chars))
	mentor := make(map[string]bool, len(chars))
	for _, c := range chars {
		if len(chars) > 1 && c.Level > capLevel {
			synced[c.ID] = capLevel
			mentor[c.ID] = true
		} else {
			synced[c.ID] = c.Level
			mentor[c.ID] = false
		}
	}
	return chars, synced, mentor, nil
}

func (s *Server) createCoopInstanceTx(ctx context.Context, tx pgx.Tx, rules *CoopRules, dungeonID, difficulty, goal string, partyID, leaderID string, memberIDs []string, autoReadyLeader bool) (string, error) {
	d, err := validateDungeonOption(rules, dungeonID, difficulty, goal)
	if err != nil {
		return "", err
	}
	chars, synced, mentor, err := buildCoopParticipants(ctx, tx, memberIDs, rules)
	if err != nil {
		return "", err
	}
	for _, ch := range chars {
		if ch.Level < d.MinLevel {
			return "", &apiError{409, "level_too_low", "队员等级未达到副本要求"}
		}
		if err = ensureNoActiveCoop(ctx, tx, ch.ID); err != nil {
			return "", err
		}
		if d.RequiresJourneyUnlock {
			progress, pErr := readJourney(ctx, tx, ch.ID)
			if pErr != nil {
				return "", pErr
			}
			if progress.Step != "complete" {
				return "", errCoopLocked
			}
		}
	}
	instID := newID()
	scale := rules.scalingFor(len(chars), difficulty)
	scaleJSON, _ := json.Marshal(scale)
	roomState := map[string]any{
		"solved_mechanics": map[string]bool{},
		"stage_messages":   []string{d.Stages[0].Hint},
		"bonus_cargo":      false,
	}
	roomJSON, _ := json.Marshal(roomState)
	status := "ready"
	if len(chars) == 1 && autoReadyLeader {
		status = "active"
	}
	if _, err = tx.Exec(ctx, `INSERT INTO coop_instances(id,dungeon_id,difficulty,goal,party_id,leader_character_id,status,stage_index,checkpoint_stage,room_state,member_count,scale_snapshot,content_version,ruleset_version)
		VALUES($1,$2,$3,$4,nullif($5,'')::uuid,$6,$7,0,0,$8,$9,$10,$11,$12)`,
		instID, dungeonID, difficulty, goal, partyID, leaderID, status, roomJSON, len(chars), scaleJSON, s.cfg.ContentVersion, RulesetVersion); err != nil {
		return "", err
	}
	for _, ch := range chars {
		ready := (len(chars) == 1 && autoReadyLeader) || (autoReadyLeader && ch.ID == leaderID)
		mStatus := "ready"
		if status == "active" {
			mStatus = "active"
		}
		if _, err = tx.Exec(ctx, `INSERT INTO coop_instance_members(instance_id,character_id,account_id,character_name,role_id,character_level,synced_level,is_mentor,ready,status)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
			instID, ch.ID, ch.AccountID, ch.Nickname, ch.RoleID, ch.Level, synced[ch.ID], mentor[ch.ID], ready, mStatus); err != nil {
			return "", err
		}
	}
	return instID, nil
}

func (s *Server) createCoopInstance(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		DungeonID  string `json:"dungeon_id"`
		Difficulty string `json:"difficulty"`
		Goal       string `json:"goal"`
		AllowSolo  bool   `json:"allow_solo"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.Difficulty == "" {
		body.Difficulty = "standard"
	}
	if body.Goal == "" {
		body.Goal = "first_clear"
	}
	data, err := s.command(r, who, "coop.create:"+body.DungeonID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules, journey, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		var partyID, leaderID string
		err = tx.QueryRow(ctx, `SELECT p.id::text,p.leader_character_id::text FROM party_members pm JOIN parties p ON p.id=pm.party_id WHERE pm.character_id=$1`, c.ID).
			Scan(&partyID, &leaderID)
		var members []string
		if errors.Is(err, pgx.ErrNoRows) {
			if !body.AllowSolo {
				return nil, &apiError{409, "party_or_queue_required", "请先组队、加入匹配或选择单人进入"}
			}
			members = []string{c.ID}
			leaderID = c.ID
		} else if err != nil {
			return nil, err
		} else {
			if leaderID != c.ID {
				return nil, errPartyLeader
			}
			rows, qErr := tx.Query(ctx, `SELECT character_id::text FROM party_members WHERE party_id=$1 ORDER BY joined_at`, partyID)
			if qErr != nil {
				return nil, qErr
			}
			for rows.Next() {
				var mid string
				if qErr = rows.Scan(&mid); qErr != nil {
					rows.Close()
					return nil, qErr
				}
				members = append(members, mid)
			}
			rows.Close()
			if len(members) == 1 && !body.AllowSolo {
				return nil, &apiError{409, "party_needs_members", "当前队伍仅有1人，请邀请队友或选择单人进入"}
			}
		}
		instID, err := s.createCoopInstanceTx(ctx, tx, rules, body.DungeonID, body.Difficulty, body.Goal, partyID, leaderID, members, body.AllowSolo && len(members) == 1)
		if err != nil {
			return nil, err
		}
		return s.buildCoopViewTx(ctx, tx, rules, journey, instID, c.ID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) joinCoopQueue(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		DungeonID   string `json:"dungeon_id"`
		Difficulty  string `json:"difficulty"`
		Goal        string `json:"goal"`
		FriendsOnly bool   `json:"friends_only"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.Difficulty == "" {
		body.Difficulty = "standard"
	}
	if body.Goal == "" {
		body.Goal = "first_clear"
	}
	data, err := s.command(r, who, "coop.queue.join:"+body.DungeonID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules, journey, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		d, err := validateDungeonOption(rules, body.DungeonID, body.Difficulty, body.Goal)
		if err != nil {
			return nil, err
		}
		if c.Level < d.MinLevel {
			return nil, &apiError{409, "level_too_low", "角色等级未达到副本要求"}
		}
		if d.RequiresJourneyUnlock {
			progress, pErr := readJourney(ctx, tx, c.ID)
			if pErr != nil {
				return nil, pErr
			}
			if progress.Step != "complete" {
				return nil, errCoopLocked
			}
		}
		if err = ensureNoActiveCoop(ctx, tx, c.ID); err != nil {
			return nil, err
		}
		var partyID string
		_ = tx.QueryRow(ctx, `SELECT party_id::text FROM party_members WHERE character_id=$1`, c.ID).Scan(&partyID)
		if _, err = tx.Exec(ctx, `INSERT INTO coop_queues(character_id,account_id,dungeon_id,difficulty,goal,party_id,friends_only,role_id,character_level,status,matched_instance_id,queued_at,updated_at)
			VALUES($1,$2,$3,$4,$5,nullif($6,'')::uuid,$7,$8,$9,'queued',NULL,now(),now())
			ON CONFLICT (character_id) DO UPDATE SET dungeon_id=$3,difficulty=$4,goal=$5,party_id=nullif($6,'')::uuid,friends_only=$7,role_id=$8,character_level=$9,status='queued',matched_instance_id=NULL,updated_at=now()`,
			c.ID, who.AccountID, body.DungeonID, body.Difficulty, body.Goal, partyID, body.FriendsOnly, c.RoleID, c.Level); err != nil {
			return nil, err
		}
		rows, err := tx.Query(ctx, `SELECT q.character_id::text,q.account_id::text,q.friends_only FROM coop_queues q
			WHERE q.dungeon_id=$1 AND q.difficulty=$2 AND q.status='queued' ORDER BY q.queued_at FOR UPDATE`, body.DungeonID, body.Difficulty)
		if err != nil {
			return nil, err
		}
		type qCand struct {
			charID      string
			accountID   string
			friendsOnly bool
		}
		cands := []qCand{}
		for rows.Next() {
			var cand qCand
			if err = rows.Scan(&cand.charID, &cand.accountID, &cand.friendsOnly); err != nil {
				rows.Close()
				return nil, err
			}
			cands = append(cands, cand)
		}
		rows.Close()
		compatible := []qCand{{charID: c.ID, accountID: who.AccountID, friendsOnly: body.FriendsOnly}}
		for _, cand := range cands {
			if cand.charID == c.ID {
				continue
			}
			pairOK := true
			for _, picked := range compatible {
				var blocked bool
				_ = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM player_blocks WHERE (owner_account_id=$1 AND blocked_account_id=$2) OR (owner_account_id=$2 AND blocked_account_id=$1))`,
					picked.accountID, cand.accountID).Scan(&blocked)
				if blocked {
					pairOK = false
					break
				}
				if picked.friendsOnly || cand.friendsOnly {
					a, b := picked.charID, cand.charID
					if a > b {
						a, b = b, a
					}
					var isFriend bool
					_ = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM friendships WHERE character_a=$1 AND character_b=$2)`, a, b).Scan(&isFriend)
					if !isFriend {
						pairOK = false
						break
					}
				}
			}
			if !pairOK {
				continue
			}
			compatible = append(compatible, cand)
			if len(compatible) == 4 {
				break
			}
		}
		if len(compatible) >= 2 {
			memberIDs := make([]string, 0, len(compatible))
			for _, m := range compatible {
				memberIDs = append(memberIDs, m.charID)
			}
			instID, err := s.createCoopInstanceTx(ctx, tx, rules, body.DungeonID, body.Difficulty, body.Goal, "", compatible[1].charID, memberIDs, false)
			if err != nil {
				return nil, err
			}
			if _, err = tx.Exec(ctx, `UPDATE coop_queues SET status='matched',matched_instance_id=$1,updated_at=now() WHERE character_id = ANY($2::uuid[])`, instID, memberIDs); err != nil {
				return nil, err
			}
			view, err := s.buildCoopViewTx(ctx, tx, rules, journey, instID, c.ID)
			if err != nil {
				return nil, err
			}
			return map[string]any{"status": "matched", "instance": view}, nil
		}
		return map[string]any{"status": "queued", "dungeon_id": body.DungeonID, "difficulty": body.Difficulty, "goal": body.Goal}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) leaveCoopQueue(w http.ResponseWriter, r *http.Request, who identity) {
	data, err := s.command(r, who, "coop.queue.leave", struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `DELETE FROM coop_queues WHERE character_id=$1`, c.ID); err != nil {
			return nil, err
		}
		return map[string]any{"status": "cancelled"}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) readCoopDropsTx(ctx context.Context, tx pgx.Tx, charID string, includeClaimed bool) ([]coopDropPayload, error) {
	query := `SELECT d.id::text,d.instance_id::text,ci.dungeon_id,d.source_stage,d.item_template_id,d.quantity,d.gold_amount,d.experience_amount,d.is_first_clear,d.is_mentor_bonus,d.claimed_at,d.expires_at
		FROM coop_instance_drops d JOIN coop_instances ci ON ci.id=d.instance_id WHERE d.character_id=$1`
	if !includeClaimed {
		query += ` AND d.claimed_at IS NULL AND d.expires_at > now()`
	}
	query += ` ORDER BY d.created_at DESC LIMIT 50`
	rows, err := tx.Query(ctx, query, charID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []coopDropPayload{}
	for rows.Next() {
		var p coopDropPayload
		if err = rows.Scan(&p.ID, &p.InstanceID, &p.DungeonID, &p.SourceStage, &p.ItemID, &p.Quantity, &p.Gold, &p.Experience, &p.FirstClear, &p.MentorBonus, &p.ClaimedAt, &p.ExpiresAt); err != nil {
			return nil, err
		}
		if s.cfg.Rules.Journey != nil {
			p.ItemName = s.cfg.Rules.Journey.Items[p.ItemID].Name
		}
		if p.ItemName == "" {
			p.ItemName = p.ItemID
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (s *Server) listCoopDrops(w http.ResponseWriter, r *http.Request, who identity) {
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	drops, err := s.readCoopDropsTx(r.Context(), tx, c.ID, true)
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{"drops": drops})
}

func (s *Server) claimCoopDrop(w http.ResponseWriter, r *http.Request, who identity) {
	dropID := r.PathValue("id")
	if !validID(dropID) {
		s.fail(w, bad("invalid_drop_id", "战利品标识无效"))
		return
	}
	data, err := s.command(r, who, "coop.drop.claim:"+dropID, struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		_, journey, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		var charID, itemID string
		var qty int
		var gold, exp int64
		var claimedAt *time.Time
		var expiresAt time.Time
		err = tx.QueryRow(ctx, `SELECT character_id::text,item_template_id,quantity,gold_amount,experience_amount,claimed_at,expires_at FROM coop_instance_drops WHERE id=$1 FOR UPDATE`, dropID).
			Scan(&charID, &itemID, &qty, &gold, &exp, &claimedAt, &expiresAt)
		if errors.Is(err, pgx.ErrNoRows) || charID != c.ID {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if claimedAt != nil || !expiresAt.After(time.Now()) {
			return nil, errCoopDropClaimed
		}
		if journey.Items[itemID].Tradeable {
			if _, err = grantCustomPackItemTx(ctx, tx, c.ID, "coop_drop:"+dropID, journey.PackSlots, itemID, qty, false, []byte(`{"origin":"coop_repeat"}`)); err != nil {
				return nil, err
			}
		} else if err = grantPackItems(ctx, tx, c.ID, "coop_drop:"+dropID, journey.PackSlots, []itemGrant{{itemID, qty}}); err != nil {
			return nil, err
		}
		var newGold int64
		if err = tx.QueryRow(ctx, `UPDATE wallets SET gold=gold+$2,version=version+1,updated_at=now() WHERE character_id=$1 RETURNING gold`, c.ID, gold).Scan(&newGold); err != nil {
			return nil, err
		}
		if gold > 0 {
			if _, err = tx.Exec(ctx, `INSERT INTO wallet_ledger(id,character_id,transaction_id,currency,delta,balance_after,reason) VALUES($1,$2,$3,'gold',$4,$5,'coop_drop')`,
				newID(), c.ID, "coop_drop:"+dropID, gold, newGold); err != nil {
				return nil, err
			}
		}
		if exp > 0 {
			if _, err = tx.Exec(ctx, `UPDATE characters SET experience=experience+$1,version=version+1,updated_at=now() WHERE id=$2`, exp, c.ID); err != nil {
				return nil, err
			}
		}
		if _, err = tx.Exec(ctx, `UPDATE coop_instance_drops SET claimed_at=now(),request_id=$2 WHERE id=$1`, dropID, r.Header.Get("Idempotency-Key")); err != nil {
			return nil, err
		}
		drops, err := s.readCoopDropsTx(ctx, tx, c.ID, false)
		if err != nil {
			return nil, err
		}
		return map[string]any{"claimed_drop_id": dropID, "gold": newGold, "granted_item": itemID, "quantity": qty, "unclaimed_drops": drops}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) buildCoopViewTx(ctx context.Context, tx pgx.Tx, rules *CoopRules, journey *JourneyRules, instID, viewerID string) (map[string]any, error) {
	var dungeonID, difficulty, goal, leaderID, status, battleStatus, battleResult string
	var stageIdx, checkpointIdx, memberCount, battleTick, confirmedSeq int
	var battleIDPtr *string
	var roomRaw, scaleRaw, snapRaw []byte
	var version int64
	err := tx.QueryRow(ctx, `SELECT dungeon_id,difficulty,goal,leader_character_id::text,status,stage_index,checkpoint_stage,room_state,battle_id::text,battle_status,battle_result,battle_snapshot,battle_tick,battle_confirmed_seq,member_count,scale_snapshot,version
		FROM coop_instances WHERE id=$1`, instID).
		Scan(&dungeonID, &difficulty, &goal, &leaderID, &status, &stageIdx, &checkpointIdx, &roomRaw, &battleIDPtr, &battleStatus, &battleResult, &snapRaw, &battleTick, &confirmedSeq, &memberCount, &scaleRaw, &version)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, errCoopInstance
	}
	if err != nil {
		return nil, err
	}
	var roomState, scaleSnap map[string]any
	_ = json.Unmarshal(roomRaw, &roomState)
	_ = json.Unmarshal(scaleRaw, &scaleSnap)
	var battleSnap any
	if len(snapRaw) > 0 {
		_ = json.Unmarshal(snapRaw, &battleSnap)
	}
	rows, err := tx.Query(ctx, `SELECT character_id::text,character_name,role_id,character_level,synced_level,is_mentor,ready,status,mechanics_done,stages_participated,damage_dealt,healing_done,rescues_done,afk_seconds,retreat_vote,last_seen_at
		FROM coop_instance_members WHERE instance_id=$1 ORDER BY joined_at`, instID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	members := []coopMemberPayload{}
	viewerIsMember := false
	for rows.Next() {
		var m coopMemberPayload
		var lastSeen time.Time
		if err = rows.Scan(&m.CharacterID, &m.Nickname, &m.RoleID, &m.Level, &m.SyncedLevel, &m.IsMentor, &m.Ready, &m.Status, &m.MechanicsDone, &m.StagesParticipated, &m.DamageDealt, &m.HealingDone, &m.RescuesDone, &m.AFKSeconds, &m.RetreatVote, &lastSeen); err != nil {
			return nil, err
		}
		if m.Status == "disconnected" || (m.Status == "active" && time.Since(lastSeen) >= time.Duration(rules.AFKWarnSeconds)*time.Second) {
			m.AFKWarn = m.AFKSeconds >= rules.AFKWarnSeconds || time.Since(lastSeen) >= time.Duration(rules.AFKWarnSeconds)*time.Second
		}
		if m.CharacterID == viewerID {
			viewerIsMember = true
		}
		members = append(members, m)
	}
	if err = rows.Err(); err != nil {
		return nil, err
	}
	if !viewerIsMember {
		return nil, errCoopInstance
	}
	d := rules.Dungeons[dungeonID]
	var currentStage any
	if stageIdx < len(d.Stages) {
		currentStage = d.Stages[stageIdx]
	}
	var battleID string
	if battleIDPtr != nil {
		battleID = *battleIDPtr
	}
	drops, err := s.readCoopDropsTx(ctx, tx, viewerID, true)
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"id":                 instID,
		"dungeon_id":         dungeonID,
		"dungeon_name":       d.Name,
		"difficulty":         difficulty,
		"goal":               goal,
		"leader_id":          leaderID,
		"status":             status,
		"stage_index":        stageIdx,
		"stage_total":        len(d.Stages),
		"checkpoint_stage":   checkpointIdx,
		"current_stage":      currentStage,
		"room_state":         roomState,
		"member_count":       memberCount,
		"scale_snapshot":     scaleSnap,
		"members":            members,
		"battle_id":          battleID,
		"battle_status":        battleStatus,
		"battle_result":        battleResult,
		"battle_tick":          battleTick,
		"battle_confirmed_seq": confirmedSeq,
		"battle_snapshot":      battleSnap,
		"version":            version,
		"drops":              drops,
	}, nil
}

func (s *Server) getCoopInstance(w http.ResponseWriter, r *http.Request, who identity) {
	instID := r.PathValue("id")
	if !validID(instID) {
		s.fail(w, errCoopInstance)
		return
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	rules, journey, err := s.requireCoop(tx)
	if err != nil {
		s.fail(w, err)
		return
	}
	// Reconnect within 90s restores 'disconnected' member safely to 'active'.
	_, _ = tx.Exec(ctxOrBg(r.Context()), `UPDATE coop_instance_members SET status=CASE WHEN status='disconnected' THEN 'active' ELSE status END,disconnected_at=NULL,last_seen_at=now() WHERE instance_id=$1 AND character_id=$2 AND status IN ('ready','active','disconnected')`, instID, c.ID)
	if err = s.syncCoopBattleIfActiveTx(r.Context(), tx, rules, journey, instID, 0); err != nil {
		s.fail(w, err)
		return
	}
	view, err := s.buildCoopViewTx(r.Context(), tx, rules, journey, instID, c.ID)
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

func ctxOrBg(ctx context.Context) context.Context {
	if ctx != nil {
		return ctx
	}
	return context.Background()
}

func (s *Server) setCoopReady(w http.ResponseWriter, r *http.Request, who identity) {
	instID := r.PathValue("id")
	if !validID(instID) {
		s.fail(w, errCoopInstance)
		return
	}
	var body struct {
		Ready bool `json:"ready"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "coop.ready:"+instID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules, journey, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		var status string
		if err = tx.QueryRow(ctx, `SELECT status FROM coop_instances WHERE id=$1 FOR UPDATE`, instID).Scan(&status); err != nil {
			return nil, errCoopInstance
		}
		if status != "ready" && status != "active" {
			return nil, errCoopInstance
		}
		tag, err := tx.Exec(ctx, `UPDATE coop_instance_members SET ready=$3,last_seen_at=now() WHERE instance_id=$1 AND character_id=$2 AND status IN ('ready','active')`, instID, c.ID, body.Ready)
		if err != nil || tag.RowsAffected() == 0 {
			return nil, errCoopInstance
		}
		var unready int
		if err = tx.QueryRow(ctx, `SELECT count(*) FROM coop_instance_members WHERE instance_id=$1 AND status IN ('ready','active','disconnected') AND ready=false`, instID).Scan(&unready); err != nil {
			return nil, err
		}
		if status == "ready" && unready == 0 {
			if _, err = tx.Exec(ctx, `UPDATE coop_instances SET status='active',updated_at=now(),version=version+1 WHERE id=$1`, instID); err != nil {
				return nil, err
			}
			if _, err = tx.Exec(ctx, `UPDATE coop_instance_members SET status='active' WHERE instance_id=$1 AND status='ready'`, instID); err != nil {
				return nil, err
			}
		}
		return s.buildCoopViewTx(ctx, tx, rules, journey, instID, c.ID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) interactCoopStage(w http.ResponseWriter, r *http.Request, who identity) {
	instID := r.PathValue("id")
	if !validID(instID) {
		s.fail(w, errCoopInstance)
		return
	}
	var body struct {
		MechanicID string `json:"mechanic_id"`
		Choice     string `json:"choice"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "coop.interact:"+instID+":"+body.MechanicID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules, journey, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		var dungeonID, status string
		var stageIdx int
		var roomRaw []byte
		err = tx.QueryRow(ctx, `SELECT dungeon_id,status,stage_index,room_state FROM coop_instances WHERE id=$1 FOR UPDATE`, instID).Scan(&dungeonID, &status, &stageIdx, &roomRaw)
		if err != nil {
			return nil, errCoopInstance
		}
		if status != "active" {
			return nil, errCoopNotReady
		}
		var mStatus string
		if err = tx.QueryRow(ctx, `SELECT status FROM coop_instance_members WHERE instance_id=$1 AND character_id=$2`, instID, c.ID).Scan(&mStatus); err != nil || (mStatus != "active" && mStatus != "ready") {
			return nil, errCoopInstance
		}
		d := rules.Dungeons[dungeonID]
		if stageIdx >= len(d.Stages) {
			return nil, bad("stage_complete", "当前副本阶段已完成")
		}
		roomState := map[string]any{}
		_ = json.Unmarshal(roomRaw, &roomState)
		solvedAny, _ := roomState["solved_mechanics"].(map[string]any)
		if solvedAny == nil {
			solvedAny = map[string]any{}
		}
		feedback := ""
		correct := false
		switch dungeonID {
		case "stele_cavern":
			switch body.MechanicID {
			case "echo_clue":
				solvedAny["echo_clue"] = true
				correct = true
				feedback = "青姨的拓片对照清晰：西碑座引回两声轻响，东碑座缺口朝向碑心。"
			case "west_stele":
				if solvedAny["echo_clue"] != true {
					return nil, bad("mechanic_locked", "请先查看石缝拓片线索")
				}
				if body.Choice == "old" {
					solvedAny["west_stele"] = true
					correct = true
					feedback = "西侧辨声碑座归位，石面传回两声轻响。"
				} else {
					feedback = "拖长的尾音指向深渊，可由任意队友重新校准西侧碑座。"
				}
			case "east_stele":
				if solvedAny["echo_clue"] != true {
					return nil, bad("mechanic_locked", "请先查看石缝拓片线索")
				}
				if body.Choice == "heart" {
					solvedAny["east_stele"] = true
					correct = true
					feedback = "东侧碑座缺口正对碑心，通往中廊的大门开启。"
				} else {
					feedback = "缺口方向偏斜，可继续调整东侧碑座。"
				}
			default:
				return nil, bad("invalid_mechanic", "未知的副本机关")
			}
		case "tidal_gate":
			switch body.MechanicID {
			case "tide_record":
				solvedAny["tide_record"] = true
				correct = true
				feedback = "港务水痕显示：上闸先泄向旧渠，再开栈桥侧闸；右侧货箱可派队友救回。"
			case "upper_sluice":
				if solvedAny["tide_record"] != true {
					return nil, bad("mechanic_locked", "请先核对港务水痕记录")
				}
				if body.Choice == "old" {
					solvedAny["upper_sluice"] = true
					correct = true
					feedback = "旧渠稳稳接住第一股潮水，栈桥闸压下降。"
				} else {
					feedback = "直接开主渠导致水位倒灌，请重调上闸水线。"
				}
			case "bridge_sluice":
				if solvedAny["upper_sluice"] != true {
					return nil, bad("mechanic_locked", "请先调整上闸水线")
				}
				if body.Choice == "bridge" || body.Choice == "cargo" {
					solvedAny["bridge_sluice"] = true
					correct = true
					feedback = "栈桥干路已经打开，前方潮道可以通行。"
				} else {
					return nil, bad("invalid_choice", "无效的闸门选择")
				}
			case "cargo_rescue":
				if solvedAny["upper_sluice"] != true {
					return nil, bad("mechanic_locked", "请先泄水后再去救堤边货箱")
				}
				solvedAny["cargo_rescue"] = true
				roomState["bonus_cargo"] = true
				correct = true
				feedback = "成功抢回堤边货箱补给，结算时全队可额外分得补给银币。"
			default:
				return nil, bad("invalid_mechanic", "未知的副本机关")
			}
		}
		roomState["solved_mechanics"] = solvedAny
		if feedback != "" {
			msgs, _ := roomState["stage_messages"].([]any)
			msgs = append(msgs, feedback)
			if len(msgs) > 10 {
				msgs = msgs[len(msgs)-10:]
			}
			roomState["stage_messages"] = msgs
		}
		if correct {
			if _, err = tx.Exec(ctx, `UPDATE coop_instance_members SET mechanics_done=mechanics_done+1,stages_participated=stages_participated+1,last_seen_at=now() WHERE instance_id=$1 AND character_id=$2`, instID, c.ID); err != nil {
				return nil, err
			}
		}
		newStageIdx := stageIdx
		newCheckpoint := stageIdx
		st := d.Stages[stageIdx]
		if st.Kind == "puzzle" {
			allDone := true
			for _, req := range st.Mechanics {
				if solvedAny[req] != true {
					allDone = false
					break
				}
			}
			if allDone && stageIdx+1 < len(d.Stages) {
				newStageIdx = stageIdx + 1
				newCheckpoint = newStageIdx
			}
		}
		roomBytes, _ := json.Marshal(roomState)
		if _, err = tx.Exec(ctx, `UPDATE coop_instances SET stage_index=$2,checkpoint_stage=GREATEST(checkpoint_stage,$3),room_state=$4,updated_at=now(),version=version+1 WHERE id=$1`,
			instID, newStageIdx, newCheckpoint, roomBytes); err != nil {
			return nil, err
		}
		view, err := s.buildCoopViewTx(ctx, tx, rules, journey, instID, c.ID)
		if err != nil {
			return nil, err
		}
		view["mechanic_feedback"] = feedback
		view["mechanic_accepted"] = correct
		return view, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func randomSeed63() int64 {
	var buf [8]byte
	_, _ = rand.Read(buf[:])
	v := int64(binary.BigEndian.Uint64(buf[:]) & 0x1fffffffffffff)
	if v <= 0 {
		return 1001
	}
	return v
}

func (s *Server) coopMembersForBattleTx(ctx context.Context, tx pgx.Tx, instID string, journey *JourneyRules) ([]map[string]any, int, error) {
	rows, err := tx.Query(ctx, `SELECT m.character_id::text,m.character_name,m.role_id,m.synced_level
		FROM coop_instance_members m WHERE m.instance_id=$1 AND m.status IN ('ready','active','disconnected') ORDER BY m.joined_at`, instID)
	if err != nil {
		return nil, 0, err
	}
	type rowM struct {
		cid, name, role string
		level           int
	}
	list := []rowM{}
	for rows.Next() {
		var r rowM
		if err = rows.Scan(&r.cid, &r.name, &r.role, &r.level); err != nil {
			rows.Close()
			return nil, 0, err
		}
		list = append(list, r)
	}
	rows.Close()
	if len(list) == 0 {
		return nil, 0, errCoopInstance
	}
	out := make([]map[string]any, 0, len(list))
	for _, r := range list {
		lo, err := loadoutForBattle(ctx, tx, Character{ID: r.cid, RoleID: r.role}, journey)
		if err != nil {
			return nil, 0, err
		}
		out = append(out, map[string]any{
			"character_id": r.cid,
			"name":         r.name,
			"role_id":      r.role,
			"level":        r.level,
			"loadout":      lo,
		})
	}
	return out, len(list), nil
}

func (s *Server) startCoopBattle(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	instID := r.PathValue("id")
	if !validID(instID) {
		s.fail(w, errCoopInstance)
		return
	}
	data, err := s.command(r, who, "coop.battle.start:"+instID, struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules, journey, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		var dungeonID, difficulty, status, battleStatus string
		var stageIdx int
		err = tx.QueryRow(ctx, `SELECT dungeon_id,difficulty,status,stage_index,battle_status FROM coop_instances WHERE id=$1 FOR UPDATE`, instID).
			Scan(&dungeonID, &difficulty, &status, &stageIdx, &battleStatus)
		if err != nil {
			return nil, errCoopInstance
		}
		if status != "active" {
			return nil, errCoopNotReady
		}
		if battleStatus == "active" {
			return s.buildCoopViewTx(ctx, tx, rules, journey, instID, c.ID)
		}
		d := rules.Dungeons[dungeonID]
		if stageIdx >= len(d.Stages) {
			return nil, bad("stage_complete", "当前关卡已全部完成")
		}
		st := d.Stages[stageIdx]
		if st.Kind != "battle" && st.Kind != "boss" {
			return nil, bad("puzzle_stage_incomplete", "请先完成当前房间机关后再开战")
		}
		members, count, err := s.coopMembersForBattleTx(ctx, tx, instID, journey)
		if err != nil {
			return nil, err
		}
		scale := rules.scalingFor(count, difficulty)
		scaleMap := map[string]any{
			"hp_mult":        scale.HPMult,
			"atk_mult":       scale.AtkMult,
			"def_mult":       scale.DefMult,
			"extra_adds":     scale.ExtraAdds,
			"add_monster_id": st.AddMonsterID,
			"gold_bonus_pct": scale.GoldBonusPct,
		}
		battleID := newID()
		seed := randomSeed63()
		var response struct {
			State json.RawMessage `json:"state"`
			Epoch string          `json:"epoch"`
		}
		if err = s.cfg.Authority.Call(ctx, "battle.sync", map[string]any{
			"battle_id":           battleID,
			"monster_id":          st.MonsterID,
			"seed":                seed,
			"members":             members,
			"downed_window_ticks": rules.DownedWindowTicks,
			"coop_scaling":        scaleMap,
			"inputs":              []any{},
			"target_tick":         0,
		}, &response); err != nil {
			return nil, errAuthority
		}
		scaleBytes, _ := json.Marshal(scaleMap)
		if _, err = tx.Exec(ctx, `UPDATE coop_instances SET member_count=$2,scale_snapshot=$3,battle_id=$4,battle_seed=$5,battle_status='active',battle_result='',battle_snapshot=$6,battle_inputs='[]'::jsonb,battle_tick=0,battle_confirmed_seq=0,authority_epoch=$7,updated_at=now(),version=version+1 WHERE id=$1`,
			instID, count, scaleBytes, battleID, seed, response.State, response.Epoch); err != nil {
			return nil, err
		}
		return s.buildCoopViewTx(ctx, tx, rules, journey, instID, c.ID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

type coopBattleInput struct {
	Sequence    int            `json:"sequence"`
	Tick        int            `json:"tick"`
	Action      map[string]any `json:"action"`
	Accepted    *bool          `json:"accepted,omitempty"`
	Reason      string         `json:"reason,omitempty"`
	AppliedTick *int           `json:"applied_tick,omitempty"`
}

func (s *Server) coopBattleCommand(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	instID := r.PathValue("id")
	if !validID(instID) {
		s.fail(w, errCoopInstance)
		return
	}
	var body struct {
		Sequence  int    `json:"sequence"`
		Action    string `json:"action"`
		SkillID   string `json:"skill_id"`
		TargetUID int    `json:"target_uid"`
		Advance   int    `json:"advance_ticks"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.Sequence < 1 || body.Sequence > 6000 {
		s.fail(w, bad("invalid_sequence", "战斗指令序号无效"))
		return
	}
	data, err := s.command(r, who, "coop.battle.cmd:"+instID+":"+strconv.Itoa(body.Sequence), body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules, journey, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		var dungeonID, battleID, battleStatus string
		var stageIdx, battleTick, confirmedSeq int
		var seed int64
		var inputsRaw, scaleRaw []byte
		err = tx.QueryRow(ctx, `SELECT dungeon_id,coalesce(battle_id::text,''),battle_status,stage_index,battle_seed,battle_tick,battle_confirmed_seq,battle_inputs,scale_snapshot
			FROM coop_instances WHERE id=$1 FOR UPDATE`, instID).
			Scan(&dungeonID, &battleID, &battleStatus, &stageIdx, &seed, &battleTick, &confirmedSeq, &inputsRaw, &scaleRaw)
		if err != nil || battleID == "" {
			return nil, errCoopInstance
		}
		if battleStatus != "active" {
			return nil, &apiError{409, "battle_not_active", "当前没有进行中的合作战斗"}
		}
		var mStatus string
		if err = tx.QueryRow(ctx, `SELECT status FROM coop_instance_members WHERE instance_id=$1 AND character_id=$2`, instID, c.ID).Scan(&mStatus); err != nil || mStatus != "active" {
			return nil, errCoopInstance
		}
		if body.Action != "attack" && body.Action != "skill" && body.Action != "potion" && body.Action != "rescue" && body.Action != "focus" && body.Action != "safe_defend" {
			return nil, bad("invalid_action", "无效的合作战斗动作")
		}
		if body.Sequence != confirmedSeq+1 {
			return nil, bad("sequence_out_of_order", "战斗指令序号不连续")
		}
		var inputs []coopBattleInput
		_ = json.Unmarshal(inputsRaw, &inputs)
		var scaleMap map[string]any
		_ = json.Unmarshal(scaleRaw, &scaleMap)
		members, _, err := s.coopMembersForBattleTx(ctx, tx, instID, journey)
		if err != nil {
			return nil, err
		}
		st := rules.Dungeons[dungeonID].Stages[stageIdx]
		adv := body.Advance
		if adv < 0 {
			adv = 0
		} else if adv > 900 {
			adv = 900
		}
		targetTick := battleTick + adv
		actionObj := map[string]any{
			"character_id": c.ID,
			"action":       body.Action,
		}
		if body.SkillID != "" {
			actionObj["skill_id"] = body.SkillID
		}
		if body.TargetUID > 0 {
			actionObj["target_uid"] = body.TargetUID
		}
		inputs = append(inputs, coopBattleInput{Sequence: body.Sequence, Tick: targetTick, Action: actionObj})
		var response struct {
			State  json.RawMessage   `json:"state"`
			Epoch  string            `json:"epoch"`
			Inputs []coopBattleInput `json:"inputs"`
		}
		if err = s.cfg.Authority.Call(ctx, "battle.sync", map[string]any{
			"battle_id":           battleID,
			"monster_id":          st.MonsterID,
			"seed":                seed,
			"members":             members,
			"downed_window_ticks": rules.DownedWindowTicks,
			"coop_scaling":        scaleMap,
			"inputs":              inputs,
			"target_tick":         targetTick,
		}, &response); err != nil {
			return nil, errAuthority
		}
		var accepted bool
		if len(response.Inputs) >= body.Sequence && response.Inputs[body.Sequence-1].Accepted != nil {
			accepted = *response.Inputs[body.Sequence-1].Accepted
		}
		if accepted && (body.Action == "potion" || body.Action == "rescue") {
			if err = consumeBattlePotion(ctx, tx, persistedBattle{ID: battleID, CharacterID: c.ID, Loadout: battleLoadout{PotionTemplate: journey.PotionTemplate}}, body.Sequence); err != nil {
				return nil, err
			}
		}
		if _, err = tx.Exec(ctx, `UPDATE coop_instance_members SET stages_participated=GREATEST(stages_participated,1),last_seen_at=now(),rescues_done=rescues_done+$3 WHERE instance_id=$1 AND character_id=$2`,
			instID, c.ID, boolToInt(accepted && body.Action == "rescue")); err != nil {
			return nil, err
		}
		newInputsJSON, _ := json.Marshal(response.Inputs)
		if err = s.persistAndSettleCoopStateTx(ctx, tx, rules, journey, instID, dungeonID, stageIdx, response.State, newInputsJSON, response.Epoch, len(response.Inputs)); err != nil {
			return nil, err
		}
		return s.buildCoopViewTx(ctx, tx, rules, journey, instID, c.ID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

func (s *Server) syncCoopBattleIfActiveTx(ctx context.Context, tx pgx.Tx, rules *CoopRules, journey *JourneyRules, instID string, advanceTicks int) error {
	var dungeonID, battleID, battleStatus string
	var stageIdx, battleTick, confirmedSeq int
	var seed int64
	var inputsRaw, scaleRaw []byte
	err := tx.QueryRow(ctx, `SELECT dungeon_id,coalesce(battle_id::text,''),battle_status,stage_index,battle_seed,battle_tick,battle_confirmed_seq,battle_inputs,scale_snapshot
		FROM coop_instances WHERE id=$1 FOR UPDATE`, instID).
		Scan(&dungeonID, &battleID, &battleStatus, &stageIdx, &seed, &battleTick, &confirmedSeq, &inputsRaw, &scaleRaw)
	if err != nil || battleStatus != "active" || battleID == "" {
		return nil
	}
	if advanceTicks <= 0 {
		return nil
	}
	if advanceTicks > 900 {
		advanceTicks = 900
	}
	var inputs []coopBattleInput
	_ = json.Unmarshal(inputsRaw, &inputs)
	var scaleMap map[string]any
	_ = json.Unmarshal(scaleRaw, &scaleMap)
	members, _, err := s.coopMembersForBattleTx(ctx, tx, instID, journey)
	if err != nil {
		return err
	}
	st := rules.Dungeons[dungeonID].Stages[stageIdx]
	targetTick := battleTick + advanceTicks
	var response struct {
		State  json.RawMessage   `json:"state"`
		Epoch  string            `json:"epoch"`
		Inputs []coopBattleInput `json:"inputs"`
	}
	if err = s.cfg.Authority.Call(ctx, "battle.sync", map[string]any{
		"battle_id":           battleID,
		"monster_id":          st.MonsterID,
		"seed":                seed,
		"members":             members,
		"downed_window_ticks": rules.DownedWindowTicks,
		"coop_scaling":        scaleMap,
		"inputs":              inputs,
		"target_tick":         targetTick,
	}, &response); err != nil {
		return errAuthority
	}
	newInputsJSON, _ := json.Marshal(response.Inputs)
	return s.persistAndSettleCoopStateTx(ctx, tx, rules, journey, instID, dungeonID, stageIdx, response.State, newInputsJSON, response.Epoch, len(response.Inputs))
}

func (s *Server) tickCoopBattle(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	instID := r.PathValue("id")
	if !validID(instID) {
		s.fail(w, errCoopInstance)
		return
	}
	var body struct {
		AdvanceTicks int `json:"advance_ticks"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.AdvanceTicks < 1 || body.AdvanceTicks > 900 {
		body.AdvanceTicks = 30
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	rules, journey, err := s.requireCoop(tx)
	if err != nil {
		s.fail(w, err)
		return
	}
	if err = s.syncCoopBattleIfActiveTx(r.Context(), tx, rules, journey, instID, body.AdvanceTicks); err != nil {
		s.fail(w, err)
		return
	}
	view, err := s.buildCoopViewTx(r.Context(), tx, rules, journey, instID, c.ID)
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

func (s *Server) persistAndSettleCoopStateTx(ctx context.Context, tx pgx.Tx, rules *CoopRules, journey *JourneyRules, instID, dungeonID string, stageIdx int, stateRaw, inputsRaw []byte, epoch string, confirmedSeq int) error {
	var parsed struct {
		Tick        int    `json:"tick"`
		Finished    bool   `json:"finished"`
		Result      string `json:"result"`
		CoopMembers map[string]struct {
			DamageDealt int64 `json:"damage_dealt"`
			HealingDone int64 `json:"healing_done"`
			Rescues     int   `json:"rescues"`
			Actions     int   `json:"actions"`
		} `json:"coop_members"`
	}
	if err := json.Unmarshal(stateRaw, &parsed); err != nil {
		return errAuthority
	}
	for cid, stats := range parsed.CoopMembers {
		if _, err := tx.Exec(ctx, `UPDATE coop_instance_members SET damage_dealt=GREATEST(damage_dealt,$3),healing_done=GREATEST(healing_done,$4),rescues_done=GREATEST(rescues_done,$5),stages_participated=GREATEST(stages_participated, CASE WHEN $6>0 OR $3>0 OR $4>0 OR $5>0 THEN 1 ELSE 0 END) WHERE instance_id=$1 AND character_id=$2`,
			instID, cid, stats.DamageDealt, stats.HealingDone, stats.Rescues, stats.Actions); err != nil {
			return err
		}
	}
	battleStatus := "active"
	newStageIdx := stageIdx
	newCheckpoint := stageIdx
	instStatus := "active"
	d := rules.Dungeons[dungeonID]
	if parsed.Finished {
		switch parsed.Result {
		case "victory":
			if stageIdx+1 < len(d.Stages) {
				battleStatus = "idle"
				newStageIdx = stageIdx + 1
				newCheckpoint = newStageIdx
			} else {
				battleStatus = "finished"
				instStatus = "completed"
				if err := s.settleCoopDropsTx(ctx, tx, rules, instID, dungeonID); err != nil {
					return err
				}
			}
		case "defeat", "draw":
			battleStatus = "idle"
		case "flee":
			battleStatus = "retreated"
		}
	}
	if _, err := tx.Exec(ctx, `UPDATE coop_instances SET status=$2,stage_index=$3,checkpoint_stage=GREATEST(checkpoint_stage,$4),battle_status=$5,battle_result=$6,battle_snapshot=$7,battle_inputs=$8,battle_tick=$9,battle_confirmed_seq=$10,authority_epoch=$11,completed_at=CASE WHEN $2='completed' THEN now() ELSE completed_at END,updated_at=now(),version=version+1 WHERE id=$1`,
		instID, instStatus, newStageIdx, newCheckpoint, battleStatus, parsed.Result, stateRaw, inputsRaw, parsed.Tick, confirmedSeq, epoch); err != nil {
		return err
	}
	if instStatus == "completed" {
		_, _ = tx.Exec(ctx, `UPDATE coop_instance_members SET status=CASE WHEN status IN ('active','disconnected') THEN 'completed' ELSE status END WHERE instance_id=$1`, instID)
	}
	return nil
}

func (s *Server) settleCoopDropsTx(ctx context.Context, tx pgx.Tx, rules *CoopRules, instID, dungeonID string) error {
	d := rules.Dungeons[dungeonID]
	var roomRaw []byte
	var memberCount int
	var difficulty string
	if err := tx.QueryRow(ctx, `SELECT room_state,member_count,difficulty FROM coop_instances WHERE id=$1`, instID).Scan(&roomRaw, &memberCount, &difficulty); err != nil {
		return err
	}
	var roomState map[string]any
	_ = json.Unmarshal(roomRaw, &roomState)
	bonusCargo := roomState["bonus_cargo"] == true
	scale := rules.scalingFor(memberCount, difficulty)
	rows, err := tx.Query(ctx, `SELECT character_id::text,account_id::text,is_mentor,mechanics_done,stages_participated,damage_dealt,healing_done,rescues_done
		FROM coop_instance_members WHERE instance_id=$1 AND status IN ('active','disconnected')`, instID)
	if err != nil {
		return err
	}
	type mDrop struct {
		cid, aid string
		mentor   bool
		eligible bool
	}
	eligible := []mDrop{}
	for rows.Next() {
		var m mDrop
		var mech, stages, rescues int
		var dmg, heal int64
		if err = rows.Scan(&m.cid, &m.aid, &m.mentor, &mech, &stages, &dmg, &heal, &rescues); err != nil {
			rows.Close()
			return err
		}
		m.eligible = mech > 0 || stages > 0 || dmg > 0 || heal > 0 || rescues > 0
		if m.eligible {
			eligible = append(eligible, m)
		}
	}
	rows.Close()
	expires := time.Now().Add(time.Duration(rules.DropExpiryHours) * time.Hour)
	for _, m := range eligible {
		var alreadyCleared bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM coop_instance_members m JOIN coop_instances ci ON ci.id=m.instance_id WHERE m.character_id=$1 AND ci.dungeon_id=$2 AND ci.id<>$3 AND ci.status='completed' AND m.status='completed')`, m.cid, dungeonID, instID).Scan(&alreadyCleared); err != nil {
			return err
		}
		var bundle CoopRewardBundle
		isFirst := false
		isMentorBonus := false
		switch {
		case m.mentor && alreadyCleared:
			bundle = d.Rewards.Mentor
			isMentorBonus = true
		case !alreadyCleared:
			bundle = d.Rewards.FirstClear
			isFirst = true
		default:
			bundle = d.Rewards.Repeat
		}
		gold := bundle.Gold + (bundle.Gold*int64(scale.GoldBonusPct))/100
		if bonusCargo {
			gold += 25
		}
		if _, err = tx.Exec(ctx, `INSERT INTO coop_instance_drops(id,instance_id,character_id,account_id,source_stage,item_template_id,quantity,gold_amount,experience_amount,is_first_clear,is_mentor_bonus,expires_at)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) ON CONFLICT (instance_id,character_id,source_stage,item_template_id) DO NOTHING`,
			newID(), instID, m.cid, m.aid, d.Stages[len(d.Stages)-1].ID, bundle.ItemID, bundle.Quantity, gold, bundle.Experience, isFirst, isMentorBonus, expires); err != nil {
			return err
		}
	}
	return nil
}

func (s *Server) disconnectCoopInstance(w http.ResponseWriter, r *http.Request, who identity) {
	instID := r.PathValue("id")
	if !validID(instID) {
		s.fail(w, errCoopInstance)
		return
	}
	data, err := s.command(r, who, "coop.disconnect:"+instID, struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules, journey, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE coop_instance_members SET status='disconnected',disconnected_at=now(),afk_seconds=$3 WHERE instance_id=$1 AND character_id=$2 AND status IN ('ready','active')`,
			instID, c.ID, rules.AFKWarnSeconds); err != nil {
			return nil, err
		}
		// Place disconnected member into defensive safe guard if battle is active.
		var battleID, battleStatus, dungeonID string
		var stageIdx, battleTick int
		var seed int64
		var inputsRaw, scaleRaw []byte
		err = tx.QueryRow(ctx, `SELECT coalesce(battle_id::text,''),battle_status,dungeon_id,stage_index,battle_seed,battle_tick,battle_inputs,scale_snapshot FROM coop_instances WHERE id=$1 FOR UPDATE`, instID).
			Scan(&battleID, &battleStatus, &dungeonID, &stageIdx, &seed, &battleTick, &inputsRaw, &scaleRaw)
		if err == nil && battleStatus == "active" && battleID != "" {
			var inputs []coopBattleInput
			_ = json.Unmarshal(inputsRaw, &inputs)
			var scaleMap map[string]any
			_ = json.Unmarshal(scaleRaw, &scaleMap)
			members, _, _ := s.coopMembersForBattleTx(ctx, tx, instID, journey)
			seq := len(inputs) + 1
			inputs = append(inputs, coopBattleInput{Sequence: seq, Tick: battleTick, Action: map[string]any{"character_id": c.ID, "action": "safe_defend", "enabled": true}})
			var response struct {
				State  json.RawMessage   `json:"state"`
				Epoch  string            `json:"epoch"`
				Inputs []coopBattleInput `json:"inputs"`
			}
			if s.cfg.Authority.Call(ctx, "battle.sync", map[string]any{
				"battle_id": battleID, "monster_id": rules.Dungeons[dungeonID].Stages[stageIdx].MonsterID,
				"seed": seed, "members": members, "downed_window_ticks": rules.DownedWindowTicks,
				"coop_scaling": scaleMap, "inputs": inputs, "target_tick": battleTick,
			}, &response) == nil {
				newInputs, _ := json.Marshal(response.Inputs)
				_ = s.persistAndSettleCoopStateTx(ctx, tx, rules, journey, instID, dungeonID, stageIdx, response.State, newInputs, response.Epoch, len(response.Inputs))
			}
		}
		return s.buildCoopViewTx(ctx, tx, rules, journey, instID, c.ID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) leaveCoopInstance(w http.ResponseWriter, r *http.Request, who identity) {
	instID := r.PathValue("id")
	if !validID(instID) {
		s.fail(w, errCoopInstance)
		return
	}
	data, err := s.command(r, who, "coop.leave:"+instID, struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules, _, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		var leaderID, difficulty string
		err = tx.QueryRow(ctx, `SELECT leader_character_id::text,difficulty FROM coop_instances WHERE id=$1 FOR UPDATE`, instID).Scan(&leaderID, &difficulty)
		if err != nil {
			return nil, errCoopInstance
		}
		if _, err = tx.Exec(ctx, `UPDATE coop_instance_members SET status='left',ready=false WHERE instance_id=$1 AND character_id=$2`, instID, c.ID); err != nil {
			return nil, err
		}
		var remainingIDs []string
		rows, err := tx.Query(ctx, `SELECT character_id::text FROM coop_instance_members WHERE instance_id=$1 AND status IN ('ready','active','disconnected') ORDER BY joined_at`, instID)
		if err != nil {
			return nil, err
		}
		for rows.Next() {
			var mid string
			if err = rows.Scan(&mid); err != nil {
				rows.Close()
				return nil, err
			}
			remainingIDs = append(remainingIDs, mid)
		}
		rows.Close()
		if len(remainingIDs) == 0 {
			if _, err = tx.Exec(ctx, `UPDATE coop_instances SET status='retreated',battle_status=CASE WHEN battle_status='active' THEN 'retreated' ELSE battle_status END,updated_at=now(),version=version+1 WHERE id=$1`, instID); err != nil {
				return nil, err
			}
			return map[string]any{"id": instID, "status": "retreated", "remaining": 0}, nil
		}
		newLeader := leaderID
		if leaderID == c.ID {
			newLeader = remainingIDs[0]
		}
		scale := rules.scalingFor(len(remainingIDs), difficulty)
		scaleBytes, _ := json.Marshal(scale)
		if _, err = tx.Exec(ctx, `UPDATE coop_instances SET leader_character_id=$2,member_count=$3,scale_snapshot=$4,updated_at=now(),version=version+1 WHERE id=$1`,
			instID, newLeader, len(remainingIDs), scaleBytes); err != nil {
			return nil, err
		}
		return map[string]any{"id": instID, "status": "left", "new_leader_id": newLeader, "remaining": len(remainingIDs)}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) retreatCoopInstance(w http.ResponseWriter, r *http.Request, who identity) {
	instID := r.PathValue("id")
	if !validID(instID) {
		s.fail(w, errCoopInstance)
		return
	}
	var body struct {
		Vote bool `json:"vote"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "coop.retreat:"+instID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		rules, journey, err := s.requireCoop(tx)
		if err != nil {
			return nil, err
		}
		var checkpointStage int
		if err = tx.QueryRow(ctx, `SELECT checkpoint_stage FROM coop_instances WHERE id=$1 FOR UPDATE`, instID).Scan(&checkpointStage); err != nil {
			return nil, errCoopInstance
		}
		if _, err = tx.Exec(ctx, `UPDATE coop_instance_members SET retreat_vote=$3,last_seen_at=now() WHERE instance_id=$1 AND character_id=$2 AND status IN ('ready','active','disconnected')`,
			instID, c.ID, body.Vote); err != nil {
			return nil, err
		}
		var activeCount, voteCount int
		if err = tx.QueryRow(ctx, `SELECT count(*),count(*) FILTER (WHERE retreat_vote) FROM coop_instance_members WHERE instance_id=$1 AND status IN ('ready','active','disconnected')`, instID).
			Scan(&activeCount, &voteCount); err != nil {
			return nil, err
		}
		if activeCount > 0 && voteCount*2 >= activeCount {
			if _, err = tx.Exec(ctx, `UPDATE coop_instances SET status='retreated',stage_index=checkpoint_stage,battle_status='retreated',updated_at=now(),version=version+1 WHERE id=$1`, instID); err != nil {
				return nil, err
			}
		}
		return s.buildCoopViewTx(ctx, tx, rules, journey, instID, c.ID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
