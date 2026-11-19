package online

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

func (s *Server) privacySummary(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	var username, status string
	var createdAt time.Time
	err := s.db.QueryRow(r.Context(), `SELECT username, status, created_at FROM accounts WHERE id=$1`, who.AccountID).Scan(&username, &status, &createdAt)
	if errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, errAuth)
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	var activeChars, deletedChars, privacyRequests, unreadNotifications int64
	if err = s.db.QueryRow(r.Context(), `SELECT
		(SELECT count(*) FROM characters WHERE account_id=$1 AND deleted_at IS NULL),
		(SELECT count(*) FROM characters WHERE account_id=$1 AND deleted_at IS NOT NULL),
		(SELECT count(*) FROM account_privacy_requests WHERE account_id=$1),
		(SELECT count(*) FROM security_notifications WHERE account_id=$1 AND acknowledged_at IS NULL)`, who.AccountID).
		Scan(&activeChars, &deletedChars, &privacyRequests, &unreadNotifications); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, http.StatusOK, map[string]any{
		"account_id":           who.AccountID,
		"username":             username,
		"status":               status,
		"created_at":           createdAt,
		"active_characters":    activeChars,
		"deleted_characters":   deletedChars,
		"privacy_requests":     privacyRequests,
		"unread_notifications": unreadNotifications,
		"self_service_actions": []string{"export", "erasure"},
	})
}

func (s *Server) privacyExport(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	if !s.limiter.allow("privacy-export:"+who.AccountID, 10, time.Hour) {
		s.fail(w, &apiError{429, "rate_limited", "导出账号数据过于频繁，请稍后重试"})
		return
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())

	var username, status string
	var createdAt time.Time
	err = tx.QueryRow(r.Context(), `SELECT username, status, created_at FROM accounts WHERE id=$1 AND status='active'`, who.AccountID).Scan(&username, &status, &createdAt)
	if errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, errAuth)
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}

	charRows, err := tx.Query(r.Context(), `SELECT c.id::text, c.nickname, c.role_id, c.appearance_id, c.level, c.experience, c.map_id, c.created_at, c.deleted_at,
		coalesce(w.gold,0), coalesce(w.expedition,0), coalesce(w.soul,0), coalesce(w.honor,0)
		FROM characters c LEFT JOIN wallets w ON w.character_id=c.id WHERE c.account_id=$1 ORDER BY c.created_at`, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	characters := make([]map[string]any, 0)
	for charRows.Next() {
		var id, nickname, roleID, appearanceID, mapID string
		var level int
		var exp, gold, expedition, soul, honor int64
		var charCreated time.Time
		var deletedAt *time.Time
		if scanErr := charRows.Scan(&id, &nickname, &roleID, &appearanceID, &level, &exp, &mapID, &charCreated, &deletedAt, &gold, &expedition, &soul, &honor); scanErr != nil {
			charRows.Close()
			s.fail(w, scanErr)
			return
		}
		characters = append(characters, map[string]any{
			"character_id":  id,
			"nickname":      nickname,
			"role_id":       roleID,
			"appearance_id": appearanceID,
			"level":         level,
			"experience":    exp,
			"map_id":        mapID,
			"created_at":    charCreated,
			"deleted_at":    deletedAt,
			"wallet": map[string]int64{
				"gold":       gold,
				"expedition": expedition,
				"soul":       soul,
				"honor":      honor,
			},
		})
	}
	charRows.Close()
	if charRows.Err() != nil {
		s.fail(w, charRows.Err())
		return
	}

	notifRows, err := tx.Query(r.Context(), `SELECT kind, created_at, acknowledged_at FROM security_notifications WHERE account_id=$1 ORDER BY created_at DESC LIMIT 50`, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	notifications := make([]map[string]any, 0)
	for notifRows.Next() {
		var kind string
		var ts time.Time
		var ack *time.Time
		if scanErr := notifRows.Scan(&kind, &ts, &ack); scanErr != nil {
			notifRows.Close()
			s.fail(w, scanErr)
			return
		}
		notifications = append(notifications, map[string]any{"kind": kind, "created_at": ts, "acknowledged_at": ack})
	}
	notifRows.Close()
	if notifRows.Err() != nil {
		s.fail(w, notifRows.Err())
		return
	}

	auditRows, err := tx.Query(r.Context(), `SELECT action, coalesce(character_id::text,''), created_at FROM audit_events WHERE account_id=$1 ORDER BY id DESC LIMIT 100`, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	audits := make([]map[string]any, 0)
	for auditRows.Next() {
		var action, charID string
		var ts time.Time
		if scanErr := auditRows.Scan(&action, &charID, &ts); scanErr != nil {
			auditRows.Close()
			s.fail(w, scanErr)
			return
		}
		audits = append(audits, map[string]any{"action": action, "character_id": charID, "created_at": ts})
	}
	auditRows.Close()
	if auditRows.Err() != nil {
		s.fail(w, auditRows.Err())
		return
	}

	reqID := newID()
	detailsJSON, _ := json.Marshal(map[string]any{"characters_count": len(characters)})
	if _, err = tx.Exec(r.Context(), `INSERT INTO account_privacy_requests(id,account_id,request_type,status,details) VALUES($1,$2,'export','completed',$3::jsonb)`, reqID, who.AccountID, string(detailsJSON)); err != nil {
		s.fail(w, err)
		return
	}
	if _, err = tx.Exec(r.Context(), `INSERT INTO audit_events(account_id,action) VALUES($1,'account.privacy.export')`, who.AccountID); err != nil {
		s.fail(w, err)
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, http.StatusOK, map[string]any{
		"request_id":      reqID,
		"exported_at":     time.Now().UTC(),
		"schema_version":  1,
		"content_version": s.cfg.ContentVersion,
		"account": map[string]any{
			"account_id": who.AccountID,
			"username":   username,
			"status":     status,
			"created_at": createdAt,
		},
		"characters":             characters,
		"security_notifications": notifications,
		"recent_audit_events":    audits,
	})
}

func (s *Server) privacyDelete(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	if !s.limiter.allow("privacy-delete:"+who.AccountID, 5, 15*time.Minute) {
		s.fail(w, &apiError{429, "rate_limited", "账号注销请求过于频繁，请稍后重试"})
		return
	}
	var body struct {
		Password     string `json:"password"`
		Confirmation string `json:"confirmation"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if strings.TrimSpace(body.Confirmation) != "DELETE" {
		s.fail(w, bad("confirmation_required", "请输入 DELETE 以确认永久注销并匿名化账号"))
		return
	}
	if len(body.Password) == 0 || len(body.Password) > 72 {
		s.fail(w, errAuth)
		return
	}

	tx, err := s.db.Begin(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())

	var hash []byte
	err = tx.QueryRow(r.Context(), `SELECT password_hash FROM accounts WHERE id=$1 AND status='active' FOR UPDATE`, who.AccountID).Scan(&hash)
	if errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, errAuth)
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	if bcrypt.CompareHashAndPassword(hash, []byte(body.Password)) != nil {
		s.fail(w, errAuth)
		return
	}

	var busy bool
	if err = tx.QueryRow(r.Context(), `SELECT
		EXISTS(SELECT 1 FROM battles b JOIN characters c ON c.id=b.character_id WHERE c.account_id=$1 AND (b.status='active' OR (b.status='settled' AND b.acknowledged_at IS NULL)))
		OR EXISTS(SELECT 1 FROM market_orders WHERE seller_account_id=$1 AND status='open')
		OR EXISTS(SELECT 1 FROM trade_sessions WHERE (initiator_account_id=$1 OR partner_account_id=$1) AND status IN ('active','open','confirming'))`, who.AccountID).Scan(&busy); err != nil {
		s.fail(w, err)
		return
	}
	if busy {
		s.fail(w, &apiError{http.StatusConflict, "active_obligations_exist", "请先结束进行中的战斗、寄售挂单与交易后再注销账号"})
		return
	}

	charIDs, err := s.accountCharacterIDs(r.Context(), tx, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	for _, cid := range charIDs {
		if err = removePartyMemberIfPresent(r.Context(), tx, cid); err != nil {
			s.fail(w, err)
			return
		}
		if _, err = tx.Exec(r.Context(), `DELETE FROM coop_queues WHERE character_id=$1`, cid); err != nil {
			s.fail(w, err)
			return
		}
		if _, err = tx.Exec(r.Context(), `DELETE FROM pvp_queues WHERE leader_character_id=$1 OR member_ids @> jsonb_build_array($1::text)`, cid); err != nil {
			s.fail(w, err)
			return
		}
		if _, err = tx.Exec(r.Context(), `DELETE FROM friendships WHERE character_a=$1 OR character_b=$1`, cid); err != nil {
			s.fail(w, err)
			return
		}
	}
	if _, err = tx.Exec(r.Context(), `DELETE FROM player_blocks WHERE owner_account_id=$1 OR blocked_account_id=$1`, who.AccountID); err != nil {
		s.fail(w, err)
		return
	}
	if _, err = tx.Exec(r.Context(), `UPDATE room_leases rl SET expires_at=now(), token=gen_random_uuid(), generation=generation+1, updated_at=now() FROM characters c WHERE rl.character_id=c.id AND c.account_id=$1`, who.AccountID); err != nil {
		s.fail(w, err)
		return
	}
	if _, err = tx.Exec(r.Context(), `UPDATE sessions SET active_character_id=NULL, revoked_at=now(), updated_at=now(), version=version+1 WHERE account_id=$1`, who.AccountID); err != nil {
		s.fail(w, err)
		return
	}
	if _, err = tx.Exec(r.Context(), `UPDATE characters SET deleted_at=coalesce(deleted_at, now()), nickname='已注销_'||substr(replace(id::text,'-',''),1,6), nickname_key='erased_'||replace(id::text,'-',''), updated_at=now(), version=version+1 WHERE account_id=$1`, who.AccountID); err != nil {
		s.fail(w, err)
		return
	}
	erasedUsername := "erased_" + strings.ReplaceAll(who.AccountID, "-", "")[:25]
	erasedPassword := []byte("erased:" + newID())
	if _, err = tx.Exec(r.Context(), `UPDATE accounts SET username=$1, password_hash=$2, recovery_salt=NULL, recovery_hash=NULL, status='erased', erased_at=now(), updated_at=now(), version=version+1 WHERE id=$3`, erasedUsername, erasedPassword, who.AccountID); err != nil {
		s.fail(w, err)
		return
	}

	reqID := newID()
	detailsJSON, _ := json.Marshal(map[string]any{"characters_anonymized": len(charIDs)})
	if _, err = tx.Exec(r.Context(), `INSERT INTO account_privacy_requests(id,account_id,request_type,status,details) VALUES($1,$2,'erasure','completed',$3::jsonb)`, reqID, who.AccountID, string(detailsJSON)); err != nil {
		s.fail(w, err)
		return
	}
	if _, err = tx.Exec(r.Context(), `INSERT INTO audit_events(account_id,action) VALUES($1,'account.privacy.delete')`, who.AccountID); err != nil {
		s.fail(w, err)
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, http.StatusOK, map[string]any{
		"request_id":            reqID,
		"erased":                true,
		"status":                "erased",
		"characters_anonymized": len(charIDs),
	})
}

func (s *Server) accountCharacterIDs(ctx context.Context, tx pgx.Tx, accountID string) ([]string, error) {
	rows, err := tx.Query(ctx, `SELECT id::text FROM characters WHERE account_id=$1`, accountID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var cid string
		if err := rows.Scan(&cid); err != nil {
			return nil, err
		}
		ids = append(ids, cid)
	}
	return ids, rows.Err()
}
