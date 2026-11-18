package online

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
)

type inventoryItem struct {
	ID       string `json:"item_uid"`
	Template string `json:"template_id"`
	Quantity int    `json:"quantity"`
	Bound    bool   `json:"bound"`
	Slot     string `json:"equipped_slot"`
}

type inventoryView struct {
	inventoryItem
	JourneyItem
}

func readPack(ctx context.Context, tx pgx.Tx, id string, rules *JourneyRules) (map[string]any, error) {
	rows, err := tx.Query(ctx, `SELECT item_uid::text,template_id,quantity,bound,coalesce(equipped_slot,'') FROM inventory_items WHERE character_id=$1 AND quantity>0 ORDER BY created_at,item_uid`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := []inventoryView{}
	for rows.Next() {
		var item inventoryView
		if err = rows.Scan(&item.ID, &item.Template, &item.Quantity, &item.Bound, &item.Slot); err != nil {
			return nil, err
		}
		item.JourneyItem = rules.Items[item.Template]
		if item.Name == "" {
			item.Name = "暂不可使用的物品"
		}
		items = append(items, item)
	}
	return map[string]any{"items": items, "capacity": rules.PackSlots}, rows.Err()
}

type itemGrant struct {
	template string
	quantity int
}

func appendInventoryLedger(ctx context.Context, tx pgx.Tx, c, item, transaction, operation string, delta, after int, slot string) error {
	_, err := tx.Exec(ctx, `INSERT INTO inventory_ledger(id,character_id,item_uid,transaction_id,operation,delta,quantity_after,equipped_slot) VALUES($1,$2,$3,$4,$5,$6,$7,nullif($8,''))`,
		newID(), c, item, transaction, operation, delta, after, slot)
	return err
}

func grantPackItems(ctx context.Context, tx pgx.Tx, c, transaction string, capacity int, grants []itemGrant) error {
	if len(grants) == 0 {
		return nil
	}
	var occupied int
	if err := tx.QueryRow(ctx, `SELECT count(*) FROM inventory_items WHERE character_id=$1 AND quantity>0`, c).Scan(&occupied); err != nil {
		return err
	}
	if occupied+len(grants) > capacity {
		return &apiError{409, "pack_full", "行囊空间不足，物品和任务进度尚未变更"}
	}
	for _, grant := range grants {
		item := newID()
		if _, err := tx.Exec(ctx, `INSERT INTO inventory_items(item_uid,character_id,template_id,quantity,source_transaction) VALUES($1,$2,$3,$4,$5)`,
			item, c, grant.template, grant.quantity, transaction); err != nil {
			return err
		}
		if err := appendInventoryLedger(ctx, tx, c, item, transaction, "grant", grant.quantity, grant.quantity, ""); err != nil {
			return err
		}
	}
	return nil
}

func setEquippedSlot(ctx context.Context, tx pgx.Tx, charID, itemID, slot, transaction string) error {
	var quantity int
	err := tx.QueryRow(ctx, `UPDATE inventory_items SET equipped_slot=nullif($3,''),updated_at=now(),version=version+1 WHERE character_id=$1 AND item_uid=$2 RETURNING quantity`,
		charID, itemID, slot).Scan(&quantity)
	if err != nil {
		return err
	}
	action := "equip"
	if slot == "" {
		action = "unequip"
	}
	return appendInventoryLedger(ctx, tx, charID, itemID, transaction, action, 0, quantity, slot)
}

func (s *Server) equipJourneyItem(w http.ResponseWriter, r *http.Request, who identity) {
	id, ok := s.journeyCharacter(w, r, who)
	if !ok {
		return
	}
	var body struct {
		Item     string `json:"item_uid"`
		Equipped *bool  `json:"equipped"`
	}
	if err := decode(r, &body); err != nil {
		s.fail(w, err)
		return
	}
	if !validID(body.Item) || body.Equipped == nil {
		s.fail(w, bad("invalid_equipment", "请选择物品和要执行的动作"))
		return
	}
	if !s.limiter.allow("journey:"+who.AccountID, 12, time.Second) {
		s.fail(w, &apiError{429, "rate_limited", "操作过于频繁，请稍后重试"})
		return
	}
	data, err := s.command(r, who, "pack.equipment:"+id, body, func(ctx context.Context, tx pgx.Tx) (any, error) {
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
		var template, oldSlot string
		var quantity int
		err = tx.QueryRow(ctx, `SELECT template_id,quantity,coalesce(equipped_slot,'') FROM inventory_items WHERE character_id=$1 AND item_uid=$2 AND quantity>0`, id, body.Item).Scan(&template, &quantity, &oldSlot)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &apiError{404, "item_not_found", "找不到这件行囊物品"}
		}
		if err != nil {
			return nil, err
		}
		rules := s.cfg.Rules.Journey
		item := rules.Items[template]
		if quantity != 1 || (item.Kind != "weapon" && item.Kind != "armor" && item.Kind != "companion") || (item.RoleID != "" && item.RoleID != c.RoleID) {
			return nil, bad("invalid_equipment", "此物品不能由当前角色装备")
		}
		newSlot := ""
		if *body.Equipped {
			newSlot = item.Kind
		}
		if oldSlot != newSlot {
			transaction := "equipment:" + newID()
			if newSlot != "" {
				var displaced string
				err = tx.QueryRow(ctx, `SELECT item_uid::text FROM inventory_items WHERE character_id=$1 AND equipped_slot=$2`, id, newSlot).Scan(&displaced)
				if err != nil && !errors.Is(err, pgx.ErrNoRows) {
					return nil, err
				}
				if displaced != "" {
					if err = setEquippedSlot(ctx, tx, id, displaced, "", transaction); err != nil {
						return nil, err
					}
				}
			}
			if err = setEquippedSlot(ctx, tx, id, body.Item, newSlot, transaction); err != nil {
				return nil, err
			}
		}
		if newSlot != "" {
			if err = advanceWithPack(ctx, tx, c, rules, newSlot); err != nil {
				return nil, err
			}
		}
		return s.journeyView(ctx, tx, id)
	})
	if err != nil {
		s.fail(w, err)
		return
	}
	respond(w, 200, data)
}

func advanceWithPack(ctx context.Context, tx pgx.Tx, c Character, rules *JourneyRules, slot string) error {
	progress, err := readJourney(ctx, tx, c.ID)
	if err != nil {
		return err
	}
	step, _ := rules.step(progress.Step)
	if step.Event == "companion" && slot == "companion" {
		return rules.advance(ctx, tx, c.ID, progress, "companion", "", nil)
	}
	if step.Event != "gear" {
		return nil
	}
	var ready bool
	if err = tx.QueryRow(ctx, `SELECT count(*)=2 FROM inventory_items WHERE character_id=$1 AND equipped_slot IN ('weapon','armor')`, c.ID).Scan(&ready); err != nil || !ready {
		return err
	}
	return rules.advance(ctx, tx, c.ID, progress, "gear", "", nil)
}

type battleLoadout struct {
	Attack         int    `json:"attack,omitempty"`
	Defense        int    `json:"defense,omitempty"`
	Health         int    `json:"health,omitempty"`
	ActivePet      string `json:"active_pet,omitempty"`
	Potions        int    `json:"potions,omitempty"`
	PotionTemplate string `json:"potion_template,omitempty"`
}

func loadoutForBattle(ctx context.Context, tx pgx.Tx, c Character, rules *JourneyRules) (battleLoadout, error) {
	var loadout battleLoadout
	if rules == nil {
		return loadout, nil
	}
	rows, err := tx.Query(ctx, `SELECT template_id,equipped_slot FROM inventory_items WHERE character_id=$1 AND equipped_slot IS NOT NULL`, c.ID)
	if err != nil {
		return loadout, err
	}
	for rows.Next() {
		var template, slot string
		if err = rows.Scan(&template, &slot); err != nil {
			rows.Close()
			return loadout, err
		}
		item, known := rules.Items[template]
		if !known || item.Kind != slot || (item.RoleID != "" && item.RoleID != c.RoleID) {
			rows.Close()
			return loadout, fmt.Errorf("online equipment state invalid")
		}
		loadout.Attack += item.Attack
		loadout.Defense += item.Defense
		loadout.Health += item.Health
		if slot == "companion" {
			loadout.ActivePet = template
		}
	}
	rows.Close()
	if err = rows.Err(); err != nil {
		return loadout, err
	}
	err = tx.QueryRow(ctx, `SELECT least(coalesce(sum(quantity),0),$3) FROM inventory_items WHERE character_id=$1 AND template_id=$2 AND equipped_slot IS NULL`,
		c.ID, rules.PotionTemplate, rules.PotionsPerFight).Scan(&loadout.Potions)
	if loadout.Potions > 0 {
		loadout.PotionTemplate = rules.PotionTemplate
	}
	return loadout, err
}

func consumeBattlePotion(ctx context.Context, tx pgx.Tx, b persistedBattle, sequence int) error {
	var item string
	var after int
	err := tx.QueryRow(ctx, `UPDATE inventory_items SET quantity=quantity-1,version=version+1,updated_at=now()
		WHERE item_uid=(SELECT item_uid FROM inventory_items WHERE character_id=$1 AND template_id=$2 AND quantity>0 AND equipped_slot IS NULL ORDER BY created_at,item_uid LIMIT 1)
		RETURNING item_uid::text,quantity`, b.CharacterID, b.Loadout.PotionTemplate).Scan(&item, &after)
	if errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("persisted battle potion stock is unavailable")
	}
	if err != nil {
		return err
	}
	return appendInventoryLedger(ctx, tx, b.CharacterID, item, "battle:"+b.ID+":"+strconv.Itoa(sequence), "consume", -1, after, "")
}
