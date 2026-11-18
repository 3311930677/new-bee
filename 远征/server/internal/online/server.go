package online

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

const ProtocolVersion = 1
const RulesetVersion = "online-0.1"

type Config struct {
	ContentVersion string
	PasswordCost   int
	AccessTTL      time.Duration
	RefreshTTL     time.Duration
	Logger         *slog.Logger
	Authority      AuthorityRPC
	Rules          OnlineRules
	TLSNotBefore   time.Time
	TLSNotAfter    time.Time
}

type Server struct {
	db            *pgxpool.Pool
	cfg           Config
	mux           *http.ServeMux
	limiter       rateLimiter
	dummyHash     []byte
	metrics       runtimeMetrics
	startedAt     time.Time
	positionFeeds positionFeeds
	marketPaused  atomic.Bool
}

type apiError struct {
	status        int
	code, message string
}

func (e *apiError) Error() string    { return e.code }
func bad(code, message string) error { return &apiError{http.StatusBadRequest, code, message} }

var errAuth = &apiError{http.StatusUnauthorized, "unauthorized", "登录已过期，请重新登录"}
var errNotFound = &apiError{http.StatusNotFound, "not_found", "找不到该在线角色"}

func NewServer(db *pgxpool.Pool, cfg Config) (*Server, error) {
	if cfg.ContentVersion == "" {
		return nil, errors.New("content version is required")
	}
	if cfg.TLSNotBefore.IsZero() != cfg.TLSNotAfter.IsZero() || (!cfg.TLSNotAfter.IsZero() && !cfg.TLSNotAfter.After(cfg.TLSNotBefore)) {
		return nil, errors.New("invalid TLS certificate validity configuration")
	}
	if cfg.Authority != nil {
		if err := cfg.Rules.Validate(); err != nil {
			return nil, err
		}
	}
	if cfg.PasswordCost == 0 {
		cfg.PasswordCost = bcrypt.DefaultCost
	}
	if cfg.AccessTTL == 0 {
		cfg.AccessTTL = 30 * time.Minute
	}
	if cfg.RefreshTTL == 0 {
		cfg.RefreshTTL = 7 * 24 * time.Hour
	}
	if cfg.Logger == nil {
		cfg.Logger = slog.Default()
	}
	dummy, err := bcrypt.GenerateFromPassword([]byte("dummy-not-an-account-password"), cfg.PasswordCost)
	if err != nil {
		return nil, err
	}
	s := &Server{db: db, cfg: cfg, mux: http.NewServeMux(), dummyHash: dummy, startedAt: time.Now()}
	s.mux.HandleFunc("GET /healthz", s.health)
	s.mux.HandleFunc("GET /livez", s.liveness)
	s.mux.HandleFunc("GET /readyz", s.ready)
	s.mux.HandleFunc("GET /v1/manifest", s.manifest)
	s.mux.HandleFunc("POST /v1/auth/register", s.register)
	s.mux.HandleFunc("POST /v1/auth/login", s.login)
	s.mux.HandleFunc("POST /v1/auth/refresh", s.refresh)
	s.mux.HandleFunc("POST /v1/auth/logout", s.authorized(s.logout))
	s.mux.HandleFunc("POST /v1/auth/recover", s.recoverAccount)
	s.mux.HandleFunc("POST /v1/account/recovery-code", s.authorized(s.replaceRecoveryCode))
	s.mux.HandleFunc("GET /v1/account/notifications", s.authorized(s.securityNotifications))
	s.mux.HandleFunc("POST /v1/account/notifications/{id}/acknowledge", s.authorized(s.acknowledgeSecurityNotification))
	s.mux.HandleFunc("GET /v1/session", s.authorized(s.session))
	s.mux.HandleFunc("GET /v1/characters", s.authorized(s.characters))
	s.mux.HandleFunc("GET /v1/characters/deleted", s.authorized(s.deletedCharacters))
	s.mux.HandleFunc("GET /v1/nicknames/suggestions", s.authorized(s.nicknameSuggestions))
	s.mux.HandleFunc("POST /v1/characters", s.authorized(s.createCharacter))
	s.mux.HandleFunc("GET /v1/characters/{id}", s.authorized(s.character))
	s.mux.HandleFunc("POST /v1/characters/{id}/select", s.authorized(s.selectCharacter))
	s.mux.HandleFunc("DELETE /v1/characters/{id}", s.authorized(s.deleteCharacter))
	s.mux.HandleFunc("POST /v1/characters/{id}/restore", s.authorized(s.restoreCharacter))
	s.mux.HandleFunc("GET /v1/characters/{id}/journey", s.authorized(s.characterJourney))
	s.mux.HandleFunc("POST /v1/characters/{id}/journey/interact", s.authorized(s.interactJourney))
	s.mux.HandleFunc("POST /v1/characters/{id}/pack/equipment", s.authorized(s.equipJourneyItem))
	s.mux.HandleFunc("POST /v1/rooms/join", s.authorized(s.joinRoom))
	s.mux.HandleFunc("POST /v1/rooms/move", s.authorized(s.moveRoom))
	s.mux.HandleFunc("GET /v1/rooms/current", s.authorized(s.roomSnapshot))
	s.mux.HandleFunc("GET /v1/rooms/positions", s.authorized(s.roomPositionStream))
	s.mux.HandleFunc("GET /v1/rooms/channels", s.authorized(s.listChannels))
	s.mux.HandleFunc("POST /v1/rooms/channels/switch", s.authorized(s.switchChannel))
	s.mux.HandleFunc("POST /v1/rooms/travel", s.authorized(s.travelPortal))
	s.mux.HandleFunc("POST /v1/npcs/{id}/interact", s.authorized(s.interactNPC))
	s.mux.HandleFunc("GET /v1/social/state", s.authorized(s.socialState))
	s.mux.HandleFunc("POST /v1/social/friends/request", s.authorized(s.requestFriend))
	s.mux.HandleFunc("POST /v1/social/friends/{id}/respond", s.authorized(s.respondFriendRequest))
	s.mux.HandleFunc("DELETE /v1/social/friends/{id}", s.authorized(s.removeFriend))
	s.mux.HandleFunc("POST /v1/social/blocks", s.authorized(s.blockPlayer))
	s.mux.HandleFunc("DELETE /v1/social/blocks/{account_id}", s.authorized(s.unblockPlayer))
	s.mux.HandleFunc("POST /v1/social/reports", s.authorized(s.reportPlayer))
	s.mux.HandleFunc("GET /v1/chat/messages", s.authorized(s.listChatMessages))
	s.mux.HandleFunc("POST /v1/chat/messages", s.authorized(s.sendChatMessage))
	s.mux.HandleFunc("GET /v1/parties/current", s.authorized(s.currentParty))
	s.mux.HandleFunc("POST /v1/parties", s.authorized(s.createParty))
	s.mux.HandleFunc("POST /v1/parties/invite", s.authorized(s.inviteToParty))
	s.mux.HandleFunc("POST /v1/parties/invites/{id}/respond", s.authorized(s.respondPartyInvite))
	s.mux.HandleFunc("POST /v1/parties/ready", s.authorized(s.setPartyReady))
	s.mux.HandleFunc("POST /v1/parties/kick", s.authorized(s.kickPartyMember))
	s.mux.HandleFunc("POST /v1/parties/leader", s.authorized(s.promotePartyLeader))
	s.mux.HandleFunc("POST /v1/parties/leave", s.authorized(s.leaveParty))
	s.mux.HandleFunc("POST /v1/battles", s.authorized(s.startBattle))
	s.mux.HandleFunc("GET /v1/battles/active", s.authorized(s.activeBattle))
	s.mux.HandleFunc("GET /v1/battles/{id}", s.authorized(s.battleSnapshot))
	s.mux.HandleFunc("POST /v1/battles/{id}/commands", s.authorized(s.battleCommand))
	s.mux.HandleFunc("POST /v1/battles/{id}/acknowledge", s.authorized(s.acknowledgeBattle))
	s.mux.HandleFunc("GET /v1/coop/dungeons", s.authorized(s.coopDungeons))
	s.mux.HandleFunc("POST /v1/coop/instances", s.authorized(s.createCoopInstance))
	s.mux.HandleFunc("POST /v1/coop/queue/join", s.authorized(s.joinCoopQueue))
	s.mux.HandleFunc("POST /v1/coop/queue/leave", s.authorized(s.leaveCoopQueue))
	s.mux.HandleFunc("GET /v1/coop/instances/{id}", s.authorized(s.getCoopInstance))
	s.mux.HandleFunc("POST /v1/coop/instances/{id}/ready", s.authorized(s.setCoopReady))
	s.mux.HandleFunc("POST /v1/coop/instances/{id}/interact", s.authorized(s.interactCoopStage))
	s.mux.HandleFunc("POST /v1/coop/instances/{id}/battle/start", s.authorized(s.startCoopBattle))
	s.mux.HandleFunc("POST /v1/coop/instances/{id}/battle/command", s.authorized(s.coopBattleCommand))
	s.mux.HandleFunc("POST /v1/coop/instances/{id}/battle/tick", s.authorized(s.tickCoopBattle))
	s.mux.HandleFunc("POST /v1/coop/instances/{id}/disconnect", s.authorized(s.disconnectCoopInstance))
	s.mux.HandleFunc("POST /v1/coop/instances/{id}/leave", s.authorized(s.leaveCoopInstance))
	s.mux.HandleFunc("POST /v1/coop/instances/{id}/retreat", s.authorized(s.retreatCoopInstance))
	s.mux.HandleFunc("GET /v1/coop/drops", s.authorized(s.listCoopDrops))
	s.mux.HandleFunc("POST /v1/coop/drops/{id}/claim", s.authorized(s.claimCoopDrop))
	s.mux.HandleFunc("GET /v1/world-boss/current", s.authorized(s.currentWorldBoss))
	s.mux.HandleFunc("POST /v1/world-boss/{id}/objective", s.authorized(s.worldBossObjective))
	s.mux.HandleFunc("POST /v1/world-boss/{id}/engage", s.authorized(s.worldBossEngage))
	s.mux.HandleFunc("POST /v1/world-boss/{id}/claim", s.authorized(s.claimWorldBossReward))
	s.mux.HandleFunc("GET /v1/market/summary", s.authorized(s.marketSummary))
	s.mux.HandleFunc("GET /v1/market/orders", s.authorized(s.listMarketOrders))
	s.mux.HandleFunc("POST /v1/market/orders", s.authorized(s.createMarketOrder))
	s.mux.HandleFunc("POST /v1/market/orders/{id}/buy", s.authorized(s.buyMarketOrder))
	s.mux.HandleFunc("POST /v1/market/orders/{id}/cancel", s.authorized(s.cancelMarketOrder))
	s.mux.HandleFunc("GET /v1/market/payouts", s.authorized(s.listMarketPayouts))
	s.mux.HandleFunc("POST /v1/market/payouts/{id}/claim", s.authorized(s.claimMarketPayout))
	s.mux.HandleFunc("POST /v1/market/npc/trade", s.authorized(s.npcMarketTrade))
	s.mux.HandleFunc("GET /v1/trade/sessions", s.authorized(s.listTradeSessions))
	s.mux.HandleFunc("POST /v1/trade/sessions", s.authorized(s.startTradeSession))
	s.mux.HandleFunc("POST /v1/trade/sessions/{id}/offer", s.authorized(s.updateTradeOffer))
	s.mux.HandleFunc("POST /v1/trade/sessions/{id}/confirm", s.authorized(s.confirmTradeSession))
	s.mux.HandleFunc("POST /v1/trade/sessions/{id}/cancel", s.authorized(s.cancelTradeSession))
	s.mux.HandleFunc("GET /v1/guilds/state", s.authorized(s.guildState))
	s.mux.HandleFunc("POST /v1/guilds", s.authorized(s.createGuild))
	s.mux.HandleFunc("POST /v1/guilds/invite", s.authorized(s.inviteToGuild))
	s.mux.HandleFunc("POST /v1/guilds/invites/{id}/respond", s.authorized(s.respondGuildInvite))
	s.mux.HandleFunc("POST /v1/guilds/permissions", s.authorized(s.updateGuildPermissions))
	s.mux.HandleFunc("POST /v1/guilds/announcement", s.authorized(s.updateGuildBanner))
	s.mux.HandleFunc("POST /v1/guilds/warehouse/deposit", s.authorized(s.depositGuildWarehouse))
	s.mux.HandleFunc("POST /v1/guilds/warehouse/withdraw", s.authorized(s.withdrawGuildWarehouse))
	s.mux.HandleFunc("POST /v1/guilds/tasks/contribute", s.authorized(s.contributeGuildTask))
	s.mux.HandleFunc("POST /v1/guilds/leave", s.authorized(s.leaveGuild))
	s.mux.HandleFunc("POST /v1/guilds/leader", s.authorized(s.transferGuildLeader))
	s.mux.HandleFunc("POST /v1/guilds/claim-leadership", s.authorized(s.claimInactiveGuildLeader))
	return s, nil
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	observed := &responseObserver{ResponseWriter: w, status: 200}
	defer func() {
		// Only route templates and timings: no credentials, URLs, IDs or payloads.
		elapsed := time.Since(started)
		s.metrics.observeRequest(r.Pattern, r.Method, observed.status, elapsed)
		s.cfg.Logger.Info("request", "route", r.Pattern, "method", metricMethod(r.Method), "status", observed.status, "duration_ms", elapsed.Milliseconds())
	}()
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("X-Protocol-Version", "1")
	w.Header().Set("X-Content-Version", s.cfg.ContentVersion)
	r.Body = http.MaxBytesReader(w, r.Body, 16<<10)
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()
	r = r.WithContext(ctx)
	// Read the bounded body before authentication or dependency failures can
	// produce an early reply. TLS clients may still be sending a second record;
	// closing with unread input can discard an otherwise valid error response.
	raw, err := io.ReadAll(r.Body)
	if err != nil {
		s.fail(observed, bad("invalid_payload", "请求内容或字段不正确"))
		return
	}
	r.Body = io.NopCloser(bytes.NewReader(raw))
	s.mux.ServeHTTP(observed, r)
}

type responseObserver struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func (w *responseObserver) WriteHeader(status int) {
	if w.wroteHeader {
		return
	}
	w.wroteHeader = true
	w.status = status
	w.ResponseWriter.WriteHeader(status)
}
func (w *responseObserver) Write(data []byte) (int, error) {
	if !w.wroteHeader {
		w.WriteHeader(http.StatusOK)
	}
	return w.ResponseWriter.Write(data)
}
func (w *responseObserver) Unwrap() http.ResponseWriter { return w.ResponseWriter }

func respond(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"data": data})
}
func (s *Server) fail(w http.ResponseWriter, err error) {
	e := &apiError{http.StatusInternalServerError, "internal_error", "服务暂时不可用，请稍后重试"}
	if !errors.As(err, &e) {
		e = &apiError{http.StatusInternalServerError, "internal_error", "服务暂时不可用，请稍后重试"}
		// Never log credentials, tokens, request bodies or database errors with parameter values.
		kind := errorType(err)
		s.metrics.observeError(kind)
		s.cfg.Logger.Error("online request failed", "error_type", kind)
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(e.status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": e.code, "message": e.message}})
}
func errorType(err error) string {
	if errors.Is(err, context.DeadlineExceeded) {
		return "timeout"
	}
	var connectionError *pgconn.ConnectError
	if errors.As(err, &connectionError) || errors.Is(err, pgconn.ErrConnClosed) {
		return "database_connection"
	}
	var databaseError *pgconn.PgError
	if errors.As(err, &databaseError) {
		// SQLSTATE is a public five-character classification. Messages and
		// details can contain user input or credentials and must stay private.
		if sqlStatePattern.MatchString(databaseError.Code) {
			return "database_" + databaseError.Code
		}
		return "database_error"
	}
	return "internal"
}

var sqlStatePattern = regexp.MustCompile(`^[0-9A-Z]{5}$`)

func decode(r *http.Request, out any) error {
	if !strings.HasPrefix(strings.ToLower(r.Header.Get("Content-Type")), "application/json") {
		return bad("json_required", "请求格式必须为 JSON")
	}
	raw, err := io.ReadAll(r.Body)
	if err != nil {
		return bad("invalid_payload", "请求内容或字段不正确")
	}
	raw = bytes.TrimSpace(raw)
	if len(raw) == 0 || raw[0] != '{' {
		return bad("invalid_payload", "请求内容必须为 JSON 对象")
	}
	d := json.NewDecoder(bytes.NewReader(raw))
	d.DisallowUnknownFields()
	if err := d.Decode(out); err != nil {
		return bad("invalid_payload", "请求内容或字段不正确")
	}
	if d.Decode(&struct{}{}) != io.EOF {
		return bad("invalid_payload", "请求中只能有一个 JSON 对象")
	}
	return nil
}
func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	if err := s.db.Ping(r.Context()); err != nil {
		s.fail(w, &apiError{503, "database_unavailable", "数据库暂不可用"})
		return
	}
	respond(w, 200, map[string]any{"status": "ok", "protocol_version": ProtocolVersion, "ruleset_version": RulesetVersion})
}
func (s *Server) manifest(w http.ResponseWriter, r *http.Request) {
	features := []string{"accounts", "online_characters", "account_recovery", "character_recovery", "character_identity"}
	if s.cfg.Authority != nil {
		features = append(features, "town_rooms", "authority_battles", "town_positions", "world_channels", "cross_map", "npc_isolation", "social_chat", "parties")
		if s.cfg.Rules.Journey != nil {
			features = append(features, "town_journey")
		}
		if s.cfg.Rules.Coop != nil {
			features = append(features, "coop_dungeons")
		}
		if s.cfg.Rules.WorldBoss != nil || len(s.cfg.Rules.WorldBosses) > 0 {
			features = append(features, "world_boss")
			if len(s.cfg.Rules.WorldBosses) > 1 {
				features = append(features, "world_boss_shenyuan")
			}
		}
		if s.cfg.Rules.Guilds != nil {
			features = append(features, "guilds")
		}
		if s.cfg.Rules.Market != nil {
			features = append(features, "market_sandbox", "npc_floor_market")
			if s.cfg.Rules.Market.allowsStage("M1") && !s.cfg.Rules.Market.SandboxOnly {
				features = append(features, "market_consignment")
			}
			if s.cfg.Rules.Market.allowsStage("M3") && !s.cfg.Rules.Market.SandboxOnly {
				features = append(features, "direct_trade")
			}
		}
	}
	respond(w, 200, map[string]any{"protocol_version": ProtocolVersion, "content_version": s.cfg.ContentVersion, "ruleset_version": RulesetVersion, "character_limit": 3, "roles": []string{"zs", "ck", "fs", "fz"}, "appearance_ids": []string{"default"}, "gender_ids": genderIDs, "avatar_ids": avatarIDs, "features": features, "starting_gold": 100})
}

type identity struct{ SessionID, AccountID, CharacterID string }
type privateHandler func(http.ResponseWriter, *http.Request, identity)

func (s *Server) authorized(next privateHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if token == "" || token == r.Header.Get("Authorization") || len(token) > 128 {
			s.fail(w, errAuth)
			return
		}
		hash := sha256.Sum256([]byte(token))
		var who identity
		err := s.db.QueryRow(r.Context(), `SELECT id::text, account_id::text, coalesce(active_character_id::text,'') FROM sessions WHERE access_hash=$1 AND revoked_at IS NULL AND access_expires_at>now() AND expires_at>now()`, hash[:]).Scan(&who.SessionID, &who.AccountID, &who.CharacterID)
		if errors.Is(err, pgx.ErrNoRows) {
			s.fail(w, errAuth)
			return
		}
		if err != nil {
			s.fail(w, err)
			return
		}
		next(w, r, who)
	}
}
func (s *Server) version(r *http.Request) error {
	if r.Header.Get("X-Content-Version") != s.cfg.ContentVersion {
		return &apiError{409, "content_version_mismatch", "客户端内容版本不一致，请更新后重试"}
	}
	return nil
}

type rateBucket struct {
	count int
	until time.Time
}
type rateLimiter struct {
	mu          sync.Mutex
	buckets     map[string]rateBucket
	lastCleanup time.Time
}

func (l *rateLimiter) allow(key string, limit int, window time.Duration) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := time.Now()
	if l.buckets == nil {
		l.buckets = make(map[string]rateBucket)
	}
	if now.Sub(l.lastCleanup) > time.Minute {
		for k, v := range l.buckets {
			if now.After(v.until) {
				delete(l.buckets, k)
			}
		}
		l.lastCleanup = now
	}
	b := l.buckets[key]
	if now.After(b.until) {
		b = rateBucket{until: now.Add(window)}
	}
	b.count++
	l.buckets[key] = b
	return b.count <= limit
}
func (s *Server) authLimit(w http.ResponseWriter, r *http.Request) bool {
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		ip = r.RemoteAddr
	}
	if !s.limiter.allow("auth:"+ip, 30, time.Minute) {
		w.Header().Set("Retry-After", "60")
		s.fail(w, &apiError{429, "rate_limited", "操作过于频繁，请稍后重试"})
		return false
	}
	return true
}

var usernamePattern = regexp.MustCompile(`^[a-z0-9_]{3,32}$`)
var requestPattern = regexp.MustCompile(`^[a-zA-Z0-9_-]{8,80}$`)

func normalizeNickname(n string) (string, string, error) {
	n = strings.TrimSpace(n)
	if utf8.RuneCountInString(n) < 2 || utf8.RuneCountInString(n) > 12 {
		return "", "", bad("invalid_nickname", "昵称需为 2–12 个汉字、字母或数字")
	}
	for _, c := range n {
		if !unicode.IsLetter(c) && !unicode.IsDigit(c) {
			return "", "", bad("invalid_nickname", "昵称只能使用汉字、字母或数字")
		}
	}
	return n, strings.ToLower(n), nil
}
