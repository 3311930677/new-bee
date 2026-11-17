package online

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"runtime"
	"strings"
	"sync"
	"time"
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
// point. It has read-only health/metrics capabilities and no game credentials.
func (s *Server) AdminHandler(token string) (http.Handler, error) {
	if len(token) < 32 || strings.TrimSpace(token) != token {
		return nil, errors.New("admin token must contain at least 32 characters without surrounding whitespace")
	}
	expected := sha256.Sum256([]byte(token))
	mux := http.NewServeMux()
	mux.HandleFunc("GET /readyz", s.ready)
	mux.HandleFunc("GET /livez", s.liveness)
	mux.HandleFunc("GET /metrics", s.metricsResponse)
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
		ctx, cancel := context.WithTimeout(r.Context(), dependencyTimeout)
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
