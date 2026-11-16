package online

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"errors"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

var errRecovery = &apiError{401, "invalid_recovery", "账号或恢复码不正确，或恢复码已失效"}

func recoveryDigest(salt []byte, code string) []byte {
	h := sha256.New()
	h.Write(salt)
	h.Write([]byte(code))
	return h.Sum(nil)
}
func newRecoveryCode() (string, []byte, []byte) {
	code := "YZR-" + randomToken()
	salt := make([]byte, 32)
	if _, err := rand.Read(salt); err != nil {
		panic("OS random source unavailable")
	}
	return code, salt, recoveryDigest(salt, code)
}
func recoveryCodeValid(code string, salt, hash []byte) bool {
	shapeValid := len(salt) == 32 && len(hash) == 32
	if !shapeValid {
		salt = make([]byte, 32)
		hash = make([]byte, 32)
	}
	match := subtle.ConstantTimeCompare(recoveryDigest(salt, code), hash) == 1
	return match && shapeValid && len(code) == 47 && strings.HasPrefix(code, "YZR-")
}
func securityEvent(ctx context.Context, tx pgx.Tx, account, kind string) error {
	if _, err := tx.Exec(ctx, `INSERT INTO security_notifications(id,account_id,kind) VALUES($1,$2,$3)`, newID(), account, kind); err != nil {
		return err
	}
	_, err := tx.Exec(ctx, `INSERT INTO audit_events(account_id,action) VALUES($1,$2)`, account, "account."+kind)
	return err
}

func (s *Server) recoverAccount(w http.ResponseWriter, r *http.Request) {
	if !s.authLimit(w, r) {
		return
	}
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		Username     string `json:"username"`
		RecoveryCode string `json:"recovery_code"`
		Password     string `json:"password"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	body.Username = strings.ToLower(strings.TrimSpace(body.Username))
	body.RecoveryCode = strings.TrimSpace(body.RecoveryCode)
	if len(body.Password) < 10 || len(body.Password) > 72 {
		s.fail(w, bad("invalid_password", "密码需为 10–72 个字节"))
		return
	}
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		ip = r.RemoteAddr
	}
	if !s.limiter.allow("recovery:"+ip+":"+body.Username, 5, 15*time.Minute) {
		w.Header().Set("Retry-After", "900")
		s.fail(w, &apiError{429, "rate_limited", "找回尝试过于频繁，请稍后重试"})
		return
	}
	// Do the same password work for unknown accounts and incorrect codes; never
	// lock or change an account merely because a reset was requested.
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(body.Password), s.cfg.PasswordCost)
	if err != nil {
		s.fail(w, err)
		return
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	var id string
	var salt, hash []byte
	err = tx.QueryRow(r.Context(), `SELECT id::text,recovery_salt,recovery_hash FROM accounts WHERE username=$1 FOR UPDATE`, body.Username).Scan(&id, &salt, &hash)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, err)
		return
	}
	valid := recoveryCodeValid(body.RecoveryCode, salt, hash)
	if !valid || id == "" {
		s.fail(w, errRecovery)
		return
	}
	code, newSalt, newHash := newRecoveryCode()
	_, err = tx.Exec(r.Context(), `UPDATE accounts SET password_hash=$1,recovery_salt=$2,recovery_hash=$3,version=version+1,updated_at=now() WHERE id=$4`, passwordHash, newSalt, newHash, id)
	if err == nil {
		_, err = tx.Exec(r.Context(), `UPDATE sessions SET revoked_at=now(),updated_at=now(),version=version+1 WHERE account_id=$1 AND revoked_at IS NULL`, id)
	}
	if err == nil {
		err = securityEvent(r.Context(), tx, id, "password_reset")
	}
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{"password_reset": true, "login_required": true, "recovery_code": code})
}

func (s *Server) replaceRecoveryCode(w http.ResponseWriter, r *http.Request, who identity) {
	if !s.limiter.allow("recovery-replace:"+who.AccountID, 5, 15*time.Minute) {
		s.fail(w, &apiError{429, "rate_limited", "更新恢复码过于频繁，请稍后重试"})
		return
	}
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	var body struct {
		Password string `json:"password"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	var hash []byte
	err = tx.QueryRow(r.Context(), `SELECT password_hash FROM accounts WHERE id=$1 FOR UPDATE`, who.AccountID).Scan(&hash)
	if err != nil {
		s.fail(w, err)
		return
	}
	var valid bool
	err = tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM sessions WHERE id=$1 AND account_id=$2 AND revoked_at IS NULL AND access_expires_at>now() AND expires_at>now())`, who.SessionID, who.AccountID).Scan(&valid)
	if err != nil {
		s.fail(w, err)
		return
	}
	if !valid {
		s.fail(w, errAuth)
		return
	}
	if bcrypt.CompareHashAndPassword(hash, []byte(body.Password)) != nil {
		s.fail(w, &apiError{401, "invalid_credentials", "密码不正确"})
		return
	}
	code, salt, recoveryHash := newRecoveryCode()
	_, err = tx.Exec(r.Context(), `UPDATE accounts SET recovery_salt=$1,recovery_hash=$2,updated_at=now(),version=version+1 WHERE id=$3`, salt, recoveryHash, who.AccountID)
	if err == nil {
		err = securityEvent(r.Context(), tx, who.AccountID, "recovery_code_replaced")
	}
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]string{"recovery_code": code})
}

func (s *Server) securityNotifications(w http.ResponseWriter, r *http.Request, who identity) {
	rows, err := s.db.Query(r.Context(), `SELECT id::text,kind,created_at FROM security_notifications WHERE account_id=$1 AND acknowledged_at IS NULL ORDER BY created_at DESC LIMIT 20`, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer rows.Close()
	notifications := []map[string]any{}
	for rows.Next() {
		var id, kind string
		var created time.Time
		if err = rows.Scan(&id, &kind, &created); err != nil {
			s.fail(w, err)
			return
		}
		notifications = append(notifications, map[string]any{"id": id, "kind": kind, "created_at": created.UTC()})
	}
	if rows.Err() != nil {
		s.fail(w, rows.Err())
		return
	}
	respond(w, 200, map[string]any{"notifications": notifications})
}
func (s *Server) acknowledgeSecurityNotification(w http.ResponseWriter, r *http.Request, who identity) {
	id := r.PathValue("id")
	if !validID(id) {
		s.fail(w, &apiError{404, "not_found", "找不到这条通知"})
		return
	}
	var body struct{}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "notification.acknowledge", map[string]string{"id": id}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		command, err := tx.Exec(ctx, `UPDATE security_notifications SET acknowledged_at=coalesce(acknowledged_at,now()) WHERE id=$1 AND account_id=$2`, id, who.AccountID)
		if err != nil {
			return nil, err
		}
		if command.RowsAffected() != 1 {
			return nil, &apiError{404, "not_found", "找不到这条通知"}
		}
		return map[string]bool{"acknowledged": true}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
