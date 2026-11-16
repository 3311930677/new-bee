package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
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
	trustedTLS := flag.Bool("behind-tls-proxy", false, "Explicitly acknowledge deployment behind a trusted TLS reverse proxy")
	roomAddress := flag.String("authority-address", "", "Optional private Godot worker loopback address")
	flag.Parse()
	host, _, err := net.SplitHostPort(*listen)
	if err != nil {
		return fmt.Errorf("invalid listen address")
	}
	ip := net.ParseIP(host)
	if (ip == nil || !ip.IsLoopback()) && (*cert == "" || *key == "") && !*trustedTLS {
		return fmt.Errorf("non-loopback deployment requires TLS or --behind-tls-proxy")
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
	initCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	if err = db.Ping(initCtx); err != nil {
		return fmt.Errorf("database unavailable")
	}
	if err = online.Migrate(initCtx, db); err != nil {
		return fmt.Errorf("database migration failed: %w", err)
	}
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
	server := &http.Server{Addr: *listen, Handler: app, ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 15 * time.Second, WriteTimeout: 20 * time.Second, IdleTimeout: 60 * time.Second, MaxHeaderBytes: 16 << 10}
	finished := make(chan error, 1)
	go func() {
		logger.Info("gateway listening", "address", *listen, "protocol", online.ProtocolVersion, "content_version", version)
		if *cert != "" {
			finished <- server.ListenAndServeTLS(*cert, *key)
		} else {
			finished <- server.ListenAndServe()
		}
	}()
	select {
	case err := <-finished:
		if err != http.ErrServerClosed {
			return err
		}
		return nil
	case <-ctx.Done():
		end, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return server.Shutdown(end)
	}
}
