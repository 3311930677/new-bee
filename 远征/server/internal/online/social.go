package online

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/jackc/pgx/v5"
)

type friendEntry struct {
	ID       string `json:"id"`
	Nickname string `json:"nickname"`
	RoleID   string `json:"role_id"`
	AvatarID string `json:"avatar_id"`
	Level    int    `json:"level"`
	Online   bool   `json:"online"`
	MapID    string `json:"map_id,omitempty"`
}

type friendRequestEntry struct {
	ID         string    `json:"id"`
	SenderID   string    `json:"sender_id"`
	Nickname   string    `json:"nickname"`
	RoleID     string    `json:"role_id"`
	Direction  string    `json:"direction"`
	CreatedAt  time.Time `json:"created_at"`
}

type blockEntry struct {
	AccountID string    `json:"account_id"`
	Nickname  string    `json:"nickname,omitempty"`
	BlockedAt time.Time `json:"blocked_at"`
}

type socialSnapshot struct {
	Friends        []friendEntry        `json:"friends"`
	FriendRequests []friendRequestEntry `json:"friend_requests"`
	Blocks         []blockEntry         `json:"blocks"`
	Party          *partyInfo           `json:"party"`
	Invitations    []partyInvite        `json:"invitations"`
}

type chatMessage struct {
	ID          int64     `json:"id"`
	ChannelKind string    `json:"channel_kind"`
	MapID       string    `json:"map_id"`
	SenderID    string    `json:"sender_id"`
	SenderName  string    `json:"sender_nickname"`
	SenderRole  string    `json:"sender_role_id"`
	RecipientID string    `json:"recipient_id,omitempty"`
	Content     string    `json:"content"`
	CreatedAt   time.Time `json:"created_at"`
}

func orderedFriendPair(a, b string) (string, string) {
	if a < b {
		return a, b
	}
	return b, a
}

func accountsBlocked(ctx context.Context, tx pgx.Tx, acctA, acctB string) (bool, error) {
	if acctA == acctB {
		return false, nil
	}
	var blocked bool
	err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM player_blocks WHERE (owner_account_id=$1 AND blocked_account_id=$2) OR (owner_account_id=$2 AND blocked_account_id=$1))`,
		acctA, acctB).Scan(&blocked)
	return blocked, err
}

func cleanText(raw string) string {
	cleaned := strings.Map(func(r rune) rune {
		if r < 32 {
			return -1
		}
		return r
	}, raw)
	return strings.TrimSpace(cleaned)
}

func readSocialSnapshot(ctx context.Context, tx pgx.Tx, charID, accountID string) (socialSnapshot, error) {
	out := socialSnapshot{
		Friends:        []friendEntry{},
		FriendRequests: []friendRequestEntry{},
		Blocks:         []blockEntry{},
		Invitations:    []partyInvite{},
	}
	rows, err := tx.Query(ctx, `SELECT c.id::text,c.nickname,c.role_id,c.avatar_id,c.level,
		s.id IS NOT NULL,coalesce(i.map_id,'')
		FROM friendships f
		JOIN characters c ON c.id=CASE WHEN f.character_a=$1 THEN f.character_b ELSE f.character_a END
		LEFT JOIN room_leases l ON l.account_id=c.account_id AND l.character_id=c.id AND l.expires_at>now()
		LEFT JOIN room_instances i ON i.id=l.room_id
		LEFT JOIN sessions s ON s.id=l.session_id AND s.active_character_id=c.id AND s.revoked_at IS NULL AND s.expires_at>now() AND s.access_expires_at>now()
		WHERE (f.character_a=$1 OR f.character_b=$1) AND c.deleted_at IS NULL
		  AND NOT EXISTS(SELECT 1 FROM player_blocks b WHERE (b.owner_account_id,b.blocked_account_id) IN (($2,c.account_id),(c.account_id,$2)))
		ORDER BY c.nickname,c.id`, charID, accountID)
	if err != nil {
		return out, err
	}
	for rows.Next() {
		var item friendEntry
		if err = rows.Scan(&item.ID, &item.Nickname, &item.RoleID, &item.AvatarID, &item.Level, &item.Online, &item.MapID); err != nil {
			rows.Close()
			return out, err
		}
		out.Friends = append(out.Friends, item)
	}
	rows.Close()
	if err = rows.Err(); err != nil {
		return out, err
	}

	reqRows, err := tx.Query(ctx, `SELECT r.id::text,
		CASE WHEN r.recipient_character_id=$1 THEN sc.id::text ELSE rc.id::text END,
		CASE WHEN r.recipient_character_id=$1 THEN sc.nickname ELSE rc.nickname END,
		CASE WHEN r.recipient_character_id=$1 THEN sc.role_id ELSE rc.role_id END,
		CASE WHEN r.recipient_character_id=$1 THEN 'incoming' ELSE 'outgoing' END,
		r.created_at
		FROM friend_requests r
		JOIN characters sc ON sc.id=r.sender_character_id
		JOIN characters rc ON rc.id=r.recipient_character_id
		WHERE r.status='pending' AND (r.recipient_character_id=$1 OR r.sender_character_id=$1)
		  AND sc.deleted_at IS NULL AND rc.deleted_at IS NULL
		  AND NOT EXISTS(SELECT 1 FROM player_blocks b WHERE (b.owner_account_id,b.blocked_account_id) IN ((sc.account_id,rc.account_id),(rc.account_id,sc.account_id)))
		ORDER BY r.created_at,r.id LIMIT 20`, charID)
	if err != nil {
		return out, err
	}
	for reqRows.Next() {
		var req friendRequestEntry
		if err = reqRows.Scan(&req.ID, &req.SenderID, &req.Nickname, &req.RoleID, &req.Direction, &req.CreatedAt); err != nil {
			reqRows.Close()
			return out, err
		}
		out.FriendRequests = append(out.FriendRequests, req)
	}
	reqRows.Close()
	if err = reqRows.Err(); err != nil {
		return out, err
	}

	blkRows, err := tx.Query(ctx, `SELECT b.blocked_account_id::text,
		coalesce((SELECT c.nickname FROM characters c WHERE c.account_id=b.blocked_account_id AND c.deleted_at IS NULL ORDER BY c.created_at LIMIT 1),''),
		b.blocked_at
		FROM player_blocks b WHERE b.owner_account_id=$1 ORDER BY b.blocked_at DESC`, accountID)
	if err != nil {
		return out, err
	}
	for blkRows.Next() {
		var blk blockEntry
		if err = blkRows.Scan(&blk.AccountID, &blk.Nickname, &blk.BlockedAt); err != nil {
			blkRows.Close()
			return out, err
		}
		out.Blocks = append(out.Blocks, blk)
	}
	blkRows.Close()
	if err = blkRows.Err(); err != nil {
		return out, err
	}

	pv, err := readPartyView(ctx, tx, charID, accountID)
	if err != nil {
		return out, err
	}
	out.Party = pv.Party
	out.Invitations = pv.Invitations
	return out, nil
}

func (s *Server) socialState(w http.ResponseWriter, r *http.Request, who identity) {
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
	snap, err := readSocialSnapshot(r.Context(), tx, c.ID, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, snap)
}

func (s *Server) socialCommand(w http.ResponseWriter, r *http.Request, who identity, op string, body any, effect func(context.Context, pgx.Tx, Character) error) {
	if err := decode(r, body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, op, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if err = effect(ctx, tx, c); err != nil {
			return nil, err
		}
		return readSocialSnapshot(ctx, tx, c.ID, who.AccountID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) requestFriend(w http.ResponseWriter, r *http.Request, who identity) {
	var body struct {
		TargetCharacterID string `json:"target_character_id"`
	}
	s.socialCommand(w, r, who, "social.friend_request", &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		if !validID(body.TargetCharacterID) || body.TargetCharacterID == c.ID {
			return bad("invalid_target", "请选择其他旅人发送好友申请")
		}
		var targetAccount string
		err := tx.QueryRow(ctx, `SELECT account_id::text FROM characters WHERE id=$1 AND deleted_at IS NULL`, body.TargetCharacterID).Scan(&targetAccount)
		if errors.Is(err, pgx.ErrNoRows) {
			return errNotFound
		}
		if err != nil {
			return err
		}
		if blocked, bErr := accountsBlocked(ctx, tx, who.AccountID, targetAccount); bErr != nil {
			return bErr
		} else if blocked {
			return &apiError{403, "player_blocked", "双方存在屏蔽关系，无法添加好友"}
		}
		a, b := orderedFriendPair(c.ID, body.TargetCharacterID)
		var already bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM friendships WHERE character_a=$1 AND character_b=$2)`, a, b).Scan(&already); err != nil {
			return err
		}
		if already {
			return &apiError{409, "already_friends", "你们已经是好友了"}
		}
		// Auto-accept if reciprocal pending invite exists.
		var reqID, sender string
		err = tx.QueryRow(ctx, `SELECT id::text,sender_character_id::text FROM friend_requests
			WHERE status='pending' AND ((sender_character_id=$1 AND recipient_character_id=$2) OR (sender_character_id=$2 AND recipient_character_id=$1)) FOR UPDATE`,
			c.ID, body.TargetCharacterID).Scan(&reqID, &sender)
		if err == nil {
			if sender == c.ID {
				return &apiError{409, "request_exists", "已经发送过好友申请"}
			}
			if _, err = tx.Exec(ctx, `UPDATE friend_requests SET status='accepted',resolved_at=now() WHERE id=$1`, reqID); err != nil {
				return err
			}
			_, err = tx.Exec(ctx, `INSERT INTO friendships(character_a,character_b) VALUES($1,$2) ON CONFLICT DO NOTHING`, a, b)
			return err
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		_, err = tx.Exec(ctx, `INSERT INTO friend_requests(id,sender_character_id,recipient_character_id) VALUES($1,$2,$3)`, newID(), c.ID, body.TargetCharacterID)
		return err
	})
}

func (s *Server) respondFriendRequest(w http.ResponseWriter, r *http.Request, who identity) {
	reqID := r.PathValue("id")
	if !validID(reqID) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		Accept *bool `json:"accept"`
	}
	s.socialCommand(w, r, who, "social.friend_respond:"+reqID, &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		if body.Accept == nil {
			return bad("invalid_response", "请选择同意或拒绝")
		}
		var senderID, senderAccount, status string
		err := tx.QueryRow(ctx, `SELECT r.sender_character_id::text,sc.account_id::text,r.status
			FROM friend_requests r JOIN characters sc ON sc.id=r.sender_character_id
			WHERE r.id=$1 AND r.recipient_character_id=$2 FOR UPDATE OF r`, reqID, c.ID).Scan(&senderID, &senderAccount, &status)
		if errors.Is(err, pgx.ErrNoRows) {
			return errNotFound
		}
		if err != nil {
			return err
		}
		if status != "pending" {
			return &apiError{409, "request_resolved", "该好友申请已处理"}
		}
		if !*body.Accept {
			_, err = tx.Exec(ctx, `UPDATE friend_requests SET status='declined',resolved_at=now() WHERE id=$1`, reqID)
			return err
		}
		if blocked, bErr := accountsBlocked(ctx, tx, who.AccountID, senderAccount); bErr != nil {
			return bErr
		} else if blocked {
			return &apiError{403, "player_blocked", "双方存在屏蔽关系，无法成为好友"}
		}
		if _, err = tx.Exec(ctx, `UPDATE friend_requests SET status='accepted',resolved_at=now() WHERE id=$1`, reqID); err != nil {
			return err
		}
		a, b := orderedFriendPair(c.ID, senderID)
		_, err = tx.Exec(ctx, `INSERT INTO friendships(character_a,character_b) VALUES($1,$2) ON CONFLICT DO NOTHING`, a, b)
		return err
	})
}

func (s *Server) removeFriend(w http.ResponseWriter, r *http.Request, who identity) {
	targetID := r.PathValue("id")
	if !validID(targetID) {
		s.fail(w, errNotFound)
		return
	}
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
	a, b := orderedFriendPair(c.ID, targetID)
	if _, err = tx.Exec(r.Context(), `DELETE FROM friendships WHERE character_a=$1 AND character_b=$2`, a, b); err != nil {
		s.fail(w, err)
		return
	}
	snap, err := readSocialSnapshot(r.Context(), tx, c.ID, who.AccountID)
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, snap)
}

func (s *Server) blockPlayer(w http.ResponseWriter, r *http.Request, who identity) {
	var body struct {
		TargetCharacterID string `json:"target_character_id"`
	}
	s.socialCommand(w, r, who, "social.block", &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		if !validID(body.TargetCharacterID) || body.TargetCharacterID == c.ID {
			return bad("invalid_target", "请选择要屏蔽的旅人")
		}
		var targetAccount string
		err := tx.QueryRow(ctx, `SELECT account_id::text FROM characters WHERE id=$1 AND deleted_at IS NULL`, body.TargetCharacterID).Scan(&targetAccount)
		if errors.Is(err, pgx.ErrNoRows) {
			return errNotFound
		}
		if err != nil {
			return err
		}
		if targetAccount == who.AccountID {
			return bad("invalid_target", "不能屏蔽自己的账号")
		}
		if _, err = tx.Exec(ctx, `INSERT INTO player_blocks(owner_account_id,blocked_account_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, who.AccountID, targetAccount); err != nil {
			return err
		}
		// Clean up friendships and pending requests/invites between both accounts.
		if _, err = tx.Exec(ctx, `DELETE FROM friendships f USING characters ca, characters cb
			WHERE ca.id=f.character_a AND cb.id=f.character_b
			  AND ((ca.account_id=$1 AND cb.account_id=$2) OR (ca.account_id=$2 AND cb.account_id=$1))`, who.AccountID, targetAccount); err != nil {
			return err
		}
		if _, err = tx.Exec(ctx, `UPDATE friend_requests r SET status='cancelled',resolved_at=now()
			FROM characters cs, characters cr
			WHERE cs.id=r.sender_character_id AND cr.id=r.recipient_character_id AND r.status='pending'
			  AND ((cs.account_id=$1 AND cr.account_id=$2) OR (cs.account_id=$2 AND cr.account_id=$1))`, who.AccountID, targetAccount); err != nil {
			return err
		}
		_, err = tx.Exec(ctx, `UPDATE party_invites i SET status='cancelled',resolved_at=now()
			FROM characters cs, characters cr
			WHERE cs.id=i.sender_id AND cr.id=i.recipient_id AND i.status='pending'
			  AND ((cs.account_id=$1 AND cr.account_id=$2) OR (cs.account_id=$2 AND cr.account_id=$1))`, who.AccountID, targetAccount)
		return err
	})
}

func (s *Server) unblockPlayer(w http.ResponseWriter, r *http.Request, who identity) {
	targetAccount := r.PathValue("account_id")
	if !validID(targetAccount) {
		s.fail(w, errNotFound)
		return
	}
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
	if _, err = tx.Exec(r.Context(), `DELETE FROM player_blocks WHERE owner_account_id=$1 AND blocked_account_id=$2`, who.AccountID, targetAccount); err != nil {
		s.fail(w, err)
		return
	}
	snap, err := readSocialSnapshot(r.Context(), tx, c.ID, who.AccountID)
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, snap)
}

func (s *Server) reportPlayer(w http.ResponseWriter, r *http.Request, who identity) {
	if !s.limiter.allow("report:"+who.AccountID, 5, time.Minute) {
		s.fail(w, &apiError{429, "rate_limited", "举报操作过于频繁"})
		return
	}
	var body struct {
		TargetCharacterID string `json:"target_character_id"`
		Category          string `json:"category"`
		Reason            string `json:"reason"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	switch body.Category {
	case "harassment", "spam", "cheating", "inappropriate_name":
	default:
		s.fail(w, bad("invalid_category", "请选择有效的举报分类"))
		return
	}
	reason := cleanText(body.Reason)
	if n := utf8.RuneCountInString(reason); n < 1 || n > 200 {
		s.fail(w, bad("invalid_reason", "举报说明需在 1–200 字之间"))
		return
	}
	if !validID(body.TargetCharacterID) {
		s.fail(w, bad("invalid_target", "请选择有效的举报对象"))
		return
	}
	data, err := s.command(r, who, "social.report", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		var targetAccount string
		err = tx.QueryRow(ctx, `SELECT account_id::text FROM characters WHERE id=$1`, body.TargetCharacterID).Scan(&targetAccount)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if targetAccount == who.AccountID {
			return nil, bad("invalid_target", "不能举报自己")
		}
		var roomID any
		if l, leaseErr := s.lease(ctx, tx, who, c.ID); leaseErr == nil {
			roomID = l.RoomID
		}
		reportID := newID()
		if _, err = tx.Exec(ctx, `INSERT INTO player_reports(id,reporter_account_id,reporter_character_id,target_account_id,target_character_id,category,reason,room_id)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8)`, reportID, who.AccountID, c.ID, targetAccount, body.TargetCharacterID, body.Category, reason, roomID); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO audit_events(account_id,character_id,action) VALUES($1,$2,'social.report')`, who.AccountID, c.ID); err != nil {
			return nil, err
		}
		return map[string]any{"report_id": reportID, "recorded": true}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 201, data)
}

func (s *Server) sendChatMessage(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
	if !s.limiter.allow("chat:"+who.AccountID, 6, 10*time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "发言过于频繁，请稍候再试"})
		return
	}
	var body struct {
		ChannelKind          string `json:"channel_kind"`
		Content              string `json:"content"`
		RecipientCharacterID string `json:"recipient_character_id,omitempty"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	switch body.ChannelKind {
	case "room", "nearby", "party", "whisper":
	default:
		s.fail(w, bad("invalid_channel", "不支持的聊天频道"))
		return
	}
	content := cleanText(body.Content)
	if n := utf8.RuneCountInString(content); n < 1 || n > 120 {
		s.fail(w, bad("invalid_content", "消息内容需在 1–120 字之间"))
		return
	}
	data, err := s.command(r, who, "chat.send", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		l, err := s.lease(ctx, tx, who, c.ID)
		if err != nil {
			return nil, err
		}
		var partyArg, recipientArg any
		if body.ChannelKind == "party" {
			var pid string
			err = tx.QueryRow(ctx, `SELECT party_id::text FROM party_members WHERE character_id=$1`, c.ID).Scan(&pid)
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, errParty
			}
			if err != nil {
				return nil, err
			}
			partyArg = pid
		} else if body.RecipientCharacterID != "" && body.ChannelKind != "whisper" {
			return nil, bad("invalid_recipient", "只有私聊可以指定收件角色")
		}
		if body.ChannelKind == "whisper" {
			if !validID(body.RecipientCharacterID) || body.RecipientCharacterID == c.ID {
				return nil, bad("invalid_recipient", "请选择私聊对象")
			}
			var targetAccount string
			err = tx.QueryRow(ctx, `SELECT account_id::text FROM characters WHERE id=$1 AND deleted_at IS NULL`, body.RecipientCharacterID).Scan(&targetAccount)
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, errNotFound
			}
			if err != nil {
				return nil, err
			}
			if blocked, bErr := accountsBlocked(ctx, tx, who.AccountID, targetAccount); bErr != nil {
				return nil, bErr
			} else if blocked {
				return nil, &apiError{403, "player_blocked", "双方存在屏蔽关系，无法私聊"}
			}
			recipientArg = body.RecipientCharacterID
		}
		var msg chatMessage
		var rec string
		err = tx.QueryRow(ctx, `INSERT INTO chat_messages(channel_kind,room_id,party_id,map_id,sender_account_id,sender_character_id,sender_nickname,sender_role_id,sender_x,sender_y,recipient_character_id,content)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
			RETURNING id,channel_kind,map_id,sender_character_id::text,sender_nickname,sender_role_id,coalesce(recipient_character_id::text,''),content,created_at`,
			body.ChannelKind, l.RoomID, partyArg, l.MapID, who.AccountID, c.ID, c.Nickname, c.RoleID, l.X, l.Y, recipientArg, content).Scan(
			&msg.ID, &msg.ChannelKind, &msg.MapID, &msg.SenderID, &msg.SenderName, &msg.SenderRole, &rec, &msg.Content, &msg.CreatedAt)
		if err != nil {
			return nil, err
		}
		msg.RecipientID = rec
		return map[string]any{"message": msg}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 201, data)
}

func (s *Server) listChatMessages(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	var afterID int64
	if raw := r.URL.Query().Get("after_id"); raw != "" {
		parsed, err := strconv.ParseInt(raw, 10, 64)
		if err != nil || parsed < 0 {
			s.fail(w, bad("invalid_after_id", "消息游标无效"))
			return
		}
		afterID = parsed
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	l, err := s.lease(r.Context(), tx, who, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	var partyID string
	err = tx.QueryRow(r.Context(), `SELECT party_id::text FROM party_members WHERE character_id=$1`, c.ID).Scan(&partyID)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, err)
		return
	}
	var partyArg any
	if partyID != "" {
		partyArg = partyID
	}
	rows, err := tx.Query(r.Context(), `SELECT id,channel_kind,map_id,sender_character_id::text,sender_nickname,sender_role_id,coalesce(recipient_character_id::text,''),content,created_at FROM (
		SELECT m.id,m.channel_kind,m.map_id,m.sender_character_id,m.sender_nickname,m.sender_role_id,m.recipient_character_id,m.content,m.created_at
		FROM chat_messages m
		WHERE m.id > $1
		  AND NOT EXISTS(SELECT 1 FROM player_blocks b WHERE (b.owner_account_id,b.blocked_account_id) IN (($2,m.sender_account_id),(m.sender_account_id,$2)))
		  AND (
			(m.channel_kind='room' AND m.room_id=$3) OR
			(m.channel_kind='nearby' AND m.room_id=$3 AND ((m.sender_x-$4)*(m.sender_x-$4)+(m.sender_y-$5)*(m.sender_y-$5)) <= $6) OR
			($7::uuid IS NOT NULL AND m.channel_kind='party' AND m.party_id=$7::uuid) OR
			(m.channel_kind='whisper' AND (m.sender_character_id=$8 OR m.recipient_character_id=$8))
		  )
		ORDER BY m.id DESC LIMIT 50
	) sub ORDER BY id ASC`, afterID, who.AccountID, l.RoomID, l.X, l.Y, worldPositionRange*worldPositionRange, partyArg, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer rows.Close()
	messages := []chatMessage{}
	for rows.Next() {
		var m chatMessage
		if err = rows.Scan(&m.ID, &m.ChannelKind, &m.MapID, &m.SenderID, &m.SenderName, &m.SenderRole, &m.RecipientID, &m.Content, &m.CreatedAt); err != nil {
			s.fail(w, err)
			return
		}
		messages = append(messages, m)
	}
	if rows.Err() != nil {
		s.fail(w, rows.Err())
		return
	}
	respond(w, 200, map[string]any{"messages": messages})
}
