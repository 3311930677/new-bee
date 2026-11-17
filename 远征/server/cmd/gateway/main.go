package main

import (
	"context"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"yuanzheng/online/internal/authority"
	"yuanzheng/online/internal/online"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(logger); err != nil {
		logger.Error("gateway stopped", "reason", err.Error())
		os.Exit(1)
	}
}
func run(logger *slog.Logger) error {
	listen := flag.String("listen", "127.0.0.1:18080", "HTTP listen address; loopback by default")
	gameRoot := flag.String("game-root", "..", "Godot project directory")
	cert := flag.String("tls-cert", "", "HTTPS certificate path")
	key := flag.String("tls-key", "", "HTTPS private key path")
	trustedTLS := flag.Bool("behind-tls-proxy", false, "Acknowledge a same-host TLS reverse proxy; plaintext still binds loopback only")
	roomAddress := flag.String("authority-address", "", "Optional private Godot worker loopback address")
	adminListen := flag.String("admin-listen", "", "Optional literal loopback address for token-protected read-only metrics")
	startupTimeout := flag.Duration("startup-timeout", 90*time.Second, "Maximum database migration and initial service startup time")
	migrationMode := flag.String("migration-mode", "auto", "auto for local development; check for a separately migrated database")
	restrictedDB := flag.Bool("require-restricted-database", false, "Reject database ownership and administrative privileges; requires migration-mode=check")
	flag.Parse()
	if (*migrationMode != "auto" && *migrationMode != "check") || (*restrictedDB && *migrationMode != "check") {
		return fmt.Errorf("invalid migration mode; restricted database startup requires check")
	}
	if *restrictedDB {
		if err := validateRuntimeEnvironment(); err != nil {
			return err
		}
	}
	if *startupTimeout < time.Second || *startupTimeout > 10*time.Minute {
		return fmt.Errorf("startup timeout must be between 1 second and 10 minutes")
	}
	adminToken := os.Getenv("YUANZHENG_ADMIN_TOKEN")
	if err := validateListeners(*listen, *cert, *key, *adminListen, adminToken); err != nil {
		return err
	}
	var tlsConfig *tls.Config
	var serverCertificate *x509.Certificate
	if *cert != "" {
		certificate, err := tls.LoadX509KeyPair(*cert, *key)
		if err != nil {
			return fmt.Errorf("TLS certificate or private key invalid")
		}
		tlsConfig = &tls.Config{MinVersion: tls.VersionTLS12, Certificates: []tls.Certificate{certificate}}
		serverCertificate, err = x509.ParseCertificate(certificate.Certificate[0])
		if err != nil {
			return fmt.Errorf("TLS certificate cannot be parsed")
		}
	}
	dsn := os.Getenv("YUANZHENG_DATABASE_URL")
	if dsn == "" {
		return fmt.Errorf("YUANZHENG_DATABASE_URL is required")
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	db, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return fmt.Errorf("database configuration invalid")
	}
	defer db.Close()
	initCtx, cancel := context.WithTimeout(ctx, *startupTimeout)
	defer cancel()
	if err = db.Ping(initCtx); err != nil {
		return fmt.Errorf("database unavailable")
	}
	migrationStarted := time.Now()
	if *migrationMode == "auto" {
		err = online.Migrate(initCtx, db)
	} else {
		err = online.CheckMigrations(initCtx, db)
	}
	if err != nil {
		return fmt.Errorf("database migration %s failed: %w", *migrationMode, err)
	}
	if *restrictedDB {
		if err = online.CheckRuntimePrivileges(initCtx, db); err != nil {
			return err
		}
	}
	logger.Info("database migrations ready", "mode", *migrationMode, "restricted_role", *restrictedDB, "duration_ms", time.Since(migrationStarted).Milliseconds())
	hash := sha256.New()
	contentFiles, err := filepath.Glob(filepath.Join(*gameRoot, "data", "*.json"))
	if err != nil || len(contentFiles) == 0 {
		return fmt.Errorf("game content tables missing")
	}
	sort.Strings(contentFiles)
	for _, path := range contentFiles {
		name := filepath.Base(path)
		data, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("content file missing: %s", name)
		}
		if !json.Valid(data) {
			return fmt.Errorf("invalid JSON content: %s", name)
		}
		hash.Write([]byte(name))
		hash.Write([]byte{0})
		hash.Write(data)
	}
	version := fmt.Sprintf("%x", hash.Sum(nil))
	config := online.Config{ContentVersion: version, Logger: logger}
	if serverCertificate != nil {
		config.TLSNotBefore, config.TLSNotAfter = serverCertificate.NotBefore, serverCertificate.NotAfter
	}
	if *roomAddress != "" {
		worker, err := authority.New(*roomAddress, []byte(os.Getenv("YUANZHENG_ROOM_SECRET")), version, online.RulesetVersion)
		if err != nil {
			return err
		}
		if _, err = worker.Ping(initCtx); err != nil {
			return fmt.Errorf("authority unavailable: %w", err)
		}
		data, err := os.ReadFile(filepath.Join(*gameRoot, "data", "online_rules.json"))
		if err != nil {
			return err
		}
		if err = json.Unmarshal(data, &config.Rules); err != nil {
			return err
		}
		config.Authority = worker
	}
	app, err := online.NewServer(db, config)
	if err != nil {
		return err
	}
	server := &http.Server{Addr: *listen, Handler: app, TLSConfig: tlsConfig, ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 15 * time.Second, WriteTimeout: 20 * time.Second, IdleTimeout: 60 * time.Second, MaxHeaderBytes: 16 << 10}
	publicListener, err := net.Listen("tcp", *listen)
	if err != nil {
		return fmt.Errorf("public listener unavailable: %w", err)
	}
	defer publicListener.Close()
	defer server.Close()
	servers := []*http.Server{server}
	finished := make(chan error, 2)
	if *adminListen != "" {
		handler, err := app.AdminHandler(adminToken)
		if err != nil {
			return err
		}
		listener, err := net.Listen("tcp", *adminListen)
		if err != nil {
			return fmt.Errorf("admin listener unavailable: %w", err)
		}
		defer listener.Close()
		admin := &http.Server{Addr: *adminListen, Handler: handler, ReadHeaderTimeout: 3 * time.Second, ReadTimeout: 5 * time.Second, WriteTimeout: 5 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 16 << 10}
		defer admin.Close()
		servers = append(servers, admin)
		go func() { finished <- admin.Serve(listener) }()
		logger.Info("read-only admin listening", "address", *adminListen)
	}
	go func() {
		logger.Info("gateway listening", "address", *listen, "tls", tlsConfig != nil, "behind_tls_proxy", *trustedTLS, "protocol", online.ProtocolVersion, "content_version", version)
		if tlsConfig != nil {
			finished <- server.ServeTLS(publicListener, "", "")
		} else {
			finished <- server.Serve(publicListener)
		}
	}()
	var serveError error
	select {
	case serveError = <-finished:
	case <-ctx.Done():
	}
	end, endCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer endCancel()
	for _, service := range servers {
		if err = service.Shutdown(end); err != nil {
			_ = service.Close()
			if serveError == nil {
				serveError = err
			}
		}
	}
	if errors.Is(serveError, http.ErrServerClosed) {
		return nil
	}
	return serveError
}

func validateRuntimeEnvironment() error {
	for _, name := range []string{"YUANZHENG_TEST_DATABASE_URL", "YUANZHENG_DBADMIN_URL", "YUANZHENG_MIGRATION_DATABASE_URL", "YUANZHENG_BACKUP_DATABASE_URL", "YUANZHENG_MIGRATOR_PASSWORD", "YUANZHENG_RUNTIME_PASSWORD", "YUANZHENG_BACKUP_PASSWORD", "PGPASSWORD", "PGPASSFILE", "PGSERVICE", "PGSERVICEFILE"} {
		if os.Getenv(name) != "" {
			return fmt.Errorf("restricted gateway must not inherit offline database credentials")
		}
	}
	return nil
}

func validateListeners(listen, cert, key, adminListen, adminToken string) error {
	host, port, err := net.SplitHostPort(listen)
	number, portError := strconv.Atoi(port)
	if err != nil || portError != nil || number < 1 || number > 65535 {
		return fmt.Errorf("invalid public listen address")
	}
	if (cert == "") != (key == "") {
		return fmt.Errorf("TLS certificate and private key must be supplied together")
	}
	ip := net.ParseIP(host)
	if cert == "" && (ip == nil || !ip.IsLoopback()) {
		return fmt.Errorf("plaintext HTTP requires a literal loopback address, including behind a TLS proxy")
	}
	if adminListen != "" {
		host, port, err = net.SplitHostPort(adminListen)
		number, portError = strconv.Atoi(port)
		ip = net.ParseIP(host)
		if err != nil || portError != nil || ip == nil || !ip.IsLoopback() || number < 1024 || number > 65535 {
			return fmt.Errorf("admin listener requires a literal loopback address and unprivileged port")
		}
		if len(adminToken) < 32 || strings.TrimSpace(adminToken) != adminToken {
			return fmt.Errorf("YUANZHENG_ADMIN_TOKEN must contain at least 32 characters without surrounding whitespace")
		}
	}
	return nil
}
