package online

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

type monitoredAuthority struct {
	delegate AuthorityRPC
	mu       sync.Mutex
	mode     string
}

func (a *monitoredAuthority) set(mode string) { a.mu.Lock(); a.mode = mode; a.mu.Unlock() }
func (a *monitoredAuthority) Call(ctx context.Context, method string, args, out any) error {
	if method != "ping" {
		return a.delegate.Call(ctx, method, args, out)
	}
	a.mu.Lock()
	mode := a.mode
	a.mu.Unlock()
	if mode == "stalled" {
		<-ctx.Done()
		return ctx.Err()
	}
	if mode == "failed" {
		return errors.New("private worker unavailable")
	}
	health := map[string]any{"ok": true, "epoch": "11111111111111111111111111111111", "content_version": "integration-v1", "ruleset_version": RulesetVersion}
	switch mode {
	case "wrong content":
		health["content_version"] = "different"
	case "wrong rules":
		health["ruleset_version"] = "different"
	case "invalid epoch":
		health["epoch"] = strings.Repeat("z", 32)
	case "missing confirmation":
		delete(health, "ok")
	}
	raw, err := json.Marshal(health)
	if err != nil {
		return err
	}
	return json.Unmarshal(raw, out)
}

func setupOperations(t *testing.T) (*harness, *Server, *monitoredAuthority) {
	h := setupTown(t, 2)
	app := h.server.Config.Handler.(*Server)
	worker := &monitoredAuthority{delegate: app.cfg.Authority}
	app.cfg.Authority = worker
	return h, app, worker
}

func TestReadinessChecksWorkerVersionsAndDeadline(t *testing.T) {
	h, _, worker := setupOperations(t)
	for _, mode := range []string{"", "wrong content", "wrong rules", "invalid epoch", "missing confirmation", "failed", "stalled", ""} {
		worker.set(mode)
		started := time.Now()
		response := h.request("GET", "/readyz", "", "", nil)
		status := http.StatusServiceUnavailable
		if mode == "" {
			status = http.StatusOK
		}
		requireStatus(t, response, status)
		if mode == "stalled" && time.Since(started) > 3500*time.Millisecond {
			t.Fatal("readiness exceeded its independent dependency deadline")
		}
		requireStatus(t, h.request("GET", "/livez", "", "", nil), 200)
		requireStatus(t, h.request("GET", "/healthz", "", "", nil), 200)
	}
}

func TestLivenessSurvivesDatabaseFailureAndAccountOnlyReadiness(t *testing.T) {
	h := setup(t)
	requireStatus(t, h.request("GET", "/readyz", "", "", nil), 200)
	h.db.Close()
	requireStatus(t, h.request("GET", "/livez", "", "", nil), 200)
	requireStatus(t, h.request("GET", "/healthz", "", "", nil), 503)
	requireStatus(t, h.request("GET", "/readyz", "", "", nil), 503)
	app := h.server.Config.Handler.(*Server)
	handler, err := app.AdminHandler(strings.Repeat("a", 64))
	if err != nil {
		t.Fatal(err)
	}
	r := httptest.NewRequest("GET", "/metrics", nil)
	r.Header.Set("Authorization", "Bearer "+strings.Repeat("a", 64))
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, r)
	if w.Code != 200 || !strings.Contains(w.Body.String(), "yuanzheng_database_up 0\n") || strings.Contains(w.Body.String(), "yuanzheng_active_sessions ") {
		t.Fatal("database failure metrics invented unavailable state values")
	}
}

func TestReadinessAndMetricsTrackCertificateValidity(t *testing.T) {
	h := setup(t)
	for _, item := range []struct {
		name          string
		before, after time.Time
		ready         bool
	}{
		{"valid", time.Now().Add(-time.Hour), time.Now().Add(time.Hour), true},
		{"expired", time.Now().Add(-2 * time.Hour), time.Now().Add(-time.Hour), false},
		{"future", time.Now().Add(time.Hour), time.Now().Add(2 * time.Hour), false},
	} {
		app, err := NewServer(h.db, Config{ContentVersion: "integration-v1", PasswordCost: 4, TLSNotBefore: item.before, TLSNotAfter: item.after})
		if err != nil {
			t.Fatal(err)
		}
		request := httptest.NewRequest("GET", "/readyz", nil)
		response := httptest.NewRecorder()
		app.ServeHTTP(response, request)
		expected := 503
		if item.ready {
			expected = 200
		}
		if response.Code != expected {
			t.Fatalf("%s certificate readiness=%d", item.name, response.Code)
		}
		handler, err := app.AdminHandler(strings.Repeat("t", 64))
		if err != nil {
			t.Fatal(err)
		}
		request = httptest.NewRequest("GET", "/metrics", nil)
		request.Header.Set("Authorization", "Bearer "+strings.Repeat("t", 64))
		response = httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		wanted := "yuanzheng_tls_certificate_valid 0\n"
		if item.ready {
			wanted = "yuanzheng_tls_certificate_valid 1\n"
		}
		if !strings.Contains(response.Body.String(), wanted) || !strings.Contains(response.Body.String(), "yuanzheng_tls_certificate_expiry_seconds ") {
			t.Fatal("certificate validity is not observable")
		}
	}
	if _, err := NewServer(h.db, Config{ContentVersion: "integration-v1", TLSNotAfter: time.Now()}); err == nil {
		t.Fatal("partial certificate validity accepted")
	}
}

func TestAdminMetricsAuthenticationStateAndPrivacy(t *testing.T) {
	h, app, _ := setupOperations(t)
	first, id, lease := h.townRole("ops_one")
	second, secondID, _ := h.townRole("ops_two")
	ended := battleID(t, h.request("POST", "/v1/battles", first, "ops-battle-one", map[string]string{"encounter_id": "training_wolf"}))
	requireStatus(t, h.request("POST", "/v1/battles/"+ended+"/commands", first, "ops-battle-flee", battleAction{Action: "flee"}), 200)
	requireStatus(t, h.request("POST", "/v1/battles", second, "ops-battle-two", map[string]string{"encounter_id": "training_wolf"}), 201)
	for index := 0; index < 10; index++ {
		requireStatus(t, h.request("GET", "/v1/characters/"+newID(), "", "", nil), 401)
	}
	unknownMethod, err := http.NewRequest("PRIVATE_METHOD", h.server.URL+"/v1/characters", nil)
	if err != nil {
		t.Fatal(err)
	}
	rejected, err := h.server.Client().Do(unknownMethod)
	if err != nil {
		t.Fatal(err)
	}
	rejected.Body.Close()
	if rejected.StatusCode != 405 {
		t.Fatal("unsupported method was accepted")
	}
	public, err := h.server.Client().Get(h.server.URL + "/metrics")
	if err != nil {
		t.Fatal(err)
	}
	public.Body.Close()
	if public.StatusCode != 404 {
		t.Fatal("public game endpoint exposed metrics")
	}
	for _, invalid := range []string{"", "short", " " + strings.Repeat("a", 64)} {
		if _, err := app.AdminHandler(invalid); err == nil {
			t.Fatal("unsafe admin credential accepted")
		}
	}
	secret := strings.Repeat("admin-private-", 5)
	handler, err := app.AdminHandler(secret)
	if err != nil {
		t.Fatal(err)
	}
	admin := httptest.NewServer(handler)
	defer admin.Close()
	get := func(token string) (int, string, string) {
		req, err := http.NewRequest("GET", admin.URL+"/metrics", nil)
		if err != nil {
			t.Fatal(err)
		}
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		response, err := admin.Client().Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer response.Body.Close()
		body, err := io.ReadAll(response.Body)
		if err != nil {
			t.Fatal(err)
		}
		return response.StatusCode, string(body), response.Header.Get("Content-Type")
	}
	for _, token := range []string{"", "incorrect", first} {
		status, _, _ := get(token)
		if status != 401 {
			t.Fatal("missing, wrong or game credential accessed management metrics")
		}
	}
	status, body, contentType := get(secret)
	if status != 200 || !strings.HasPrefix(contentType, "text/plain; version=0.0.4") {
		t.Fatal("metrics response is not Prometheus text")
	}
	for _, expected := range []string{
		"yuanzheng_ready 1\n", "yuanzheng_database_up 1\n", "yuanzheng_authority_up 1\n", "yuanzheng_state_query_up 1\n",
		"yuanzheng_active_sessions 2\n", "yuanzheng_active_room_leases 2\n", "yuanzheng_active_battles 1\n", "yuanzheng_unacknowledged_results 1\n",
		`yuanzheng_http_requests_total{route="POST /v1/characters/{id}/select",method="POST",status_class="2xx"} 2`,
		`yuanzheng_http_requests_total{route="GET /v1/characters/{id}",method="GET",status_class="4xx"} 10`,
		`method="OTHER"`,
	} {
		if !strings.Contains(body, expected) {
			t.Fatalf("missing required metric %s", expected)
		}
	}
	for _, private := range []string{first, second, secret, id, secondID, lease.Token, "ops_one", "ops_two", "PRIVATE_METHOD"} {
		if strings.Contains(body, private) {
			t.Fatal("management labels exposed identity or supplied data")
		}
	}
	requireStatus(t, h.request("POST", "/v1/auth/logout", first, "", nil), 200)
	_, body, _ = get(secret)
	if !strings.Contains(body, "yuanzheng_active_sessions 1\n") || !strings.Contains(body, "yuanzheng_active_room_leases 1\n") {
		t.Fatal("revoked sessions still count as online")
	}
}

func TestRequestMetricsCumulativeBucketsAndConcurrentScrapes(t *testing.T) {
	var metrics runtimeMetrics
	for _, duration := range []time.Duration{5 * time.Millisecond, 50 * time.Millisecond, 300 * time.Millisecond} {
		metrics.observeRequest("", "PRIVATE_METHOD", 200, duration)
	}
	var initial bytes.Buffer
	metrics.write(&initial)
	for _, expected := range []string{`le="0.01"} 1`, `le="0.05"} 2`, `le="0.5"} 3`, `le="+Inf"} 3`} {
		if !strings.Contains(initial.String(), expected) {
			t.Fatal("histogram buckets are not cumulative")
		}
	}
	var wait sync.WaitGroup
	for index := 0; index < 20; index++ {
		wait.Add(1)
		go func() {
			defer wait.Done()
			for i := 0; i < 50; i++ {
				metrics.observeRequest("", "ANOTHER_PRIVATE_METHOD", 200, time.Millisecond)
				var scrape bytes.Buffer
				metrics.write(&scrape)
			}
		}()
	}
	wait.Wait()
	var final bytes.Buffer
	metrics.write(&final)
	if !strings.Contains(final.String(), `yuanzheng_http_requests_total{route="unmatched",method="OTHER",status_class="2xx"} 1003`) {
		t.Fatal("concurrent metrics lost increments or created user-controlled labels")
	}
	if strings.Contains(final.String(), "PRIVATE_METHOD") {
		t.Fatal("unbounded method label escaped normalization")
	}
}

type delayedRequestBody struct {
	started     chan struct{}
	release     chan struct{}
	once        sync.Once
	releaseOnce sync.Once
	data        *strings.Reader
}

func (b *delayedRequestBody) Read(destination []byte) (int, error) {
	b.once.Do(func() { close(b.started) })
	<-b.release
	return b.data.Read(destination)
}
func (b *delayedRequestBody) Close() error { return nil }
func (b *delayedRequestBody) unblock()     { b.releaseOnce.Do(func() { close(b.release) }) }

func TestDependencyErrorConsumesBoundedRequestBeforeResponding(t *testing.T) {
	h := setup(t)
	h.db.Close()
	body := &delayedRequestBody{started: make(chan struct{}), release: make(chan struct{}), data: strings.NewReader(`{"nickname":"断线旅人","role_id":"zs","appearance_id":"default"}`)}
	defer body.unblock()
	request := httptest.NewRequest("POST", "/v1/characters", nil)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer not-a-real-session")
	request.Body = body
	request.ContentLength = int64(body.data.Len())
	response := httptest.NewRecorder()
	done := make(chan struct{})
	go func() { h.server.Config.Handler.ServeHTTP(response, request); close(done) }()
	select {
	case <-body.started:
	case <-done:
		t.Fatal("dependency failure responded before consuming the pending request body")
	case <-time.After(time.Second):
		t.Fatal("request body was not read")
	}
	body.unblock()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("dependency failure did not complete after the request body")
	}
	var decoded struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if response.Code != 500 || json.Unmarshal(response.Body.Bytes(), &decoded) != nil || decoded.Error.Code != "internal_error" {
		t.Fatal("dependency failure did not produce a complete JSON response")
	}
}
