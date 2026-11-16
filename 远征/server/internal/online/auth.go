package online

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"golang.org/x/crypto/bcrypt"
)

type credentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
}
type tokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
	SessionID    string `json:"session_id"`
	RecoveryCode string `json:"recovery_code,omitempty"`
}

func randomToken() string {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic("OS random source unavailable")
	}
	return base64.RawURLEncoding.EncodeToString(b[:])
}
func tokenHash(token string) []byte { h := sha256.Sum256([]byte(token)); return h[:] }
func (s *Server) tokens(sessionID string) tokenPair {
	return tokenPair{AccessToken: randomToken(), RefreshToken: randomToken(), ExpiresIn: int64(s.cfg.AccessTTL / time.Second), SessionID: sessionID}
}
func isUnique(err error) bool { var e *pgconn.PgError; return errors.As(err, &e) && e.Code == "23505" }

func (s *Server) register(w http.ResponseWriter, r *http.Request) {
	if !s.authLimit(w, r) {
		return
	}
	var body credentials
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	body.Username = strings.ToLower(strings.TrimSpace(body.Username))
	if !usernamePattern.MatchString(body.Username) {
		s.fail(w, bad("invalid_username", "账号需为 3–32 位字母、数字或下划线"))
		return
	}
	if len(body.Password) < 10 || len(body.Password) > 72 {
		s.fail(w, bad("invalid_password", "密码需为 10–72 个字节"))
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), s.cfg.PasswordCost)
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
	id := newID()
	code, salt, recoveryHash := newRecoveryCode()
	_, err = tx.Exec(r.Context(), `INSERT INTO accounts(id,username,password_hash,recovery_salt,recovery_hash) VALUES($1,$2,$3,$4,$5)`, id, body.Username, hash, salt, recoveryHash)
	if isUnique(err) {
		s.fail(w, &apiError{409, "username_unavailable", "此账号已被使用"})
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	pair, err := s.issueSession(r.Context(), tx, id)
	pair.RecoveryCode = code
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, http.StatusCreated, pair)
}

func (s *Server) login(w http.ResponseWriter, r *http.Request) {
	if !s.authLimit(w, r) {
		return
	}
	var body credentials
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	body.Username = strings.ToLower(strings.TrimSpace(body.Username))
	var id string
	var hash []byte
	err := s.db.QueryRow(r.Context(), `SELECT id::text,password_hash FROM accounts WHERE username=$1`, body.Username).Scan(&id, &hash)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, err)
		return
	}
	if id == "" {
		hash = s.dummyHash
	}
	match := bcrypt.CompareHashAndPassword(hash, []byte(body.Password)) == nil
	if !match || id == "" {
		s.fail(w, &apiError{401, "invalid_credentials", "账号或密码不正确"})
		return
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	// Recheck the hash under the same account lock as password recovery. A login
	// verified just before a reset must not create a session using the old password.
	var currentHash []byte
	err = tx.QueryRow(r.Context(), `SELECT password_hash FROM accounts WHERE id=$1 FOR UPDATE`, id).Scan(&currentHash)
	if err != nil {
		s.fail(w, err)
		return
	}
	if string(currentHash) != string(hash) && bcrypt.CompareHashAndPassword(currentHash, []byte(body.Password)) != nil {
		s.fail(w, &apiError{401, "invalid_credentials", "账号或密码不正确"})
		return
	}
	pair, err := s.issueSession(r.Context(), tx, id)
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, pair)
}

func (s *Server) issueSession(ctx context.Context, tx pgx.Tx, account string) (tokenPair, error) {
	// Account lock also serializes refresh, role changes and same-account simultaneous login.
	if _, err := tx.Exec(ctx, `SELECT id FROM accounts WHERE id=$1 FOR UPDATE`, account); err != nil {
		return tokenPair{}, err
	}
	if _, err := tx.Exec(ctx, `UPDATE sessions SET revoked_at=now(),updated_at=now(),version=version+1 WHERE account_id=$1 AND revoked_at IS NULL`, account); err != nil {
		return tokenPair{}, err
	}
	pair := s.tokens(newID())
	_, err := tx.Exec(ctx, `INSERT INTO sessions(id,account_id,access_hash,refresh_hash,access_expires_at,expires_at) VALUES($1,$2,$3,$4,now()+$5*interval '1 second',now()+$6*interval '1 second')`, pair.SessionID, account, tokenHash(pair.AccessToken), tokenHash(pair.RefreshToken), int64(s.cfg.AccessTTL/time.Second), int64(s.cfg.RefreshTTL/time.Second))
	return pair, err
}

func (s *Server) refresh(w http.ResponseWriter, r *http.Request) {
	if !s.authLimit(w, r) {
		return
	}
	var body struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if len(body.RefreshToken) != 43 {
		s.fail(w, errAuth)
		return
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	var id, account string
	err = tx.QueryRow(r.Context(), `SELECT id::text,account_id::text FROM sessions WHERE refresh_hash=$1`, tokenHash(body.RefreshToken)).Scan(&id, &account)
	if errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, errAuth)
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	if _, err = tx.Exec(r.Context(), `SELECT id FROM accounts WHERE id=$1 FOR UPDATE`, account); err != nil {
		s.fail(w, err)
		return
	}
	pair := s.tokens(id)
	cmd, err := tx.Exec(r.Context(), `UPDATE sessions SET access_hash=$1,refresh_hash=$2,access_expires_at=now()+$3*interval '1 second',updated_at=now(),version=version+1 WHERE id=$4 AND refresh_hash=$5 AND revoked_at IS NULL AND expires_at>now()`, tokenHash(pair.AccessToken), tokenHash(pair.RefreshToken), int64(s.cfg.AccessTTL/time.Second), id, tokenHash(body.RefreshToken))
	if err != nil {
		s.fail(w, err)
		return
	}
	if cmd.RowsAffected() != 1 {
		s.fail(w, errAuth)
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, pair)
}

func (s *Server) logout(w http.ResponseWriter, r *http.Request, who identity) {
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	if _, err = tx.Exec(r.Context(), `SELECT id FROM accounts WHERE id=$1 FOR UPDATE`, who.AccountID); err == nil {
		_, err = tx.Exec(r.Context(), `UPDATE sessions SET revoked_at=now(),updated_at=now(),version=version+1 WHERE id=$1`, who.SessionID)
	}
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]bool{"logged_out": true})
}
func (s *Server) session(w http.ResponseWriter, r *http.Request, who identity) {
	respond(w, 200, map[string]any{"session_id": who.SessionID, "account_id": who.AccountID, "active_character_id": who.CharacterID})
}
