package main

import (
	"os"
	"strings"
	"testing"
)

func TestListenerBoundaries(t *testing.T) {
	secret := strings.Repeat("a", 64)
	for _, item := range []struct {
		name, public, cert, key, admin, token string
		allowed                               bool
	}{
		{"local development", "127.0.0.1:18080", "", "", "", "", true},
		{"IPv6 local", "[::1]:18080", "", "", "[::1]:18081", secret, true},
		{"public TLS", "0.0.0.0:443", "certificate.pem", "key.pem", "127.0.0.1:18081", secret, true},
		{"public plaintext", "0.0.0.0:18080", "", "", "", "", false},
		{"hostname plaintext", "localhost:18080", "", "", "", "", false},
		{"missing private key", "127.0.0.1:18080", "certificate.pem", "", "", "", false},
		{"missing certificate", "127.0.0.1:18080", "", "key.pem", "", "", false},
		{"invalid public port", "127.0.0.1:70000", "", "", "", "", false},
		{"public admin", "127.0.0.1:18080", "", "", "0.0.0.0:18081", secret, false},
		{"hostname admin", "127.0.0.1:18080", "", "", "localhost:18081", secret, false},
		{"privileged admin", "127.0.0.1:18080", "", "", "127.0.0.1:443", secret, false},
		{"missing admin token", "127.0.0.1:18080", "", "", "127.0.0.1:18081", "", false},
		{"weak admin token", "127.0.0.1:18080", "", "", "127.0.0.1:18081", "short", false},
		{"whitespace token", "127.0.0.1:18080", "", "", "127.0.0.1:18081", " " + secret, false},
	} {
		t.Run(item.name, func(t *testing.T) {
			err := validateListeners(item.public, item.cert, item.key, item.admin, item.token)
			if (err == nil) != item.allowed {
				t.Fatalf("allowed=%t, error=%v", item.allowed, err)
			}
			if err != nil && item.token != "" && strings.Contains(err.Error(), item.token) {
				t.Fatal("configuration error exposed admin token")
			}
		})
	}
}

func TestRestrictedGatewayRejectsOfflineCredentialEnvironment(t *testing.T) {
	names := []string{"YUANZHENG_TEST_DATABASE_URL", "YUANZHENG_DBADMIN_URL", "YUANZHENG_MIGRATION_DATABASE_URL", "YUANZHENG_BACKUP_DATABASE_URL", "YUANZHENG_MIGRATOR_PASSWORD", "YUANZHENG_RUNTIME_PASSWORD", "YUANZHENG_BACKUP_PASSWORD", "PGPASSWORD", "PGPASSFILE", "PGSERVICE", "PGSERVICEFILE"}
	for _, name := range names {
		t.Setenv(name, "")
	}
	if err := validateRuntimeEnvironment(); err != nil {
		t.Fatal(err)
	}
	for _, name := range names {
		t.Setenv(name, "private-must-not-be-reported")
		if err := validateRuntimeEnvironment(); err == nil || strings.Contains(err.Error(), os.Getenv(name)) {
			t.Fatal("offline credential accepted or disclosed")
		}
		t.Setenv(name, "")
	}
}
