// Package devcert creates disposable local TLS fixtures. It never installs a
// system root, retains a CA private key, or overwrites an existing directory.
package devcert

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"time"
)

type Manifest struct {
	GeneratedAt time.Time         `json:"generated_at"`
	ValidUntil  time.Time         `json:"server_valid_until"`
	PublicFiles map[string]string `json:"public_files_sha256"`
	PrivateKey  string            `json:"private_key_file"`
	Purpose     string            `json:"purpose"`
}

func serial() (*big.Int, error) { return rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128)) }

func root(now time.Time) (*x509.Certificate, *rsa.PrivateKey, []byte, error) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, nil, nil, err
	}
	number, err := serial()
	if err != nil {
		return nil, nil, nil, err
	}
	template := &x509.Certificate{SerialNumber: number, Subject: pkix.Name{CommonName: "Yuanzheng disposable local test CA"},
		NotBefore: now.Add(-time.Hour), NotAfter: now.Add(7 * 24 * time.Hour), IsCA: true, BasicConstraintsValid: true,
		KeyUsage: x509.KeyUsageCertSign | x509.KeyUsageCRLSign}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		return nil, nil, nil, err
	}
	certificate, err := x509.ParseCertificate(der)
	return certificate, key, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}), err
}

func Create(directory string, negativeFixtures bool, now time.Time) (Manifest, error) {
	manifest := Manifest{GeneratedAt: now.UTC(), ValidUntil: now.Add(48 * time.Hour).UTC(), PublicFiles: map[string]string{}, PrivateKey: "server-key.pem", Purpose: "disposable loopback development; not production PKI or system trust"}
	if _, err := os.Stat(directory); !os.IsNotExist(err) {
		return manifest, fmt.Errorf("output directory already exists or cannot be checked")
	}
	if err := os.MkdirAll(filepath.Dir(directory), 0700); err != nil {
		return manifest, err
	}
	if err := os.Mkdir(directory, 0700); err != nil {
		return manifest, err
	}
	write := func(name string, data []byte, private bool) error {
		mode := os.FileMode(0644)
		if private {
			mode = 0600
		}
		file, err := os.OpenFile(filepath.Join(directory, name), os.O_WRONLY|os.O_CREATE|os.O_EXCL, mode)
		if err != nil {
			return err
		}
		_, writeError := file.Write(data)
		closeError := file.Close()
		if writeError != nil {
			return writeError
		}
		if !private {
			manifest.PublicFiles[name] = fmt.Sprintf("%x", sha256.Sum256(data))
		}
		return closeError
	}
	ca, caKey, caPEM, err := root(now)
	if err != nil {
		return manifest, err
	}
	if err = write("ca-cert.pem", caPEM, false); err != nil {
		return manifest, err
	}
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return manifest, err
	}
	private, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return manifest, err
	}
	if err = write(manifest.PrivateKey, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: private}), true); err != nil {
		return manifest, err
	}
	issue := func(name, hostname string, before, after time.Time) error {
		number, err := serial()
		if err != nil {
			return err
		}
		template := &x509.Certificate{SerialNumber: number, Subject: pkix.Name{CommonName: hostname}, DNSNames: []string{hostname},
			NotBefore: before, NotAfter: after, BasicConstraintsValid: true,
			KeyUsage: x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment, ExtKeyUsage: []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth}}
		if hostname == "localhost" {
			template.IPAddresses = []net.IP{net.ParseIP("127.0.0.1"), net.ParseIP("::1")}
		}
		der, err := x509.CreateCertificate(rand.Reader, template, ca, &key.PublicKey, caKey)
		if err != nil {
			return err
		}
		return write(name, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}), false)
	}
	if err = issue("server-cert.pem", "localhost", now.Add(-time.Minute), manifest.ValidUntil); err != nil {
		return manifest, err
	}
	if negativeFixtures {
		if err = issue("wrong-name-cert.pem", "wrong.invalid", now.Add(-time.Minute), manifest.ValidUntil); err != nil {
			return manifest, err
		}
		if err = issue("expired-cert.pem", "localhost", now.Add(-48*time.Hour), now.Add(-24*time.Hour)); err != nil {
			return manifest, err
		}
		_, _, wrongCA, err := root(now)
		if err != nil {
			return manifest, err
		}
		if err = write("untrusted-ca.pem", wrongCA, false); err != nil {
			return manifest, err
		}
	}
	metadata, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return manifest, err
	}
	if err = write("manifest.json", metadata, true); err != nil {
		return manifest, err
	}
	return manifest, nil
}
