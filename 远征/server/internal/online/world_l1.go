package online

import (
	"context"
	"errors"
	"math"
	"net/http"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"
)

type MapRule struct {
	Name     string                `json:"name"`
	Capacity int                   `json:"capacity"`
	Spawn    [2]float64            `json:"spawn"`
	Speed    float64               `json:"speed"`
	Arrivals map[string][2]float64 `json:"arrivals,omitempty"`
}

type PortalRule struct {
	FromMap  string     `json:"from_map"`
	Position [2]float64 `json:"position"`
	Radius   float64    `json:"radius"`
	ToMap    string     `json:"to_map"`
	Arrival  string     `json:"arrival,omitempty"`
	Label    string     `json:"label"`
}

type NPCRule struct {
	MapID               string     `json:"map_id"`
	Name                string     `json:"name"`
	Position            [2]float64 `json:"position"`
	Radius              float64    `json:"radius"`
	Greeting            string     `json:"greeting"`
	AfterPatrolGreeting string     `json:"after_patrol_greeting,omitempty"`
}

type channelInfo struct {
	RoomID      string `json:"room_id"`
	MapID       string `json:"map_id"`
	Channel     int    `json:"channel"`
	PlayerCount int64  `json:"player_count"`
	Capacity    int    `json:"capacity"`
	Current     bool   `json:"current"`
}

type portalView struct {
	ID       string     `json:"id"`
	Position [2]float64 `json:"position"`
	Radius   float64    `json:"radius"`
	ToMap    string     `json:"to_map"`
	Label    string     `json:"label"`
}

type npcView struct {
	ID               string     `json:"id"`
	MapID            string     `json:"map_id"`
	Name             string     `json:"name"`
	Position         [2]float64 `json:"position"`
	Radius           float64    `json:"radius"`
	Dialogue         string     `json:"dialogue"`
	Interacted       bool       `json:"interacted"`
	InteractionCount int        `json:"interaction_count"`
}

func (r OnlineRules) mapRule(mapID string) (MapRule, bool) {
	if rule, ok := r.Maps[mapID]; ok {
		return rule, true
	}
	if mapID == r.Town.MapID {
		return MapRule{
			Name:     "昭元边城",
			Capacity: r.Town.Capacity,
			Spawn:    r.Town.Spawn,
			Speed:    r.Town.Speed,
		}, true
	}
	return MapRule{}, false
}

func (r OnlineRules) effectiveEncounterMap(e EncounterRule) string {
	if e.MapID != "" {
		return e.MapID
	}
	return r.Town.MapID
}

func (r OnlineRules) encountersForMap(mapID, journeyStep string) map[string]EncounterRule {
	out := make(map[string]EncounterRule)
	for id, rule := range r.Encounters {
		if r.effectiveEncounterMap(rule) != mapID {
			continue
		}
		if rule.JourneyStep != "" && rule.JourneyStep != journeyStep {
			continue
		}
		out[id] = rule
	}
	return out
}

func (r OnlineRules) portalsForMap(mapID string) []portalView {
	ids := make([]string, 0, len(r.Portals))
	for id, portal := range r.Portals {
		if portal.FromMap == mapID {
			ids = append(ids, id)
		}
	}
	sort.Strings(ids)
	out := make([]portalView, 0, len(ids))
	for _, id := range ids {
		portal := r.Portals[id]
		out = append(out, portalView{
			ID:       id,
			Position: portal.Position,
			Radius:   portal.Radius,
			ToMap:    portal.ToMap,
			Label:    portal.Label,
		})
	}
	return out
}

func (r OnlineRules) validateWorldL1() error {
	finite := func(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) }
	for id, m := range r.Maps {
		if !journeyIdentifier.MatchString(id) || m.Name == "" || m.Capacity < 1 || m.Capacity > 100 ||
			!finite(m.Speed) || m.Speed <= 0 || m.Speed > 400 ||
			!finite(m.Spawn[0]) || !finite(m.Spawn[1]) || m.Spawn[0] <= 0 || m.Spawn[1] <= 0 {
			return errors.New("invalid map rules")
		}
		for _, pos := range m.Arrivals {
			if !finite(pos[0]) || !finite(pos[1]) || pos[0] <= 0 || pos[1] <= 0 {
				return errors.New("invalid map arrival rules")
			}
		}
	}
	for id, e := range r.Encounters {
		if !journeyIdentifier.MatchString(id) {
			return errors.New("invalid encounter id")
		}
		if _, ok := r.mapRule(r.effectiveEncounterMap(e)); !ok {
			return errors.New("encounter references unknown map")
		}
	}
	for id, p := range r.Portals {
		if !journeyIdentifier.MatchString(id) || p.Label == "" || !finite(p.Radius) || p.Radius <= 0 || p.Radius > 300 ||
			!finite(p.Position[0]) || !finite(p.Position[1]) || p.Position[0] <= 0 || p.Position[1] <= 0 {
			return errors.New("invalid portal rules")
		}
		if _, ok := r.mapRule(p.FromMap); !ok {
			return errors.New("portal references unknown source map")
		}
		if _, ok := r.mapRule(p.ToMap); !ok {
			return errors.New("portal references unknown destination map")
		}
	}
	for id, n := range r.NPCs {
		if !journeyIdentifier.MatchString(id) || n.Name == "" || n.Greeting == "" ||
			!finite(n.Radius) || n.Radius <= 0 || n.Radius > 300 ||
			!finite(n.Position[0]) || !finite(n.Position[1]) || n.Position[0] <= 0 || n.Position[1] <= 0 {
			return errors.New("invalid npc rules")
		}
		if _, ok := r.mapRule(n.MapID); !ok {
			return errors.New("npc references unknown map")
		}
	}
	return nil
}

func readMapChannels(ctx context.Context, tx pgx.Tx, mapID, currentRoomID string) ([]channelInfo, error) {
	rows, err := tx.Query(ctx, `SELECT i.id::text,i.map_id,i.channel,
		(SELECT count(*) FROM room_leases l JOIN sessions s ON s.id=l.session_id
		 WHERE l.room_id=i.id AND l.expires_at>now() AND s.revoked_at IS NULL AND s.access_expires_at>now() AND s.active_character_id=l.character_id),
		i.capacity
		FROM room_instances i WHERE i.map_id=$1 ORDER BY i.channel`, mapID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]channelInfo, 0)
	for rows.Next() {
		var ch channelInfo
		if err = rows.Scan(&ch.RoomID, &ch.MapID, &ch.Channel, &ch.PlayerCount, &ch.Capacity); err != nil {
			return nil, err
		}
		ch.Current = ch.RoomID == currentRoomID
		out = append(out, ch)
	}
	return out, rows.Err()
}

func readCharacterNPCs(ctx context.Context, tx pgx.Tx, charID, mapID string, rules OnlineRules) ([]npcView, error) {
	counts := make(map[string]int)
	rows, err := tx.Query(ctx, `SELECT npc_id,interaction_count FROM npc_interactions WHERE character_id=$1`, charID)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var npcID string
		var count int
		if err = rows.Scan(&npcID, &count); err != nil {
			rows.Close()
			return nil, err
		}
		counts[npcID] = count
	}
	rows.Close()
	if err = rows.Err(); err != nil {
		return nil, err
	}
	var completed bool
	if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM quest_events WHERE character_id=$1 AND next_step_id='complete')`, charID).Scan(&completed); err != nil {
		return nil, err
	}
	ids := make([]string, 0, len(rules.NPCs))
	for id, npc := range rules.NPCs {
		if npc.MapID == mapID {
			ids = append(ids, id)
		}
	}
	sort.Strings(ids)
	out := make([]npcView, 0, len(ids))
	for _, id := range ids {
		npc := rules.NPCs[id]
		dialogue := npc.Greeting
		if completed && npc.AfterPatrolGreeting != "" {
			dialogue = npc.AfterPatrolGreeting
		}
		count := counts[id]
		out = append(out, npcView{
			ID:               id,
			MapID:            npc.MapID,
			Name:             npc.Name,
			Position:         npc.Position,
			Radius:           npc.Radius,
			Dialogue:         dialogue,
			Interacted:       count > 0,
			InteractionCount: count,
		})
	}
	return out, nil
}

func (s *Server) buildRoomSnapshot(ctx context.Context, tx pgx.Tx, c Character, l roomLease) (map[string]any, error) {
	all, err := readWorldEntities(ctx, tx, l.RoomID)
	if err != nil {
		return nil, err
	}
	entities := worldNeighbors(worldEntity{X: l.X, Y: l.Y}, all)
	journeyStep := ""
	var journey map[string]any
	if rules := s.cfg.Rules.Journey; rules != nil {
		progress, readErr := readJourney(ctx, tx, c.ID)
		if readErr != nil {
			return nil, readErr
		}
		journeyStep = progress.Step
		if l.MapID == s.cfg.Rules.Town.MapID {
			journey = rules.view(progress)
		}
	}
	encounters := s.cfg.Rules.encountersForMap(l.MapID, journeyStep)
	channels, err := readMapChannels(ctx, tx, l.MapID, l.RoomID)
	if err != nil {
		return nil, err
	}
	npcs, err := readCharacterNPCs(ctx, tx, c.ID, l.MapID, s.cfg.Rules)
	if err != nil {
		return nil, err
	}
	mapRule, _ := s.cfg.Rules.mapRule(l.MapID)
	reply := map[string]any{
		"lease":      l,
		"entities":   entities,
		"encounters": encounters,
		"portals":    s.cfg.Rules.portalsForMap(l.MapID),
		"npcs":       npcs,
		"channels":   channels,
		"map": map[string]any{
			"id":    l.MapID,
			"name":  mapRule.Name,
			"speed": mapRule.Speed,
		},
		"speed": mapRule.Speed,
	}
	if journey != nil {
		reply["journey"] = journey
	}
	return reply, nil
}

func (s *Server) listChannels(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
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
	channels, err := readMapChannels(r.Context(), tx, l.MapID, l.RoomID)
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, map[string]any{"map_id": l.MapID, "current_room_id": l.RoomID, "channels": channels})
}

func (s *Server) switchChannel(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
	if !s.limiter.allow("channel:"+who.AccountID, 12, time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "切换频道过于频繁"})
		return
	}
	var body struct {
		Channel int    `json:"channel,omitempty"`
		RoomID  string `json:"room_id,omitempty"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if body.Channel < 0 || (body.Channel == 0 && body.RoomID == "") || (body.RoomID != "" && !validID(body.RoomID)) {
		s.fail(w, bad("invalid_channel", "请选择有效的频道"))
		return
	}
	data, err := s.command(r, who, "room.switch_channel", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if err = requireOutsideBattle(ctx, tx, c.ID); err != nil {
			return nil, err
		}
		l, err := s.lease(ctx, tx, who, c.ID)
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, "town:"+l.MapID); err != nil {
			return nil, err
		}
		channels, err := readMapChannels(ctx, tx, l.MapID, l.RoomID)
		if err != nil {
			return nil, err
		}
		var target *channelInfo
		for i := range channels {
			ch := &channels[i]
			if (body.RoomID != "" && ch.RoomID == body.RoomID) || (body.Channel > 0 && ch.Channel == body.Channel) {
				target = ch
				break
			}
		}
		if target == nil {
			return nil, &apiError{404, "channel_not_found", "找不到指定的频道"}
		}
		if target.RoomID != l.RoomID && target.PlayerCount >= int64(target.Capacity) {
			return nil, &apiError{409, "channel_full", "目标频道已满，请选择其他频道"}
		}
		if target.RoomID != l.RoomID {
			if _, err = tx.Exec(ctx, `UPDATE room_leases SET room_id=$1,token=$2,generation=room_leases.generation+1,move_sequence=0,expires_at=now()+interval '90 seconds',updated_at=now() WHERE account_id=$3`, target.RoomID, newID(), who.AccountID); err != nil {
				return nil, err
			}
		} else {
			if _, err = tx.Exec(ctx, `UPDATE room_leases SET expires_at=now()+interval '90 seconds',updated_at=now() WHERE account_id=$1`, who.AccountID); err != nil {
				return nil, err
			}
		}
		updated, err := s.lease(ctx, tx, who, c.ID)
		if err != nil {
			return nil, err
		}
		return s.buildRoomSnapshot(ctx, tx, c, updated)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) travelPortal(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
	if !s.limiter.allow("travel:"+who.AccountID, 12, time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "跨图操作过于频繁"})
		return
	}
	var body struct {
		PortalID string `json:"portal_id"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	portal, exists := s.cfg.Rules.Portals[body.PortalID]
	if !exists {
		s.fail(w, &apiError{404, "portal_not_found", "找不到该地图出口"})
		return
	}
	data, err := s.command(r, who, "room.travel", body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if err = requireOutsideBattle(ctx, tx, c.ID); err != nil {
			return nil, err
		}
		l, err := s.lease(ctx, tx, who, c.ID)
		if err != nil {
			return nil, err
		}
		if l.MapID != portal.FromMap {
			return nil, &apiError{409, "wrong_map", "当前不在该出口所在地图"}
		}
		if math.Hypot(l.X-portal.Position[0], l.Y-portal.Position[1]) > portal.Radius {
			return nil, bad("too_far", "请先走近地图出口再传送")
		}
		destRule, ok := s.cfg.Rules.mapRule(portal.ToMap)
		if !ok {
			return nil, errAuthority
		}
		arrival := destRule.Spawn
		if portal.Arrival != "" {
			if pos, found := destRule.Arrivals[portal.Arrival]; found {
				arrival = pos
			}
		}
		if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,0))`, "town:"+portal.ToMap); err != nil {
			return nil, err
		}
		var room string
		err = tx.QueryRow(ctx, `SELECT i.id::text FROM room_instances i WHERE i.map_id=$1 AND (SELECT count(*) FROM room_leases l JOIN sessions s ON s.id=l.session_id WHERE l.room_id=i.id AND l.expires_at>now() AND s.revoked_at IS NULL AND s.access_expires_at>now() AND s.active_character_id=l.character_id)<i.capacity ORDER BY i.channel LIMIT 1`, portal.ToMap).Scan(&room)
		if errors.Is(err, pgx.ErrNoRows) {
			room = newID()
			_, err = tx.Exec(ctx, `INSERT INTO room_instances(id,map_id,channel,capacity) SELECT $1,$2,coalesce(max(channel),0)+1,$3 FROM room_instances WHERE map_id=$2`, room, portal.ToMap, destRule.Capacity)
		}
		if err != nil {
			return nil, err
		}
		if _, err = tx.Exec(ctx, `UPDATE room_leases SET room_id=$1,token=$2,generation=room_leases.generation+1,x=$3,y=$4,move_sequence=0,position_updated_at=now(),expires_at=now()+interval '90 seconds',updated_at=now() WHERE account_id=$5`, room, newID(), arrival[0], arrival[1], who.AccountID); err != nil {
			return nil, err
		}
		updated, err := s.lease(ctx, tx, who, c.ID)
		if err != nil {
			return nil, err
		}
		return s.buildRoomSnapshot(ctx, tx, c, updated)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) interactNPC(w http.ResponseWriter, r *http.Request, who identity) {
	if s.cfg.Authority == nil {
		s.fail(w, errAuthority)
		return
	}
	id := r.PathValue("id")
	npc, exists := s.cfg.Rules.NPCs[id]
	if !exists {
		s.fail(w, errNotFound)
		return
	}
	if !s.limiter.allow("npc:"+who.AccountID, 12, time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "交谈操作过于频繁"})
		return
	}
	var body struct{}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.command(r, who, "npc.interact:"+id, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if err = requireOutsideBattle(ctx, tx, c.ID); err != nil {
			return nil, err
		}
		l, err := s.lease(ctx, tx, who, c.ID)
		if err != nil {
			return nil, err
		}
		if l.MapID != npc.MapID {
			return nil, &apiError{409, "wrong_map", "该角色不在当前地图"}
		}
		if math.Hypot(l.X-npc.Position[0], l.Y-npc.Position[1]) > npc.Radius {
			return nil, bad("too_far", "请先走近NPC再交谈")
		}
		var completed bool
		if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM quest_events WHERE character_id=$1 AND next_step_id='complete')`, c.ID).Scan(&completed); err != nil {
			return nil, err
		}
		dialogue := npc.Greeting
		if completed && npc.AfterPatrolGreeting != "" {
			dialogue = npc.AfterPatrolGreeting
		}
		if _, err = tx.Exec(ctx, `INSERT INTO npc_interactions(character_id,npc_id,interaction_count,last_dialogue,updated_at) VALUES($1,$2,1,$3,now())
			ON CONFLICT(character_id,npc_id) DO UPDATE SET interaction_count=npc_interactions.interaction_count+1,last_dialogue=excluded.last_dialogue,updated_at=now()`, c.ID, id, dialogue); err != nil {
			return nil, err
		}
		npcs, err := readCharacterNPCs(ctx, tx, c.ID, l.MapID, s.cfg.Rules)
		if err != nil {
			return nil, err
		}
		var current npcView
		for _, item := range npcs {
			if item.ID == id {
				current = item
				break
			}
		}
		return map[string]any{"npc": current, "npcs": npcs}, nil
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}
