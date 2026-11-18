package online

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
)

func TestFriendsBlockReportAndChatFiltering(t *testing.T) {
	h := setupL1World(t, 8)
	tokenA, charA, _ := h.townRole("soc_alpha")
	tokenB, charB, _ := h.townRole("soc_bravo")

	// Friend request + accept + idempotency.
	req := h.request("POST", "/v1/social/friends/request", tokenA, "fr-req-001", map[string]any{"target_character_id": charB})
	requireStatus(t, req, http.StatusOK)
	snapB := h.request("GET", "/v1/social/state", tokenB, "", nil)
	requireStatus(t, snapB, http.StatusOK)
	var bState socialSnapshot
	if err := json.Unmarshal(mustMarshal(t, snapB.data), &bState); err != nil || len(bState.FriendRequests) != 1 {
		t.Fatalf("expected 1 incoming friend request for B, got %+v err=%v", bState, err)
	}
	reqID := bState.FriendRequests[0].ID
	accept := h.request("POST", "/v1/social/friends/"+reqID+"/respond", tokenB, "fr-acc-001", map[string]any{"accept": true})
	requireStatus(t, accept, http.StatusOK)
	var accState socialSnapshot
	_ = json.Unmarshal(mustMarshal(t, accept.data), &accState)
	if len(accState.Friends) != 1 || accState.Friends[0].ID != charA {
		t.Fatalf("expected A in B friends, got %+v", accState.Friends)
	}

	// Room chat, nearby AOI chat, and whisper.
	requireStatus(t, h.request("POST", "/v1/chat/messages", tokenA, "chat-room-001", map[string]any{"channel_kind": "room", "content": "大家好"}), http.StatusCreated)
	requireStatus(t, h.request("POST", "/v1/chat/messages", tokenA, "chat-near-001", map[string]any{"channel_kind": "nearby", "content": "附近可见"}), http.StatusCreated)
	requireStatus(t, h.request("POST", "/v1/chat/messages", tokenA, "chat-whsp-001", map[string]any{"channel_kind": "whisper", "recipient_character_id": charB, "content": "私聊密语"}), http.StatusCreated)

	// Move B 600px away (>480 AOI) -> B sees room + whisper, NOT nearby!
	if _, err := h.db.Exec(context.Background(), `UPDATE room_leases SET y=2120 WHERE character_id=$1`, charB); err != nil {
		t.Fatal(err)
	}
	farChat := h.request("GET", "/v1/chat/messages", tokenB, "", nil)
	requireStatus(t, farChat, http.StatusOK)
	var farMsgs []chatMessage
	_ = json.Unmarshal(farChat.data["messages"], &farMsgs)
	if len(farMsgs) != 2 {
		t.Fatalf("expected room+whisper (2) when >480px away, got %+v", farMsgs)
	}

	// Move B back within AOI -> sees all 3.
	if _, err := h.db.Exec(context.Background(), `UPDATE room_leases SET y=1540 WHERE character_id=$1`, charB); err != nil {
		t.Fatal(err)
	}
	nearChat := h.request("GET", "/v1/chat/messages", tokenB, "", nil)
	requireStatus(t, nearChat, http.StatusOK)
	var nearMsgs []chatMessage
	_ = json.Unmarshal(nearChat.data["messages"], &nearMsgs)
	if len(nearMsgs) != 3 {
		t.Fatalf("expected all 3 chat messages within AOI, got %+v", nearMsgs)
	}

	// Report A cleanly.
	rep := h.request("POST", "/v1/social/reports", tokenB, "report-alpha-001", map[string]any{"target_character_id": charA, "category": "harassment", "reason": "恶意刷屏骚扰"})
	requireStatus(t, rep, http.StatusCreated)
	var reportCount int
	if err := h.db.QueryRow(context.Background(), `SELECT count(*) FROM player_reports WHERE target_character_id=$1`, charA).Scan(&reportCount); err != nil || reportCount != 1 {
		t.Fatalf("expected 1 persisted report, got %d err=%v", reportCount, err)
	}

	// Block A -> clears friendship, hides A's messages from B, blocks whisper & friend request.
	blk := h.request("POST", "/v1/social/blocks", tokenB, "block-alpha-001", map[string]any{"target_character_id": charA})
	requireStatus(t, blk, http.StatusOK)
	var blkState socialSnapshot
	_ = json.Unmarshal(mustMarshal(t, blk.data), &blkState)
	if len(blkState.Friends) != 0 || len(blkState.Blocks) != 1 {
		t.Fatalf("expected friendship cleared and 1 block, got %+v", blkState)
	}
	blockedChat := h.request("GET", "/v1/chat/messages", tokenB, "", nil)
	var blockedMsgs []chatMessage
	_ = json.Unmarshal(blockedChat.data["messages"], &blockedMsgs)
	if len(blockedMsgs) != 0 {
		t.Fatalf("blocked sender messages leaked: %+v", blockedMsgs)
	}
	requireStatus(t, h.request("POST", "/v1/chat/messages", tokenA, "chat-blk-001", map[string]any{"channel_kind": "whisper", "recipient_character_id": charB, "content": "拦截"}), http.StatusForbidden)
	requireStatus(t, h.request("POST", "/v1/social/friends/request", tokenA, "fr-blk-001", map[string]any{"target_character_id": charB}), http.StatusForbidden)

	// Unblock cleanly.
	unblk := h.request("DELETE", "/v1/social/blocks/"+blkState.Blocks[0].AccountID, tokenB, "", nil)
	requireStatus(t, unblk, http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/social/friends/request", tokenA, "fr-unblk-001", map[string]any{"target_character_id": charB}), http.StatusOK)
}

func TestPartyCreateInviteReadyLeaderTransferKickAndCapacity(t *testing.T) {
	h := setupL1World(t, 8)
	tokens := make([]string, 5)
	chars := make([]string, 5)
	for i := range 5 {
		tokens[i], chars[i], _ = h.townRole(fmt.Sprintf("party_u%d", i+1))
	}

	requireStatus(t, h.request("POST", "/v1/parties", tokens[0], "pt-create-001", map[string]any{}), http.StatusOK)
	// Duplicate create rejected 409.
	requireStatus(t, h.request("POST", "/v1/parties", tokens[0], "pt-create-002", map[string]any{}), http.StatusConflict)

	for i := 1; i <= 3; i++ {
		requireStatus(t, h.request("POST", "/v1/parties/invite", tokens[0], fmt.Sprintf("pt-inv-%d", i), map[string]any{"target_character_id": chars[i]}), http.StatusOK)
		pv := h.request("GET", "/v1/parties/current", tokens[i], "", nil)
		requireStatus(t, pv, http.StatusOK)
		var view partyView
		_ = json.Unmarshal(mustMarshal(t, pv.data), &view)
		if len(view.Invitations) != 1 {
			t.Fatalf("expected 1 invite for member %d, got %+v", i, view.Invitations)
		}
		requireStatus(t, h.request("POST", "/v1/parties/invites/"+view.Invitations[0].ID+"/respond", tokens[i], fmt.Sprintf("pt-acc-%d", i), map[string]any{"accept": true}), http.StatusOK)
	}

	// 5th invite hits 4-player cap.
	full := h.request("POST", "/v1/parties/invite", tokens[0], "pt-inv-full", map[string]any{"target_character_id": chars[4]})
	requireStatus(t, full, http.StatusConflict)
	if full.code != "party_full" {
		t.Fatalf("expected party_full, got %s", full.code)
	}

	// Non-leader cannot kick or promote.
	requireStatus(t, h.request("POST", "/v1/parties/kick", tokens[1], "pt-kick-unauth", map[string]any{"target_character_id": chars[2]}), http.StatusForbidden)
	requireStatus(t, h.request("POST", "/v1/parties/ready", tokens[1], "pt-rdy-001", map[string]any{"ready": true}), http.StatusOK)

	// Party chat reaches cross-map teammate and excludes non-member P5.
	if _, err := h.db.Exec(context.Background(), `UPDATE room_leases SET x=616,y=140 WHERE character_id=$1`, chars[1]); err != nil {
		t.Fatal(err)
	}
	requireStatus(t, h.request("POST", "/v1/rooms/travel", tokens[1], "pt-travel-001", map[string]any{"portal_id": "north_gate"}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/chat/messages", tokens[0], "pt-chat-001", map[string]any{"channel_kind": "party", "content": "小队集结枫林"}), http.StatusCreated)
	p2Chat := h.request("GET", "/v1/chat/messages", tokens[1], "", nil)
	var p2Msgs []chatMessage
	_ = json.Unmarshal(p2Chat.data["messages"], &p2Msgs)
	if len(p2Msgs) != 1 || p2Msgs[0].Content != "小队集结枫林" {
		t.Fatalf("expected cross-map party message for member, got %+v", p2Msgs)
	}
	p5Chat := h.request("GET", "/v1/chat/messages", tokens[4], "", nil)
	var p5Msgs []chatMessage
	_ = json.Unmarshal(p5Chat.data["messages"], &p5Msgs)
	if len(p5Msgs) != 0 {
		t.Fatalf("outsider received party message: %+v", p5Msgs)
	}

	// Promote member 1 -> kick member 3 -> member 1 leaves (member 2 auto-promoted) -> all leave (disbanded).
	requireStatus(t, h.request("POST", "/v1/parties/leader", tokens[0], "pt-lead-001", map[string]any{"target_character_id": chars[1]}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/parties/kick", tokens[1], "pt-kick-001", map[string]any{"target_character_id": chars[3]}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/parties/leave", tokens[0], "pt-leave-0", map[string]any{}), http.StatusOK)
	requireStatus(t, h.request("POST", "/v1/parties/leave", tokens[1], "pt-leave-1", map[string]any{}), http.StatusOK)
	p3State := h.request("GET", "/v1/parties/current", tokens[2], "", nil)
	var p3View partyView
	_ = json.Unmarshal(mustMarshal(t, p3State.data), &p3View)
	if p3View.Party == nil || p3View.Party.Leader != chars[2] || len(p3View.Party.Members) != 1 {
		t.Fatalf("expected char 2 auto-promoted to sole leader, got %+v", p3View.Party)
	}
	requireStatus(t, h.request("POST", "/v1/parties/leave", tokens[2], "pt-leave-2", map[string]any{}), http.StatusOK)

	var leftParties, leftMembers int
	_ = h.db.QueryRow(context.Background(), `SELECT (SELECT count(*) FROM parties),(SELECT count(*) FROM party_members)`).Scan(&leftParties, &leftMembers)
	if leftParties != 0 || leftMembers != 0 {
		t.Fatalf("expected clean party disband, got parties=%d members=%d", leftParties, leftMembers)
	}
}

func mustMarshal(t *testing.T, m map[string]json.RawMessage) []byte {
	t.Helper()
	b, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	return b
}
