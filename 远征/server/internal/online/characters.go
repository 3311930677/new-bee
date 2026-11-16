package online

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/jackc/pgx/v5"
)

type Character struct {
	ID           string `json:"id"`
	Nickname     string `json:"nickname"`
	RoleID       string `json:"role_id"`
	AppearanceID string `json:"appearance_id"`
	Level        int    `json:"level"`
	Experience   int64  `json:"experience"`
	MapID        string `json:"map_id"`
	Version      int64  `json:"version"`
}

const characterColumns = `id::text,nickname,role_id,appearance_id,level,experience,map_id,version`

func scanCharacter(row pgx.Row) (Character, error) {
	var c Character
	err := row.Scan(&c.ID, &c.Nickname, &c.RoleID, &c.AppearanceID, &c.Level, &c.Experience, &c.MapID, &c.Version)
	return c, err
}

type createCharacterBody struct {
	Nickname     string `json:"nickname"`
	RoleID       string `json:"role_id"`
	AppearanceID string `json:"appearance_id"`
}

func (s *Server) characters(w http.ResponseWriter, r *http.Request, who identity) {
	rows, err := s.db.Query(r.Context(), `SELECT `+characterColumns+` FROM characters WHERE account_id=$1 AND deleted_at IS NULL ORDER BY created_at,id`, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer rows.Close()
	list := []Character{}
	for rows.Next() {
		c, err := scanCharacter(rows)
		if err != nil {
			s.fail(w, err)
			return
		}
		list = append(list, c)
	}
	if err = rows.Err(); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{"characters": list, "limit": 3})
}

// command commits an effect and its receipt together. Same key+payload returns the
// original response; a changed payload is rejected instead of silently replayed.
func (s *Server) command(r *http.Request, who identity, operation string, payload any, effect func(context.Context, pgx.Tx) (any, error)) (json.RawMessage, error) {
	if err := s.version(r); err != nil {
		return nil, err
	}
	key := r.Header.Get("Idempotency-Key")
	if !requestPattern.MatchString(key) {
		return nil, bad("request_id_required", "请提供有效的请求标识")
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	hash := sha256.Sum256(body)
	ctx := r.Context()
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)
	if _, err = tx.Exec(ctx, `SELECT id FROM accounts WHERE id=$1 FOR UPDATE`, who.AccountID); err != nil {
		return nil, err
	}
	var valid bool
	err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM sessions WHERE id=$1 AND account_id=$2 AND revoked_at IS NULL AND access_expires_at>now() AND expires_at>now())`, who.SessionID, who.AccountID).Scan(&valid)
	if err != nil {
		return nil, err
	}
	if !valid {
		return nil, errAuth
	}
	var oldHash, reply []byte
	err = tx.QueryRow(ctx, `SELECT payload_hash,response FROM command_receipts WHERE account_id=$1 AND operation=$2 AND request_id=$3`, who.AccountID, operation, key).Scan(&oldHash, &reply)
	if err == nil {
		if !bytes.Equal(oldHash, hash[:]) {
			return nil, &apiError{409, "request_id_conflict", "同一请求标识不能用于不同内容"}
		}
		return json.RawMessage(reply), nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}
	data, err := effect(ctx, tx)
	if err != nil {
		return nil, err
	}
	reply, err = json.Marshal(data)
	if err != nil {
		return nil, err
	}
	_, err = tx.Exec(ctx, `INSERT INTO command_receipts(account_id,operation,request_id,payload_hash,response) VALUES($1,$2,$3,$4,$5)`, who.AccountID, operation, key, hash[:], reply)
	if err == nil {
		err = tx.Commit(ctx)
	}
	return json.RawMessage(reply), err
}

func (s *Server) createCharacter(w http.ResponseWriter, r *http.Request, who identity) {
	var body createCharacterBody
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	nickname, key, err := normalizeNickname(body.Nickname)
	if err != nil {
		s.fail(w, err)
		return
	}
	if body.RoleID != "zs" && body.RoleID != "ck" && body.RoleID != "fs" && body.RoleID != "fz" {
		s.fail(w, bad("invalid_role", "请选择有效职业"))
		return
	}
	if body.AppearanceID == "" {
		body.AppearanceID = "default"
	}
	if body.AppearanceID != "default" {
		s.fail(w, bad("invalid_appearance", "此外观尚未在线开放"))
		return
	}
	body.Nickname = nickname
	data, err := s.command(r, who, "character.create", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		var count int
		if err := tx.QueryRow(ctx, `SELECT count(*) FROM characters WHERE account_id=$1 AND (deleted_at IS NULL OR deleted_at>now()-interval '7 days')`, who.AccountID).Scan(&count); err != nil {
			return nil, err
		}
		if count >= 3 {
			return nil, &apiError{409, "character_limit", "最多保留三个在线角色，恢复期内角色也占用名额"}
		}
		id := newID()
		c, err := scanCharacter(tx.QueryRow(ctx, `INSERT INTO characters(id,account_id,nickname,nickname_key,role_id,appearance_id) VALUES($1,$2,$3,$4,$5,$6) RETURNING `+characterColumns, id, who.AccountID, nickname, key, body.RoleID, body.AppearanceID))
		if isUnique(err) {
			return nil, &apiError{409, "nickname_unavailable", "此昵称已被使用，请换一个昵称"}
		}
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO wallets(character_id,gold) VALUES($1,100)`, id); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO wallet_ledger(id,character_id,transaction_id,currency,delta,balance_after,reason) VALUES($1,$2,$3,'gold',100,100,'online_starter')`, newID(), id, "starter:"+id); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO character_progress(character_id) VALUES($1)`, id); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO audit_events(account_id,character_id,action) VALUES($1,$2,'character.create')`, who.AccountID, id); err != nil {
			return nil, err
		}
		return map[string]any{"character": c, "imported_assets": false}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 201, data)
}

func (s *Server) character(w http.ResponseWriter, r *http.Request, who identity) {
	id := r.PathValue("id")
	if !validID(id) {
		s.fail(w, errNotFound)
		return
	}
	c, err := scanCharacter(s.db.QueryRow(r.Context(), `SELECT `+characterColumns+` FROM characters WHERE id=$1 AND account_id=$2 AND deleted_at IS NULL`, id, who.AccountID))
	if errors.Is(err, pgx.ErrNoRows) {
		s.fail(w, errNotFound)
		return
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	var gold, expedition, soul, honor int64
	err = s.db.QueryRow(r.Context(), `SELECT gold,expedition,soul,honor FROM wallets WHERE character_id=$1`, id).Scan(&gold, &expedition, &soul, &honor)
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{"character": c, "wallet": map[string]int64{"gold": gold, "expedition": expedition, "soul": soul, "honor": honor}})
}

func (s *Server) selectCharacter(w http.ResponseWriter, r *http.Request, who identity) {
	id := r.PathValue("id")
	if !validID(id) {
		s.fail(w, errNotFound)
		return
	}
	var body struct{}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "character.select", map[string]string{"id": id}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := scanCharacter(tx.QueryRow(ctx, `SELECT `+characterColumns+` FROM characters WHERE id=$1 AND account_id=$2 AND deleted_at IS NULL`, id, who.AccountID))
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		var busy bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM battles WHERE account_id=$1 AND character_id<>$2 AND (status='active' OR (status='settled' AND acknowledged_at IS NULL)))`, who.AccountID, id).Scan(&busy); err != nil {
			return nil, err
		}
		if busy {
			return nil, &apiError{409, "battle_active", "请先完成原角色的战斗并确认结算"}
		}
		if _, err = tx.Exec(ctx, `UPDATE sessions SET active_character_id=$1,version=version+1,updated_at=now() WHERE id=$2`, id, who.SessionID); err != nil {
			return nil, err
		}
		return map[string]any{"character": c, "session_id": who.SessionID}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func validID(id string) bool {
	if len(id) != 36 {
		return false
	}
	for i, c := range id {
		if i == 8 || i == 13 || i == 18 || i == 23 {
			if c != '-' {
				return false
			}
			continue
		}
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

func (s *Server) deleteCharacter(w http.ResponseWriter, r *http.Request, who identity) {
	id := r.PathValue("id")
	if !validID(id) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		ConfirmNickname string `json:"confirm_nickname"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "character.delete", map[string]string{"id": id, "confirm_nickname": body.ConfirmNickname}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		var nickname string
		err := tx.QueryRow(ctx, `SELECT nickname FROM characters WHERE id=$1 AND account_id=$2 AND deleted_at IS NULL`, id, who.AccountID).Scan(&nickname)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if body.ConfirmNickname != nickname {
			return nil, bad("confirmation_required", "请完整输入角色昵称以确认删除")
		}
		var busy bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM battles WHERE character_id=$1 AND (status='active' OR (status='settled' AND acknowledged_at IS NULL)))`, id).Scan(&busy); err != nil {
			return nil, err
		}
		if busy {
			return nil, &apiError{409, "battle_active", "请先完成此角色的战斗并确认结算"}
		}
		if _, err = tx.Exec(ctx, `UPDATE characters SET deleted_at=now(),updated_at=now(),version=version+1 WHERE id=$1`, id); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE sessions SET active_character_id=NULL,updated_at=now(),version=version+1 WHERE active_character_id=$1`, id); err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO audit_events(account_id,character_id,action) VALUES($1,$2,'character.delete')`, who.AccountID, id); err != nil {
			return nil, err
		}
		return map[string]any{"character_id": id, "deleted": true, "recovery_days": 7}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) restoreCharacter(w http.ResponseWriter, r *http.Request, who identity) {
	id := r.PathValue("id")
	if !validID(id) {
		s.fail(w, errNotFound)
		return
	}
	var body struct{}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "character.restore", map[string]string{"id": id}, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := scanCharacter(tx.QueryRow(ctx, `UPDATE characters SET deleted_at=NULL,updated_at=now(),version=version+1 WHERE id=$1 AND account_id=$2 AND deleted_at>now()-interval '7 days' RETURNING `+characterColumns, id, who.AccountID))
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound
		}
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO audit_events(account_id,character_id,action) VALUES($1,$2,'character.restore')`, who.AccountID, id); err != nil {
			return nil, err
		}
		return map[string]any{"character": c, "restored": true}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
