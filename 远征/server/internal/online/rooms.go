package online

import (
	"context"
	"errors"
	"math"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
	"yuanzheng/online/internal/authority"
)

type AuthorityRPC interface {
	Call(context.Context, string, any, any) error
}
type OnlineRules struct {
	Version string `json:"version"`
	Town    struct {
		MapID    string     `json:"map_id"`
		Capacity int        `json:"capacity"`
		Spawn    [2]float64 `json:"spawn"`
		Speed    float64    `json:"speed"`
	} `json:"town"`
	Maps       map[string]MapRule       `json:"maps,omitempty"`
	Portals    map[string]PortalRule    `json:"portals,omitempty"`
	NPCs       map[string]NPCRule       `json:"npcs,omitempty"`
	Encounters map[string]EncounterRule `json:"encounters"`
	Journey    *JourneyRules            `json:"journey,omitempty"`
}
type EncounterRule struct {
	MapID        string     `json:"map_id,omitempty"`
	MonsterID    string     `json:"monster_id"`
	Position     [2]float64 `json:"position"`
	Radius       float64    `json:"radius"`
	Gold         int64      `json:"gold"`
	Experience   int64      `json:"experience"`
	RewardPolicy string     `json:"reward_policy"`
	JourneyStep  string     `json:"journey_step,omitempty"`
}

func (r OnlineRules) Validate() error {
	finite := func(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) }
	if r.Version != RulesetVersion || r.Town.MapID == "" || r.Town.Capacity < 1 || r.Town.Capacity > 100 || !finite(r.Town.Speed) || r.Town.Speed <= 0 || r.Town.Speed > 400 || !finite(r.Town.Spawn[0]) || !finite(r.Town.Spawn[1]) || len(r.Encounters) == 0 {
		return errors.New("invalid online rules")
	}
	for _, e := range r.Encounters {
		if e.MonsterID == "" || !finite(e.Radius) || e.Radius <= 0 || !finite(e.Position[0]) || !finite(e.Position[1]) || e.Gold < 0 || e.Experience < 0 || (e.RewardPolicy != "once" && e.RewardPolicy != "per_battle") {
			return errors.New("invalid encounter rules")
		}
	}
	if err := r.validateWorldL1(); err != nil {
		return err
	}
	if r.Journey != nil {
		return r.Journey.validate(r.Encounters)
	}
	return nil
}

var errRoom = &apiError{409, "room_required", "请先进入在线城镇"}
var errAuthority = &apiError{503, "authority_unavailable", "世界服务暂时不可用，请稍后重试"}

func (s *Server) activeCharacter(ctx context.Context, tx pgx.Tx, who identity) (Character, error) {
	var id string
	err := tx.QueryRow(ctx, `SELECT coalesce(active_character_id::text,'') FROM sessions WHERE id=$1 AND account_id=$2 AND revoked_at IS NULL AND expires_at>now() AND access_expires_at>now()`, who.SessionID, who.AccountID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return Character{}, errAuth
	}
	if err != nil {
		return Character{}, err
	}
	if id == "" {
		return Character{}, &apiError{409, "character_required", "请先选择在线角色"}
	}
	c, err := scanCharacter(tx.QueryRow(ctx, `SELECT `+characterColumns+` FROM characters WHERE id=$1 AND account_id=$2 AND deleted_at IS NULL`, id, who.AccountID))
	if errors.Is(err, pgx.ErrNoRows) {
		return Character{}, errNotFound
	}
	return c, err
}
func (s *Server) beginActive(ctx context.Context, who identity) (pgx.Tx, Character, error) {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, Character{}, err
	}
	if _, err = tx.Exec(ctx, `SELECT id FROM accounts WHERE id=$1 FOR UPDATE`, who.AccountID); err != nil {
		tx.Rollback(ctx)
		return nil, Character{}, err
	}
	c, err := s.activeCharacter(ctx, tx, who)
	if err != nil {
		tx.Rollback(ctx)
		return nil, Character{}, err
	}
	return tx, c, nil
}

type roomLease struct {
	RoomID          string    `json:"room_id"`
	Token           string    `json:"lease_token"`
	Generation      int64     `json:"generation"`
	CharacterID     string    `json:"character_id"`
	MapID           string    `json:"map_id"`
	X               float64   `json:"x"`
	Y               float64   `json:"y"`
	Sequence        int64     `json:"move_sequence"`
	PositionUpdated time.Time `json:"-"`
}

func (s *Server) lease(ctx context.Context, tx pgx.Tx, who identity, charID string) (roomLease, error) {
	var l roomLease
	err := tx.QueryRow(ctx, `SELECT l.room_id::text,l.token::text,l.generation,l.character_id::text,i.map_id,l.x,l.y,l.move_sequence,l.position_updated_at FROM room_leases l JOIN room_instances i ON i.id=l.room_id WHERE l.account_id=$1 AND l.session_id=$2 AND l.character_id=$3 AND l.expires_at>now()`, who.AccountID, who.SessionID, charID).Scan(&l.RoomID, &l.Token, &l.Generation, &l.CharacterID, &l.MapID, &l.X, &l.Y, &l.Sequence, &l.PositionUpdated)
	if errors.Is(err, pgx.ErrNoRows) {
		return l, errRoom
	}
	return l, err
}
func (s *Server) joinRoom(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
	var body struct {
		Channel int `json:"channel,omitempty"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.Channel < 0 {
		s.fail(w, bad("invalid_channel", "频道编号无效"))
		return
	}
	data, err := s.command(r, who, "room.join", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if l, err := s.lease(ctx, tx, who, c.ID); err == nil {
			if body.Channel == 0 {
				_, err = tx.Exec(ctx, `UPDATE room_leases SET expires_at=now()+interval '90 seconds',updated_at=now() WHERE account_id=$1`, who.AccountID)
				return map[string]any{"lease": l}, err
			}
		} else if err != errRoom {
			return nil, err
		}
		targetMap := s.cfg.Rules.Town.MapID
		rule, _ := s.cfg.Rules.mapRule(targetMap)
		x, y := rule.Spawn[0], rule.Spawn[1]
		var prevMap string
		var previousX, previousY float64
		err = tx.QueryRow(ctx, `SELECT i.map_id,l.x,l.y FROM room_leases l JOIN room_instances i ON i.id=l.room_id WHERE l.account_id=$1 AND l.character_id=$2`, who.AccountID, c.ID).Scan(&prevMap, &previousX, &previousY)
		if err == nil {
			if prevRule, ok := s.cfg.Rules.mapRule(prevMap); ok {
				targetMap = prevMap
				rule = prevRule
				x, y = previousX, previousY
			}
		} else if !errors.Is(err, pgx.ErrNoRows) {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, "town:"+targetMap); err != nil {
			return nil, err
		}
		var room string
		if body.Channel > 0 {
			var count int64
			var cap int
			err = tx.QueryRow(ctx, `SELECT i.id::text,(SELECT count(*) FROM room_leases l JOIN sessions s ON s.id=l.session_id WHERE l.room_id=i.id AND l.expires_at>now() AND s.revoked_at IS NULL AND s.access_expires_at>now() AND s.active_character_id=l.character_id),i.capacity FROM room_instances i WHERE i.map_id=$1 AND i.channel=$2`, targetMap, body.Channel).Scan(&room, &count, &cap)
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, &apiError{404, "channel_not_found", "找不到指定的频道"}
			}
			if err != nil {
				return nil, err
			}
			if count >= int64(cap) {
				return nil, &apiError{409, "channel_full", "目标频道已满，请选择其他频道"}
			}
		} else {
			err = tx.QueryRow(ctx, `SELECT i.id::text FROM room_instances i WHERE i.map_id=$1 AND (SELECT count(*) FROM room_leases l JOIN sessions s ON s.id=l.session_id WHERE l.room_id=i.id AND l.expires_at>now() AND s.revoked_at IS NULL AND s.access_expires_at>now() AND s.active_character_id=l.character_id)<i.capacity ORDER BY i.channel LIMIT 1`, targetMap).Scan(&room)
			if errors.Is(err, pgx.ErrNoRows) {
				room = newID()
				_, err = tx.Exec(ctx, `INSERT INTO room_instances(id,map_id,channel,capacity) SELECT $1,$2,coalesce(max(channel),0)+1,$3 FROM room_instances WHERE map_id=$2`, room, targetMap, rule.Capacity)
			}
			if err != nil {
				return nil, err
			}
		}
		_, err = tx.Exec(ctx, `INSERT INTO room_leases(account_id,character_id,session_id,room_id,token,generation,x,y,expires_at) VALUES($1,$2,$3,$4,$5,1,$6,$7,now()+interval '90 seconds') ON CONFLICT(account_id) DO UPDATE SET character_id=excluded.character_id,session_id=excluded.session_id,room_id=excluded.room_id,token=excluded.token,generation=room_leases.generation+1,x=excluded.x,y=excluded.y,move_sequence=0,position_updated_at=now(),expires_at=excluded.expires_at,updated_at=now()`, who.AccountID, c.ID, who.SessionID, room, newID(), x, y)
		if err != nil {
			return nil, err
		}
		l, err := s.lease(ctx, tx, who, c.ID)
		return map[string]any{"lease": l}, err
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
func (s *Server) roomSnapshot(w http.ResponseWriter, r *http.Request, who identity) {
	if err := s.version(r); err != nil {
		s.fail(w, err)
		return
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	l, err := s.lease(r.Context(), tx, who, c.ID)
	if err != nil {
		s.fail(w, err)
		return
	}
	reply, err := s.buildRoomSnapshot(r.Context(), tx, c, l)
	if err != nil {
		s.fail(w, err)
		return
	}
	_, err = tx.Exec(r.Context(), `UPDATE room_leases SET expires_at=now()+interval '90 seconds',updated_at=now() WHERE account_id=$1`, who.AccountID)
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, reply)
}

type moveBody struct {
	Token      string  `json:"lease_token"`
	Generation int64   `json:"generation"`
	Sequence   int64   `json:"sequence"`
	X          float64 `json:"x"`
	Y          float64 `json:"y"`
}

func (s *Server) moveRoom(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
	if !s.limiter.allow("move:"+who.AccountID, 30, time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "移动指令过于频繁"})
		return
	}
	var body moveBody
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if math.IsNaN(body.X) || math.IsNaN(body.Y) || math.IsInf(body.X, 0) || math.IsInf(body.Y, 0) {
		s.fail(w, bad("invalid_position", "位置无效"))
		return
	}
	data, err := s.command(r, who, "room.move", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		l, err := s.lease(ctx, tx, who, c.ID)
		if err != nil {
			return nil, err
		}
		if l.Token != body.Token || l.Generation != body.Generation || body.Sequence != l.Sequence+1 {
			return nil, &apiError{409, "stale_lease", "城镇连接已更新，请重新进入"}
		}
		var fighting bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM battles WHERE character_id=$1 AND status='active')`, c.ID).Scan(&fighting); err != nil {
			return nil, err
		}
		if fighting {
			return nil, &apiError{409, "in_battle", "战斗结束后才能移动"}
		}
		var result struct {
			X float64 `json:"x"`
			Y float64 `json:"y"`
		}
		mapRule, _ := s.cfg.Rules.mapRule(l.MapID)
		err = s.cfg.Authority.Call(ctx, "world.validate_move", map[string]any{"map_id": l.MapID, "from_x": l.X, "from_y": l.Y, "x": body.X, "y": body.Y, "elapsed": time.Since(l.PositionUpdated).Seconds(), "speed": mapRule.Speed}, &result)
		if err != nil {
			var rejected *authority.RPCError
			if errors.As(err, &rejected) && (rejected.Code == "invalid_speed" || rejected.Code == "outside_map" || rejected.Code == "blocked" || rejected.Code == "invalid_position") {
				return nil, bad("move_rejected", "该位置暂时无法到达，请重新选择方向")
			}
			return nil, errAuthority
		}
		_, err = tx.Exec(ctx, `UPDATE room_leases SET x=$1,y=$2,move_sequence=$3,position_updated_at=now(),expires_at=now()+interval '90 seconds',updated_at=now() WHERE account_id=$4`, result.X, result.Y, body.Sequence, who.AccountID)
		if err != nil {
			return nil, err
		}
		l.X = result.X
		l.Y = result.Y
		l.Sequence = body.Sequence
		return map[string]any{"lease": l}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
