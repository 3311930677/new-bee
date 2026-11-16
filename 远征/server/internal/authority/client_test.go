package authority

import (
	"bufio"
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net"
	"strconv"
	"strings"
	"testing"
	"time"
)

func privatePeer(t *testing.T, handler func(request) response) *Client {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = listener.Close() })
	key := []byte(strings.Repeat("test-key", 8))
	client, err := New(listener.Addr().String(), key, "test-content", "test-rules")
	if err != nil {
		t.Fatal(err)
	}
	go func() {
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		var req request
		raw, err := bufio.NewReader(conn).ReadBytes('\n')
		if err != nil {
			return
		}
		if json.Unmarshal(raw, &req) != nil {
			return
		}
		_ = json.NewEncoder(conn).Encode(handler(req))
	}()
	return client
}

func TestSignedTransportAndUTF8(t *testing.T) {
	key := []byte(strings.Repeat("test-key", 8))
	client := privatePeer(t, func(req request) response {
		expected := hex.EncodeToString(mac(key, strings.Join([]string{strconv.FormatInt(req.IssuedAt, 10), req.Nonce, req.Body}, "|")))
		if req.Signature != expected {
			t.Error("request was not authenticated")
		}
		var payload map[string]any
		if json.Unmarshal([]byte(req.Body), &payload) != nil || payload["content_version"] != "test-content" {
			t.Error("version envelope missing")
		}
		body := `{"ok":true,"message":"归路旅人"}`
		return response{Body: body, Nonce: req.Nonce, Signature: hex.EncodeToString(mac(key, req.Nonce+"|"+body))}
	})
	var result struct {
		Message string `json:"message"`
	}
	if err := client.Call(context.Background(), "ping", nil, &result); err != nil {
		t.Fatal(err)
	}
	if result.Message != "归路旅人" {
		t.Fatal("UTF8 response changed")
	}
}

func TestRejectTamperedResponseAndNonce(t *testing.T) {
	for _, kind := range []string{"signature", "nonce"} {
		t.Run(kind, func(t *testing.T) {
			client := privatePeer(t, func(req request) response {
				body := `{"ok":true}`
				key := []byte(strings.Repeat("test-key", 8))
				r := response{Body: body, Nonce: req.Nonce, Signature: hex.EncodeToString(mac(key, req.Nonce+"|"+body))}
				if kind == "signature" {
					r.Body = `{"ok":true,"gold":999999}`
				} else {
					r.Nonce = nonce()
				}
				return r
			})
			if err := client.Call(context.Background(), "ping", nil, nil); !errors.Is(err, ErrAuthentication) {
				t.Fatalf("tampered response accepted: %v", err)
			}
		})
	}
}

func TestPrivateAddressAndKeyBoundary(t *testing.T) {
	key := []byte(strings.Repeat("k", 32))
	for _, address := range []string{"0.0.0.0:19081", "192.168.1.2:19081", "example.com:19081", "127.0.0.1:80"} {
		if _, err := New(address, key, "content", "rules"); err == nil {
			t.Fatalf("private boundary accepted %s", address)
		}
	}
	if _, err := New("127.0.0.1:19081", []byte("short"), "content", "rules"); err == nil {
		t.Fatal("short key accepted")
	}
}

func TestContextCancellationClosesPrivateSocket(t *testing.T) {
	client := privatePeer(t, func(req request) response { time.Sleep(250 * time.Millisecond); return response{} })
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Millisecond)
	defer cancel()
	started := time.Now()
	if err := client.Call(ctx, "ping", nil, nil); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("expected deadline, got %v", err)
	}
	if time.Since(started) > time.Second {
		t.Fatal("cancelled request kept the socket blocked")
	}
}
