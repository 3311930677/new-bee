package online

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
)

const partySize = 4

var errParty = &apiError{409, "party_required", "你还没有队伍"}
var errPartyLeader = &apiError{403, "party_leader_required", "只有当前队长可以执行这项操作"}
var errPartyInvite = &apiError{409, "party_invite_unavailable", "这条组队邀请已经失效"}

type partyMember struct {
	ID       string `json:"id"`
	Nickname string `json:"nickname"`
	RoleID   string `json:"role_id"`
	AvatarID string `json:"avatar_id"`
	Level    int    `json:"level"`
	Pet      string `json:"pet,omitempty"`
	Online   bool   `json:"online"`
	Ready    bool   `json:"ready"`
}

type partyInvite struct {
	ID        string    `json:"id"`
	PartyID   string    `json:"party_id"`
	Sender    string    `json:"sender_id"`
	Nickname  string    `json:"nickname"`
	RoleID    string    `json:"role_id"`
	ExpiresAt time.Time `json:"expires_at"`
}

type partyInfo struct {
	ID      string        `json:"id"`
	Leader  string        `json:"leader_id"`
	Version int64         `json:"version"`
	Members []partyMember `json:"members"`
}

type partyView struct {
	Party       *partyInfo    `json:"party"`
	Invitations []partyInvite `json:"invitations"`
}

func lockCharacterParty(ctx context.Context, tx pgx.Tx, id string) (partyInfo, error) {
	var info partyInfo
	err := tx.QueryRow(ctx, `SELECT p.id::text,p.leader_character_id::text,p.version FROM parties p
		JOIN party_members m ON m.party_id=p.id WHERE m.character_id=$1 FOR UPDATE OF p`, id).Scan(&info.ID, &info.Leader, &info.Version)
	if errors.Is(err, pgx.ErrNoRows) {
		return info, errParty
	}
	return info, err
}

func readPartyView(ctx context.Context, tx pgx.Tx, characterID, accountID string) (partyView, error) {
	view := partyView{Invitations: []partyInvite{}}
	var info partyInfo
	err := tx.QueryRow(ctx, `SELECT p.id::text,p.leader_character_id::text,p.version FROM party_members m JOIN parties p ON p.id=m.party_id
		WHERE m.character_id=$1`, characterID).Scan(&info.ID, &info.Leader, &info.Version)
	if err == nil {
		view.Party = &info
		info.Members, err = readPartyMembers(ctx, tx, info.ID)
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return view, err
	}
	rows, err := tx.Query(ctx, `SELECT i.id::text,i.party_id::text,i.sender_id::text,c.nickname,c.role_id,i.expires_at
		FROM party_invites i JOIN characters c ON c.id=i.sender_id JOIN parties p ON p.id=i.party_id
		WHERE i.recipient_id=$1 AND i.status='pending' AND i.expires_at>now() AND c.deleted_at IS NULL AND p.leader_character_id=i.sender_id
		  AND NOT EXISTS(SELECT 1 FROM player_blocks b WHERE (b.owner_account_id,b.blocked_account_id) IN (($2,c.account_id),(c.account_id,$2)))
		ORDER BY i.created_at,i.id LIMIT 12`, characterID, accountID)
	if err != nil {
		return view, err
	}
	defer rows.Close()
	for rows.Next() {
		var invite partyInvite
		if err := rows.Scan(&invite.ID, &invite.PartyID, &invite.Sender, &invite.Nickname, &invite.RoleID, &invite.ExpiresAt); err != nil {
			return view, err
		}
		view.Invitations = append(view.Invitations, invite)
	}
	return view, rows.Err()
}

func readPartyMembers(ctx context.Context, tx pgx.Tx, partyID string) ([]partyMember, error) {
	rows, err := tx.Query(ctx, `SELECT c.id::text,c.nickname,c.role_id,c.avatar_id,c.level,coalesce(pet.template_id,''),
		s.id IS NOT NULL,coalesce(m.ready_session_id=s.id,false)
		FROM party_members m JOIN characters c ON c.id=m.character_id
		LEFT JOIN inventory_items pet ON pet.character_id=c.id AND pet.equipped_slot='companion'
		LEFT JOIN room_leases l ON l.account_id=c.account_id AND l.character_id=c.id AND l.expires_at>now()
		LEFT JOIN sessions s ON s.id=l.session_id AND s.active_character_id=c.id AND s.revoked_at IS NULL AND s.expires_at>now() AND s.access_expires_at>now()
		WHERE m.party_id=$1 AND c.deleted_at IS NULL ORDER BY m.joined_at,c.id`, partyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	members := []partyMember{}
	for rows.Next() {
		var member partyMember
		if err = rows.Scan(&member.ID, &member.Nickname, &member.RoleID, &member.AvatarID, &member.Level, &member.Pet, &member.Online, &member.Ready); err != nil {
			return nil, err
		}
		members = append(members, member)
	}
	return members, rows.Err()
}

func (s *Server) currentParty(w http.ResponseWriter, r *http.Request, who identity) {
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
	view, err := readPartyView(r.Context(), tx, c.ID, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, http.StatusOK, view)
}

func (s *Server) partyCommand(w http.ResponseWriter, r *http.Request, who identity, operation string, body any,
	effect func(context.Context, pgx.Tx, Character) error) {
	if err := decode(r, body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, operation, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if err = effect(ctx, tx, c); err != nil {
			return nil, err
		}
		return readPartyView(ctx, tx, c.ID, who.AccountID)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, http.StatusOK, data)
}

func (s *Server) createParty(w http.ResponseWriter, r *http.Request, who identity) {
	var body struct{}
	s.partyCommand(w, r, who, "party.create", &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		var exists bool
		if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM party_members WHERE character_id=$1)`, c.ID).Scan(&exists); err != nil {
			return err
		}
		if exists {
			return &apiError{409, "already_in_party", "你已经在队伍中"}
		}
		partyID := newID()
		if _, err := tx.Exec(ctx, `INSERT INTO parties(id,leader_character_id) VALUES($1,$2)`, partyID, c.ID); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `INSERT INTO party_members(character_id,party_id) VALUES($1,$2)`, c.ID, partyID)
		return err
	})
}

func (s *Server) inviteToParty(w http.ResponseWriter, r *http.Request, who identity) {
	var body struct {
		TargetCharacterID string `json:"target_character_id"`
	}
	s.partyCommand(w, r, who, "party.invite", &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		if !validID(body.TargetCharacterID) || body.TargetCharacterID == c.ID {
			return bad("invalid_target", "请选择其他旅人发送组队邀请")
		}
		party, err := lockCharacterParty(ctx, tx, c.ID)
		if err != nil {
			return err
		}
		if party.Leader != c.ID {
			return errPartyLeader
		}
		var count int
		if err = tx.QueryRow(ctx, `SELECT count(*) FROM party_members WHERE party_id=$1`, party.ID).Scan(&count); err != nil {
			return err
		}
		if count >= partySize {
			return &apiError{409, "party_full", "队伍人数已满（最多4人）"}
		}
		var targetAccount string
		err = tx.QueryRow(ctx, `SELECT account_id::text FROM characters WHERE id=$1 AND deleted_at IS NULL`, body.TargetCharacterID).Scan(&targetAccount)
		if errors.Is(err, pgx.ErrNoRows) {
			return errNotFound
		}
		if err != nil {
			return err
		}
		if blocked, blockErr := accountsBlocked(ctx, tx, who.AccountID, targetAccount); blockErr != nil {
			return blockErr
		} else if blocked {
			return &apiError{403, "player_blocked", "双方存在屏蔽关系，无法发送组队邀请"}
		}
		var inParty bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM party_members WHERE character_id=$1)`, body.TargetCharacterID).Scan(&inParty); err != nil {
			return err
		}
		if inParty {
			return &apiError{409, "target_in_party", "对方已在其他队伍中"}
		}
		if _, err = tx.Exec(ctx, `UPDATE party_invites SET status='expired',resolved_at=now() WHERE party_id=$1 AND recipient_id=$2 AND status='pending' AND expires_at<=now()`, party.ID, body.TargetCharacterID); err != nil {
			return err
		}
		var pending bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM party_invites WHERE party_id=$1 AND recipient_id=$2 AND status='pending')`, party.ID, body.TargetCharacterID).Scan(&pending); err != nil {
			return err
		}
		if pending {
			return &apiError{409, "invite_exists", "已经向对方发送过组队邀请"}
		}
		_, err = tx.Exec(ctx, `INSERT INTO party_invites(id,party_id,sender_id,recipient_id,expires_at) VALUES($1,$2,$3,$4,now()+interval '5 minutes')`,
			newID(), party.ID, c.ID, body.TargetCharacterID)
		return err
	})
}

func (s *Server) respondPartyInvite(w http.ResponseWriter, r *http.Request, who identity) {
	inviteID := r.PathValue("id")
	if !validID(inviteID) {
		s.fail(w, errPartyInvite)
		return
	}
	var body struct {
		Accept *bool `json:"accept"`
	}
	s.partyCommand(w, r, who, "party.invite_respond:"+inviteID, &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		if body.Accept == nil {
			return bad("invalid_response", "请选择接受或拒绝邀请")
		}
		var partyID, senderID, senderAccount, status string
		var expired bool
		err := tx.QueryRow(ctx, `SELECT i.party_id::text,i.sender_id::text,sc.account_id::text,i.status,i.expires_at<=now()
			FROM party_invites i JOIN characters sc ON sc.id=i.sender_id
			WHERE i.id=$1 AND i.recipient_id=$2 FOR UPDATE OF i`, inviteID, c.ID).Scan(&partyID, &senderID, &senderAccount, &status, &expired)
		if errors.Is(err, pgx.ErrNoRows) {
			return errPartyInvite
		}
		if err != nil {
			return err
		}
		if status != "pending" || expired {
			if status == "pending" && expired {
				_, _ = tx.Exec(ctx, `UPDATE party_invites SET status='expired',resolved_at=now() WHERE id=$1`, inviteID)
			}
			return errPartyInvite
		}
		if !*body.Accept {
			_, err = tx.Exec(ctx, `UPDATE party_invites SET status='declined',resolved_at=now() WHERE id=$1`, inviteID)
			return err
		}
		if blocked, blockErr := accountsBlocked(ctx, tx, who.AccountID, senderAccount); blockErr != nil {
			return blockErr
		} else if blocked {
			return &apiError{403, "player_blocked", "双方存在屏蔽关系，无法加入该队伍"}
		}
		var leader string
		err = tx.QueryRow(ctx, `SELECT leader_character_id::text FROM parties WHERE id=$1 FOR UPDATE`, partyID).Scan(&leader)
		if errors.Is(err, pgx.ErrNoRows) || leader != senderID {
			return errPartyInvite
		}
		if err != nil {
			return err
		}
		var alreadyInParty bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM party_members WHERE character_id=$1)`, c.ID).Scan(&alreadyInParty); err != nil {
			return err
		}
		if alreadyInParty {
			return &apiError{409, "already_in_party", "你已经在其他队伍中，请先离队"}
		}
		var count int
		if err = tx.QueryRow(ctx, `SELECT count(*) FROM party_members WHERE party_id=$1`, partyID).Scan(&count); err != nil {
			return err
		}
		if count >= partySize {
			return &apiError{409, "party_full", "目标队伍已满"}
		}
		if _, err = tx.Exec(ctx, `UPDATE party_invites SET status='accepted',resolved_at=now() WHERE id=$1`, inviteID); err != nil {
			return err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO party_members(character_id,party_id) VALUES($1,$2)`, c.ID, partyID); err != nil {
			return err
		}
		return updatePartyRoster(ctx, tx, partyID, leader)
	})
}

func (s *Server) setPartyReady(w http.ResponseWriter, r *http.Request, who identity) {
	var body struct {
		Ready *bool `json:"ready"`
	}
	s.partyCommand(w, r, who, "party.ready", &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		if body.Ready == nil {
			return bad("invalid_ready", "请选择准备或取消准备")
		}
		party, err := lockCharacterParty(ctx, tx, c.ID)
		if err != nil {
			return err
		}
		var session any
		if *body.Ready {
			if _, err = s.lease(ctx, tx, who, c.ID); err != nil {
				return err
			}
			session = who.SessionID
		}
		write, err := tx.Exec(ctx, `UPDATE party_members SET ready_session_id=$2 WHERE character_id=$1 AND ready_session_id IS DISTINCT FROM $2`, c.ID, session)
		if err == nil && write.RowsAffected() > 0 {
			_, err = tx.Exec(ctx, `UPDATE parties SET version=version+1,updated_at=now() WHERE id=$1`, party.ID)
		}
		return err
	})
}

func (s *Server) kickPartyMember(w http.ResponseWriter, r *http.Request, who identity) {
	var body struct {
		TargetCharacterID string `json:"target_character_id"`
	}
	s.partyCommand(w, r, who, "party.kick", &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		if !validID(body.TargetCharacterID) || body.TargetCharacterID == c.ID {
			return bad("invalid_target", "请选择要移出的队友")
		}
		party, err := lockCharacterParty(ctx, tx, c.ID)
		if err != nil {
			return err
		}
		if party.Leader != c.ID {
			return errPartyLeader
		}
		var inSameParty bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM party_members WHERE party_id=$1 AND character_id=$2)`, party.ID, body.TargetCharacterID).Scan(&inSameParty); err != nil {
			return err
		}
		if !inSameParty {
			return errNotFound
		}
		return removePartyMember(ctx, tx, body.TargetCharacterID)
	})
}

func (s *Server) promotePartyLeader(w http.ResponseWriter, r *http.Request, who identity) {
	var body struct {
		TargetCharacterID string `json:"target_character_id"`
	}
	s.partyCommand(w, r, who, "party.leader", &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		if !validID(body.TargetCharacterID) || body.TargetCharacterID == c.ID {
			return bad("invalid_target", "请选择要移交队长的队友")
		}
		party, err := lockCharacterParty(ctx, tx, c.ID)
		if err != nil {
			return err
		}
		if party.Leader != c.ID {
			return errPartyLeader
		}
		var inSameParty bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM party_members WHERE party_id=$1 AND character_id=$2)`, party.ID, body.TargetCharacterID).Scan(&inSameParty); err != nil {
			return err
		}
		if !inSameParty {
			return errNotFound
		}
		return updatePartyRoster(ctx, tx, party.ID, body.TargetCharacterID)
	})
}

func (s *Server) leaveParty(w http.ResponseWriter, r *http.Request, who identity) {
	var body struct{}
	s.partyCommand(w, r, who, "party.leave", &body, func(ctx context.Context, tx pgx.Tx, c Character) error {
		return removePartyMember(ctx, tx, c.ID)
	})
}

func removePartyMemberIfPresent(ctx context.Context, tx pgx.Tx, id string) error {
	err := removePartyMember(ctx, tx, id)
	if errors.Is(err, errParty) {
		return nil
	}
	return err
}

func removePartyMember(ctx context.Context, tx pgx.Tx, id string) error {
	party, err := lockCharacterParty(ctx, tx, id)
	if err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `DELETE FROM party_members WHERE party_id=$1 AND character_id=$2`, party.ID, id); err != nil {
		return err
	}
	var successor string
	err = tx.QueryRow(ctx, `SELECT character_id::text FROM party_members WHERE party_id=$1 ORDER BY joined_at,character_id LIMIT 1`, party.ID).Scan(&successor)
	if errors.Is(err, pgx.ErrNoRows) {
		_, err = tx.Exec(ctx, `DELETE FROM parties WHERE id=$1`, party.ID)
		return err
	}
	if err != nil {
		return err
	}
	leader := party.Leader
	if leader == id {
		leader = successor
	}
	return updatePartyRoster(ctx, tx, party.ID, leader)
}

func updatePartyRoster(ctx context.Context, tx pgx.Tx, id, leader string) error {
	if _, err := tx.Exec(ctx, `UPDATE party_members SET ready_session_id=NULL WHERE party_id=$1 AND ready_session_id IS NOT NULL`, id); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE party_invites SET status='cancelled',resolved_at=now()
		WHERE party_id=$1 AND sender_id<>$2 AND status='pending'`, id, leader); err != nil {
		return err
	}
	_, err := tx.Exec(ctx, `UPDATE parties SET leader_character_id=$2,version=version+1,updated_at=now() WHERE id=$1`, id, leader)
	return err
}
