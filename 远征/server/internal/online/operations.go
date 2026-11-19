package online

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"
)

const dependencyTimeout = 2 * time.Second

type dependencyState struct{ database, authority, authorityConfigured, tlsConfigured, tlsValid bool }

func (d dependencyState) ready() bool { return d.database && d.authority && d.tlsValid }

func (s *Server) dependencies(ctx context.Context) dependencyState {
	ctx, cancel := context.WithTimeout(ctx, dependencyTimeout)
	defer cancel()
	state := dependencyState{authorityConfigured: s.cfg.Authority != nil, authority: s.cfg.Authority == nil}
	state.tlsConfigured = !s.cfg.TLSNotAfter.IsZero()
	now := time.Now()
	state.tlsValid = !state.tlsConfigured || (!now.Before(s.cfg.TLSNotBefore) && now.Before(s.cfg.TLSNotAfter))
	var wait sync.WaitGroup
	wait.Add(1)
	go func() {
		defer wait.Done()
		state.database = s.db.Ping(ctx) == nil
	}()
	if state.authorityConfigured {
		wait.Add(1)
		go func() {
			defer wait.Done()
			var health struct {
				OK             bool   `json:"ok"`
				Epoch          string `json:"epoch"`
				ContentVersion string `json:"content_version"`
				RulesetVersion string `json:"ruleset_version"`
			}
			err := s.cfg.Authority.Call(ctx, "ping", nil, &health)
			epoch, decodeError := hex.DecodeString(health.Epoch)
			state.authority = err == nil && health.OK && decodeError == nil && len(epoch) == 16 &&
				health.ContentVersion == s.cfg.ContentVersion && health.RulesetVersion == RulesetVersion
		}()
	}
	wait.Wait()
	return state
}

func (s *Server) liveness(w http.ResponseWriter, r *http.Request) {
	respond(w, http.StatusOK, map[string]string{"status": "alive"})
}

func (s *Server) ready(w http.ResponseWriter, r *http.Request) {
	if s.dependencies(r.Context()).ready() {
		respond(w, http.StatusOK, map[string]string{"status": "ready"})
	} else {
		respond(w, http.StatusServiceUnavailable, map[string]string{"status": "unavailable"})
	}
}

// AdminHandler must be bound only to a literal loopback listener by the entry
// point. It handles loopback monitoring and operator moderation/config actions.
func (s *Server) AdminHandler(token string) (http.Handler, error) {
	if len(token) < 32 || strings.TrimSpace(token) != token {
		return nil, errors.New("admin token must contain at least 32 characters without surrounding whitespace")
	}
	expected := sha256.Sum256([]byte(token))
	mux := http.NewServeMux()
	mux.HandleFunc("GET /readyz", s.ready)
	mux.HandleFunc("GET /livez", s.liveness)
	mux.HandleFunc("GET /metrics", s.metricsResponse)
	mux.HandleFunc("GET /ops/reports", s.opsReports)
	mux.HandleFunc("POST /ops/reports/{id}/resolve", s.opsResolveReport)
	mux.HandleFunc("GET /ops/capacity", s.opsCapacity)
	mux.HandleFunc("POST /ops/config/market-pause", s.opsMarketPause)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		header := r.Header.Get("Authorization")
		provided := strings.TrimPrefix(header, "Bearer ")
		hash := sha256.Sum256([]byte(provided))
		if provided == header || subtle.ConstantTimeCompare(expected[:], hash[:]) != 1 {
			w.Header().Set("WWW-Authenticate", `Bearer realm="operations"`)
			respond(w, http.StatusUnauthorized, map[string]string{"status": "unauthorized"})
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		mux.ServeHTTP(w, r.WithContext(ctx))
	}), nil
}

func (s *Server) metricsResponse(w http.ResponseWriter, r *http.Request) {
	state := s.dependencies(r.Context())
	var sessions, leases, battles, pending int64
	queryOK := false
	if state.database {
		err := s.db.QueryRow(r.Context(), `SELECT
			(SELECT count(*) FROM sessions WHERE revoked_at IS NULL AND access_expires_at>now() AND expires_at>now()),
			(SELECT count(*) FROM room_leases l JOIN sessions s ON s.id=l.session_id WHERE l.expires_at>now() AND s.revoked_at IS NULL AND s.access_expires_at>now() AND s.expires_at>now()),
			(SELECT count(*) FROM battles WHERE status='active'),
			(SELECT count(*) FROM battles WHERE status='settled' AND acknowledged_at IS NULL)`).Scan(&sessions, &leases, &battles, &pending)
		queryOK = err == nil
	}
	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	flag := func(v bool) int {
		if v {
			return 1
		}
		return 0
	}
	for _, sample := range []struct {
		name  string
		value int
		help  string
	}{
		{"ready", flag(state.ready()), "Whether all configured service dependencies and certificate validity are ready."},
		{"database_up", flag(state.database), "Whether the database accepted a bounded connectivity check."},
		{"authority_configured", flag(state.authorityConfigured), "Whether this gateway has a configured private authority."},
		{"authority_up", flag(state.authority), "Whether the configured authority answered with compatible versions."},
		{"state_query_up", flag(queryOK), "Whether database state gauges were read successfully."},
		{"tls_configured", flag(state.tlsConfigured), "Whether direct TLS is configured on the public listener."},
		{"tls_certificate_valid", flag(state.tlsValid), "Whether the configured certificate is currently within its validity period."},
	} {
		fmt.Fprintf(w, "# HELP yuanzheng_%s %s\n# TYPE yuanzheng_%s gauge\nyuanzheng_%s %d\n", sample.name, sample.help, sample.name, sample.name, sample.value)
	}
	if state.tlsConfigured {
		fmt.Fprintf(w, "# HELP yuanzheng_tls_certificate_expiry_seconds Seconds remaining until the configured certificate expires.\n# TYPE yuanzheng_tls_certificate_expiry_seconds gauge\nyuanzheng_tls_certificate_expiry_seconds %g\n", time.Until(s.cfg.TLSNotAfter).Seconds())
	}
	if queryOK {
		for _, sample := range []struct {
			name  string
			value int64
			help  string
		}{
			{"active_sessions", sessions, "Number of unrevoked and unexpired access sessions."},
			{"active_room_leases", leases, "Number of live room leases owned by valid sessions."},
			{"active_battles", battles, "Number of persisted active battles."},
			{"unacknowledged_results", pending, "Number of settled battles awaiting client acknowledgment."},
		} {
			fmt.Fprintf(w, "# HELP yuanzheng_%s %s\n# TYPE yuanzheng_%s gauge\nyuanzheng_%s %d\n", sample.name, sample.help, sample.name, sample.name, sample.value)
		}
	}
	fmt.Fprintf(w, "# HELP yuanzheng_process_uptime_seconds Seconds since the gateway started.\n# TYPE yuanzheng_process_uptime_seconds gauge\nyuanzheng_process_uptime_seconds %g\n", time.Since(s.startedAt).Seconds())
	fmt.Fprintf(w, "# HELP yuanzheng_process_goroutines Number of current Go goroutines.\n# TYPE yuanzheng_process_goroutines gauge\nyuanzheng_process_goroutines %d\n", runtime.NumGoroutine())
	s.metrics.write(w)
}

func (s *Server) opsReports(w http.ResponseWriter, r *http.Request) {
	statusFilter := strings.TrimSpace(r.URL.Query().Get("status"))
	if statusFilter != "" && statusFilter != "open" && statusFilter != "resolved" {
		s.fail(w, bad("invalid_filter", "status 仅支持 open 或 resolved"))
		return
	}
	limit := 50
	if rawLimit := strings.TrimSpace(r.URL.Query().Get("limit")); rawLimit != "" {
		if parsed, err := strconv.Atoi(rawLimit); err == nil && parsed >= 1 && parsed <= 200 {
			limit = parsed
		}
	}
	rows, err := s.db.Query(r.Context(), `SELECT r.id::text, r.category, r.reason, r.target_character_id::text, coalesce(tc.nickname,''), r.created_at,
		coalesce(m.decision,'open'), coalesce(m.operator_label,''), coalesce(m.note,''), m.created_at
		FROM player_reports r
		LEFT JOIN characters tc ON tc.id=r.target_character_id
		LEFT JOIN LATERAL (SELECT decision, operator_label, note, created_at FROM moderation_actions WHERE report_id=r.id ORDER BY id DESC LIMIT 1) m ON true
		WHERE ($1='' OR ($1='open' AND m.decision IS NULL) OR ($1='resolved' AND m.decision IS NOT NULL))
		ORDER BY r.created_at DESC LIMIT $2`, statusFilter, limit)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer rows.Close()
	reports := make([]map[string]any, 0)
	for rows.Next() {
		var id, category, reason, targetCharID, targetNick, decision, operatorLabel, note string
		var createdAt time.Time
		var decidedAt *time.Time
		if scanErr := rows.Scan(&id, &category, &reason, &targetCharID, &targetNick, &createdAt, &decision, &operatorLabel, &note, &decidedAt); scanErr != nil {
			s.fail(w, scanErr)
			return
		}
		reports = append(reports, map[string]any{
			"report_id":           id,
			"category":            category,
			"reason":              reason,
			"target_character_id": targetCharID,
			"target_nickname":     targetNick,
			"created_at":          createdAt,
			"decision":            decision,
			"operator_label":      operatorLabel,
			"note":                note,
			"decided_at":          decidedAt,
		})
	}
	if rows.Err() != nil {
		s.fail(w, rows.Err())
		return
	}
	respond(w, http.StatusOK, map[string]any{"reports": reports})
}

func (s *Server) opsResolveReport(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !validID(id) {
		s.fail(w, errNotFound)
		return
	}
	var body struct {
		Operator string `json:"operator"`
		Decision string `json:"decision"`
		Note     string `json:"note"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	operator := strings.TrimSpace(body.Operator)
	if n := utf8.RuneCountInString(operator); n < 2 || n > 64 {
		s.fail(w, bad("invalid_operator", "请提供 2–64 字符的操作人标识"))
		return
	}
	switch body.Decision {
	case "dismissed", "warned", "muted", "suspended":
	default:
		s.fail(w, bad("invalid_decision", "decision 必须为 dismissed、warned、muted 或 suspended"))
		return
	}
	note := strings.TrimSpace(body.Note)
	if utf8.RuneCountInString(note) > 200 {
		s.fail(w, bad("invalid_note", "处置说明不能超过 200 字"))
		return
	}
	tx, err := s.db.Begin(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())

	var exists bool
	if err = tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM player_reports WHERE id=$1)`, id).Scan(&exists); err != nil {
		s.fail(w, err)
		return
	}
	if !exists {
		s.fail(w, errNotFound)
		return
	}
	var actionID int64
	var decidedAt time.Time
	if err = tx.QueryRow(r.Context(), `INSERT INTO moderation_actions(report_id,operator_label,decision,note) VALUES($1,$2,$3,$4) RETURNING id, created_at`,
		id, operator, body.Decision, note).Scan(&actionID, &decidedAt); err != nil {
		s.fail(w, err)
		return
	}
	detailsJSON, _ := json.Marshal(map[string]any{"report_id": id, "decision": body.Decision, "operator": operator})
	if _, err = tx.Exec(r.Context(), `INSERT INTO audit_events(action,details) VALUES('ops.moderation.resolve',$1::jsonb)`, string(detailsJSON)); err != nil {
		s.fail(w, err)
		return
	}
	if err = tx.Commit(r.Context()); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, http.StatusOK, map[string]any{
		"action_id":  actionID,
		"report_id":  id,
		"decision":   body.Decision,
		"operator":   operator,
		"decided_at": decidedAt,
	})
}

func (s *Server) opsCapacity(w http.ResponseWriter, r *http.Request) {
	var sessions, leases, battles, coopInstances, coopQueued, pvpMatches, pvpQueued, openReports int64
	if err := s.db.QueryRow(r.Context(), `SELECT
		(SELECT count(*) FROM sessions WHERE revoked_at IS NULL AND expires_at>now()),
		(SELECT count(*) FROM room_leases WHERE expires_at>now()),
		(SELECT count(*) FROM battles WHERE status='active'),
		(SELECT count(*) FROM coop_instances WHERE status IN ('ready','active')),
		(SELECT count(*) FROM coop_queues WHERE status='queued'),
		(SELECT count(*) FROM pvp_matches WHERE status IN ('ready','active')),
		(SELECT count(*) FROM pvp_queues WHERE status='queued'),
		(SELECT count(*) FROM player_reports pr WHERE NOT EXISTS(SELECT 1 FROM moderation_actions ma WHERE ma.report_id=pr.id))`).
		Scan(&sessions, &leases, &battles, &coopInstances, &coopQueued, &pvpMatches, &pvpQueued, &openReports); err != nil {
		s.fail(w, err)
		return
	}
	rows, err := s.db.Query(r.Context(), `SELECT r.map_id, r.channel, count(l.character_id)
		FROM room_instances r
		LEFT JOIN room_leases l ON l.room_id=r.id AND l.expires_at>now()
		GROUP BY r.map_id, r.channel
		ORDER BY r.map_id, r.channel`)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer rows.Close()
	channels := make([]map[string]any, 0)
	for rows.Next() {
		var mapID string
		var channelNo int
		var activeCount int64
		if scanErr := rows.Scan(&mapID, &channelNo, &activeCount); scanErr != nil {
			s.fail(w, scanErr)
			return
		}
		channels = append(channels, map[string]any{
			"map_id":  mapID,
			"channel": channelNo,
			"players": activeCount,
		})
	}
	if rows.Err() != nil {
		s.fail(w, rows.Err())
		return
	}
	respond(w, http.StatusOK, map[string]any{
		"content_version":       s.cfg.ContentVersion,
		"ruleset_version":       RulesetVersion,
		"protocol_version":      ProtocolVersion,
		"market_paused":         s.marketPaused.Load(),
		"active_sessions":       sessions,
		"active_room_leases":    leases,
		"active_battles":        battles,
		"active_coop_instances": coopInstances,
		"coop_queue_entries":    coopQueued,
		"active_pvp_matches":    pvpMatches,
		"pvp_queue_entries":     pvpQueued,
		"open_reports":          openReports,
		"channels":              channels,
	})
}

func (s *Server) opsMarketPause(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Paused bool   `json:"paused"`
		Reason string `json:"reason"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	reason := strings.TrimSpace(body.Reason)
	if utf8.RuneCountInString(reason) > 200 {
		s.fail(w, bad("invalid_reason", "原因说明不能超过 200 字"))
		return
	}
	s.SetMarketPaused(body.Paused)
	detailsJSON, _ := json.Marshal(map[string]any{"paused": body.Paused, "reason": reason})
	if _, err := s.db.Exec(r.Context(), `INSERT INTO audit_events(action,details) VALUES('ops.config.market_pause',$1::jsonb)`, string(detailsJSON)); err != nil {
		s.fail(w, err)
		return
	}
	respond(w, http.StatusOK, map[string]any{
		"market_paused": s.marketPaused.Load(),
		"reason":        reason,
	})
}
