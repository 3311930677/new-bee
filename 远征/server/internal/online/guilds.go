package online

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

type GuildRules struct {
	CreateCostGold       int64    `json:"create_cost_gold"`
	MinLevel             int      `json:"min_level"`
	RequireAct2Complete  bool     `json:"require_act2_complete"`
	BaseMemberCap        int      `json:"base_member_cap"`
	MaxMemberCap         int      `json:"max_member_cap"`
	WeeklyPointsPerSlot  int      `json:"weekly_points_per_slot"`
	LeaveCooldownSeconds int      `json:"leave_cooldown_seconds"`
	LeaderInactiveSeconds int     `json:"leader_inactive_seconds"`
	WarehouseMaterials   []string `json:"warehouse_materials"`
}

func (g GuildRules) validate(items map[string]JourneyItem) error {
	invalid := errors.New("invalid guild rules")
	if g.CreateCostGold < 0 || g.MinLevel < 1 || g.BaseMemberCap < 5 || g.MaxMemberCap < g.BaseMemberCap ||
		g.WeeklyPointsPerSlot < 1 || g.LeaveCooldownSeconds < 0 || g.LeaderInactiveSeconds < 60 || len(g.WarehouseMaterials) == 0 {
		return invalid
	}
	for _, tpl := range g.WarehouseMaterials {
		it, ok := items[tpl]
		if !ok || it.Tradeable || !it.GuildBuilding {
			return invalid
		}
	}
	return nil
}

func (g GuildRules) allowsWarehouseMaterial(tpl string) bool {
	for _, m := range g.WarehouseMaterials {
		if m == tpl {
			return true
		}
	}
	return false
}

func (s *Server) requireGuilds() (*GuildRules, *JourneyRules, error) {
	if s.cfg.Rules.Guilds == nil || s.cfg.Rules.Journey == nil {
		return nil, nil, &apiError{404, "guilds_unavailable", "帮派功能尚未开放"}
	}
	return s.cfg.Rules.Guilds, s.cfg.Rules.Journey, nil
}

func appendGuildAuditTx(ctx context.Context, tx pgx.Tx, guildID, actorID, targetID, action, tpl string, qty int, details map[string]any) error {
	if details == nil {
		details = map[string]any{}
	}
	raw, _ := json.Marshal(details)
	if len(raw) == 0 || string(raw) == "null" {
		raw = []byte("{}")
	}
	_, err := tx.Exec(ctx, `INSERT INTO guild_audit_logs(guild_id,actor_character_id,target_character_id,action,template_id,quantity,details)
        VALUES($1,nullif($2,'')::uuid,nullif($3,'')::uuid,$4,$5,$6,$7::jsonb)`,
		guildID, actorID, targetID, action, tpl, qty, string(raw))
	return err
}

func touchGuildLeaderActivityTx(ctx context.Context, tx pgx.Tx, guildID, charID string) {
	_, _ = tx.Exec(ctx, `UPDATE guilds SET last_leader_active_at=now(),updated_at=now() WHERE id=$1 AND leader_character_id=$2`, guildID, charID)
}

func (s *Server) buildGuildSnapshotTx(ctx context.Context, tx pgx.Tx, rules *GuildRules, journey *JourneyRules, c Character) (map[string]any, error) {
	var cooldownUntil *time.Time
	_ = tx.QueryRow(ctx, `SELECT cooldown_until FROM guild_member_cooldowns WHERE character_id=$1 AND cooldown_until>now()`, c.ID).Scan(&cooldownUntil)

	var guildID string
	_ = tx.QueryRow(ctx, `SELECT m.guild_id::text FROM guild_members m JOIN guilds g ON g.id=m.guild_id WHERE m.character_id=$1 AND g.disbanded_at IS NULL`, c.ID).Scan(&guildID)

	var guildView any
	if guildID != "" {
		var name, motto, ann, leaderID, banner, monument string
		var capCount, weeklyPts, decorLvl int
		var lastLeaderActive time.Time
		err := tx.QueryRow(ctx, `SELECT name,motto,announcement,leader_character_id::text,member_cap,weekly_coop_points,decor_level,decor_banner,decor_monument,last_leader_active_at
            FROM guilds WHERE id=$1`, guildID).
			Scan(&name, &motto, &ann, &leaderID, &capCount, &weeklyPts, &decorLvl, &banner, &monument, &lastLeaderActive)
		if err != nil {
			return nil, err
		}
		mRows, err := tx.Query(ctx, `SELECT m.character_id::text,ch.nickname,ch.role_id,ch.level,m.rank,m.can_invite,m.can_manage_warehouse,m.can_edit_announcement,m.contribution_points
            FROM guild_members m JOIN characters ch ON ch.id=m.character_id
            WHERE m.guild_id=$1 ORDER BY CASE m.rank WHEN 'leader' THEN 0 WHEN 'officer' THEN 1 ELSE 2 END,m.joined_at`, guildID)
		if err != nil {
			return nil, err
		}
		members := []map[string]any{}
		for mRows.Next() {
			var cid, nick, role, rank string
			var lvl, contrib int
			var canInv, canWH, canAnn bool
			if err = mRows.Scan(&cid, &nick, &role, &lvl, &rank, &canInv, &canWH, &canAnn, &contrib); err != nil {
				mRows.Close()
				return nil, err
			}
			members = append(members, map[string]any{
				"character_id":          cid,
				"nickname":              nick,
				"role_id":               role,
				"level":                 lvl,
				"rank":                  rank,
				"can_invite":            canInv,
				"can_manage_warehouse":  canWH,
				"can_edit_announcement": canAnn,
				"contribution_points":   contrib,
			})
		}
		mRows.Close()

		wRows, err := tx.Query(ctx, `SELECT template_id,quantity FROM guild_warehouse WHERE guild_id=$1 AND quantity>0 ORDER BY template_id`, guildID)
		if err != nil {
			return nil, err
		}
		warehouse := []map[string]any{}
		for wRows.Next() {
			var tpl string
			var qty int
			if err = wRows.Scan(&tpl, &qty); err != nil {
				wRows.Close()
				return nil, err
			}
			warehouse = append(warehouse, map[string]any{"template_id": tpl, "name": journey.Items[tpl].Name, "quantity": qty})
		}
		wRows.Close()

		aRows, err := tx.Query(ctx, `SELECT a.id,coalesce(c1.nickname,''),coalesce(c2.nickname,''),a.action,a.template_id,a.quantity,a.details,a.created_at
            FROM guild_audit_logs a LEFT JOIN characters c1 ON c1.id=a.actor_character_id LEFT JOIN characters c2 ON c2.id=a.target_character_id
            WHERE a.guild_id=$1 ORDER BY a.id DESC LIMIT 20`, guildID)
		if err != nil {
			return nil, err
		}
		logs := []map[string]any{}
		for aRows.Next() {
			var lid int64
			var actorNick, targetNick, act, tpl string
			var qty int
			var dRaw []byte
			var ts time.Time
			if err = aRows.Scan(&lid, &actorNick, &targetNick, &act, &tpl, &qty, &dRaw, &ts); err != nil {
				aRows.Close()
				return nil, err
			}
			var details any = map[string]any{}
			_ = json.Unmarshal(dRaw, &details)
			logs = append(logs, map[string]any{
				"id": lid, "actor": actorNick, "target": targetNick, "action": act,
				"template_id": tpl, "quantity": qty, "details": details,
				"created_at": ts.UTC().Format(time.RFC3339),
			})
		}
		aRows.Close()

		canClaimLeader := leaderID != c.ID && time.Since(lastLeaderActive) >= time.Duration(rules.LeaderInactiveSeconds)*time.Second
		guildView = map[string]any{
			"id":                    guildID,
			"name":                  name,
			"motto":                 motto,
			"announcement":          ann,
			"leader_character_id":   leaderID,
			"member_cap":            capCount,
			"member_count":          len(members),
			"weekly_coop_points":    weeklyPts,
			"decor_level":           decorLvl,
			"decor_banner":          banner,
			"decor_monument":        monument,
			"last_leader_active_at": lastLeaderActive.UTC().Format(time.RFC3339),
			"can_claim_inactive":    canClaimLeader,
			"members":               members,
			"warehouse":             warehouse,
			"audit_logs":            logs,
		}
	}

	iRows, err := tx.Query(ctx, `SELECT i.id::text,i.guild_id::text,g.name,c1.nickname,i.created_at
        FROM guild_invites i JOIN guilds g ON g.id=i.guild_id JOIN characters c1 ON c1.id=i.inviter_character_id
        WHERE i.target_character_id=$1 AND i.status='pending' AND g.disbanded_at IS NULL ORDER BY i.created_at DESC`, c.ID)
	if err != nil {
		return nil, err
	}
	invites := []map[string]any{}
	for iRows.Next() {
		var iid, gid, gname, invNick string
		var ts time.Time
		if err = iRows.Scan(&iid, &gid, &gname, &invNick, &ts); err != nil {
			iRows.Close()
			return nil, err
		}
		invites = append(invites, map[string]any{
			"id": iid, "guild_id": gid, "guild_name": gname, "inviter": invNick, "created_at": ts.UTC().Format(time.RFC3339),
		})
	}
	iRows.Close()

	return map[string]any{
		"guild":               guildView,
		"invites":             invites,
		"cooldown_until":      cooldownUntil,
		"create_cost_gold":    rules.CreateCostGold,
		"warehouse_materials": rules.WarehouseMaterials,
	}, nil
}

func (s *Server) guildState(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
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
	snap, err := s.buildGuildSnapshotTx(r.Context(), tx, rules, journey, c)
	if err != nil {
		s.fail(w, err)
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, snap)
}

func (s *Server) createGuild(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		Name  string `json:"name"`
		Motto string `json:"motto"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	name := strings.TrimSpace(body.Name)
	motto := cleanText(body.Motto)
	if utf8.RuneCountInString(name) < 2 || utf8.RuneCountInString(name) > 16 || utf8.RuneCountInString(motto) > 80 {
		s.fail(w, bad("invalid_guild_name", "帮派名称需为 2–16 个字，宣言不超过 80 字"))
		return
	}
	data, err := s.command(r, who, "guild.create", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if rules.RequireAct2Complete {
			prog, err := readJourney(ctx, tx, c.ID)
			if err != nil {
				return nil, err
			}
			if prog.Step != "complete" && c.Level < 3 {
				return nil, &apiError{409, "act2_required", "需完成边城旅程（第 II 幕）或达到 Lv.3 后才可创立帮派"}
			}
		}
		var inGuild bool
		_ = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM guild_members m JOIN guilds g ON g.id=m.guild_id WHERE m.character_id=$1 AND g.disbanded_at IS NULL)`, c.ID).Scan(&inGuild)
		if inGuild {
			return nil, &apiError{409, "already_in_guild", "当前已加入帮派"}
		}
		var onCD bool
		_ = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM guild_member_cooldowns WHERE character_id=$1 AND cooldown_until>now())`, c.ID).Scan(&onCD)
		if onCD {
			return nil, &apiError{409, "guild_cooldown", "退帮冷却期尚未结束"}
		}
		gid := newID()
		if rules.CreateCostGold > 0 {
			if _, err = adjustGoldTx(ctx, tx, c.ID, "guild_create:"+gid, -rules.CreateCostGold, "guild_create"); err != nil {
				return nil, err
			}
		}
		if _, err = tx.Exec(ctx, `INSERT INTO guilds(id,name,motto,announcement,leader_character_id,member_cap) VALUES($1,$2,$3,$4,$5,$6)`,
			gid, name, motto, "欢迎加入共同建设帮派据点！", c.ID, rules.BaseMemberCap); err != nil {
			if isUniqueViolation(err) {
				return nil, &apiError{409, "guild_name_taken", "帮派名称已被使用"}
			}
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO guild_members(guild_id,character_id,account_id,rank,can_invite,can_manage_warehouse,can_edit_announcement)
            VALUES($1,$2,$3,'leader',true,true,true)`, gid, c.ID, who.AccountID); err != nil {
			return nil, err
		}
		if err = appendGuildAuditTx(ctx, tx, gid, c.ID, "", "create", "", 0, map[string]any{"name": name, "cost_gold": rules.CreateCostGold}); err != nil {
			return nil, err
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) inviteToGuild(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
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
		s.fail(w, bad("invalid_character", "目标角色无效"))
		return
	}
	var snap map[string]any
	err = pgx.BeginFunc(r.Context(), s.db, func(tx pgx.Tx) error {
		c, err := s.activeCharacter(r.Context(), tx, who)
		if err != nil {
			return err
		}
		var guildID, rank string
		var canInv bool
		err = tx.QueryRow(r.Context(), `SELECT m.guild_id::text,m.rank,m.can_invite FROM guild_members m JOIN guilds g ON g.id=m.guild_id
            WHERE m.character_id=$1 AND g.disbanded_at IS NULL FOR UPDATE`, c.ID).Scan(&guildID, &rank, &canInv)
		if errors.Is(err, pgx.ErrNoRows) {
			return &apiError{409, "not_in_guild", "当前未加入帮派"}
		}
		if err != nil {
			return err
		}
		if rank != "leader" && !canInv {
			return &apiError{403, "forbidden", "当前权限不能发出帮派招募邀请"}
		}
		var targetAcc string
		if err = tx.QueryRow(r.Context(), `SELECT account_id::text FROM characters WHERE id=$1 AND deleted_at IS NULL`, body.TargetCharacterID).Scan(&targetAcc); err != nil {
			return &apiError{404, "not_found", "找不到目标角色"}
		}
		if err = requireNotBlocked(r.Context(), tx, who.AccountID, targetAcc); err != nil {
			return err
		}
		var capCount, curCount int
		_ = tx.QueryRow(r.Context(), `SELECT member_cap FROM guilds WHERE id=$1`, guildID).Scan(&capCount)
		_ = tx.QueryRow(r.Context(), `SELECT count(*) FROM guild_members WHERE guild_id=$1`, guildID).Scan(&curCount)
		if curCount >= capCount {
			return &apiError{409, "guild_full", "帮派成员人数已满"}
		}
		if _, err = tx.Exec(r.Context(), `INSERT INTO guild_invites(id,guild_id,inviter_character_id,target_character_id) VALUES($1,$2,$3,$4)`,
			newID(), guildID, c.ID, body.TargetCharacterID); err != nil {
			if isUniqueViolation(err) {
				return &apiError{409, "invite_exists", "已向该旅人发送过帮派邀请"}
			}
			return err
		}
		touchGuildLeaderActivityTx(r.Context(), tx, guildID, c.ID)
		snap, err = s.buildGuildSnapshotTx(r.Context(), tx, rules, journey, c)
		return err
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, snap)
}

func (s *Server) respondGuildInvite(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
		return
	}
	invID := r.PathValue("id")
	if !validID(invID) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		Accept bool `json:"accept"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "guild.invite.respond:"+invID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var guildID, targetID, status string
		err = tx.QueryRow(ctx, `SELECT guild_id::text,target_character_id::text,status FROM guild_invites WHERE id=$1 FOR UPDATE`, invID).
			Scan(&guildID, &targetID, &status)
		if errors.Is(err, pgx.ErrNoRows) || targetID != c.ID {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if status != "pending" {
			return nil, &apiError{409, "invite_resolved", "该帮派邀请已处理"}
		}
		nextStatus := "declined"
		if body.Accept {
			var onCD bool
			_ = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM guild_member_cooldowns WHERE character_id=$1 AND cooldown_until>now())`, c.ID).Scan(&onCD)
			if onCD {
				return nil, &apiError{409, "guild_cooldown", "退帮冷却期尚未结束"}
			}
			var inGuild bool
			_ = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM guild_members WHERE character_id=$1)`, c.ID).Scan(&inGuild)
			if inGuild {
				return nil, &apiError{409, "already_in_guild", "当前已加入其他帮派"}
			}
			var capCount, curCount int
			if err = tx.QueryRow(ctx, `SELECT member_cap FROM guilds WHERE id=$1 AND disbanded_at IS NULL FOR UPDATE`, guildID).Scan(&capCount); err != nil {
				return nil, &apiError{409, "guild_disbanded", "该帮派已解散"}
			}
			_ = tx.QueryRow(ctx, `SELECT count(*) FROM guild_members WHERE guild_id=$1`, guildID).Scan(&curCount)
			if curCount >= capCount {
				return nil, &apiError{409, "guild_full", "帮派成员人数已满"}
			}
			if _, err = tx.Exec(ctx, `INSERT INTO guild_members(guild_id,character_id,account_id,rank) VALUES($1,$2,$3,'member')`, guildID, c.ID, who.AccountID); err != nil {
				return nil, err
			}
			if err = appendGuildAuditTx(ctx, tx, guildID, c.ID, c.ID, "join", "", 0, nil); err != nil {
				return nil, err
			}
			nextStatus = "accepted"
		}
		if _, err = tx.Exec(ctx, `UPDATE guild_invites SET status=$2,resolved_at=now() WHERE id=$1`, invID, nextStatus); err != nil {
			return nil, err
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) updateGuildPermissions(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		TargetCharacterID   string `json:"target_character_id"`
		Rank                string `json:"rank"`
		CanInvite           bool   `json:"can_invite"`
		CanManageWarehouse  bool   `json:"can_manage_warehouse"`
		CanEditAnnouncement bool   `json:"can_edit_announcement"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if !validID(body.TargetCharacterID) || (body.Rank != "officer" && body.Rank != "member") {
		s.fail(w, bad("invalid_permission", "成员职级或权限参数无效"))
		return
	}
	data, err := s.command(r, who, "guild.permission:"+body.TargetCharacterID, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var guildID, rank string
		if err = tx.QueryRow(ctx, `SELECT m.guild_id::text,m.rank FROM guild_members m JOIN guilds g ON g.id=m.guild_id
            WHERE m.character_id=$1 AND g.disbanded_at IS NULL FOR UPDATE`, c.ID).Scan(&guildID, &rank); err != nil || rank != "leader" {
			return nil, &apiError{403, "leader_required", "仅会长可变更帮派成员职级与仓库权限"}
		}
		if body.TargetCharacterID == c.ID {
			return nil, bad("invalid_permission", "不能直接将自己降职")
		}
		tag, err := tx.Exec(ctx, `UPDATE guild_members SET rank=$3,can_invite=$4,can_manage_warehouse=$5,can_edit_announcement=$6
            WHERE guild_id=$1 AND character_id=$2`,
			guildID, body.TargetCharacterID, body.Rank, body.CanInvite, body.CanManageWarehouse, body.CanEditAnnouncement)
		if err != nil {
			return nil, err
		}
		if tag.RowsAffected() == 0 {
			return nil, &apiError{404, "member_not_found", "该角色不在本帮派中"}
		}
		touchGuildLeaderActivityTx(ctx, tx, guildID, c.ID)
		if err = appendGuildAuditTx(ctx, tx, guildID, c.ID, body.TargetCharacterID, "permission", "", 0, map[string]any{
			"rank": body.Rank, "can_invite": body.CanInvite, "can_manage_warehouse": body.CanManageWarehouse, "can_edit_announcement": body.CanEditAnnouncement,
		}); err != nil {
			return nil, err
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) updateGuildBanner(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		Announcement  string `json:"announcement"`
		DecorBanner   string `json:"decor_banner,omitempty"`
		DecorMonument string `json:"decor_monument,omitempty"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	ann := cleanText(body.Announcement)
	if utf8.RuneCountInString(ann) > 200 {
		s.fail(w, bad("invalid_announcement", "帮派公告不超过 200 字"))
		return
	}
	data, err := s.command(r, who, "guild.announcement", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var guildID, rank string
		var canAnn bool
		err = tx.QueryRow(ctx, `SELECT m.guild_id::text,m.rank,m.can_edit_announcement FROM guild_members m JOIN guilds g ON g.id=m.guild_id
            WHERE m.character_id=$1 AND g.disbanded_at IS NULL FOR UPDATE`, c.ID).Scan(&guildID, &rank, &canAnn)
		if err != nil {
			return nil, &apiError{409, "not_in_guild", "当前未加入帮派"}
		}
		if rank != "leader" && !canAnn {
			return nil, &apiError{403, "forbidden", "当前无公告或据点陈设权限"}
		}
		banner := strings.TrimSpace(body.DecorBanner)
		monument := strings.TrimSpace(body.DecorMonument)
		if _, err = tx.Exec(ctx, `UPDATE guilds SET announcement=$2,
            decor_banner=coalesce(nullif($3,''),decor_banner),
            decor_monument=coalesce(nullif($4,''),decor_monument),
            version=version+1,updated_at=now() WHERE id=$1`, guildID, ann, banner, monument); err != nil {
			return nil, err
		}
		touchGuildLeaderActivityTx(ctx, tx, guildID, c.ID)
		if err = appendGuildAuditTx(ctx, tx, guildID, c.ID, "", "decorate", "", 0, map[string]any{"announcement": ann, "banner": banner, "monument": monument}); err != nil {
			return nil, err
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) depositGuildWarehouse(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		ItemUID  string `json:"item_uid"`
		Quantity int    `json:"quantity"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if !validID(body.ItemUID) || body.Quantity <= 0 || body.Quantity > 99 {
		s.fail(w, bad("invalid_item", "存入帮派仓库的物品与数量不正确"))
		return
	}
	data, err := s.command(r, who, "guild.warehouse.deposit", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var guildID string
		if err = tx.QueryRow(ctx, `SELECT m.guild_id::text FROM guild_members m JOIN guilds g ON g.id=m.guild_id WHERE m.character_id=$1 AND g.disbanded_at IS NULL`, c.ID).Scan(&guildID); err != nil {
			return nil, &apiError{409, "not_in_guild", "需先加入帮派后才可存物"}
		}
		var tpl string
		var have int
		var bound bool
		var slot string
		err = tx.QueryRow(ctx, `SELECT template_id,quantity,bound,coalesce(equipped_slot,'') FROM inventory_items WHERE character_id=$1 AND item_uid=$2 AND quantity>0 FOR UPDATE`,
			c.ID, body.ItemUID).Scan(&tpl, &have, &bound, &slot)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &apiError{404, "item_not_found", "找不到该行囊物品"}
		}
		if err != nil {
			return nil, err
		}
		if slot != "" {
			return nil, bad("item_equipped", "已装备物品不可存入")
		}
		it := journey.Items[tpl]
		if !bound || it.Tradeable || !rules.allowsWarehouseMaterial(tpl) {
			return nil, bad("tradeable_item_forbidden", "帮派仓库先只收不可交易的协作建筑材料")
		}
		if body.Quantity > have {
			return nil, bad("invalid_quantity", "可用建筑材料数量不足")
		}
		var after int
		if err = tx.QueryRow(ctx, `UPDATE inventory_items SET quantity=quantity-$1,version=version+1,updated_at=now() WHERE character_id=$2 AND item_uid=$3 RETURNING quantity`,
			body.Quantity, c.ID, body.ItemUID).Scan(&after); err != nil {
			return nil, err
		}
		if err = appendInventoryLedger(ctx, tx, c.ID, body.ItemUID, "guild_dep:"+newID(), "consume", -body.Quantity, after, ""); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO guild_warehouse(guild_id,template_id,quantity,updated_at) VALUES($1,$2,$3,now())
            ON CONFLICT (guild_id,template_id) DO UPDATE SET quantity=guild_warehouse.quantity+$3,updated_at=now()`,
			guildID, tpl, body.Quantity); err != nil {
			return nil, err
		}
		pts := body.Quantity * 10
		_, _ = tx.Exec(ctx, `UPDATE guild_members SET contribution_points=contribution_points+$2 WHERE character_id=$1`, c.ID, pts)
		touchGuildLeaderActivityTx(ctx, tx, guildID, c.ID)
		if err = appendGuildAuditTx(ctx, tx, guildID, c.ID, "", "warehouse_deposit", tpl, body.Quantity, map[string]any{"points": pts}); err != nil {
			return nil, err
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) withdrawGuildWarehouse(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		TemplateID string `json:"template_id"`
		Quantity   int    `json:"quantity"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if !rules.allowsWarehouseMaterial(body.TemplateID) || body.Quantity <= 0 || body.Quantity > 99 {
		s.fail(w, bad("invalid_item", "帮派仓库取出参数不正确"))
		return
	}
	data, err := s.command(r, who, "guild.warehouse.withdraw", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var guildID, rank string
		var canWH bool
		err = tx.QueryRow(ctx, `SELECT m.guild_id::text,m.rank,m.can_manage_warehouse FROM guild_members m JOIN guilds g ON g.id=m.guild_id
            WHERE m.character_id=$1 AND g.disbanded_at IS NULL FOR UPDATE`, c.ID).Scan(&guildID, &rank, &canWH)
		if err != nil {
			return nil, &apiError{409, "not_in_guild", "当前未加入帮派"}
		}
		if rank != "leader" && !canWH {
			return nil, &apiError{403, "forbidden", "当前权限不可从帮派仓库提取材料"}
		}
		var have int
		err = tx.QueryRow(ctx, `SELECT quantity FROM guild_warehouse WHERE guild_id=$1 AND template_id=$2 FOR UPDATE`, guildID, body.TemplateID).Scan(&have)
		if errors.Is(err, pgx.ErrNoRows) || have < body.Quantity {
			return nil, &apiError{409, "insufficient_warehouse", "帮派仓库对应材料库存不足"}
		}
		if err != nil {
			return nil, err
		}
		if _, err = grantCustomPackItemTx(ctx, tx, c.ID, "guild_wd:"+newID(), journey.PackSlots, body.TemplateID, body.Quantity, true, []byte(`{"origin":"guild_warehouse"}`)); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE guild_warehouse SET quantity=quantity-$3,updated_at=now() WHERE guild_id=$1 AND template_id=$2`,
			guildID, body.TemplateID, body.Quantity); err != nil {
			return nil, err
		}
		touchGuildLeaderActivityTx(ctx, tx, guildID, c.ID)
		if err = appendGuildAuditTx(ctx, tx, guildID, c.ID, "", "warehouse_withdraw", body.TemplateID, body.Quantity, nil); err != nil {
			return nil, err
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) contributeGuildTask(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		TemplateID string `json:"template_id"`
		Quantity   int    `json:"quantity"`
	}
	if err = decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if !rules.allowsWarehouseMaterial(body.TemplateID) || body.Quantity <= 0 || body.Quantity > 99 {
		s.fail(w, bad("invalid_item", "帮派建设消耗参数不正确"))
		return
	}
	data, err := s.command(r, who, "guild.task.contribute", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var guildID string
		if err = tx.QueryRow(ctx, `SELECT m.guild_id::text FROM guild_members m JOIN guilds g ON g.id=m.guild_id WHERE m.character_id=$1 AND g.disbanded_at IS NULL`, c.ID).Scan(&guildID); err != nil {
			return nil, &apiError{409, "not_in_guild", "当前未加入帮派"}
		}
		var have int
		err = tx.QueryRow(ctx, `SELECT quantity FROM guild_warehouse WHERE guild_id=$1 AND template_id=$2 FOR UPDATE`, guildID, body.TemplateID).Scan(&have)
		if errors.Is(err, pgx.ErrNoRows) || have < body.Quantity {
			return nil, &apiError{409, "insufficient_warehouse", "请先向帮派仓库存入足够建材"}
		}
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE guild_warehouse SET quantity=quantity-$3,updated_at=now() WHERE guild_id=$1 AND template_id=$2`, guildID, body.TemplateID, body.Quantity); err != nil {
			return nil, err
		}
		gainPts := body.Quantity * 25
		var totalPts int
		if err = tx.QueryRow(ctx, `UPDATE guilds SET weekly_coop_points=weekly_coop_points+$2,
            member_cap=LEAST($3, $4 + ((weekly_coop_points+$2) / $5)),
            decor_level=LEAST(10, 1 + ((weekly_coop_points+$2) / 50)),
            version=version+1,updated_at=now() WHERE id=$1 RETURNING weekly_coop_points`,
			guildID, gainPts, rules.MaxMemberCap, rules.BaseMemberCap, rules.WeeklyPointsPerSlot).Scan(&totalPts); err != nil {
			return nil, err
		}
		_, _ = tx.Exec(ctx, `UPDATE guild_members SET contribution_points=contribution_points+$2 WHERE character_id=$1`, c.ID, gainPts)
		touchGuildLeaderActivityTx(ctx, tx, guildID, c.ID)
		if err = appendGuildAuditTx(ctx, tx, guildID, c.ID, "", "weekly_task", body.TemplateID, body.Quantity, map[string]any{"weekly_points": totalPts}); err != nil {
			return nil, err
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) leaveGuild(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "guild.leave", struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var guildID, rank string
		err = tx.QueryRow(ctx, `SELECT m.guild_id::text,m.rank FROM guild_members m JOIN guilds g ON g.id=m.guild_id
            WHERE m.character_id=$1 AND g.disbanded_at IS NULL FOR UPDATE`, c.ID).Scan(&guildID, &rank)
		if err != nil {
			return nil, &apiError{409, "not_in_guild", "当前未加入帮派"}
		}
		var memCount int
		_ = tx.QueryRow(ctx, `SELECT count(*) FROM guild_members WHERE guild_id=$1`, guildID).Scan(&memCount)
		if rank == "leader" && memCount > 1 {
			return nil, &apiError{409, "leader_must_handoff", "会长退出前需先移交会长职位"}
		}
		if _, err = tx.Exec(ctx, `DELETE FROM guild_members WHERE character_id=$1`, c.ID); err != nil {
			return nil, err
		}
		cdUntil := time.Now().UTC().Add(time.Duration(rules.LeaveCooldownSeconds) * time.Second)
		if _, err = tx.Exec(ctx, `INSERT INTO guild_member_cooldowns(character_id,cooldown_until,updated_at) VALUES($1,$2,now())
            ON CONFLICT (character_id) DO UPDATE SET cooldown_until=$2,updated_at=now()`, c.ID, cdUntil); err != nil {
			return nil, err
		}
		if rank == "leader" && memCount == 1 {
			if _, err = tx.Exec(ctx, `UPDATE guilds SET disbanded_at=now(),updated_at=now() WHERE id=$1`, guildID); err != nil {
				return nil, err
			}
			_ = appendGuildAuditTx(ctx, tx, guildID, c.ID, "", "disband", "", 0, nil)
		} else {
			_ = appendGuildAuditTx(ctx, tx, guildID, c.ID, "", "leave", "", 0, nil)
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) transferGuildLeader(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
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
		s.fail(w, bad("invalid_character", "目标成员无效"))
		return
	}
	data, err := s.command(r, who, "guild.leader", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var guildID, rank string
		if err = tx.QueryRow(ctx, `SELECT m.guild_id::text,m.rank FROM guild_members m JOIN guilds g ON g.id=m.guild_id WHERE m.character_id=$1 AND g.disbanded_at IS NULL FOR UPDATE`, c.ID).Scan(&guildID, &rank); err != nil || rank != "leader" {
			return nil, &apiError{403, "leader_required", "仅现任会长可移交会长职位"}
		}
		var targetExists bool
		_ = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM guild_members WHERE guild_id=$1 AND character_id=$2)`, guildID, body.TargetCharacterID).Scan(&targetExists)
		if !targetExists || body.TargetCharacterID == c.ID {
			return nil, bad("invalid_target", "只能向帮派内其他成员移交会长")
		}
		if _, err = tx.Exec(ctx, `UPDATE guild_members SET rank='officer',can_invite=true WHERE guild_id=$1 AND character_id=$2`, guildID, c.ID); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE guild_members SET rank='leader',can_invite=true,can_manage_warehouse=true,can_edit_announcement=true WHERE guild_id=$1 AND character_id=$2`, guildID, body.TargetCharacterID); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE guilds SET leader_character_id=$2,last_leader_active_at=now(),updated_at=now() WHERE id=$1`, guildID, body.TargetCharacterID); err != nil {
			return nil, err
		}
		if err = appendGuildAuditTx(ctx, tx, guildID, c.ID, body.TargetCharacterID, "leader_handoff", "", 0, nil); err != nil {
			return nil, err
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) claimInactiveGuildLeader(w http.ResponseWriter, r *http.Request, who identity) {
	rules, journey, err := s.requireGuilds()
	if err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "guild.claim_inactive", struct{}{}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var guildID, rank, prevLeader string
		var lastActive time.Time
		err = tx.QueryRow(ctx, `SELECT m.guild_id::text,m.rank,g.leader_character_id::text,g.last_leader_active_at
            FROM guild_members m JOIN guilds g ON g.id=m.guild_id WHERE m.character_id=$1 AND g.disbanded_at IS NULL FOR UPDATE`, c.ID).
			Scan(&guildID, &rank, &prevLeader, &lastActive)
		if err != nil {
			return nil, &apiError{409, "not_in_guild", "当前未加入帮派"}
		}
		if prevLeader == c.ID {
			return nil, bad("already_leader", "你已是当前帮派会长")
		}
		if time.Since(lastActive) < time.Duration(rules.LeaderInactiveSeconds)*time.Second {
			return nil, &apiError{409, "leader_still_active", "原会长尚未超过公开移交离线时限"}
		}
		if _, err = tx.Exec(ctx, `UPDATE guild_members SET rank='member' WHERE guild_id=$1 AND character_id=$2`, guildID, prevLeader); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE guild_members SET rank='leader',can_invite=true,can_manage_warehouse=true,can_edit_announcement=true WHERE guild_id=$1 AND character_id=$2`, guildID, c.ID); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE guilds SET leader_character_id=$2,last_leader_active_at=now(),updated_at=now() WHERE id=$1`, guildID, c.ID); err != nil {
			return nil, err
		}
		if err = appendGuildAuditTx(ctx, tx, guildID, c.ID, prevLeader, "leader_claim_inactive", "", 0, map[string]any{"previous_rank": rank}); err != nil {
			return nil, err
		}
		return s.buildGuildSnapshotTx(ctx, tx, rules, journey, c)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
