package servicehost

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func TestServiceChildProcess(t *testing.T) {
	mode := os.Getenv("SERVICEHOST_TEST_CHILD")
	if mode == "" {
		return
	}
	if mode == "exit" {
		os.Exit(7)
	}
	for {
		if path := os.Getenv("SERVICEHOST_TEST_HEARTBEAT"); path != "" {
			_ = os.WriteFile(path, []byte(strconv.FormatInt(time.Now().UnixNano(), 10)), 0600)
		}
		time.Sleep(50 * time.Millisecond)
	}
}

func testPolicy() Policy {
	var p Policy
	p.defaults()
	p.ProbeIntervalMS, p.ProbeTimeoutMS, p.StartupTimeoutSec = 100, 100, 1
	p.FailureThreshold, p.RestartWindowSec, p.RestartBurst = 2, 10, 3
	p.LivenessGraceMS = 200
	p.BackoffInitialMS, p.BackoffMaximumMS = 100, 100
	p.StopTimeoutSec = 1
	return p
}

func helperSpec(t *testing.T, mode string, probe Probe) Spec {
	t.Helper()
	return Spec{Kind: "gateway", Command: []string{os.Args[0], "-test.run=^TestServiceChildProcess$"},
		Environment: append(os.Environ(), "SERVICEHOST_TEST_CHILD="+mode), Directory: t.TempDir(),
		StateDirectory: filepath.Join(t.TempDir(), "state"), Policy: testPolicy(), Probe: probe, DevelopmentACL: true}
}

func awaitStatus(t *testing.T, directory string, predicate func(Status) bool) Status {
	t.Helper()
	deadline := time.Now().Add(8 * time.Second)
	for time.Now().Before(deadline) {
		data, _ := os.ReadFile(filepath.Join(directory, "status.json"))
		var status Status
		if json.Unmarshal(data, &status) == nil && predicate(status) {
			return status
		}
		time.Sleep(15 * time.Millisecond)
	}
	t.Fatal("service state did not reach the required actual-process condition")
	return Status{}
}

func startManager(t *testing.T, spec Spec, logger *slog.Logger) (context.CancelFunc, <-chan error) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() { done <- Run(ctx, spec, logger); close(done) }()
	t.Cleanup(func() {
		cancel()
		select {
		case <-done:
		case <-time.After(5 * time.Second):
		}
	})
	return cancel, done
}

func quietLogger() *slog.Logger { return slog.New(slog.NewJSONHandler(io.Discard, nil)) }

func TestServiceReadinessDoesNotRestartAndExitRecovers(t *testing.T) {
	var ready atomic.Bool
	spec := helperSpec(t, "hold", func(context.Context) Health { return Health{Live: true, Ready: ready.Load()} })
	_, done := startManager(t, spec, quietLogger())
	first := awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Phase == "degraded" && s.ChildPID != 0 })
	time.Sleep(350 * time.Millisecond)
	still := awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Phase == "degraded" })
	if first.Generation != 1 || still.Generation != 1 || still.ChildPID != first.ChildPID {
		t.Fatal("dependency unready restarted a live child")
	}
	ready.Store(true)
	awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Ready })
	process, err := os.FindProcess(first.ChildPID)
	if err != nil || process.Kill() != nil {
		t.Fatal("could not kill the owned helper process")
	}
	_ = process.Release()
	next := awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Generation == 2 && s.Ready })
	if next.ChildPID == first.ChildPID || next.ChildStarts != 2 {
		t.Fatal("owned child did not actually restart")
	}
	if err := RequestStop(spec.StateDirectory); err != nil {
		t.Fatal(err)
	}
	select {
	case err := <-done:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("private stop did not finish")
	}
	awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Phase == "stopped" && s.ChildPID == 0 })
}

func TestServiceWatchdogAndFiniteRestartBudget(t *testing.T) {
	var healthy atomic.Bool
	healthy.Store(true)
	var events bytes.Buffer
	spec := helperSpec(t, "hold", func(context.Context) Health { return Health{Live: healthy.Load(), Ready: healthy.Load()} })
	cancel, done := startManager(t, spec, slog.New(slog.NewJSONHandler(&events, nil)))
	first := awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Ready })
	healthy.Store(false)
	awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Generation == 2 && s.ChildPID != 0 })
	healthy.Store(true)
	next := awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Generation == 2 && s.Ready })
	if next.ChildPID == first.ChildPID {
		t.Fatal("liveness watchdog did not replace the process")
	}
	cancel()
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(events.String(), `"reason":"liveness_timeout"`) {
		t.Fatal("watchdog restart lacks its specific reason")
	}
	crash := helperSpec(t, "exit", func(context.Context) Health { return Health{} })
	ctx, finish := context.WithTimeout(context.Background(), 8*time.Second)
	defer finish()
	if err := Run(ctx, crash, quietLogger()); !errors.Is(err, ErrRestartBudget) {
		t.Fatal("crash loop did not exhaust its explicit budget")
	}
	terminal := awaitStatus(t, crash.StateDirectory, func(s Status) bool { return s.Phase == "failed" })
	if terminal.Generation != 3 || terminal.ChildPID != 0 || terminal.Reason != "restart_budget" {
		t.Fatal("restart budget state is incorrect")
	}
}

func TestServiceExclusiveOwnershipAndStaleStop(t *testing.T) {
	spec := helperSpec(t, "hold", func(context.Context) Health { return Health{Live: true, Ready: true} })
	_, done := startManager(t, spec, quietLogger())
	first := awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Ready })
	if err := Run(context.Background(), spec, quietLogger()); !errors.Is(err, ErrState) {
		t.Fatal("second host obtained the same private state directory")
	}
	if err := RequestStop(spec.StateDirectory); err != nil {
		t.Fatal(err)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	_, resumed := startManager(t, spec, quietLogger())
	current := awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Ready && s.RunID != first.RunID })
	time.Sleep(250 * time.Millisecond)
	if current.Generation != 1 {
		t.Fatal("stale stop affected new host")
	}
	if err := RequestStop(spec.StateDirectory); err != nil {
		t.Fatal(err)
	}
	if err := <-resumed; err != nil {
		t.Fatal(err)
	}
}

func TestServiceTransientProbeFailuresKeepTheOriginalProcess(t *testing.T) {
	var healthy atomic.Bool
	healthy.Store(true)
	spec := helperSpec(t, "hold", func(context.Context) Health { return Health{Live: healthy.Load(), Ready: healthy.Load()} })
	spec.Policy.LivenessGraceMS = 700
	cancel, done := startManager(t, spec, quietLogger())
	first := awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Ready })
	healthy.Store(false)
	awaitStatus(t, spec.StateDirectory, func(s Status) bool { return !s.Live && s.UnhealthyForMS >= 200 })
	healthy.Store(true)
	recovered := awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Ready && s.UnhealthyForMS == 0 })
	if recovered.Generation != first.Generation || recovered.ChildPID != first.ChildPID {
		t.Fatal("short probe failure replaced a live recovering process")
	}
	cancel()
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

func TestServiceStopPreservesUnrelatedProcess(t *testing.T) {
	heartbeat := filepath.Join(t.TempDir(), "unrelated-heartbeat")
	control := exec.Command(os.Args[0], "-test.run=^TestServiceChildProcess$")
	control.Env = append(os.Environ(), "SERVICEHOST_TEST_CHILD=hold", "SERVICEHOST_TEST_HEARTBEAT="+heartbeat)
	controlGuard, err := containProcess(control)
	if err != nil {
		t.Fatal(err)
	}
	if err := control.Start(); err != nil {
		controlGuard.close()
		t.Fatal(err)
	}
	if err := controlGuard.attach(control.Process.Pid); err != nil {
		_ = control.Process.Kill()
		_ = control.Wait()
		controlGuard.close()
		t.Fatal(err)
	}
	t.Cleanup(func() {
		controlGuard.terminate(control.Process.Pid)
		_ = control.Process.Kill()
		_ = control.Wait()
		controlGuard.close()
	})
	spec := helperSpec(t, "hold", func(context.Context) Health { return Health{Live: true, Ready: true} })
	cancel, done := startManager(t, spec, quietLogger())
	awaitStatus(t, spec.StateDirectory, func(s Status) bool { return s.Ready })
	var before []byte
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		before, err = os.ReadFile(heartbeat)
		if err == nil && len(before) > 0 {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if err != nil || len(before) == 0 {
		t.Fatal("unrelated real helper did not begin its heartbeat")
	}
	cancel()
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	time.Sleep(150 * time.Millisecond)
	after, err := os.ReadFile(heartbeat)
	if err != nil || bytes.Equal(before, after) {
		t.Fatal("stopping owned child stopped or stalled an unrelated process")
	}
}

func TestServiceBoundedLogsKeepUnrelatedFiles(t *testing.T) {
	directory := t.TempDir()
	keep := filepath.Join(directory, "operator-notes.txt")
	if err := os.WriteFile(keep, []byte("preserve"), 0600); err != nil {
		t.Fatal(err)
	}
	runID := strings.Repeat("a", 32)
	for generation := 1; generation <= 12; generation++ {
		output, err := newBoundedLog(directory, runID, generation)
		if err != nil {
			t.Fatal(err)
		}
		if generation == 12 {
			payload := bytes.Repeat([]byte("x"), childLogLimit+100)
			if n, err := output.Write(payload); err != nil || n != len(payload) {
				t.Fatal("bounded writer did not consume over-budget output")
			}
		}
		output.Close()
	}
	entries, _ := os.ReadDir(directory)
	logs := 0
	for _, entry := range entries {
		if childLogName.MatchString(entry.Name()) {
			logs++
			info, _ := entry.Info()
			if info.Size() > childLogLimit+64 {
				t.Fatal("child log exceeded its cap")
			}
		}
	}
	if logs != retainedChildLogs {
		t.Fatal("restart logs were not retained within the limit")
	}
	if data, _ := os.ReadFile(keep); string(data) != "preserve" {
		t.Fatal("log retention changed an unrelated file")
	}
}

func TestServiceFixedRolesAndPrivateCredentialBoundary(t *testing.T) {
	root := t.TempDir()
	game := filepath.Join(root, "game")
	credentials := filepath.Join(root, "credentials")
	if err := os.MkdirAll(filepath.Join(game, "data"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(credentials, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(game, "data", "sample.json"), []byte(`{"sample":1}`), 0600); err != nil {
		t.Fatal(err)
	}
	_ = os.WriteFile(filepath.Join(game, "RoomHost.gd"), []byte("extends SceneTree\n"), 0600)
	version, _ := contentVersion(game)
	key := strings.Repeat("s", 48)
	_ = os.WriteFile(filepath.Join(credentials, "room-secret"), []byte(key), 0600)
	cfg := Config{Version: 1, Kind: "authority", Executable: os.Args[0], GameRoot: game, StateDirectory: filepath.Join(root, "state"), Listen: "127.0.0.1:19081", ContentVersion: version, RulesetVersion: "online-0.1", Policy: testPolicy()}
	base := append(os.Environ(), "YUANZHENG_DATABASE_URL=offline-should-not-pass", "YUANZHENG_ADMIN_TOKEN=admin-should-not-pass", "PGPASSWORD=pg-should-not-pass", "ANOTHER_API_KEY=private-should-not-pass", "CREDENTIALS_DIRECTORY=private-should-not-pass")
	spec, err := Prepare(cfg, credentials, base, true)
	if err != nil {
		t.Fatal(err)
	}
	childEnv := strings.Join(spec.Environment, "\n")
	for _, private := range []string{"offline-should-not-pass", "admin-should-not-pass", "pg-should-not-pass", "private-should-not-pass"} {
		if strings.Contains(childEnv, private) || strings.Contains(strings.Join(spec.Command, " "), private) {
			t.Fatal("other-role or unrelated credential escaped into child")
		}
	}
	if !strings.Contains(childEnv, "YUANZHENG_ROOM_SECRET="+key) {
		t.Fatal("worker did not receive its own key")
	}
	_ = os.WriteFile(filepath.Join(credentials, "database-url"), []byte("offline"), 0600)
	if _, err = Prepare(cfg, credentials, base, true); !errors.Is(err, ErrConfiguration) {
		t.Fatal("worker admitted another role's credential file")
	}
	_ = os.Remove(filepath.Join(credentials, "database-url"))
	changed := cfg
	changed.ContentVersion = strings.Repeat("0", 64)
	if _, err = Prepare(changed, credentials, base, true); !errors.Is(err, ErrConfiguration) {
		t.Fatal("service content mismatch accepted")
	}
	changed = cfg
	changed.Kind = "shell"
	if _, err = Prepare(changed, credentials, base, true); !errors.Is(err, ErrConfiguration) {
		t.Fatal("arbitrary execution role accepted")
	}
	changed = cfg
	changed.StateDirectory = filepath.Join(game, "state")
	if _, err = Prepare(changed, credentials, base, true); !errors.Is(err, ErrConfiguration) {
		t.Fatal("private state admitted inside shared game root")
	}
	configPath := filepath.Join(root, "config.json")
	_ = os.WriteFile(configPath, []byte(`{"version":1,"command":"credential-must-not-appear-in-errors"}`), 0600)
	if _, err = ReadConfig(configPath); !errors.Is(err, ErrConfiguration) || strings.Contains(err.Error(), "credential-must-not-appear-in-errors") {
		t.Fatal("unknown configuration or error redaction failed")
	}
}

func TestGatewayPrivateProbeSeparatesReadinessAndLiveness(t *testing.T) {
	root := t.TempDir()
	game, credentials := filepath.Join(root, "game"), filepath.Join(root, "credentials")
	_ = os.MkdirAll(filepath.Join(game, "data"), 0700)
	_ = os.Mkdir(credentials, 0700)
	_ = os.WriteFile(filepath.Join(game, "data", "sample.json"), []byte(`{"sample":1}`), 0600)
	version, _ := contentVersion(game)
	admin := strings.Repeat("a", 48)
	for name, value := range map[string]string{"room-secret": strings.Repeat("s", 48), "database-url": "postgres://fixture:private-fixture@127.0.0.1:55432/fixture", "admin-token": admin} {
		if err := os.WriteFile(filepath.Join(credentials, name), []byte(value), 0600); err != nil {
			t.Fatal(err)
		}
	}
	var ready, live atomic.Bool
	live.Store(true)
	var unauthorized atomic.Bool
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer "+admin {
			unauthorized.Store(true)
			w.WriteHeader(401)
			return
		}
		if (r.URL.Path == "/livez" && live.Load()) || (r.URL.Path == "/readyz" && ready.Load()) {
			w.WriteHeader(200)
		} else {
			w.WriteHeader(503)
		}
	}))
	defer server.Close()
	cert, key := filepath.Join(root, "cert.pem"), filepath.Join(root, "key.pem")
	_ = os.WriteFile(cert, []byte("fixture certificate"), 0600)
	_ = os.WriteFile(key, []byte("fixture private key"), 0600)
	cfg := Config{Version: 1, Kind: "gateway", Executable: os.Args[0], GameRoot: game, StateDirectory: filepath.Join(root, "state"), Listen: "127.0.0.1:24443",
		AuthorityAddress: "127.0.0.1:19081", AdminListen: server.Listener.Addr().String(), TLSCertificate: cert, TLSPrivateKey: key,
		ContentVersion: version, RulesetVersion: "online-0.1", Policy: testPolicy()}
	spec, err := Prepare(cfg, credentials, os.Environ(), true)
	if err != nil {
		t.Fatal(err)
	}
	args := strings.Join(spec.Command, " ")
	if !strings.Contains(args, "--migration-mode check --require-restricted-database") || strings.Contains(args, "private-fixture") || strings.Contains(args, admin) {
		t.Fatal("gateway arguments weakened DB mode or exposed credentials")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if health := spec.Probe(ctx); !health.Live || health.Ready {
		t.Fatal("dependency failure was confused with a dead gateway")
	}
	ready.Store(true)
	if health := spec.Probe(ctx); !health.Live || !health.Ready {
		t.Fatal("private gateway readiness did not recover")
	}
	live.Store(false)
	if health := spec.Probe(ctx); health.Live || health.Ready {
		t.Fatal("dead gateway was reported healthy")
	}
	if unauthorized.Load() {
		t.Fatal("private probe did not authenticate")
	}
}

func TestPrivateStopReplacesLinkWithoutChangingItsTarget(t *testing.T) {
	directory := t.TempDir()
	status := Status{RunID: strings.Repeat("b", 32)}
	data, _ := json.Marshal(status)
	if err := os.WriteFile(filepath.Join(directory, "status.json"), data, 0600); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(directory, "operator-file")
	if err := os.WriteFile(target, []byte("preserve operator content"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Link(target, filepath.Join(directory, "stop.request")); err != nil {
		t.Fatal(err)
	}
	if err := RequestStop(directory); err != nil {
		t.Fatal(err)
	}
	if data, _ := os.ReadFile(target); string(data) != "preserve operator content" {
		t.Fatal("stop control followed an existing hard link")
	}
	if data, _ := os.ReadFile(filepath.Join(directory, "stop.request")); string(data) != status.RunID {
		t.Fatal("stop control did not atomically publish its nonce")
	}
}
