package online

import (
	"context"
	"errors"
	"math"
	"net/http"
	"regexp"
	"time"

	"github.com/jackc/pgx/v5"
)

type JourneyRules struct {
	PackSlots       int                     `json:"pack_slots"`
	PotionsPerFight int                     `json:"potions_per_battle"`
	StarterPotions  int                     `json:"starter_potions"`
	PotionTemplate  string                  `json:"potion_template"`
	ArmorTemplate   string                  `json:"armor_template"`
	Companion       string                  `json:"companion_template"`
	Weapons         map[string]string       `json:"weapons"`
	Items           map[string]JourneyItem  `json:"items"`
	Points          map[string]JourneyPoint `json:"points"`
	Steps           []JourneyStep           `json:"steps"`
}

type JourneyItem struct {
	Name           string `json:"name"`
	Icon           string `json:"icon"`
	Kind           string `json:"kind"`
	RoleID         string `json:"role_id,omitempty"`
	Attack         int    `json:"attack,omitempty"`
	Defense        int    `json:"defense,omitempty"`
	Health         int    `json:"health,omitempty"`
	Tradeable      bool   `json:"tradeable,omitempty"`
	MarketCategory string `json:"market_category,omitempty"`
	BasePrice      int64  `json:"base_price,omitempty"`
	NpcBuyPrice    int64  `json:"npc_buy_price,omitempty"`
	NpcSellPrice   int64  `json:"npc_sell_price,omitempty"`
}

type JourneyPoint struct {
	Name     string     `json:"name"`
	Position [2]float64 `json:"position"`
	Radius   float64    `json:"radius"`
}

type JourneyStep struct {
	ID       string `json:"id"`
	Title    string `json:"title"`
	Goal     string `json:"goal"`
	Event    string `json:"event"`
	Target   string `json:"target_id,omitempty"`
	Dialogue string `json:"dialogue,omitempty"`
	Reward   string `json:"reward,omitempty"`
}

var journeyIdentifier = regexp.MustCompile(`^[a-z][a-z0-9_]{0,63}$`)

func (j JourneyRules) validate(encounters map[string]EncounterRule) error {
	invalid := errors.New("invalid online journey rules")
	if j.PackSlots < 4 || j.PackSlots > 500 || j.PotionsPerFight < 1 || j.PotionsPerFight > 20 ||
		j.StarterPotions < 1 || j.StarterPotions > j.PotionsPerFight ||
		j.Items[j.PotionTemplate].Kind != "potion" || j.Items[j.ArmorTemplate].Kind != "armor" ||
		j.Companion != "pet_rockturtle" || j.Items[j.Companion].Kind != "companion" {
		return invalid
	}
	for _, role := range []string{"zs", "ck", "fs", "fz"} {
		item := j.Items[j.Weapons[role]]
		if item.Kind != "weapon" || item.RoleID != role {
			return invalid
		}
	}
	for id, item := range j.Items {
		if !journeyIdentifier.MatchString(id) || !journeyIdentifier.MatchString(item.Icon) || item.Name == "" ||
			item.Attack < 0 || item.Attack > 100 || item.Defense < 0 || item.Defense > 100 || item.Health < 0 || item.Health > 500 {
			return invalid
		}
		switch item.Kind {
		case "weapon":
			if item.RoleID != "zs" && item.RoleID != "ck" && item.RoleID != "fs" && item.RoleID != "fz" {
				return invalid
			}
		case "armor", "potion", "companion", "material":
			if item.RoleID != "" || (item.Kind != "armor" && (item.Attack != 0 || item.Defense != 0 || item.Health != 0)) {
				return invalid
			}
		default:
			return invalid
		}
		if item.BasePrice < 0 || item.NpcBuyPrice < 0 || item.NpcSellPrice < 0 {
			return invalid
		}
		if item.Tradeable && item.MarketCategory != "commodity" && item.MarketCategory != "equipment" {
			return invalid
		}
		if item.MarketCategory != "" && item.MarketCategory != "commodity" && item.MarketCategory != "equipment" {
			return invalid
		}
	}
	for id, point := range j.Points {
		if !journeyIdentifier.MatchString(id) || point.Name == "" || !(point.Radius > 0 && point.Radius <= 180) ||
			!(point.Position[0] > 0 && point.Position[0] <= 10000) || !(point.Position[1] > 0 && point.Position[1] <= 10000) {
			return invalid
		}
	}
	if len(j.Steps) < 2 || len(j.Steps) > 40 || j.Steps[0].ID != "s01" || j.Steps[len(j.Steps)-1].ID != "complete" {
		return invalid
	}
	seen := map[string]bool{}
	for i, step := range j.Steps {
		if !journeyIdentifier.MatchString(step.ID) || seen[step.ID] || step.Title == "" || step.Goal == "" {
			return invalid
		}
		seen[step.ID] = true
		if step.Reward != "" && (step.Event != "interact" || (step.Reward != "supplies" && step.Reward != "companion")) {
			return invalid
		}
		switch step.Event {
		case "interact":
			if _, ok := j.Points[step.Target]; !ok || i == len(j.Steps)-1 {
				return invalid
			}
		case "victory":
			encounter, ok := encounters[step.Target]
			if !ok || i == len(j.Steps)-1 || (encounter.JourneyStep != "" && encounter.JourneyStep != step.ID) {
				return invalid
			}
		case "gear", "companion":
			if step.Target != "" || i == len(j.Steps)-1 {
				return invalid
			}
		case "complete":
			if i != len(j.Steps)-1 || step.Target != "" {
				return invalid
			}
		default:
			return invalid
		}
	}
	for id, encounter := range encounters {
		if encounter.JourneyStep != "" {
			step, ok := j.step(encounter.JourneyStep)
			if !ok || step.Event != "victory" || step.Target != id {
				return invalid
			}
		}
	}
	return nil
}

func (j *JourneyRules) step(id string) (JourneyStep, bool) {
	for _, step := range j.Steps {
		if step.ID == id {
			return step, true
		}
	}
	return JourneyStep{}, false
}

type journeyProgress struct {
	Step    string
	Version int64
}

func readJourney(ctx context.Context, tx pgx.Tx, id string) (journeyProgress, error) {
	var progress journeyProgress
	err := tx.QueryRow(ctx, `SELECT story_step,version FROM character_progress WHERE character_id=$1`, id).Scan(&progress.Step, &progress.Version)
	return progress, err
}

func (j *JourneyRules) view(progress journeyProgress) map[string]any {
	step, ok := j.step(progress.Step)
	if !ok {
		return map[string]any{"id": progress.Step, "version": progress.Version}
	}
	view := map[string]any{"id": step.ID, "title": step.Title, "goal": step.Goal, "event": step.Event,
		"target_id": step.Target, "version": progress.Version, "completed": step.Event == "complete"}
	if point, exists := j.Points[step.Target]; exists {
		view["point"] = point
	}
	if step.Event == "complete" {
		view["coop_entry"] = "stele_cavern"
	}
	return view
}

var errJourneyUnavailable = &apiError{409, "journey_unavailable", "当前服务器尚未开放边城旅程"}
var errJourneyChanged = &apiError{409, "journey_changed", "任务进度已更新，请查看当前目标"}
var errJourneyBattle = &apiError{409, "battle_active", "请先结束当前战斗并确认结算"}

func requireCharacter(c Character, id string) error {
	if c.ID != id {
		return errNotFound
	}
	return nil
}

func requireOutsideBattle(ctx context.Context, tx pgx.Tx, id string) error {
	var busy bool
	err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM battles WHERE character_id=$1 AND (status='active' OR (status='settled' AND acknowledged_at IS NULL)))`, id).Scan(&busy)
	if err != nil {
		return err
	}
	if busy {
		return errJourneyBattle
	}
	return nil
}

func (s *Server) journeyCharacter(w http.ResponseWriter, r *http.Request, who identity) (string, bool) {
	id := r.PathValue("id")
	if s.cfg.Rules.Journey == nil {
		s.fail(w, errJourneyUnavailable)
		return "", false
	}
	if !validID(id) || id != who.CharacterID {
		s.fail(w, errNotFound)
		return "", false
	}
	return id, true
}

func (s *Server) journeyView(ctx context.Context, tx pgx.Tx, id string) (map[string]any, error) {
	rules := s.cfg.Rules.Journey
	progress, err := readJourney(ctx, tx, id)
	if err != nil {
		return nil, err
	}
	pack, err := readPack(ctx, tx, id, rules)
	if err != nil {
		return nil, err
	}
	return map[string]any{"journey": rules.view(progress), "pack": pack}, nil
}

func (s *Server) characterJourney(w http.ResponseWriter, r *http.Request, who identity) {
	id, ok := s.journeyCharacter(w, r, who)
	if !ok {
		return
	}
	err := s.version(r)
	if err != nil {
		s.fail(w, err)
		return
	}
	tx, c, err := s.beginActive(r.Context(), who)
	if err != nil {
		s.fail(w, err)
		return
	}
	defer tx.Rollback(r.Context())
	if err = requireCharacter(c, id); err != nil {
		s.fail(w, err)
		return
	}
	data, err := s.journeyView(r.Context(), tx, id)
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func (s *Server) interactJourney(w http.ResponseWriter, r *http.Request, who identity) {
	id, ok := s.journeyCharacter(w, r, who)
	if !ok {
		return
	}
	var body struct {
		Step   string `json:"step_id"`
		Target string `json:"target_id"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	j := s.cfg.Rules.Journey
	point, exists := j.Points[body.Target]
	if !exists || !journeyIdentifier.MatchString(body.Step) {
		s.fail(w, bad("invalid_target", "请选择当前任务目标"))
		return
	}
	if !s.limiter.allow("journey:"+who.AccountID, 12, time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "操作过于频繁，请稍后重试"})
		return
	}
	data, err := s.command(r, who, "journey.interact:"+id, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
		c, err := s.activeCharacter(ctx, tx, who)
		if err != nil {
			return nil, err
		}
		if err = requireCharacter(c, id); err != nil {
			return nil, err
		}
		if err = requireOutsideBattle(ctx, tx, id); err != nil {
			return nil, err
		}
		progress, err := readJourney(ctx, tx, id)
		if err != nil {
			return nil, err
		}
		step, exists := j.step(progress.Step)
		if !exists || step.ID != body.Step || step.Event != "interact" || step.Target != body.Target {
			return nil, errJourneyChanged
		}
		lease, err := s.lease(ctx, tx, who, id)
		if err != nil {
			return nil, err
		}
		if lease.MapID != s.cfg.Rules.Town.MapID || math.Hypot(lease.X-point.Position[0], lease.Y-point.Position[1]) > point.Radius {
			return nil, bad("too_far", "请先走近任务目标")
		}
		var grants []itemGrant
		switch step.Reward {
		case "supplies":
			grants = []itemGrant{{j.Weapons[c.RoleID], 1}, {j.ArmorTemplate, 1}, {j.PotionTemplate, j.StarterPotions}}
		case "companion":
			grants = []itemGrant{{j.Companion, 1}}
		}
		if err = grantPackItems(ctx, tx, id, "journey:"+step.ID, j.PackSlots, grants); err != nil {
			return nil, err
		}
		if err = j.advance(ctx, tx, id, progress, "interact", body.Target, nil); err != nil {
			return nil, err
		}
		reply, err := s.journeyView(ctx, tx, id)
		if err == nil {
			reply["dialogue"] = step.Dialogue
			reply["speaker"] = point.Name
		}
		return reply, err
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

// The account row is held by the caller. A battle advance shares the victory
// transaction, so a rolled back reward cannot leave a quest step completed.
func (j *JourneyRules) advance(ctx context.Context, tx pgx.Tx, id string, progress journeyProgress, event, target string, battle any) error {
	for i := 0; i+1 < len(j.Steps); i++ {
		step := j.Steps[i]
		if step.ID != progress.Step || step.Event != event || step.Target != target {
			continue
		}
		next := j.Steps[i+1].ID
		if _, err := tx.Exec(ctx, `INSERT INTO quest_events(character_id,step_id,next_step_id,event,target_id,battle_id) VALUES($1,$2,$3,$4,$5,$6)`,
			id, step.ID, next, event, target, battle); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `UPDATE character_progress SET story_step=$2,version=version+1,updated_at=now() WHERE character_id=$1`, id, next)
		return err
	}
	return nil
}

func (s *Server) journeyVictory(ctx context.Context, tx pgx.Tx, b persistedBattle) error {
	j := s.cfg.Rules.Journey
	if j == nil {
		return nil
	}
	progress, err := readJourney(ctx, tx, b.CharacterID)
	if err != nil {
		return err
	}
	return j.advance(ctx, tx, b.CharacterID, progress, "victory", b.EncounterID, b.ID)
}
