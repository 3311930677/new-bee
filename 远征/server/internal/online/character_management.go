package online

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"time"
)

func (s *Server) deletedCharacters(w http.ResponseWriter, r *http.Request, who identity) {
	rows, err := s.db.Query(r.Context(), `SELECT `+characterColumns+`,deleted_at,deleted_at+interval '7 days' FROM characters WHERE account_id=$1 AND deleted_at>now()-interval '7 days' ORDER BY deleted_at DESC,id`, who.AccountID)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer rows.Close()
	type deleted struct {
		Character
		DeletedAt    time.Time `json:"deleted_at"`
		RecoverUntil time.Time `json:"recover_until"`
	}
	list := []deleted{}
	for rows.Next() {
		var c deleted
		if err = rows.Scan(&c.ID, &c.Nickname, &c.RoleID, &c.AppearanceID, &c.Level, &c.Experience, &c.MapID, &c.Version, &c.DeletedAt, &c.RecoverUntil); err != nil {
			s.fail(w, err)
			return
		}
		c.DeletedAt = c.DeletedAt.UTC()
		c.RecoverUntil = c.RecoverUntil.UTC()
		list = append(list, c)
	}
	if rows.Err() != nil {
		s.fail(w, rows.Err())
		return
	}
	respond(w, 200, map[string]any{"characters": list, "recovery_days": 7})
}
func (s *Server) nicknameSuggestions(w http.ResponseWriter, r *http.Request, who identity) {
	if !s.limiter.allow("nickname-suggestions:"+who.AccountID, 20, time.Minute) {
		s.fail(w, &apiError{429, "rate_limited", "查询过于频繁，请稍后重试"})
		return
	}
	nickname, _, err := normalizeNickname(r.URL.Query().Get("nickname"))
	if err != nil {
		s.fail(w, err)
		return
	}
	runes := []rune(nickname)
	if len(runes) > 8 {
		runes = runes[:8]
	}
	base := string(runes)
	list := []string{}
	seen := map[string]bool{}
	for attempts := 0; attempts < 64 && len(list) < 3; attempts++ {
		prefix, digits, limit := base, 4, int64(10000)
		if attempts >= 32 {
			// A popular eight-character prefix can exhaust its four-digit
			// suffixes. Widen the namespace while keeping the 12-rune limit.
			if utf := []rune(prefix); len(utf) > 4 {
				prefix = string(utf[:4])
			}
			digits, limit = 8, 100000000
		}
		number, err := rand.Int(rand.Reader, big.NewInt(limit))
		if err != nil {
			s.fail(w, err)
			return
		}
		candidate := fmt.Sprintf("%s%0*d", prefix, digits, number.Int64())
		if seen[candidate] {
			continue
		}
		seen[candidate] = true
		var exists bool
		if err = s.db.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM characters WHERE nickname_key=$1)`, strings.ToLower(candidate)).Scan(&exists); err != nil {
			s.fail(w, err)
			return
		}
		if !exists {
			list = append(list, candidate)
		}
	}
	if len(list) != 3 {
		s.fail(w, &apiError{503, "suggestions_unavailable", "暂未找到三个可用昵称，请自行输入或稍后重试"})
		return
	}
	respond(w, 200, map[string]any{"suggestions": list, "reserved": false})
}
