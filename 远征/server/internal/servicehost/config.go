// Package servicehost supervises one fixed server role, never a shell command.
package servicehost

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"

	"yuanzheng/online/internal/authority"
	"yuanzheng/online/internal/online"
)

var ErrConfiguration = errors.New("service configuration rejected")

type Policy struct {
	ProbeIntervalMS   int `json:"probe_interval_ms"`
	ProbeTimeoutMS    int `json:"probe_timeout_ms"`
	StartupTimeoutSec int `json:"startup_timeout_sec"`
	StopTimeoutSec    int `json:"stop_timeout_sec"`
	FailureThreshold  int `json:"failure_threshold"`
	LivenessGraceMS   int `json:"liveness_grace_ms"`
	RestartWindowSec  int `json:"restart_window_sec"`
	RestartBurst      int `json:"restart_burst"`
	BackoffInitialMS  int `json:"backoff_initial_ms"`
	BackoffMaximumMS  int `json:"backoff_maximum_ms"`
}

func (p *Policy) defaults() {
	values := []struct {
		value    *int
		fallback int
	}{
		{&p.ProbeIntervalMS, 2000}, {&p.ProbeTimeoutMS, 1000}, {&p.StartupTimeoutSec, 120},
		{&p.StopTimeoutSec, 12}, {&p.FailureThreshold, 3}, {&p.LivenessGraceMS, 5000}, {&p.RestartWindowSec, 300},
		{&p.RestartBurst, 5}, {&p.BackoffInitialMS, 2000}, {&p.BackoffMaximumMS, 30000},
	}
	for _, v := range values {
		if *v.value == 0 {
			*v.value = v.fallback
		}
	}
}

func (p Policy) valid() bool {
	return p.ProbeIntervalMS >= 100 && p.ProbeIntervalMS <= 30000 && p.ProbeTimeoutMS >= 100 && p.ProbeTimeoutMS <= 5000 &&
		p.StartupTimeoutSec >= 1 && p.StartupTimeoutSec <= 600 && p.StopTimeoutSec >= 1 && p.StopTimeoutSec <= 30 &&
		p.FailureThreshold >= 1 && p.FailureThreshold <= 10 && p.LivenessGraceMS >= 100 && p.LivenessGraceMS <= 60000 && p.RestartWindowSec >= 10 && p.RestartWindowSec <= 3600 &&
		p.RestartBurst >= 1 && p.RestartBurst <= 20 && p.BackoffInitialMS >= 100 && p.BackoffInitialMS <= 30000 &&
		p.BackoffMaximumMS >= p.BackoffInitialMS && p.BackoffMaximumMS <= 60000
}

type Config struct {
	Version          int    `json:"version"`
	Kind             string `json:"kind"`
	Executable       string `json:"executable"`
	GameRoot         string `json:"game_root"`
	StateDirectory   string `json:"state_directory"`
	Listen           string `json:"listen"`
	AuthorityAddress string `json:"authority_address,omitempty"`
	AdminListen      string `json:"admin_listen,omitempty"`
	TLSCertificate   string `json:"tls_certificate,omitempty"`
	TLSPrivateKey    string `json:"tls_private_key,omitempty"`
	ContentVersion   string `json:"content_version"`
	RulesetVersion   string `json:"ruleset_version"`
	Policy           Policy `json:"policy"`
}

func ReadConfig(path string) (Config, error) {
	file, err := os.Open(path)
	if err != nil {
		return Config{}, ErrConfiguration
	}
	defer file.Close()
	data, err := io.ReadAll(io.LimitReader(file, 16385))
	if err != nil || len(data) > 16384 || len(bytes.TrimSpace(data)) == 0 || bytes.TrimSpace(data)[0] != '{' {
		return Config{}, ErrConfiguration
	}
	var cfg Config
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&cfg) != nil || decoder.Decode(new(any)) != io.EOF {
		return Config{}, ErrConfiguration
	}
	cfg.Policy.defaults()
	return cfg, nil
}

func privateAddress(value string) bool {
	host, port, err := net.SplitHostPort(value)
	n, e := strconv.Atoi(port)
	ip := net.ParseIP(host)
	return err == nil && e == nil && n >= 1024 && n <= 65535 && ip != nil && ip.IsLoopback()
}

func contained(parent, path string) bool {
	rel, err := filepath.Rel(parent, path)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(os.PathSeparator)) && !filepath.IsAbs(rel)
}

func regularAbsolute(path string) bool {
	if !filepath.IsAbs(path) {
		return false
	}
	info, err := os.Lstat(path)
	return err == nil && info.Mode().IsRegular()
}

func contentVersion(root string) (string, error) {
	files, err := filepath.Glob(filepath.Join(root, "data", "*.json"))
	if err != nil || len(files) == 0 {
		return "", ErrConfiguration
	}
	sort.Strings(files)
	hash := sha256.New()
	for _, path := range files {
		data, err := os.ReadFile(path)
		if err != nil || !json.Valid(data) {
			return "", ErrConfiguration
		}
		hash.Write([]byte(filepath.Base(path)))
		hash.Write([]byte{0})
		hash.Write(data)
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func readSecret(directory, name string) (string, error) {
	path := filepath.Join(directory, name)
	if !regularAbsolute(path) {
		return "", ErrConfiguration
	}
	info, err := os.Stat(path)
	if err != nil || info.Size() > 8192 || (runtime.GOOS != "windows" && info.Mode().Perm()&0077 != 0) {
		return "", ErrConfiguration
	}
	data, err := os.ReadFile(path)
	value := strings.TrimSpace(string(data))
	if err != nil || value == "" || strings.ContainsAny(value, "\r\n\x00") {
		return "", ErrConfiguration
	}
	return value, nil
}

// Prepare admits exactly the two game roles. Secrets stay in role-specific
// files and child environments; no value is included in argv, state or errors.
func Prepare(cfg Config, credentials string, base []string, developmentACL bool) (Spec, error) {
	if cfg.Version != 1 || (cfg.Kind != "gateway" && cfg.Kind != "authority") || !cfg.Policy.valid() ||
		!regularAbsolute(cfg.Executable) || !filepath.IsAbs(cfg.GameRoot) || !filepath.IsAbs(cfg.StateDirectory) ||
		!filepath.IsAbs(credentials) || contained(cfg.GameRoot, cfg.StateDirectory) || contained(cfg.GameRoot, credentials) ||
		contained(cfg.StateDirectory, credentials) || contained(credentials, cfg.StateDirectory) || cfg.RulesetVersion != online.RulesetVersion {
		return Spec{}, ErrConfiguration
	}
	info, err := os.Stat(cfg.GameRoot)
	if err != nil || !info.IsDir() {
		return Spec{}, ErrConfiguration
	}
	if runtime.GOOS == "windows" && !developmentACL {
		return Spec{}, ErrConfiguration
	}
	info, err = os.Lstat(credentials)
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 || (runtime.GOOS != "windows" && info.Mode().Perm()&0077 != 0) {
		return Spec{}, ErrConfiguration
	}
	allowedFiles := map[string]bool{"room-secret": true}
	if cfg.Kind == "gateway" {
		allowedFiles["database-url"], allowedFiles["admin-token"] = true, true
	}
	entries, err := os.ReadDir(credentials)
	if err != nil {
		return Spec{}, ErrConfiguration
	}
	for _, entry := range entries {
		if !allowedFiles[entry.Name()] {
			return Spec{}, ErrConfiguration
		}
	}
	version, err := contentVersion(cfg.GameRoot)
	if err != nil || version != cfg.ContentVersion {
		return Spec{}, ErrConfiguration
	}
	secret, err := readSecret(credentials, "room-secret")
	if err != nil || len(secret) < 32 || len(secret) > 256 {
		return Spec{}, ErrConfiguration
	}
	values := map[string]string{"YUANZHENG_ROOM_SECRET": secret}
	command := []string{cfg.Executable}
	var probe Probe
	if cfg.Kind == "authority" {
		host, port, err := net.SplitHostPort(cfg.Listen)
		if err != nil || host != "127.0.0.1" || !privateAddress(cfg.Listen) || !regularAbsolute(filepath.Join(cfg.GameRoot, "RoomHost.gd")) ||
			cfg.AuthorityAddress != "" || cfg.AdminListen != "" || cfg.TLSCertificate != "" || cfg.TLSPrivateKey != "" {
			return Spec{}, ErrConfiguration
		}
		client, err := authority.New(cfg.Listen, []byte(secret), cfg.ContentVersion, cfg.RulesetVersion)
		if err != nil {
			return Spec{}, ErrConfiguration
		}
		command = append(command, "--headless", "--path", cfg.GameRoot, "--script", "res://RoomHost.gd", "--", "--port="+port)
		probe = func(ctx context.Context) Health {
			var health authority.Health
			err := client.Call(ctx, "ping", nil, &health)
			if err != nil {
				code := "authority_transport"
				switch {
				case errors.Is(ctx.Err(), context.DeadlineExceeded):
					code = "authority_deadline"
				case errors.Is(ctx.Err(), context.Canceled):
					code = "authority_cancelled"
				case errors.Is(err, authority.ErrAuthentication):
					code = "authority_authentication"
				case errors.Is(err, authority.ErrProtocol):
					code = "authority_protocol"
				}
				return Health{Code: code}
			}
			if health.ContentVersion != cfg.ContentVersion || health.RulesetVersion != cfg.RulesetVersion {
				return Health{Code: "authority_version"}
			}
			validEpoch, decodeErr := hex.DecodeString(health.Epoch)
			if !health.OK || decodeErr != nil || len(validEpoch) != 16 {
				return Health{Code: "authority_invalid_ping"}
			}
			return Health{Live: true, Ready: true}
		}
	} else {
		_, port, err := net.SplitHostPort(cfg.Listen)
		n, numberErr := strconv.Atoi(port)
		if err != nil || numberErr != nil || n < 1024 || n > 65535 || !privateAddress(cfg.AdminListen) || !privateAddress(cfg.AuthorityAddress) ||
			cfg.AdminListen == cfg.AuthorityAddress || cfg.AdminListen == cfg.Listen || !regularAbsolute(cfg.TLSCertificate) || !regularAbsolute(cfg.TLSPrivateKey) {
			return Spec{}, ErrConfiguration
		}
		database, err := readSecret(credentials, "database-url")
		if err != nil {
			return Spec{}, ErrConfiguration
		}
		admin, err := readSecret(credentials, "admin-token")
		if err != nil || len(admin) < 32 || len(admin) > 256 {
			return Spec{}, ErrConfiguration
		}
		values["YUANZHENG_DATABASE_URL"], values["YUANZHENG_ADMIN_TOKEN"] = database, admin
		command = append(command, "--game-root", cfg.GameRoot, "--listen", cfg.Listen, "--authority-address", cfg.AuthorityAddress,
			"--admin-listen", cfg.AdminListen, "--tls-cert", cfg.TLSCertificate, "--tls-key", cfg.TLSPrivateKey,
			"--migration-mode", "check", "--require-restricted-database", "--startup-timeout", strconv.Itoa(cfg.Policy.StartupTimeoutSec)+"s")
		transport := &http.Transport{Proxy: nil, MaxIdleConns: 2, MaxConnsPerHost: 2}
		client := &http.Client{Transport: transport, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
		request := func(ctx context.Context, path string) int {
			req, err := http.NewRequestWithContext(ctx, "GET", "http://"+cfg.AdminListen+path, nil)
			if err != nil {
				return 0
			}
			req.Header.Set("Authorization", "Bearer "+admin)
			response, err := client.Do(req)
			if err != nil {
				return 0
			}
			defer response.Body.Close()
			_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 65536))
			return response.StatusCode
		}
		probe = func(ctx context.Context) Health {
			live := request(ctx, "/livez") == 200
			return Health{Live: live, Ready: live && request(ctx, "/readyz") == 200}
		}
	}
	env := []string{}
	publicEnvironment := map[string]bool{}
	for _, key := range []string{"SYSTEMROOT", "WINDIR", "SYSTEMDRIVE", "PROGRAMDATA", "PROGRAMFILES", "PROGRAMFILES(X86)", "COMSPEC", "PATHEXT", "PATH", "TEMP", "TMP", "USERPROFILE", "HOME", "USERNAME", "NUMBER_OF_PROCESSORS", "PROCESSOR_ARCHITECTURE", "OS", "LANG", "LC_ALL", "LC_CTYPE", "TZ", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY", "SSL_CERT_FILE", "SSL_CERT_DIR"} {
		publicEnvironment[key] = true
	}
	for _, value := range base {
		key, _, _ := strings.Cut(value, "=")
		upper := strings.ToUpper(key)
		if publicEnvironment[upper] {
			env = append(env, value)
		}
	}
	values["APPDATA"], values["LOCALAPPDATA"] = filepath.Join(cfg.StateDirectory, "userdata"), filepath.Join(cfg.StateDirectory, "userdata")
	values["XDG_DATA_HOME"], values["XDG_CACHE_HOME"] = filepath.Join(cfg.StateDirectory, "userdata"), filepath.Join(cfg.StateDirectory, "cache")
	keys := []string{}
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		env = append(env, key+"="+values[key])
	}
	return Spec{Kind: cfg.Kind, Command: command, Environment: env, Directory: cfg.GameRoot, StateDirectory: cfg.StateDirectory, Policy: cfg.Policy, Probe: probe, DevelopmentACL: developmentACL}, nil
}
