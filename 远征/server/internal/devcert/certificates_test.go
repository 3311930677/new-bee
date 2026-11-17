package devcert

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/pem"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestDevelopmentCertificatesValidateAndRejectFixtures(t *testing.T) {
	directory := filepath.Join(t.TempDir(), "tls")
	now := time.Now()
	manifest, err := Create(directory, true, now)
	if err != nil {
		t.Fatal(err)
	}
	if len(manifest.PublicFiles) != 5 {
		t.Fatal("expected all public test certificates")
	}
	if _, err := tls.LoadX509KeyPair(filepath.Join(directory, "server-cert.pem"), filepath.Join(directory, "server-key.pem")); err != nil {
		t.Fatal(err)
	}
	pool := func(name string) *x509.CertPool {
		raw, err := os.ReadFile(filepath.Join(directory, name))
		if err != nil {
			t.Fatal(err)
		}
		result := x509.NewCertPool()
		if !result.AppendCertsFromPEM(raw) {
			t.Fatal("invalid CA")
		}
		return result
	}
	correctCA, wrongCA := pool("ca-cert.pem"), pool("untrusted-ca.pem")
	for _, item := range []struct {
		certificate, hostname string
		roots                 *x509.CertPool
		valid                 bool
	}{
		{"server-cert.pem", "127.0.0.1", correctCA, true},
		{"server-cert.pem", "localhost", correctCA, true},
		{"server-cert.pem", "::1", correctCA, true},
		{"server-cert.pem", "127.0.0.1", wrongCA, false},
		{"wrong-name-cert.pem", "127.0.0.1", correctCA, false},
		{"expired-cert.pem", "127.0.0.1", correctCA, false},
	} {
		raw, err := os.ReadFile(filepath.Join(directory, item.certificate))
		if err != nil {
			t.Fatal(err)
		}
		block, _ := pem.Decode(raw)
		if block == nil {
			t.Fatal("invalid certificate PEM")
		}
		certificate, err := x509.ParseCertificate(block.Bytes)
		if err != nil {
			t.Fatal(err)
		}
		_, err = certificate.Verify(x509.VerifyOptions{DNSName: item.hostname, Roots: item.roots, CurrentTime: now})
		if (err == nil) != item.valid {
			t.Fatalf("certificate=%s host=%s expected-valid=%t error=%v", item.certificate, item.hostname, item.valid, err)
		}
	}
	if _, err := os.Stat(filepath.Join(directory, "ca-key.pem")); !os.IsNotExist(err) {
		t.Fatal("CA private key must not be retained")
	}
}

func TestDevelopmentCertificatesNeverOverwriteExistingDirectory(t *testing.T) {
	directory := t.TempDir()
	sentinel := filepath.Join(directory, "server-key.pem")
	if err := os.WriteFile(sentinel, []byte("existing private material"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := Create(directory, false, time.Now()); err == nil {
		t.Fatal("existing directory accepted")
	}
	data, err := os.ReadFile(sentinel)
	if err != nil || string(data) != "existing private material" {
		t.Fatal("existing key changed")
	}
}
