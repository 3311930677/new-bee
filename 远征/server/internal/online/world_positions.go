package online

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
)

const (
	worldPositionInterval = 100 * time.Millisecond
	worldPositionRange    = 480.0
	worldStreamLifetime   = 8 * time.Second
)

type worldEntity struct {
	ID           string  `json:"id"`
	Nickname     string  `json:"nickname"`
	RoleID       string  `json:"role_id"`
	GenderID     string  `json:"gender_id"`
	AvatarID     string  `json:"avatar_id"`
	Level        int     `json:"level"`
	X            float64 `json:"x"`
	Y            float64 `json:"y"`
	MoveSequence int64   `json:"move_sequence"`
	InBattle     bool    `json:"in_battle"`
	sessionID    string
	generation   int64
	accessHash   []byte
}

type positionQueryer interface {
	Query(context.Context, string, ...any) (pgx.Rows, error)
}

// Only committed positions are published. A stream cannot keep an expired
// lease, switched character or revoked session visible to other players.
func readWorldEntities(ctx context.Context, db positionQueryer, roomID string) ([]worldEntity, error) {
	rows, err := db.Query(ctx, `SELECT c.id::text,c.nickname,c.role_id,c.gender_id,c.avatar_id,c.level,
		l.x,l.y,l.move_sequence,EXISTS(SELECT 1 FROM battles b WHERE b.character_id=c.id AND b.status='active'),
		s.id::text,l.generation,s.access_hash
		FROM room_leases l JOIN sessions s ON s.id=l.session_id JOIN characters c ON c.id=l.character_id
		WHERE l.room_id=$1 AND l.expires_at>now() AND s.revoked_at IS NULL AND s.expires_at>now()
		  AND s.access_expires_at>now() AND s.active_character_id=c.id AND c.deleted_at IS NULL ORDER BY c.id`, roomID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	entities := make([]worldEntity, 0)
	for rows.Next() {
		var person worldEntity
		err = rows.Scan(&person.ID, &person.Nickname, &person.RoleID, &person.GenderID, &person.AvatarID, &person.Level,
			&person.X, &person.Y, &person.MoveSequence, &person.InBattle, &person.sessionID, &person.generation, &person.accessHash)
		if err != nil {
			return nil, err
		}
		entities = append(entities, person)
	}
	return entities, rows.Err()
}

func worldNeighbors(center worldEntity, all []worldEntity) []worldEntity {
	neighbors := make([]worldEntity, 0, len(all))
	for _, candidate := range all {
		dx, dy := candidate.X-center.X, candidate.Y-center.Y
		if dx*dx+dy*dy <= worldPositionRange*worldPositionRange {
			neighbors = append(neighbors, candidate)
		}
	}
	return neighbors
}

type roomPositionSample struct {
	tick     uint64
	entities []worldEntity
}

type roomPositionFeed struct {
	cancel      context.CancelFunc
	subscribers map[string]chan roomPositionSample
}

type positionFeeds struct {
	mu     sync.Mutex
	byRoom map[string]*roomPositionFeed
}

func (s *Server) subscribePositions(roomID, sessionID string) (<-chan roomPositionSample, func()) {
	feeds := &s.positionFeeds
	feeds.mu.Lock()
	defer feeds.mu.Unlock()
	if feeds.byRoom == nil {
		feeds.byRoom = make(map[string]*roomPositionFeed)
	}
	feed := feeds.byRoom[roomID]
	if feed == nil {
		ctx, cancel := context.WithCancel(context.Background())
		feed = &roomPositionFeed{cancel: cancel, subscribers: make(map[string]chan roomPositionSample)}
		feeds.byRoom[roomID] = feed
		go s.collectPositions(ctx, roomID, feed)
	}
	// A reconnect replaces its previous observer. Slow clients cannot make a
	// queue grow or prevent another viewer from receiving the latest position.
	if old := feed.subscribers[sessionID]; old != nil {
		close(old)
	}
	updates := make(chan roomPositionSample, 1)
	feed.subscribers[sessionID] = updates
	return updates, func() {
		feeds.mu.Lock()
		defer feeds.mu.Unlock()
		if feed.subscribers[sessionID] != updates {
			return
		}
		delete(feed.subscribers, sessionID)
		if len(feed.subscribers) == 0 {
			feed.cancel()
			delete(feeds.byRoom, roomID)
		}
	}
}

func (s *Server) collectPositions(ctx context.Context, roomID string, feed *roomPositionFeed) {
	ticker := time.NewTicker(worldPositionInterval)
	defer ticker.Stop()
	var tick uint64
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			read, cancel := context.WithTimeout(ctx, 2*worldPositionInterval)
			entities, err := readWorldEntities(read, s.db, roomID)
			cancel()
			if err != nil {
				continue
			}
			tick++
			s.positionFeeds.mu.Lock()
			for _, updates := range feed.subscribers {
				select {
				case <-updates:
				default:
				}
				updates <- roomPositionSample{tick: tick, entities: entities}
			}
			s.positionFeeds.mu.Unlock()
		}
	}
}

type worldPositionFrame struct {
	RoomID     string        `json:"room_id"`
	MapID      string        `json:"map_id"`
	Generation int64         `json:"generation"`
	Tick       uint64        `json:"tick"`
	Entities   []worldEntity `json:"entities"`
}

func (s *Server) roomPositionStream(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
	if !s.limiter.allow("positions:"+who.AccountID, 8, time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "城镇连接过于频繁"})
		return
	}
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	tx, character, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	lease, err := s.lease(r.Context(), tx, who, character.ID)
	_ = tx.Rollback(r.Context())
	if err != nil {
		s.fail(w, err)
		return
	}
	accessHash := sha256.Sum256([]byte(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")))

	stream, cancel := context.WithTimeout(r.Context(), worldStreamLifetime)
	defer cancel()
	updates, release := s.subscribePositions(lease.RoomID, who.SessionID)
	defer release()
	w.Header().Set("Content-Type", "application/x-ndjson; charset=utf-8")
	w.Header().Set("X-Accel-Buffering", "no")
	flush := http.NewResponseController(w)
	encoder := json.NewEncoder(w)
	for {
		select {
		case <-stream.Done():
			return
		case sample, open := <-updates:
			if !open || stream.Err() != nil {
				return
			}
			var self worldEntity
			for _, entity := range sample.entities {
				if entity.ID == lease.CharacterID && entity.sessionID == who.SessionID && entity.generation == lease.Generation &&
					bytes.Equal(entity.accessHash, accessHash[:]) {
					self = entity
					break
				}
			}
			if self.ID == "" {
				return
			}
			deadline := time.Now().Add(time.Second)
			if err = flush.SetWriteDeadline(deadline); err != nil && !errors.Is(err, http.ErrNotSupported) {
				return
			}
			frame := worldPositionFrame{
				RoomID: lease.RoomID, MapID: lease.MapID, Generation: lease.Generation, Tick: sample.tick,
				Entities: worldNeighbors(self, sample.entities),
			}
			if encoder.Encode(frame) != nil || flush.Flush() != nil {
				return
			}
		}
	}
}
