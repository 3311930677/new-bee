package online

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestRoomPositionStreamFollowsCommittedNearbyPlayers(t *testing.T) {
	h := setupTown(t, 2)
	token, self, lease := h.townRole("pos_observe")
	peerToken, peer, peerLease := h.townRole("pos_neighbor")
	_, other, otherLease := h.townRole("pos_outside")
	if peerLease.RoomID != lease.RoomID || otherLease.RoomID == lease.RoomID {
		t.Fatal("fixture needs two channels")
	}
	requireStatus(t, h.request("GET", "/v1/rooms/positions", "", "", nil), http.StatusUnauthorized)

	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, h.server.URL+"/v1/rooms/positions", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-Content-Version", "integration-v1")
	resp, err := h.server.Client().Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK || !strings.HasPrefix(resp.Header.Get("Content-Type"), "application/x-ndjson") {
		t.Fatal("room did not publish a position stream")
	}
	decoder := json.NewDecoder(resp.Body)
	var lastTick uint64
	readUntil := func(predicate func(map[string]worldEntity) bool) {
		t.Helper()
		for {
			var raw json.RawMessage
			if err := decoder.Decode(&raw); err != nil {
				t.Fatal("position stream ended before the expected committed frame")
			}
			for _, private := range []string{"lease_token", "session_id", "access_hash", lease.Token, peerLease.Token, token, peerToken, other} {
				if bytes.Contains(raw, []byte(private)) {
					t.Fatal("position stream contained a private value or a different channel")
				}
			}
			var frame worldPositionFrame
			if err := json.Unmarshal(raw, &frame); err != nil {
				t.Fatal(err)
			}
			if frame.RoomID != lease.RoomID || frame.MapID != lease.MapID || frame.Generation != lease.Generation || frame.Tick <= lastTick {
				t.Fatal("position frame moved backwards or left the viewer's lease")
			}
			lastTick = frame.Tick
			view := make(map[string]worldEntity)
			for _, entity := range frame.Entities {
				view[entity.ID] = entity
			}
			if view[self].ID != self {
				t.Fatal("the viewing role is absent from its own frame")
			}
			if predicate(view) {
				return
			}
		}
	}
	readUntil(func(view map[string]worldEntity) bool { return len(view) == 2 && view[peer].ID == peer })
	requireStatus(t, h.request("POST", "/v1/rooms/move", peerToken, "position-stream-move", moveBody{
		Token: peerLease.Token, Generation: peerLease.Generation, Sequence: 1, X: 620, Y: 1520,
	}), http.StatusOK)
	readUntil(func(view map[string]worldEntity) bool { return view[peer].MoveSequence == 1 && view[peer].X == 620 })

	// Move the fixture outside viewing range, then back to the border.
	movePeer := func(x float64) {
		t.Helper()
		if _, err := h.db.Exec(ctx, `UPDATE room_leases SET x=$1 WHERE token=$2`, x, peerLease.Token); err != nil {
			t.Fatal(err)
		}
	}
	movePeer(1081)
	readUntil(func(view map[string]worldEntity) bool { return len(view) == 1 })
	snapshot := h.request("GET", "/v1/rooms/current", token, "", nil)
	requireStatus(t, snapshot, 200)
	if bytes.Contains(snapshot.data["entities"], []byte(peer)) {
		t.Fatal("fallback snapshot revealed an out-of-range position")
	}
	movePeer(1080)
	readUntil(func(view map[string]worldEntity) bool { return view[peer].X == 1080 })

	login := h.request("POST", "/v1/auth/login", "", "", credentials{"pos_observe", "long-test-password"})
	requireStatus(t, login, http.StatusOK)
	for {
		var last json.RawMessage
		err = decoder.Decode(&last)
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			t.Fatal("revoked old observer did not close cleanly")
		}
	}
	requireStatus(t, h.request("GET", "/v1/rooms/positions", token, "", nil), http.StatusUnauthorized)
}

func TestTownPositionFeedSharesAChannelAcross24Clients(t *testing.T) {
	const capacity = 24
	h := setupTown(t, capacity)
	tokens := make([]string, capacity)
	ids := make([]string, capacity)
	var roomID string
	for i := range tokens {
		token, id, lease := h.townRole(fmt.Sprintf("town_pos_%02d", i))
		tokens[i], ids[i] = token, id
		if i == 0 {
			roomID = lease.RoomID
		}
		if lease.RoomID != roomID {
			t.Fatal("channel split before reaching its online capacity")
		}
	}
	overflowToken, overflowID, overflowLease := h.townRole("pos_overflow")
	if overflowLease.RoomID == roomID {
		t.Fatal("the 25th character entered a full channel")
	}
	overflow := h.request("GET", "/v1/rooms/current", overflowToken, "", nil)
	requireStatus(t, overflow, http.StatusOK)
	var overflowView []worldEntity
	if err := json.Unmarshal(overflow.data["entities"], &overflowView); err != nil || len(overflowView) != 1 || overflowView[0].ID != overflowID {
		t.Fatal("overflow channel exposed the first channel's players")
	}

	type observation struct {
		index int
		frame worldPositionFrame
		err   error
	}
	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
	defer cancel()
	results := make(chan observation, capacity)
	for i, token := range tokens {
		go func(index int, token string) {
			frame, err := observeFirstFrame(ctx, h.server.Client(), h.server.URL, token)
			results <- observation{index, frame, err}
		}(i, token)
	}
	for range capacity {
		result := <-results
		if result.err != nil || result.frame.RoomID != roomID || len(result.frame.Entities) != capacity {
			t.Fatalf("viewer %d did not receive its full nearby channel: %v", result.index, result.err)
		}
		found := false
		for _, entity := range result.frame.Entities {
			found = found || entity.ID == ids[result.index]
			if entity.ID == overflowID {
				t.Fatal("stream exposed the overflow channel")
			}
		}
		if !found {
			t.Fatalf("viewer %d did not receive its own confirmed position", result.index)
		}
	}
}

func observeFirstFrame(ctx context.Context, client *http.Client, base, token string) (worldPositionFrame, error) {
	var frame worldPositionFrame
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, base+"/v1/rooms/positions", nil)
	if err != nil {
		return frame, err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("X-Content-Version", "integration-v1")
	response, err := client.Do(req)
	if err != nil {
		return frame, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return frame, fmt.Errorf("unexpected HTTP code %d", response.StatusCode)
	}
	err = json.NewDecoder(response.Body).Decode(&frame)
	return frame, err
}
