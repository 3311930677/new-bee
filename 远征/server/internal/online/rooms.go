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
	Encounters map[string]EncounterRule `json:"encounters"`
	Journey    *JourneyRules            `json:"journey,omitempty"`
}
type EncounterRule struct {
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
	var body struct{}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "room.join", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if l, err := s.lease(ctx, tx, who, c.ID); err == nil {
			_, err = tx.Exec(ctx, `UPDATE room_leases SET expires_at=now()+interval '90 seconds',updated_at=now() WHERE account_id=$1`, who.AccountID)
			return map[string]any{"lease": l}, err
		} else if err != errRoom {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, "town:"+s.cfg.Rules.Town.MapID); err != nil {
			return nil, err
		}
		// A new session rotates the lease but keeps this character's last trusted
		// position. Different characters start at the configured town spawn.
		x, y := s.cfg.Rules.Town.Spawn[0], s.cfg.Rules.Town.Spawn[1]
		var previousX, previousY float64
		err = tx.QueryRow(ctx, `SELECT l.x,l.y FROM room_leases l JOIN room_instances i ON i.id=l.room_id WHERE l.account_id=$1 AND l.character_id=$2 AND i.map_id=$3`, who.AccountID, c.ID, s.cfg.Rules.Town.MapID).Scan(&previousX, &previousY)
		if err == nil {
			x, y = previousX, previousY
		} else if !errors.Is(err, pgx.ErrNoRows) {
			return nil, err
		}
		var room string
		err = tx.QueryRow(ctx, `SELECT i.id::text FROM room_instances i WHERE i.map_id=$1 AND (SELECT count(*) FROM room_leases l JOIN sessions s ON s.id=l.session_id WHERE l.room_id=i.id AND l.expires_at>now() AND s.revoked_at IS NULL AND s.access_expires_at>now() AND s.active_character_id=l.character_id)<i.capacity ORDER BY i.channel LIMIT 1`, s.cfg.Rules.Town.MapID).Scan(&room)
		if errors.Is(err, pgx.ErrNoRows) {
			room = newID()
			_, err = tx.Exec(ctx, `INSERT INTO room_instances(id,map_id,channel,capacity) SELECT $1,$2,coalesce(max(channel),0)+1,$3 FROM room_instances WHERE map_id=$2`, room, s.cfg.Rules.Town.MapID, s.cfg.Rules.Town.Capacity)
		}
		if err != nil {
			return nil, err
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
	rows, err := tx.Query(r.Context(), `SELECT c.id::text,c.nickname,c.role_id,c.gender_id,c.avatar_id,c.level,l.x,l.y,l.move_sequence,EXISTS(SELECT 1 FROM battles b WHERE b.character_id=c.id AND b.status='active') FROM room_leases l JOIN sessions s ON s.id=l.session_id JOIN characters c ON c.id=l.character_id WHERE l.room_id=$1 AND l.expires_at>now() AND s.revoked_at IS NULL AND s.expires_at>now() AND s.access_expires_at>now() AND s.active_character_id=c.id AND c.deleted_at IS NULL ORDER BY c.id`, l.RoomID)
	if err != nil {
		s.fail(w, err)
		return
	}
	entities := []map[string]any{}
	for rows.Next() {
		var id, name, role, gender, avatar string
		var level int
		var x, y float64
		var sequence int64
		var fighting bool
		if err = rows.Scan(&id, &name, &role, &gender, &avatar, &level, &x, &y, &sequence, &fighting); err != nil {
			rows.Close()
			s.fail(w, err)
			return
		}
		entities = append(entities, map[string]any{"id": id, "nickname": name, "role_id": role, "gender_id": gender, "avatar_id": avatar, "level": level, "x": x, "y": y, "move_sequence": sequence, "in_battle": fighting})
	}
	rows.Close()
	if rows.Err() != nil {
		s.fail(w, rows.Err())
		return
	}
	encounters := s.cfg.Rules.Encounters
	var journey map[string]any
	if rules := s.cfg.Rules.Journey; rules != nil {
		progress, readErr := readJourney(r.Context(), tx, c.ID)
		if readErr != nil {
			s.fail(w, readErr)
			return
		}
		journey = rules.view(progress)
		encounters = make(map[string]EncounterRule)
		for id, rule := range s.cfg.Rules.Encounters {
			if rule.JourneyStep == "" || rule.JourneyStep == progress.Step {
				encounters[id] = rule
			}
		}
	}
	_, err = tx.Exec(r.Context(), `UPDATE room_leases SET expires_at=now()+interval '90 seconds',updated_at=now() WHERE account_id=$1`, who.AccountID)
	if err == nil {
		err = tx.Commit(r.Context())
	}
	if err != nil {
		s.fail(w, err)
		return
	}
	reply := map[string]any{"lease": l, "entities": entities, "encounters": encounters, "speed": s.cfg.Rules.Town.Speed}
	if journey != nil {
		reply["journey"] = journey
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
		err = s.cfg.Authority.Call(ctx, "world.validate_move", map[string]any{"map_id": l.MapID, "from_x": l.X, "from_y": l.Y, "x": body.X, "y": body.Y, "elapsed": time.Since(l.PositionUpdated).Seconds(), "speed": s.cfg.Rules.Town.Speed}, &result)
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
