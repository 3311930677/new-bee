package main

import (
	"context"
	"flag"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"yuanzheng/online/internal/servicehost"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	path := flag.String("config", "", "Absolute path to one role's non-secret JSON configuration")
	credentials := flag.String("credentials-directory", os.Getenv("CREDENTIALS_DIRECTORY"), "Private credential directory; systemd supplies the default")
	developmentACL := flag.Bool("development-acl", false, "Acknowledge Windows foreground testing without production ACL acceptance")
	stopDirectory := flag.String("request-stop", "", "Write a nonce-bound stop request to this private foreground-host state directory")
	flag.Parse()
	if *stopDirectory != "" {
		if servicehost.RequestStop(*stopDirectory) != nil {
			logger.Error("service stop request rejected")
			os.Exit(1)
		}
		return
	}
	cfg, err := servicehost.ReadConfig(*path)
	if err != nil {
		logger.Error("service configuration rejected")
		os.Exit(1)
	}
	spec, err := servicehost.Prepare(cfg, *credentials, os.Environ(), *developmentACL)
	if err != nil {
		logger.Error("service role or credential boundary rejected")
		os.Exit(1)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := servicehost.Run(ctx, spec, logger); err != nil {
		logger.Error("service host stopped", "reason", err.Error())
		os.Exit(1)
	}
}
