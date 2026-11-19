package online

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

type PvPRules struct {
	SyncedLevel             int                       `json:"synced_level"`
	AoETargetCap            int                       `json:"aoe_target_cap"`
	HealMult                float64                   `json:"heal_mult"`
	TurnTimeoutTicks        int                       `json:"turn_timeout_ticks"`
	DisconnectGraceSeconds  int                       `json:"disconnect_grace_seconds"`
	WeeklyHonorCap          int                       `json:"weekly_honor_cap"`
	RepeatOpponentDailyCap  int                       `json:"repeat_opponent_daily_cap"`
	MaxGearBonusCap         map[string]int            `json:"max_gear_bonus_cap"`
	Modes                   map[string]PvPModeRule    `json:"modes"`
	Tiers                   []PvPTierRule             `json:"tiers"`
	DefaultSeason           PvPDefaultSeason          `json:"default_season"`
	HonorShop               []PvPHonorShopEntry       `json:"honor_shop"`
}

type PvPModeRule struct {
	Label      string `json:"label"`
	TeamSize   int    `json:"team_size"`
	MaxTicks   int    `json:"max_ticks"`
	BaseRating int    `json:"base_rating"`
	KFactor    int    `json:"k_factor"`
	HonorWin   int    `json:"honor_win"`
	HonorLoss  int    `json:"honor_loss"`
	HonorDraw  int    `json:"honor_draw"`
}

type PvPTierRule struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	MinRating   int    `json:"min_rating"`
	RewardHonor int    `json:"reward_honor"`
}

type PvPDefaultSeason struct {
	ID              string                       `json:"id"`
	Name            string                       `json:"name"`
	CosmeticRewards map[string]map[string]string `json:"cosmetic_rewards"`
}

type PvPHonorShopEntry struct {
	ItemID     string `json:"item_id"`
	PriceHonor int    `json:"price_honor"`
	Quantity   int    `json:"quantity"`
	Label      string `json:"label"`
}

var validPvPModes = []string{"1v1", "2v2", "3v3"}

func pvpConflict(code, message string) error {
	return &apiError{409, code, message}
}

func characterAccountIDTx(ctx context.Context, tx pgx.Tx, charID string) (string, error) {
	var acctID string
	err := tx.QueryRow(ctx, `SELECT account_id::text FROM characters WHERE id=$1 AND deleted_at IS NULL`, charID).Scan(&acctID)
	return acctID, err
}

func (p PvPRules) validate(items map[string]JourneyItem) error {
	inv := errors.New("invalid pvp rules")
	if p.SyncedLevel < 1 || p.SyncedLevel > 60 || p.AoETargetCap < 1 || p.AoETargetCap > 4 ||
		p.HealMult <= 0.2 || p.HealMult > 2.0 || p.TurnTimeoutTicks < 30 || p.TurnTimeoutTicks > 3600 ||
		p.DisconnectGraceSeconds < 10 || p.WeeklyHonorCap < 10 || p.RepeatOpponentDailyCap < 1 ||
		p.DefaultSeason.ID == "" || p.DefaultSeason.Name == "" || len(p.Tiers) == 0 {
		return inv
	}
	for i, m := range validPvPModes {
		mr, ok := p.Modes[m]
		if !ok || mr.TeamSize != i+1 || mr.MaxTicks < 300 || mr.MaxTicks > 9000 ||
			mr.BaseRating < 100 || mr.KFactor < 1 || mr.HonorWin < 0 || mr.HonorLoss < 0 || mr.HonorDraw < 0 {
			return inv
		}
	}
	for _, item := range p.HonorShop {
		if _, ok := items[item.ItemID]; !ok || item.PriceHonor <= 0 || item.Quantity <= 0 {
			return inv
		}
	}
	return nil
}

func (p PvPRules) tierFor(rating int) PvPTierRule {
	best := p.Tiers[0]
	for _, t := range p.Tiers {
		if rating >= t.MinRating && t.MinRating >= best.MinRating {
			best = t
		}
	}
	return best
}

func (s *Server) requirePvP() (*PvPRules, *JourneyRules, error) {
	if s.cfg.Authority == nil || s.cfg.Rules.PvP == nil || s.cfg.Rules.Journey == nil {
		return nil, nil, errAuthority
	}
	return s.cfg.Rules.PvP, s.cfg.Rules.Journey, nil
}

func ensureActiveSeasonTx(ctx context.Context, tx pgx.Tx, rules *PvPRules) (string, string, error) {
	var id, name string
	err := tx.QueryRow(ctx, `SELECT id,name FROM pvp_seasons WHERE status='active' ORDER BY started_at DESC LIMIT 1`).Scan(&id, &name)
	if errors.Is(err, pgx.ErrNoRows) {
		snap, _ := json.Marshal(rules.DefaultSeason)
		_, err = tx.Exec(ctx, `INSERT INTO pvp_seasons(id,name,status,rules_snapshot) VALUES($1,$2,'active',$3) ON CONFLICT (id) DO NOTHING`,
			rules.DefaultSeason.ID, rules.DefaultSeason.Name, snap)
		if err != nil {
			return "", "", err
		}
		return rules.DefaultSeason.ID, rules.DefaultSeason.Name, nil
	}
	return id, name, err
}

func ensureRatingRowsTx(ctx context.Context, tx pgx.Tx, rules *PvPRules, charID, seasonID string) error {
	for _, mode := range validPvPModes {
		base := rules.Modes[mode].BaseRating
		tier := rules.tierFor(base).ID
		if _, err := tx.Exec(ctx, `INSERT INTO pvp_ratings(character_id,mode,season_id,rating,peak_rating,tier) VALUES($1,$2,$3,$4,$4,$5) ON CONFLICT (character_id,mode,season_id) DO NOTHING`,
			charID, mode, seasonID, base, tier); err != nil {
			return err
		}
	}
	return nil
}

func currentIsoWeekKey() string {
	y, w := time.Now().UTC().ISOWeek()
	return fmt.Sprintf("%04d-W%02d", y, w)
}

func ensureHonorWalletTx(ctx context.Context, tx pgx.Tx, charID string) (int, int, string, map[string]any, error) {
	weekKey := currentIsoWeekKey()
	if _, err := tx.Exec(ctx, `INSERT INTO pvp_honor_wallets(character_id,week_key) VALUES($1,$2) ON CONFLICT (character_id) DO NOTHING`, charID, weekKey); err != nil {
		return 0, 0, "", nil, err
	}
	var bal, weekly int
	var wk string
	var claimedRaw []byte
	if err := tx.QueryRow(ctx, `SELECT honor_balance,weekly_honor_earned,week_key,claimed_seasons FROM pvp_honor_wallets WHERE character_id=$1 FOR UPDATE`, charID).
		Scan(&bal, &weekly, &wk, &claimedRaw); err != nil {
		return 0, 0, "", nil, err
	}
	if wk != weekKey {
		weekly = 0
		wk = weekKey
		if _, err := tx.Exec(ctx, `UPDATE pvp_honor_wallets SET weekly_honor_earned=0,week_key=$2,updated_at=now() WHERE character_id=$1`, charID, wk); err != nil {
			return 0, 0, "", nil, err
		}
	}
	claimed := map[string]any{}
	_ = json.Unmarshal(claimedRaw, &claimed)
	return bal, weekly, wk, claimed, nil
}

func adjustHonorTx(ctx context.Context, tx pgx.Tx, charID, txID string, delta int, reason string, details map[string]any, weeklyCap int) (int, int, error) {
	var existing int
	if err := tx.QueryRow(ctx, `SELECT balance_after FROM pvp_honor_ledger WHERE character_id=$1 AND transaction_id=$2`, charID, txID).Scan(&existing); err == nil {
		return 0, existing, nil
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return 0, 0, err
	}
	bal, weekly, _, _, err := ensureHonorWalletTx(ctx, tx, charID)
	if err != nil {
		return 0, 0, err
	}
	effectiveDelta := delta
	newWeekly := weekly
	if delta > 0 && weeklyCap > 0 {
		avail := weeklyCap - weekly
		if avail <= 0 {
			effectiveDelta = 0
		} else if effectiveDelta > avail {
			effectiveDelta = avail
		}
		newWeekly += effectiveDelta
	}
	newBal := bal + effectiveDelta
	if newBal < 0 {
		return 0, bal, bad("insufficient_honor", "演武荣誉点不足")
	}
	if _, err := tx.Exec(ctx, `UPDATE pvp_honor_wallets SET honor_balance=$2,weekly_honor_earned=$3,updated_at=now() WHERE character_id=$1`, charID, newBal, newWeekly); err != nil {
		return 0, 0, err
	}
	if details == nil {
		details = map[string]any{}
	}
	detRaw, _ := json.Marshal(details)
	if _, err := tx.Exec(ctx, `INSERT INTO pvp_honor_ledger(character_id,transaction_id,delta,balance_after,reason,details) VALUES($1,$2,$3,$4,$5,$6)`,
		charID, txID, effectiveDelta, newBal, reason, detRaw); err != nil {
		return 0, 0, err
	}
	return effectiveDelta, newBal, nil
}

func (s *Server) pvpOverview(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	modeFilter := r.URL.Query().Get("mode")
	if modeFilter == "" {
		modeFilter = "1v1"
	}
	if _, ok := rules.Modes[modeFilter]; !ok {
		s.fail(w, bad("invalid_pvp_mode", "无效的竞技模式"))
		return
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())

	seasonID, seasonName, err := ensureActiveSeasonTx(r.Context(), tx, rules)
	if err != nil {
		s.fail(w, err)
		return
	}
	if err = ensureRatingRowsTx(r.Context(), tx, rules, c.ID, seasonID); err != nil {
		s.fail(w, err)
		return
	}
	honorBal, weeklyHonor, weekKey, claimedSeasons, err := ensureHonorWalletTx(r.Context(), tx, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}

	ratings := map[string]any{}
	rows, err := tx.Query(r.Context(), `SELECT mode,rating,peak_rating,tier,wins,losses,draws,streak FROM pvp_ratings WHERE character_id=$1 AND season_id=$2`, c.ID, seasonID)
	if err != nil {
		s.fail(w, err)
		return
	}
	for rows.Next() {
		var m, tier string
		var rating, peak, wins, losses, draws, streak int
		if err = rows.Scan(&m, &rating, &peak, &tier, &wins, &losses, &draws, &streak); err != nil {
			rows.Close()
			s.fail(w, err)
			return
		}
		tInfo := rules.tierFor(rating)
		ratings[m] = map[string]any{
			"mode": m, "rating": rating, "peak_rating": peak, "tier": tier, "tier_name": tInfo.Name,
			"wins": wins, "losses": losses, "draws": draws, "streak": streak,
		}
	}
	rows.Close()

	// Active queue
	var queueObj any = nil
	var qID, qMode, qEntryType, qStatus, matchedMatchID string
	var allowFill bool
	var memberIDsRaw []byte
	qErr := tx.QueryRow(r.Context(), `SELECT id::text,mode,entry_type,member_ids,allow_random_fill,status,coalesce(matched_match_id::text,'')
		FROM pvp_queues WHERE status='queued' AND (leader_character_id=$1 OR member_ids ? $1::text) ORDER BY created_at DESC LIMIT 1`, c.ID).
		Scan(&qID, &qMode, &qEntryType, &memberIDsRaw, &allowFill, &qStatus, &matchedMatchID)
	if qErr == nil {
		var mList []string
		_ = json.Unmarshal(memberIDsRaw, &mList)
		queueObj = map[string]any{
			"id": qID, "mode": qMode, "entry_type": qEntryType, "member_ids": mList,
			"allow_random_fill": allowFill, "status": qStatus, "matched_match_id": matchedMatchID,
		}
	} else if !errors.Is(qErr, pgx.ErrNoRows) {
		s.fail(w, qErr)
		return
	}

	// Pending challenges
	challenges := []map[string]any{}
	chRows, err := tx.Query(r.Context(), `SELECT pc.id::text,pc.mode,pc.challenger_id::text,ca.nickname,pc.target_id::text,cb.nickname,pc.status
		FROM pvp_challenges pc
		JOIN characters ca ON ca.id=pc.challenger_id
		JOIN characters cb ON cb.id=pc.target_id
		WHERE pc.status='pending' AND (pc.challenger_id=$1 OR pc.target_id=$1)
		ORDER BY pc.created_at DESC LIMIT 10`, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	for chRows.Next() {
		var id, m, cID, cName, tID, tName, st string
		if err = chRows.Scan(&id, &m, &cID, &cName, &tID, &tName, &st); err != nil {
			chRows.Close()
			s.fail(w, err)
			return
		}
		challenges = append(challenges, map[string]any{
			"id": id, "mode": m, "challenger_id": cID, "challenger_name": cName,
			"target_id": tID, "target_name": tName, "status": st,
			"direction": map[bool]string{true: "incoming", false: "outgoing"}[tID == c.ID],
		})
	}
	chRows.Close()

	// Active or most recent match
	var activeMatchID string
	err = tx.QueryRow(r.Context(), `SELECT m.id::text FROM pvp_matches m JOIN pvp_match_participants p ON p.match_id=m.id
		WHERE p.character_id=$1 AND m.status IN ('ready','active') ORDER BY m.created_at DESC LIMIT 1`, c.ID).Scan(&activeMatchID)
	var activeMatch any = nil
	if err == nil && activeMatchID != "" {
		mv, mErr := s.buildPvPMatchViewTx(r.Context(), tx, rules, journey, activeMatchID, c.ID)
		if mErr != nil {
			s.fail(w, mErr)
			return
		}
		activeMatch = mv
	}

	// Recent matches for replay
	recent := []map[string]any{}
	recRows, err := tx.Query(r.Context(), `SELECT m.id::text,m.mode,m.match_kind,m.status,m.winner_side,m.result_reason,m.battle_tick,p.side,p.rating_before,p.rating_after,p.honor_delta,m.created_at
		FROM pvp_matches m JOIN pvp_match_participants p ON p.match_id=m.id
		WHERE p.character_id=$1 ORDER BY m.created_at DESC LIMIT 10`, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	for recRows.Next() {
		var mID, mMode, mKind, mStatus, wSide, rReason, pSide string
		var bTick, rBefore, rAfter, hDelta int
		var createdAt time.Time
		if err = recRows.Scan(&mID, &mMode, &mKind, &mStatus, &wSide, &rReason, &bTick, &pSide, &rBefore, &rAfter, &hDelta, &createdAt); err != nil {
			recRows.Close()
			s.fail(w, err)
			return
		}
		recent = append(recent, map[string]any{
			"id": mID, "mode": mMode, "match_kind": mKind, "status": mStatus,
			"winner_side": wSide, "result_reason": rReason, "battle_tick": bTick,
			"my_side": pSide, "rating_delta": rAfter - rBefore, "honor_delta": hDelta,
			"created_at": createdAt.UTC().Format(time.RFC3339),
		})
	}
	recRows.Close()

	// Leaderboard for requested mode
	lb := []map[string]any{}
	lbRows, err := tx.Query(r.Context(), `SELECT pr.character_id::text,ch.nickname,ch.role_id,pr.rating,pr.tier,pr.wins,pr.losses,pr.draws
		FROM pvp_ratings pr JOIN characters ch ON ch.id=pr.character_id
		WHERE pr.season_id=$1 AND pr.mode=$2 AND ch.deleted_at IS NULL
		ORDER BY pr.rating DESC, pr.wins DESC, pr.updated_at ASC LIMIT 20`, seasonID, modeFilter)
	if err != nil {
		s.fail(w, err)
		return
	}
	rank := 0
	for lbRows.Next() {
		rank++
		var cid, nick, roleID, tier string
		var rating, wins, losses, draws int
		if err = lbRows.Scan(&cid, &nick, &roleID, &rating, &tier, &wins, &losses, &draws); err != nil {
			lbRows.Close()
			s.fail(w, err)
			return
		}
		lb = append(lb, map[string]any{
			"rank": rank, "character_id": cid, "nickname": nick, "role_id": roleID,
			"rating": rating, "tier": tier, "tier_name": rules.tierFor(rating).Name,
			"wins": wins, "losses": losses, "draws": draws,
		})
	}
	lbRows.Close()

	// Friends list for quick sparring invite
	friends := []map[string]any{}
	fRows, err := tx.Query(r.Context(), `SELECT CASE WHEN character_a=$1 THEN character_b::text ELSE character_a::text END AS fid,
		ch.nickname,ch.role_id,ch.level
		FROM friendships f JOIN characters ch ON ch.id=(CASE WHEN f.character_a=$1 THEN f.character_b ELSE f.character_a END)
		WHERE (f.character_a=$1 OR f.character_b=$1) AND ch.deleted_at IS NULL ORDER BY ch.nickname ASC LIMIT 30`, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	for fRows.Next() {
		var fid, nick, roleID string
		var lvl int
		if err = fRows.Scan(&fid, &nick, &roleID, &lvl); err != nil {
			fRows.Close()
			s.fail(w, err)
			return
		}
		friends = append(friends, map[string]any{"character_id": fid, "nickname": nick, "role_id": roleID, "level": lvl})
	}
	fRows.Close()

	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{
		"season":             map[string]any{"id": seasonID, "name": seasonName, "claimed": claimedSeasons[seasonID] == true},
		"character_id":       c.ID,
		"ratings":            ratings,
		"honor_balance":      honorBal,
		"weekly_honor":       weeklyHonor,
		"weekly_honor_cap":   rules.WeeklyHonorCap,
		"week_key":           weekKey,
		"queue":              queueObj,
		"challenges":         challenges,
		"active_match":       activeMatch,
		"recent_matches":     recent,
		"leaderboard_mode":   modeFilter,
		"leaderboard":        lb,
		"friends":            friends,
		"honor_shop":         rules.HonorShop,
		"modes":              rules.Modes,
		"rules_summary":      fmt.Sprintf("属性等级同步 Lv.%d · 群体上限 %d 人 · 15秒超时自动防御/普攻 · 无装备掉落与经验扣除", rules.SyncedLevel, rules.AoETargetCap),
	})
}

type pvpMemberSpec struct {
	CharacterID   string         `json:"character_id"`
	AccountID     string         `json:"-"`
	Nickname      string         `json:"name"`
	RoleID        string         `json:"role_id"`
	Level         int            `json:"level"`
	PartyID       string         `json:"-"`
	WasRandomFill bool           `json:"-"`
	Loadout       map[string]any `json:"loadout,omitempty"`
}

func buildPvPLoadoutTx(ctx context.Context, tx pgx.Tx, rules *PvPRules, journey *JourneyRules, c Character) (map[string]any, error) {
	lo, err := loadoutForBattle(ctx, tx, c, journey)
	if err != nil {
		return nil, err
	}
	capAtk := rules.MaxGearBonusCap["attack"]
	capDef := rules.MaxGearBonusCap["defense"]
	capHp := rules.MaxGearBonusCap["health"]
	atk := lo.Attack
	if capAtk > 0 && atk > capAtk {
		atk = capAtk
	}
	def := lo.Defense
	if capDef > 0 && def > capDef {
		def = capDef
	}
	hp := lo.Health
	if capHp > 0 && hp > capHp {
		hp = capHp
	}
	res := map[string]any{
		"attack":  atk,
		"defense": def,
		"health":  hp,
		"potions": 1,
	}
	if lo.ActivePet != "" {
		res["active_pet"] = lo.ActivePet
	}
	return res, nil
}

func collectSideRosterTx(ctx context.Context, tx pgx.Tx, rules *PvPRules, journey *JourneyRules, leaderChar Character, wantSize int) ([]pvpMemberSpec, string, error) {
	pInfo, err := lockCharacterParty(ctx, tx, leaderChar.ID)
	if err != nil && !errors.Is(err, errParty) {
		return nil, "", err
	}
	if errors.Is(err, errParty) || pInfo.ID == "" {
		if wantSize != 1 {
			return nil, "", bad("party_size_mismatch", fmt.Sprintf("%dv%d 切磋需要对应人数队伍", wantSize, wantSize))
		}
		acctID, err := characterAccountIDTx(ctx, tx, leaderChar.ID)
		if err != nil {
			return nil, "", err
		}
		lo, err := buildPvPLoadoutTx(ctx, tx, rules, journey, leaderChar)
		if err != nil {
			return nil, "", err
		}
		return []pvpMemberSpec{{
			CharacterID: leaderChar.ID, AccountID: acctID, Nickname: leaderChar.Nickname,
			RoleID: leaderChar.RoleID, Level: rules.SyncedLevel, Loadout: lo,
		}}, "", nil
	}
	members, err := readPartyMembers(ctx, tx, pInfo.ID)
	if err != nil {
		return nil, "", err
	}
	if len(members) != wantSize {
		return nil, "", bad("party_size_mismatch", fmt.Sprintf("当前队伍人数(%d)不符合 %dv%d", len(members), wantSize, wantSize))
	}
	out := make([]pvpMemberSpec, 0, len(members))
	for _, m := range members {
		ch, err := scanCharacter(tx.QueryRow(ctx, `SELECT `+characterColumns+` FROM characters WHERE id=$1 AND deleted_at IS NULL`, m.ID))
		if err != nil {
			return nil, "", err
		}
		acctID, err := characterAccountIDTx(ctx, tx, ch.ID)
		if err != nil {
			return nil, "", err
		}
		lo, err := buildPvPLoadoutTx(ctx, tx, rules, journey, ch)
		if err != nil {
			return nil, "", err
		}
		out = append(out, pvpMemberSpec{
			CharacterID: ch.ID, AccountID: acctID, Nickname: ch.Nickname,
			RoleID: ch.RoleID, Level: rules.SyncedLevel, PartyID: pInfo.ID, Loadout: lo,
		})
	}
	return out, pInfo.ID, nil
}

func (s *Server) sendPvPChallenge(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		Mode              string `json:"mode"`
		TargetCharacterID string `json:"target_character_id"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	mr, ok := rules.Modes[body.Mode]
	if !ok || !validID(body.TargetCharacterID) {
		s.fail(w, bad("invalid_pvp_challenge", "无效的切磋目标或模式"))
		return
	}
	data, err := s.command(r, who, "pvp.challenge.send", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if c.ID == body.TargetCharacterID {
			return nil, bad("invalid_pvp_challenge", "不能向自己发起切磋")
		}
		targetChar, err := scanCharacter(tx.QueryRow(ctx, `SELECT `+characterColumns+` FROM characters WHERE id=$1 AND deleted_at IS NULL`, body.TargetCharacterID))
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if err = requireFriendshipTx(ctx, tx, c.ID, targetChar.ID); err != nil {
			return nil, err
		}
		targetAcct, err := characterAccountIDTx(ctx, tx, targetChar.ID)
		if err != nil {
			return nil, err
		}
		blocked, err := accountsBlocked(ctx, tx, who.AccountID, targetAcct)
		if err != nil {
			return nil, err
		}
		if blocked || who.AccountID == targetAcct {
			return nil, pvpConflict("challenge_blocked", "无法向该玩家发起切磋")
		}
		_, cPartyID, err := collectSideRosterTx(ctx, tx, rules, journey, c, mr.TeamSize)
		if err != nil {
			return nil, err
		}
		_, tPartyID, err := collectSideRosterTx(ctx, tx, rules, journey, targetChar, mr.TeamSize)
		if err != nil {
			return nil, err
		}
		var chPartyAny, tgPartyAny any
		if cPartyID != "" {
			chPartyAny = cPartyID
		}
		if tPartyID != "" {
			tgPartyAny = tPartyID
		}
		cid := newID()
		if _, err = tx.Exec(ctx, `INSERT INTO pvp_challenges(id,mode,challenger_id,target_id,challenger_party_id,target_party_id,status) VALUES($1,$2,$3,$4,$5,$6,'pending')`,
			cid, body.Mode, c.ID, targetChar.ID, chPartyAny, tgPartyAny); err != nil {
			return nil, err
		}
		return map[string]any{"challenge_id": cid, "mode": body.Mode, "status": "pending"}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) respondPvPChallenge(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	cid := r.PathValue("id")
	if !validID(cid) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		Accept bool `json:"accept"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "pvp.challenge.respond", map[string]any{"id": cid, "accept": body.Accept}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var mode, chID, tgID, st string
		err = tx.QueryRow(ctx, `SELECT mode,challenger_id::text,target_id::text,status FROM pvp_challenges WHERE id=$1 FOR UPDATE`, cid).
			Scan(&mode, &chID, &tgID, &st)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if tgID != c.ID && chID != c.ID {
			return nil, errNotFound
		}
		if st != "pending" {
			return nil, pvpConflict("challenge_closed", "切磋邀请已失效")
		}
		if !body.Accept {
			newSt := "declined"
			if chID == c.ID {
				newSt = "cancelled"
			}
			if _, err = tx.Exec(ctx, `UPDATE pvp_challenges SET status=$2,updated_at=now() WHERE id=$1`, cid, newSt); err != nil {
				return nil, err
			}
			return map[string]any{"challenge_id": cid, "status": newSt}, nil
		}
		if tgID != c.ID {
			return nil, bad("cannot_accept_own", "只能由受邀方接受切磋")
		}
		mr := rules.Modes[mode]
		chChar, err := scanCharacter(tx.QueryRow(ctx, `SELECT `+characterColumns+` FROM characters WHERE id=$1 AND deleted_at IS NULL`, chID))
		if err != nil {
			return nil, err
		}
		teamA, _, err := collectSideRosterTx(ctx, tx, rules, journey, chChar, mr.TeamSize)
		if err != nil {
			return nil, err
		}
		teamB, _, err := collectSideRosterTx(ctx, tx, rules, journey, c, mr.TeamSize)
		if err != nil {
			return nil, err
		}
		matchID, err := s.createPvPMatchTx(ctx, tx, rules, mode, "sparring", teamA, teamB)
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE pvp_challenges SET status='accepted',match_id=$2,updated_at=now() WHERE id=$1`, cid, matchID); err != nil {
			return nil, err
		}
		mv, err := s.buildPvPMatchViewTx(ctx, tx, rules, journey, matchID, c.ID)
		if err != nil {
			return nil, err
		}
		return map[string]any{"challenge_id": cid, "status": "accepted", "match_id": matchID, "match": mv}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) joinPvPQueue(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		Mode            string `json:"mode"`
		AllowRandomFill bool   `json:"allow_random_fill"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	mr, ok := rules.Modes[body.Mode]
	if !ok {
		s.fail(w, bad("invalid_pvp_mode", "无效的排位模式"))
		return
	}
	data, err := s.command(r, who, "pvp.queue.join", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		// Prevent duplicate active match
		var inMatch bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM pvp_match_participants p JOIN pvp_matches m ON m.id=p.match_id WHERE p.character_id=$1 AND m.status IN ('ready','active'))`, c.ID).Scan(&inMatch); err != nil {
			return nil, err
		}
		if inMatch {
			return nil, pvpConflict("already_in_match", "当前已有未结束的演武对局")
		}
		seasonID, _, err := ensureActiveSeasonTx(ctx, tx, rules)
		if err != nil {
			return nil, err
		}
		if err = ensureRatingRowsTx(ctx, tx, rules, c.ID, seasonID); err != nil {
			return nil, err
		}
		// Determine solo vs party
		pInfo, err := lockCharacterParty(ctx, tx, c.ID)
		if err != nil && !errors.Is(err, errParty) {
			return nil, err
		}
		entryType := "solo"
		memberIDs := []string{c.ID}
		var partyAny any = nil
		if !errors.Is(err, errParty) && pInfo.ID != "" {
			if pInfo.Leader != c.ID {
				return nil, pvpConflict("party_leader_required", "需由队长发起队伍排位")
			}
			members, err := readPartyMembers(ctx, tx, pInfo.ID)
			if err != nil {
				return nil, err
			}
			if len(members) > mr.TeamSize {
				return nil, bad("party_too_large", fmt.Sprintf("队伍人数超出 %s 上限", body.Mode))
			}
			if len(members) > 1 {
				entryType = "party"
				partyAny = pInfo.ID
				memberIDs = memberIDs[:0]
				for _, m := range members {
					memberIDs = append(memberIDs, m.ID)
				}
			}
		}
		if len(memberIDs) < mr.TeamSize && !body.AllowRandomFill {
			return nil, bad("random_fill_required", fmt.Sprintf("人数不足 %d 人时需勾选允许随机补位", mr.TeamSize))
		}
		// Ensure all members not already queued or matched
		for _, mid := range memberIDs {
			var busy bool
			if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM pvp_queues WHERE status='queued' AND member_ids ? $1::text)`, mid).Scan(&busy); err != nil {
				return nil, err
			}
			if busy {
				return nil, pvpConflict("already_queued", "队列中已有成员正在匹配")
			}
			if err = ensureRatingRowsTx(ctx, tx, rules, mid, seasonID); err != nil {
				return nil, err
			}
		}
		var sumRating int
		for _, mid := range memberIDs {
			var rVal int
			if err = tx.QueryRow(ctx, `SELECT rating FROM pvp_ratings WHERE character_id=$1 AND mode=$2 AND season_id=$3`, mid, body.Mode, seasonID).Scan(&rVal); err != nil {
				return nil, err
			}
			sumRating += rVal
		}
		avgRating := sumRating / len(memberIDs)
		qid := newID()
		mBytes, _ := json.Marshal(memberIDs)
		if _, err = tx.Exec(ctx, `INSERT INTO pvp_queues(id,mode,entry_type,leader_character_id,party_id,member_ids,avg_rating,allow_random_fill,status) VALUES($1,$2,$3,$4,$5,$6,$7,$8,'queued')`,
			qid, body.Mode, entryType, c.ID, partyAny, mBytes, avgRating, body.AllowRandomFill); err != nil {
			return nil, err
		}
		matchID, err := s.tryMatchPvPQueueTx(ctx, tx, rules, journey, body.Mode)
		if err != nil {
			return nil, err
		}
		out := map[string]any{"queue_id": qid, "mode": body.Mode, "status": "queued", "allow_random_fill": body.AllowRandomFill}
		if matchID != "" {
			mv, err := s.buildPvPMatchViewTx(ctx, tx, rules, journey, matchID, c.ID)
			if err != nil {
				return nil, err
			}
			out["status"] = "matched"
			out["match_id"] = matchID
			out["match"] = mv
		}
		return out, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) leavePvPQueue(w http.ResponseWriter, r *http.Request, who identity) {
	if _, _, err := s.requirePvP(); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "pvp.queue.leave", map[string]any{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		tag, err := tx.Exec(ctx, `UPDATE pvp_queues SET status='cancelled',updated_at=now() WHERE status='queued' AND leader_character_id=$1`, c.ID)
		if err != nil {
			return nil, err
		}
		return map[string]any{"cancelled": tag.RowsAffected() > 0}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

type pvpQueueTicket struct {
	ID              string
	PartyID         string
	MemberIDs       []string
	AccountIDs      []string
	AvgRating       int
	AllowRandomFill bool
}

func (s *Server) tryMatchPvPQueueTx(ctx context.Context, tx pgx.Tx, rules *PvPRules, journey *JourneyRules, mode string) (string, error) {
	mr := rules.Modes[mode]
	wantSize := mr.TeamSize
	rows, err := tx.Query(ctx, `SELECT id::text,coalesce(party_id::text,''),member_ids,avg_rating,allow_random_fill
		FROM pvp_queues WHERE mode=$1 AND status='queued' ORDER BY created_at ASC FOR UPDATE`, mode)
	if err != nil {
		return "", err
	}
	tickets := []pvpQueueTicket{}
	for rows.Next() {
		var t pvpQueueTicket
		var raw []byte
		if err = rows.Scan(&t.ID, &t.PartyID, &raw, &t.AvgRating, &t.AllowRandomFill); err != nil {
			rows.Close()
			return "", err
		}
		_ = json.Unmarshal(raw, &t.MemberIDs)
		if len(t.MemberIDs) > wantSize {
			continue
		}
		if len(t.MemberIDs) < wantSize && !t.AllowRandomFill {
			continue
		}
		tickets = append(tickets, t)
	}
	rows.Close()

	// Resolve account IDs for block & same-account exclusion
	for i := range tickets {
		for _, cid := range tickets[i].MemberIDs {
			var aid string
			if err = tx.QueryRow(ctx, `SELECT account_id::text FROM characters WHERE id=$1 AND deleted_at IS NULL`, cid).Scan(&aid); err != nil {
				return "", err
			}
			tickets[i].AccountIDs = append(tickets[i].AccountIDs, aid)
		}
	}

	// Build two non-overlapping teams of exact wantSize without blocked pairs or same account
	var teamATickets, teamBTickets []pvpQueueTicket
	var buildTeams func(idx int, sizeA, sizeB int, used map[int]bool) bool
	checkGroupCompat := func(group []pvpQueueTicket, cand pvpQueueTicket) bool {
		for _, g := range group {
			for _, a1 := range g.AccountIDs {
				for _, a2 := range cand.AccountIDs {
					if a1 == a2 {
						return false
					}
					blk, bErr := accountsBlocked(ctx, tx, a1, a2)
					if bErr == nil && blk {
						return false
					}
				}
			}
		}
		return true
	}
	checkCrossCompat := func(aGroup, bGroup []pvpQueueTicket) bool {
		for _, ga := range aGroup {
			for _, gb := range bGroup {
				for _, a1 := range ga.AccountIDs {
					for _, a2 := range gb.AccountIDs {
						if a1 == a2 {
							return false
						}
						blk, bErr := accountsBlocked(ctx, tx, a1, a2)
						if bErr == nil && blk {
							return false
						}
					}
				}
			}
		}
		return true
	}
	buildTeams = func(idx int, sizeA, sizeB int, used map[int]bool) bool {
		if sizeA == wantSize && sizeB == wantSize {
			return checkCrossCompat(teamATickets, teamBTickets)
		}
		for i := idx; i < len(tickets); i++ {
			if used[i] {
				continue
			}
			cand := tickets[i]
			n := len(cand.MemberIDs)
			if sizeA < wantSize && sizeA+n <= wantSize && checkGroupCompat(teamATickets, cand) {
				teamATickets = append(teamATickets, cand)
				used[i] = true
				if buildTeams(0, sizeA+n, sizeB, used) {
					return true
				}
				used[i] = false
				teamATickets = teamATickets[:len(teamATickets)-1]
			}
			if sizeA == wantSize && sizeB < wantSize && sizeB+n <= wantSize && checkGroupCompat(teamBTickets, cand) {
				teamBTickets = append(teamBTickets, cand)
				used[i] = true
				if buildTeams(0, sizeA, sizeB+n, used) {
					return true
				}
				used[i] = false
				teamBTickets = teamBTickets[:len(teamBTickets)-1]
			}
		}
		return false
	}

	if !buildTeams(0, 0, 0, map[int]bool{}) {
		return "", nil
	}

	loadSpecs := func(tks []pvpQueueTicket) ([]pvpMemberSpec, []string, error) {
		specs := []pvpMemberSpec{}
		qids := []string{}
		for _, tk := range tks {
			qids = append(qids, tk.ID)
			randomFill := len(tk.MemberIDs) < wantSize
			for _, mid := range tk.MemberIDs {
				ch, err := scanCharacter(tx.QueryRow(ctx, `SELECT `+characterColumns+` FROM characters WHERE id=$1 AND deleted_at IS NULL`, mid))
				if err != nil {
					return nil, nil, err
				}
				acctID, err := characterAccountIDTx(ctx, tx, ch.ID)
				if err != nil {
					return nil, nil, err
				}
				lo, err := buildPvPLoadoutTx(ctx, tx, rules, journey, ch)
				if err != nil {
					return nil, nil, err
				}
				specs = append(specs, pvpMemberSpec{
					CharacterID: ch.ID, AccountID: acctID, Nickname: ch.Nickname,
					RoleID: ch.RoleID, Level: rules.SyncedLevel, PartyID: tk.PartyID,
					WasRandomFill: randomFill, Loadout: lo,
				})
			}
		}
		return specs, qids, nil
	}

	teamA, qA, err := loadSpecs(teamATickets)
	if err != nil {
		return "", err
	}
	teamB, qB, err := loadSpecs(teamBTickets)
	if err != nil {
		return "", err
	}
	matchID, err := s.createPvPMatchTx(ctx, tx, rules, mode, "ranked", teamA, teamB)
	if err != nil {
		return "", err
	}
	for _, qid := range append(qA, qB...) {
		if _, err = tx.Exec(ctx, `UPDATE pvp_queues SET status='matched',matched_match_id=$2,updated_at=now() WHERE id=$1`, qid, matchID); err != nil {
			return "", err
		}
	}
	return matchID, nil
}

func (s *Server) createPvPMatchTx(ctx context.Context, tx pgx.Tx, rules *PvPRules, mode, matchKind string, teamA, teamB []pvpMemberSpec) (string, error) {
	mr := rules.Modes[mode]
	seasonID, _, err := ensureActiveSeasonTx(ctx, tx, rules)
	if err != nil {
		return "", err
	}
	for _, m := range append(append([]pvpMemberSpec{}, teamA...), teamB...) {
		if err = ensureRatingRowsTx(ctx, tx, rules, m.CharacterID, seasonID); err != nil {
			return "", err
		}
	}
	matchID := newID()
	seed := randomSeed63()
	cfgObj := map[string]any{
		"battle_id":      matchID,
		"mode":           "pvp",
		"pvp_format":     mode,
		"seed":           seed,
		"team_a":         teamA,
		"team_b":         teamB,
		"pvp_max_ticks":  mr.MaxTicks,
		"aoe_target_cap": rules.AoETargetCap,
		"pvp_heal_mult":  rules.HealMult,
	}
	cfgBytes, _ := json.Marshal(cfgObj)
	partsSummary := []map[string]any{}
	insertSide := func(side string, list []pvpMemberSpec) error {
		for idx, m := range list {
			var curRating int
			if err := tx.QueryRow(ctx, `SELECT rating FROM pvp_ratings WHERE character_id=$1 AND mode=$2 AND season_id=$3`, m.CharacterID, mode, seasonID).Scan(&curRating); err != nil {
				return err
			}
			var partyAny any = nil
			if m.PartyID != "" {
				partyAny = m.PartyID
			}
			if _, err := tx.Exec(ctx, `INSERT INTO pvp_match_participants(match_id,character_id,account_id,side,slot_index,party_id,was_random_fill,rating_before,rating_after) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$8)`,
				matchID, m.CharacterID, m.AccountID, side, idx, partyAny, m.WasRandomFill, curRating); err != nil {
				return err
			}
			partsSummary = append(partsSummary, map[string]any{"character_id": m.CharacterID, "nickname": m.Nickname, "side": side, "slot": idx})
		}
		return nil
	}
	pBytes, _ := json.Marshal(partsSummary)
	if _, err = tx.Exec(ctx, `INSERT INTO pvp_matches(id,season_id,mode,match_kind,status,seed,config_snapshot,participants) VALUES($1,$2,$3,$4,'ready',$5,$6,$7)`,
		matchID, seasonID, mode, matchKind, seed, cfgBytes, pBytes); err != nil {
		return "", err
	}
	if err = insertSide("ally", teamA); err != nil {
		return "", err
	}
	if err = insertSide("enemy", teamB); err != nil {
		return "", err
	}
	return matchID, nil
}

func (s *Server) getPvPMatch(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	mid := r.PathValue("id")
	if !validID(mid) {
		s.fail(w, errNotFound)
		return
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	mv, err := s.buildPvPMatchViewTx(r.Context(), tx, rules, journey, mid, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, mv)
}

func (s *Server) readyPvPMatch(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	mid := r.PathValue("id")
	if !validID(mid) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		Ready bool `json:"ready"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "pvp.match.ready", map[string]any{"id": mid, "ready": body.Ready}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var st string
		var cfgRaw []byte
		err = tx.QueryRow(ctx, `SELECT status,config_snapshot FROM pvp_matches WHERE id=$1 FOR UPDATE`, mid).Scan(&st, &cfgRaw)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if st != "ready" {
			if st == "active" {
				return s.buildPvPMatchViewTx(ctx, tx, rules, journey, mid, c.ID)
			}
			return nil, pvpConflict("match_not_ready", "当前对局阶段不可更改准备状态")
		}
		tag, err := tx.Exec(ctx, `UPDATE pvp_match_participants SET ready=$3 WHERE match_id=$1 AND character_id=$2`, mid, c.ID, body.Ready)
		if err != nil {
			return nil, err
		}
		if tag.RowsAffected() == 0 {
			return nil, errNotFound
		}
		var notReady int
		if err = tx.QueryRow(ctx, `SELECT count(*) FROM pvp_match_participants WHERE match_id=$1 AND NOT ready`, mid).Scan(&notReady); err != nil {
			return nil, err
		}
		if notReady == 0 {
			cfgMap := map[string]any{}
			_ = json.Unmarshal(cfgRaw, &cfgMap)
			cfgMap["inputs"] = []any{}
			cfgMap["target_tick"] = 0
			var resp struct {
				State json.RawMessage `json:"state"`
			}
			if err = s.cfg.Authority.Call(ctx, "battle.sync", cfgMap, &resp); err != nil {
				return nil, errAuthority
			}
			var stateObj map[string]any
			_ = json.Unmarshal(resp.State, &stateObj)
			stateHash := fmt.Sprint(stateObj["state_hash"])
			if _, err = tx.Exec(ctx, `UPDATE pvp_matches SET status='active',battle_snapshot=$2,battle_inputs='[]'::jsonb,battle_tick=0,confirmed_sequence=0,state_hash=$3,last_action_tick=0,updated_at=now() WHERE id=$1`,
				mid, resp.State, stateHash); err != nil {
				return nil, err
			}
		}
		return s.buildPvPMatchViewTx(ctx, tx, rules, journey, mid, c.ID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) commandPvPMatch(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	mid := r.PathValue("id")
	if !validID(mid) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		Sequence  int    `json:"sequence"`
		Action    string `json:"action"`
		SkillID   string `json:"skill_id,omitempty"`
		TargetUID int    `json:"target_uid,omitempty"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.Sequence < 1 || (body.Action != "attack" && body.Action != "skill" && body.Action != "potion" && body.Action != "focus") {
		s.fail(w, bad("invalid_pvp_command", "竞技战斗指令无效"))
		return
	}
	data, err := s.command(r, who, "pvp.match.command", map[string]any{"id": mid, "body": body}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var st, mode, mKind, seasonID string
		var bTick, seq int
		var cfgRaw, inputsRaw []byte
		err = tx.QueryRow(ctx, `SELECT status,mode,match_kind,season_id,battle_tick,confirmed_sequence,config_snapshot,battle_inputs FROM pvp_matches WHERE id=$1 FOR UPDATE`, mid).
			Scan(&st, &mode, &mKind, &seasonID, &bTick, &seq, &cfgRaw, &inputsRaw)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if st != "active" {
			return nil, pvpConflict("match_not_active", "当前对局未处于进行中")
		}
		var inMatch bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM pvp_match_participants WHERE match_id=$1 AND character_id=$2)`, mid, c.ID).Scan(&inMatch); err != nil {
			return nil, err
		}
		if !inMatch {
			return nil, errNotFound
		}
		var inputs []coopBattleInput
		_ = json.Unmarshal(inputsRaw, &inputs)
		if body.Sequence != len(inputs)+1 {
			return nil, pvpConflict("sequence_out_of_order", "战斗操作序号与服务端状态不同步")
		}
		actionMap := map[string]any{"action": body.Action, "character_id": c.ID}
		if body.SkillID != "" {
			actionMap["skill_id"] = body.SkillID
		}
		if body.TargetUID > 0 {
			actionMap["target_uid"] = body.TargetUID
		}
		nextTick := bTick + 6
		inputs = append(inputs, coopBattleInput{Sequence: body.Sequence, Tick: nextTick, Action: actionMap})
		if err = s.syncAndSettlePvPTx(ctx, tx, rules, mid, seasonID, mode, mKind, cfgRaw, inputs, nextTick, c.ID, false); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE pvp_match_participants SET last_command_tick=$3 WHERE match_id=$1 AND character_id=$2`, mid, c.ID, nextTick); err != nil {
			return nil, err
		}
		return s.buildPvPMatchViewTx(ctx, tx, rules, journey, mid, c.ID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) tickPvPMatch(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	mid := r.PathValue("id")
	if !validID(mid) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		AdvanceTicks int `json:"advance_ticks"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.AdvanceTicks < 1 {
		body.AdvanceTicks = 60
	}
	if body.AdvanceTicks > 900 {
		body.AdvanceTicks = 900
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())

	var st, mode, mKind, seasonID string
	var bTick, lastActTick int
	var cfgRaw, inputsRaw []byte
	err = tx.QueryRow(r.Context(), `SELECT status,mode,match_kind,season_id,battle_tick,last_action_tick,config_snapshot,battle_inputs FROM pvp_matches WHERE id=$1 FOR UPDATE`, mid).
		Scan(&st, &mode, &mKind, &seasonID, &bTick, &lastActTick, &cfgRaw, &inputsRaw)
	if errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, errNotFound)
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	if st != "active" {
		mv, mErr := s.buildPvPMatchViewTx(r.Context(), tx, rules, journey, mid, c.ID)
		if mErr != nil {
			s.fail(w, mErr)
			return
		}
		_ = tx.Commit(r.Context())
		respond(w, 200, mv)
		return
	}
	var inputs []coopBattleInput
	_ = json.Unmarshal(inputsRaw, &inputs)
	targetTick := bTick + body.AdvanceTicks
	timeoutApplied := false
	// Check turn timeout & idle players -> inject deterministic timeout_default
	if targetTick-lastActTick >= rules.TurnTimeoutTicks {
		pRows, pErr := tx.Query(r.Context(), `SELECT character_id::text FROM pvp_match_participants WHERE match_id=$1 ORDER BY side,slot_index`, mid)
		if pErr != nil {
			s.fail(w, pErr)
			return
		}
		stalled := []string{}
		for pRows.Next() {
			var pCharID string
			if pErr = pRows.Scan(&pCharID); pErr != nil {
				pRows.Close()
				s.fail(w, pErr)
				return
			}
			stalled = append(stalled, pCharID)
		}
		pRows.Close()
		for _, pCharID := range stalled {
			nextSeq := len(inputs) + 1
			inputs = append(inputs, coopBattleInput{
				Sequence: nextSeq,
				Tick:     targetTick,
				Action:   map[string]any{"action": "timeout_default", "character_id": pCharID},
			})
			if _, err = tx.Exec(r.Context(), `UPDATE pvp_match_participants SET timeout_defaults=timeout_defaults+1 WHERE match_id=$1 AND character_id=$2`, mid, pCharID); err != nil {
				s.fail(w, err)
				return
			}
			timeoutApplied = true
		}
	}
	if err = s.syncAndSettlePvPTx(r.Context(), tx, rules, mid, seasonID, mode, mKind, cfgRaw, inputs, targetTick, "", timeoutApplied); err != nil {
		s.fail(w, err)
		return
	}
	mv, err := s.buildPvPMatchViewTx(r.Context(), tx, rules, journey, mid, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, mv)
}

func (s *Server) connectionPvPMatch(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	mid := r.PathValue("id")
	if !validID(mid) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		Status string `json:"status"` // disconnected / reconnected
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.Status != "disconnected" && body.Status != "reconnected" {
		s.fail(w, bad("invalid_connection_status", "连接状态无效"))
		return
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())

	var st, mode, mKind, seasonID string
	var bTick int
	var cfgRaw, inputsRaw []byte
	err = tx.QueryRow(r.Context(), `SELECT status,mode,match_kind,season_id,battle_tick,config_snapshot,battle_inputs FROM pvp_matches WHERE id=$1 FOR UPDATE`, mid).
		Scan(&st, &mode, &mKind, &seasonID, &bTick, &cfgRaw, &inputsRaw)
	if errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, errNotFound)
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	if st == "active" {
		connected := body.Status == "reconnected"
		var inputs []coopBattleInput
		_ = json.Unmarshal(inputsRaw, &inputs)
		if connected {
			if _, err = tx.Exec(ctxOr(r), `UPDATE pvp_match_participants SET connected=true,disconnected_at=NULL WHERE match_id=$1 AND character_id=$2`, mid, c.ID); err != nil {
				s.fail(w, err)
				return
			}
			inputs = append(inputs, coopBattleInput{
				Sequence: len(inputs) + 1,
				Tick:     bTick,
				Action:   map[string]any{"action": "safe_defend", "character_id": c.ID, "enabled": false},
			})
		} else {
			if _, err = tx.Exec(ctxOr(r), `UPDATE pvp_match_participants SET connected=false,disconnected_at=now() WHERE match_id=$1 AND character_id=$2`, mid, c.ID); err != nil {
				s.fail(w, err)
				return
			}
			inputs = append(inputs, coopBattleInput{
				Sequence: len(inputs) + 1,
				Tick:     bTick,
				Action:   map[string]any{"action": "safe_defend", "character_id": c.ID, "enabled": true},
			})
		}
		if err = s.syncAndSettlePvPTx(r.Context(), tx, rules, mid, seasonID, mode, mKind, cfgRaw, inputs, bTick, c.ID, false); err != nil {
			s.fail(w, err)
			return
		}
	}
	mv, err := s.buildPvPMatchViewTx(r.Context(), tx, rules, journey, mid, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, mv)
}

func ctxOr(r *http.Request) context.Context { return r.Context() }

func (s *Server) forfeitPvPMatch(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	mid := r.PathValue("id")
	if !validID(mid) {
		s.fail(w, errNotFound)
		return
	}
	data, err := s.command(r, who, "pvp.match.forfeit", map[string]any{"id": mid}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var st, mode, mKind, seasonID string
		var bTick int
		var cfgRaw, inputsRaw []byte
		err = tx.QueryRow(ctx, `SELECT status,mode,match_kind,season_id,battle_tick,config_snapshot,battle_inputs FROM pvp_matches WHERE id=$1 FOR UPDATE`, mid).
			Scan(&st, &mode, &mKind, &seasonID, &bTick, &cfgRaw, &inputsRaw)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if st != "active" && st != "ready" {
			return s.buildPvPMatchViewTx(ctx, tx, rules, journey, mid, c.ID)
		}
		if st == "ready" {
			// Safe abort before battle starts -> zero rating penalty!
			if _, err = tx.Exec(ctx, `UPDATE pvp_matches SET status='aborted',winner_side='draw',result_reason='aborted_before_start',settled_at=now(),updated_at=now() WHERE id=$1`, mid); err != nil {
				return nil, err
			}
			return s.buildPvPMatchViewTx(ctx, tx, rules, journey, mid, c.ID)
		}
		if _, err = tx.Exec(ctx, `UPDATE pvp_match_participants SET forfeited=true WHERE match_id=$1 AND character_id=$2`, mid, c.ID); err != nil {
			return nil, err
		}
		var inputs []coopBattleInput
		_ = json.Unmarshal(inputsRaw, &inputs)
		inputs = append(inputs, coopBattleInput{
			Sequence: len(inputs) + 1,
			Tick:     bTick,
			Action:   map[string]any{"action": "forfeit", "character_id": c.ID},
		})
		if err = s.syncAndSettlePvPTx(ctx, tx, rules, mid, seasonID, mode, mKind, cfgRaw, inputs, bTick, c.ID, false); err != nil {
			return nil, err
		}
		return s.buildPvPMatchViewTx(ctx, tx, rules, journey, mid, c.ID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) syncAndSettlePvPTx(ctx context.Context, tx pgx.Tx, rules *PvPRules, mid, seasonID, mode, mKind string, cfgRaw []byte, inputs []coopBattleInput, targetTick int, actionCharID string, timeoutApplied bool) error {
	cfgMap := map[string]any{}
	_ = json.Unmarshal(cfgRaw, &cfgMap)
	cfgMap["inputs"] = inputs
	cfgMap["target_tick"] = targetTick
	var resp struct {
		OK     bool              `json:"ok"`
		Error  string            `json:"error"`
		State  json.RawMessage   `json:"state"`
		Inputs []coopBattleInput `json:"inputs"`
	}
	if err := s.cfg.Authority.Call(ctx, "battle.sync", cfgMap, &resp); err != nil || !resp.OK {
		return errAuthority
	}
	var stObj struct {
		Tick       int    `json:"tick"`
		Finished   bool   `json:"finished"`
		Result     string `json:"result"`
		WinnerSide string `json:"winner_side"`
		StateHash  string `json:"state_hash"`
	}
	_ = json.Unmarshal(resp.State, &stObj)
	inJSON, _ := json.Marshal(resp.Inputs)

	lastActClause := ""
	if actionCharID != "" {
		lastActClause = ",last_action_tick=battle_tick"
	}
	timeoutDelta := 0
	if timeoutApplied {
		timeoutDelta = 1
	}
	_, err := tx.Exec(ctx, `UPDATE pvp_matches SET battle_snapshot=$2,battle_inputs=$3,battle_tick=$4,confirmed_sequence=$5,state_hash=$6,timeout_defaults_applied=timeout_defaults_applied+$7,updated_at=now()`+lastActClause+` WHERE id=$1`,
		mid, resp.State, inJSON, stObj.Tick, len(resp.Inputs), stObj.StateHash, timeoutDelta)
	if err != nil {
		return err
	}
	if actionCharID != "" {
		_, _ = tx.Exec(ctx, `UPDATE pvp_matches SET last_action_tick=$2 WHERE id=$1`, mid, stObj.Tick)
	}
	if !stObj.Finished {
		return nil
	}
	winnerSide := stObj.WinnerSide
	if winnerSide == "" {
		if stObj.Result == "victory" {
			winnerSide = "ally"
		} else if stObj.Result == "defeat" {
			winnerSide = "enemy"
		} else {
			winnerSide = "draw"
		}
	}
	reason := "knockout"
	if stObj.Result == "draw" {
		reason = "timeout_draw"
	}
	return s.settlePvPMatchTx(ctx, tx, rules, mid, seasonID, mode, mKind, winnerSide, reason)
}

func (s *Server) settlePvPMatchTx(ctx context.Context, tx pgx.Tx, rules *PvPRules, mid, seasonID, mode, mKind, winnerSide, reason string) error {
	var curStatus string
	if err := tx.QueryRow(ctx, `SELECT status FROM pvp_matches WHERE id=$1 FOR UPDATE`, mid).Scan(&curStatus); err != nil {
		return err
	}
	if curStatus == "completed" {
		return nil
	}
	type part struct {
		CharID, Side, AcctID string
		RatingBefore         int
		Forfeited            bool
		Connected            bool
		RandomFill           bool
	}
	pRows, err := tx.Query(ctx, `SELECT character_id::text,account_id::text,side,rating_before,forfeited,connected,was_random_fill FROM pvp_match_participants WHERE match_id=$1 FOR UPDATE`, mid)
	if err != nil {
		return err
	}
	parts := []part{}
	var sumA, sumB, cntA, cntB float64
	for pRows.Next() {
		var p part
		if err = pRows.Scan(&p.CharID, &p.AcctID, &p.Side, &p.RatingBefore, &p.Forfeited, &p.Connected, &p.RandomFill); err != nil {
			pRows.Close()
			return err
		}
		parts = append(parts, p)
		if p.Side == "ally" {
			sumA += float64(p.RatingBefore)
			cntA++
		} else {
			sumB += float64(p.RatingBefore)
			cntB++
		}
	}
	pRows.Close()
	avgA := sumA / math.Max(1.0, cntA)
	avgB := sumB / math.Max(1.0, cntB)

	mr := rules.Modes[mode]
	ratingDeltas := map[string]int{}
	honorAwards := map[string]int{}

	// Check if losing side had any disconnected/forfeited player so innocent random-fill teammate gets rating loss protection
	anyLeaverOnSide := map[string]bool{}
	for _, p := range parts {
		if p.Forfeited || !p.Connected {
			anyLeaverOnSide[p.Side] = true
		}
	}

	for _, p := range parts {
		newRating := p.RatingBefore
		honorGrant := 0
		won := (winnerSide == p.Side)
		isDraw := (winnerSide == "draw")

		if mKind == "ranked" {
			// Score against opponent average
			oppAvg := avgB
			if p.Side == "enemy" {
				oppAvg = avgA
			}
			expected := 1.0 / (1.0 + math.Pow(10.0, (oppAvg-float64(p.RatingBefore))/400.0))
			score := 0.0
			if isDraw {
				score = 0.5
			} else if won {
				score = 1.0
			}
			delta := int(math.Round(float64(mr.KFactor) * (score - expected)))
			if won && delta < 1 {
				delta = 1
			}
			if !won && !isDraw && rules.ReconnectRatingProtectionEnabled() && p.RandomFill && anyLeaverOnSide[p.Side] && !p.Forfeited && p.Connected {
				// Protect cooperative random-fill teammate from unfair drop when a teammate left
				delta = 0
			}
			newRating = p.RatingBefore + delta
			if newRating < 0 {
				newRating = 0
			}
			ratingDeltas[p.CharID] = newRating - p.RatingBefore

			wInc, lInc, dInc := 0, 0, 0
			if isDraw {
				dInc = 1
			} else if won {
				wInc = 1
			} else {
				lInc = 1
			}
			var prevStreak int
			_ = tx.QueryRow(ctx, `SELECT streak FROM pvp_ratings WHERE character_id=$1 AND mode=$2 AND season_id=$3`, p.CharID, mode, seasonID).Scan(&prevStreak)
			nextStreak := 0
			if won {
				nextStreak = prevStreak + 1
			}
			tierID := rules.tierFor(newRating).ID
			if _, err = tx.Exec(ctx, `UPDATE pvp_ratings SET rating=$4,peak_rating=GREATEST(peak_rating,$4),tier=$5,wins=wins+$6,losses=losses+$7,draws=draws+$8,streak=$9,updated_at=now()
				WHERE character_id=$1 AND mode=$2 AND season_id=$3`, p.CharID, mode, seasonID, newRating, tierID, wInc, lInc, dInc, nextStreak); err != nil {
				return err
			}

			// Honor gain with anti-farm repeat check (count recent ranked matches vs opponent side today)
			var rawHonor int
			if isDraw {
				rawHonor = mr.HonorDraw
			} else if won {
				rawHonor = mr.HonorWin
			} else {
				rawHonor = mr.HonorLoss
			}
			oppID := ""
			for _, op := range parts {
				if op.Side != p.Side {
					oppID = op.CharID
					break
				}
			}
			if oppID != "" && rules.RepeatOpponentDailyCap > 0 {
				var repeatCount int
				_ = tx.QueryRow(ctx, `SELECT count(*) FROM pvp_matches m
					JOIN pvp_match_participants pa ON pa.match_id=m.id AND pa.character_id=$1
					JOIN pvp_match_participants pb ON pb.match_id=m.id AND pb.character_id=$2
					WHERE m.status='completed' AND m.match_kind='ranked' AND m.settled_at >= date_trunc('day', now())`,
					p.CharID, oppID).Scan(&repeatCount)
				if repeatCount >= rules.RepeatOpponentDailyCap {
					rawHonor = 0
				}
			}
			if rawHonor > 0 {
				eff, _, err := adjustHonorTx(ctx, tx, p.CharID, "pvp_match:"+mid, rawHonor, "ranked_"+mode, map[string]any{"match_id": mid, "mode": mode, "won": won}, rules.WeeklyHonorCap)
				if err != nil {
					return err
				}
				honorGrant = eff
			}
		}
		honorAwards[p.CharID] = honorGrant
		if _, err = tx.Exec(ctx, `UPDATE pvp_match_participants SET rating_after=$3,honor_delta=$4 WHERE match_id=$1 AND character_id=$2`,
			mid, p.CharID, newRating, honorGrant); err != nil {
			return err
		}
	}
	rdBytes, _ := json.Marshal(ratingDeltas)
	haBytes, _ := json.Marshal(honorAwards)
	_, err = tx.Exec(ctx, `UPDATE pvp_matches SET status='completed',winner_side=$2,result_reason=$3,rating_deltas=$4,honor_awards=$5,settled_at=now(),updated_at=now() WHERE id=$1`,
		mid, winnerSide, reason, rdBytes, haBytes)
	return err
}

func (p PvPRules) ReconnectRatingProtectionEnabled() bool { return true }

func (s *Server) buildPvPMatchViewTx(ctx context.Context, tx pgx.Tx, rules *PvPRules, journey *JourneyRules, mid, viewerCharID string) (map[string]any, error) {
	var seasonID, mode, matchKind, status, winnerSide, resultReason, stateHash string
	var seed int64
	var bTick, seq, lastActTick, timeoutCnt int
	var snapRaw, inputsRaw, rdRaw, haRaw []byte
	err := tx.QueryRow(ctx, `SELECT season_id,mode,match_kind,status,seed,battle_snapshot,battle_inputs,battle_tick,confirmed_sequence,state_hash,last_action_tick,timeout_defaults_applied,winner_side,result_reason,rating_deltas,honor_awards FROM pvp_matches WHERE id=$1`, mid).
		Scan(&seasonID, &mode, &matchKind, &status, &seed, &snapRaw, &inputsRaw, &bTick, &seq, &stateHash, &lastActTick, &timeoutCnt, &winnerSide, &resultReason, &rdRaw, &haRaw)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, errNotFound
	}
	if err != nil {
		return nil, err
	}
	var snapObj any = map[string]any{}
	_ = json.Unmarshal(snapRaw, &snapObj)
	var inputsObj []any
	_ = json.Unmarshal(inputsRaw, &inputsObj)
	var rdObj, haObj map[string]int
	_ = json.Unmarshal(rdRaw, &rdObj)
	_ = json.Unmarshal(haRaw, &haObj)

	pRows, err := tx.Query(ctx, `SELECT p.character_id::text,c.nickname,c.role_id,p.side,p.slot_index,p.was_random_fill,p.ready,p.connected,p.timeout_defaults,p.forfeited,p.rating_before,p.rating_after,p.honor_delta
		FROM pvp_match_participants p JOIN characters c ON c.id=p.character_id
		WHERE p.match_id=$1 ORDER BY p.side ASC,p.slot_index ASC`, mid)
	if err != nil {
		return nil, err
	}
	parts := []map[string]any{}
	viewerSide := ""
	for pRows.Next() {
		var cid, nick, roleID, side string
		var slot, tDefs, rBefore, rAfter, hDelta int
		var randFill, ready, conn, forf bool
		if err = pRows.Scan(&cid, &nick, &roleID, &side, &slot, &randFill, &ready, &conn, &tDefs, &forf, &rBefore, &rAfter, &hDelta); err != nil {
			pRows.Close()
			return nil, err
		}
		if cid == viewerCharID {
			viewerSide = side
		}
		parts = append(parts, map[string]any{
			"character_id": cid, "nickname": nick, "role_id": roleID, "side": side,
			"slot_index": slot, "was_random_fill": randFill, "ready": ready, "connected": conn,
			"timeout_defaults": tDefs, "forfeited": forf,
			"rating_before": rBefore, "rating_after": rAfter, "honor_delta": hDelta,
		})
	}
	pRows.Close()
	if viewerSide == "" {
		return nil, errNotFound
	}
	return map[string]any{
		"id":                       mid,
		"season_id":                seasonID,
		"mode":                     mode,
		"match_kind":               matchKind,
		"status":                   status,
		"seed":                     seed,
		"battle_tick":              bTick,
		"confirmed_sequence":       seq,
		"state_hash":               stateHash,
		"last_action_tick":         lastActTick,
		"turn_timeout_ticks":       rules.TurnTimeoutTicks,
		"timeout_defaults_applied": timeoutCnt,
		"winner_side":              winnerSide,
		"result_reason":            resultReason,
		"my_side":                  viewerSide,
		"participants":             parts,
		"battle_snapshot":          snapObj,
		"battle_inputs":            inputsObj,
		"rating_deltas":            rdObj,
		"honor_awards":             haObj,
	}, nil
}

func (s *Server) replayPvPMatch(w http.ResponseWriter, r *http.Request, who identity) {
	rules, _, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	mid := r.PathValue("id")
	if !validID(mid) {
		s.fail(w, errNotFound)
		return
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())

	var isPart bool
	if err = tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM pvp_match_participants WHERE match_id=$1 AND character_id=$2)`, mid, c.ID).Scan(&isPart); err != nil || !isPart {
		s.fail(w, errNotFound)
		return
	}
	var mode, matchKind, stateHash, winnerSide, resultReason string
	var bTick int
	var cfgRaw, inputsRaw []byte
	err = tx.QueryRow(r.Context(), `SELECT mode,match_kind,battle_tick,state_hash,winner_side,result_reason,config_snapshot,battle_inputs FROM pvp_matches WHERE id=$1`, mid).
		Scan(&mode, &matchKind, &bTick, &stateHash, &winnerSide, &resultReason, &cfgRaw, &inputsRaw)
	if errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, errNotFound)
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	cfgMap := map[string]any{}
	_ = json.Unmarshal(cfgRaw, &cfgMap)
	var inputs []coopBattleInput
	_ = json.Unmarshal(inputsRaw, &inputs)
	cfgMap["inputs"] = inputs
	cfgMap["target_tick"] = bTick

	var resp struct {
		OK    bool            `json:"ok"`
		Error string          `json:"error"`
		State json.RawMessage `json:"state"`
	}
	if err = s.cfg.Authority.Call(r.Context(), "battle.replay", cfgMap, &resp); err != nil || !resp.OK {
		s.fail(w, errAuthority)
		return
	}
	var stMap map[string]any
	_ = json.Unmarshal(resp.State, &stMap)
	replayedHash := fmt.Sprint(stMap["state_hash"])
	verified := stateHash == "" || replayedHash == stateHash
	_ = tx.Commit(r.Context())

	digest := sha256.Sum256(inputsRaw)
	respond(w, 200, map[string]any{
		"match_id":        mid,
		"mode":            mode,
		"match_kind":      matchKind,
		"winner_side":     winnerSide,
		"result_reason":   resultReason,
		"battle_tick":     bTick,
		"expected_hash":   stateHash,
		"replayed_hash":   replayedHash,
		"replay_verified": verified,
		"inputs_sha256":   hex.EncodeToString(digest[:]),
		"turn_timeout":    rules.TurnTimeoutTicks,
		"inputs":          inputs,
		"final_state":     stMap,
	})
}

func (s *Server) claimPvPSeasonReward(w http.ResponseWriter, r *http.Request, who identity) {
	rules, _, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "pvp.season.claim", map[string]any{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		seasonID, _, err := ensureActiveSeasonTx(ctx, tx, rules)
		if err != nil {
			return nil, err
		}
		_, _, _, claimed, err := ensureHonorWalletTx(ctx, tx, c.ID)
		if err != nil {
			return nil, err
		}
		if claimed[seasonID] == true {
			return nil, pvpConflict("season_reward_claimed", "本赛季段位奖励已领取")
		}
		var bestRating int
		if err = tx.QueryRow(ctx, `SELECT coalesce(max(peak_rating), 1000) FROM pvp_ratings WHERE character_id=$1 AND season_id=$2`, c.ID, seasonID).Scan(&bestRating); err != nil {
			return nil, err
		}
		tier := rules.tierFor(bestRating)
		claimed[seasonID] = true
		clBytes, _ := json.Marshal(claimed)
		if _, err = tx.Exec(ctx, `UPDATE pvp_honor_wallets SET claimed_seasons=$2,updated_at=now() WHERE character_id=$1`, c.ID, clBytes); err != nil {
			return nil, err
		}
		eff, bal, err := adjustHonorTx(ctx, tx, c.ID, "season_reward:"+seasonID, tier.RewardHonor, "season_tier_"+tier.ID, map[string]any{"season": seasonID, "tier": tier.ID}, 0)
		if err != nil {
			return nil, err
		}
		cos := rules.DefaultSeason.CosmeticRewards[tier.ID]
		return map[string]any{
			"season_id":     seasonID,
			"tier":          tier.ID,
			"tier_name":     tier.Name,
			"honor_granted": eff,
			"honor_balance": bal,
			"cosmetic":      cos,
		}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) buyPvPHonorItem(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requirePvP()
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		ItemID string `json:"item_id"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	var entry *PvPHonorShopEntry
	for i := range rules.HonorShop {
		if rules.HonorShop[i].ItemID == body.ItemID {
			entry = &rules.HonorShop[i]
			break
		}
	}
	if entry == nil {
		s.fail(w, bad("invalid_honor_item", "未找到该荣誉商店商品"))
		return
	}
	data, err := s.command(r, who, "pvp.honor.buy", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		txKey := r.Header.Get("Idempotency-Key")
		if txKey == "" {
			txKey = newID()
		}
		_, newBal, err := adjustHonorTx(ctx, tx, c.ID, "shop:"+txKey, -entry.PriceHonor, "honor_shop_buy", map[string]any{"item_id": entry.ItemID}, 0)
		if err != nil {
			return nil, err
		}
		if err = grantPackItems(ctx, tx, c.ID, "pvp_shop:"+txKey, journey.PackSlots, []itemGrant{{
			template: entry.ItemID, quantity: entry.Quantity,
		}}); err != nil {
			return nil, err
		}
		return map[string]any{"item_id": entry.ItemID, "quantity": entry.Quantity, "honor_balance": newBal}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

// RolloverSeasonTx archives the current active season, starts a new season,
// and applies a soft Elo compression toward each mode's base_rating.
func RolloverPvPSeasonTx(ctx context.Context, tx pgx.Tx, rules *PvPRules, nextSeasonID, nextSeasonName string) error {
	oldID, _, err := ensureActiveSeasonTx(ctx, tx, rules)
	if err != nil {
		return err
	}
	if strings.TrimSpace(nextSeasonID) == "" || nextSeasonID == oldID {
		return bad("invalid_season_id", "新赛季标识无效")
	}
	if _, err = tx.Exec(ctx, `UPDATE pvp_seasons SET status='archived',ends_at=now() WHERE id=$1`, oldID); err != nil {
		return err
	}
	snap, _ := json.Marshal(rules.DefaultSeason)
	if _, err = tx.Exec(ctx, `INSERT INTO pvp_seasons(id,name,status,rules_snapshot) VALUES($1,$2,'active',$3)`, nextSeasonID, nextSeasonName, snap); err != nil {
		return err
	}
	rows, err := tx.Query(ctx, `SELECT character_id::text,mode,rating FROM pvp_ratings WHERE season_id=$1`, oldID)
	if err != nil {
		return err
	}
	type prev struct {
		charID, mode string
		rating       int
	}
	prevs := []prev{}
	for rows.Next() {
		var p prev
		if err = rows.Scan(&p.charID, &p.mode, &p.rating); err != nil {
			rows.Close()
			return err
		}
		prevs = append(prevs, p)
	}
	rows.Close()
	sort.Slice(prevs, func(i, j int) bool { return prevs[i].charID < prevs[j].charID })
	for _, p := range prevs {
		base := rules.Modes[p.mode].BaseRating
		soft := base + (p.rating-base)/2
		tier := rules.tierFor(soft).ID
		if _, err = tx.Exec(ctx, `INSERT INTO pvp_ratings(character_id,mode,season_id,rating,peak_rating,tier) VALUES($1,$2,$3,$4,$4,$5) ON CONFLICT DO NOTHING`,
			p.charID, p.mode, nextSeasonID, soft, tier); err != nil {
			return err
		}
	}
	return nil
}
