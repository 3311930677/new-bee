// Package authority implements authenticated private RPC to a headless Godot worker.
// It has no public client endpoint and never accepts a result without its worker MAC.
package authority

import (
	"bufio"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"regexp"
	"strconv"
	"time"
)

const MaxFrame = 2 * 1024 * 1024

var ErrAuthentication = errors.New("private authority response authentication failed")
var ErrProtocol = errors.New("private authority response invalid")

type Client struct {
	address        string
	secret         []byte
	contentVersion string
	rulesetVersion string
}

type request struct {
	Body      string `json:"body"`
	Nonce     string `json:"nonce"`
	IssuedAt  int64  `json:"issued_at"`
	Signature string `json:"signature"`
}
type response struct {
	Body      string `json:"body"`
	Nonce     string `json:"nonce"`
	Signature string `json:"signature"`
}
type RPCError struct{ Code string }

func (e *RPCError) Error() string { return "authority rejected request: " + e.Code }

func New(address string, secret []byte, contentVersion, rulesetVersion string) (*Client, error) {
	host, port, err := net.SplitHostPort(address)
	ip := net.ParseIP(host)
	number, portErr := strconv.Atoi(port)
	if err != nil || ip == nil || !ip.IsLoopback() || portErr != nil || number < 1024 || number > 65535 {
		return nil, errors.New("authority address must be a literal loopback address and unprivileged port")
	}
	if len(secret) < 32 {
		return nil, errors.New("private authority key must contain at least 32 bytes")
	}
	if contentVersion == "" || rulesetVersion == "" {
		return nil, errors.New("authority content and ruleset versions are required")
	}
	return &Client{address: address, secret: append([]byte(nil), secret...), contentVersion: contentVersion, rulesetVersion: rulesetVersion}, nil
}

func mac(key []byte, message string) []byte {
	h := hmac.New(sha256.New, key)
	_, _ = h.Write([]byte(message))
	return h.Sum(nil)
}
func nonce() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic("OS random source unavailable")
	}
	b[6] = (b[6] & 15) | 64
	b[8] = (b[8] & 63) | 128
	value := hex.EncodeToString(b[:])
	return value[:8] + "-" + value[8:12] + "-" + value[12:16] + "-" + value[16:20] + "-" + value[20:]
}

var errorCode = regexp.MustCompile(`^[a-z_]{1,64}$`)

func (c *Client) Call(ctx context.Context, method string, args any, out any) error {
	if args == nil {
		args = map[string]any{}
	}
	payload, err := json.Marshal(map[string]any{"method": method, "args": args, "content_version": c.contentVersion, "ruleset_version": c.rulesetVersion})
	if err != nil {
		return err
	}
	req := request{Body: string(payload), Nonce: nonce(), IssuedAt: time.Now().Unix()}
	req.Signature = hex.EncodeToString(mac(c.secret, fmt.Sprintf("%d|%s|%s", req.IssuedAt, req.Nonce, req.Body)))
	wire, err := json.Marshal(req)
	if err != nil {
		return err
	}
	if len(wire)+1 > MaxFrame {
		return errors.New("private authority request exceeded frame limit")
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	conn, err := (&net.Dialer{}).DialContext(ctx, "tcp", c.address)
	if err != nil {
		return operationError(ctx, err)
	}
	defer conn.Close()
	stop := context.AfterFunc(ctx, func() { _ = conn.Close() })
	defer stop()
	deadline, _ := ctx.Deadline()
	if err = conn.SetDeadline(deadline); err != nil {
		return err
	}
	if _, err = conn.Write(append(wire, '\n')); err != nil {
		return operationError(ctx, err)
	}
	raw, err := bufio.NewReader(io.LimitReader(conn, MaxFrame+1)).ReadBytes('\n')
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if err != nil {
		return operationError(ctx, err)
	}
	if len(raw) > MaxFrame {
		return ErrProtocol
	}
	var reply response
	if err = json.Unmarshal(raw, &reply); err != nil {
		return ErrProtocol
	}
	if reply.Nonce != req.Nonce {
		return ErrAuthentication
	}
	signature, err := hex.DecodeString(reply.Signature)
	if err != nil || len(signature) != sha256.Size || !hmac.Equal(signature, mac(c.secret, reply.Nonce+"|"+reply.Body)) {
		return ErrAuthentication
	}
	var base struct {
		OK    *bool  `json:"ok"`
		Error string `json:"error"`
	}
	if json.Unmarshal([]byte(reply.Body), &base) != nil || base.OK == nil {
		return ErrProtocol
	}
	if !*base.OK {
		if !errorCode.MatchString(base.Error) {
			return ErrProtocol
		}
		return &RPCError{Code: base.Error}
	}
	if out != nil {
		return json.Unmarshal([]byte(reply.Body), out)
	}
	return nil
}

func operationError(ctx context.Context, err error) error {
	if ctx.Err() != nil {
		return ctx.Err()
	}
	// A socket deadline can fire just before the context timer is scheduled.
	// Every socket deadline above comes from this context, so preserve its semantics.
	var timeout net.Error
	if errors.As(err, &timeout) && timeout.Timeout() {
		return context.DeadlineExceeded
	}
	return err
}

type Health struct {
	Epoch          string `json:"epoch"`
	OK             bool   `json:"ok"`
	ContentVersion string `json:"content_version"`
	RulesetVersion string `json:"ruleset_version"`
	Engine         string `json:"engine"`
	Battles        int    `json:"battles"`
}

func (c *Client) Ping(ctx context.Context) (Health, error) {
	var health Health
	if err := c.Call(ctx, "ping", nil, &health); err != nil {
		return Health{}, err
	}
	if health.ContentVersion != c.contentVersion || health.RulesetVersion != c.rulesetVersion {
		return Health{}, errors.New("authority version mismatch")
	}
	return health, nil
}
