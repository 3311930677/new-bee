ALTER TABLE inventory_items DROP CONSTRAINT inventory_items_quantity_check;
ALTER TABLE inventory_items ADD CONSTRAINT inventory_quantity_nonnegative CHECK (quantity >= 0);
ALTER TABLE inventory_items ADD COLUMN equipped_slot text
    CHECK (equipped_slot IN ('weapon','armor','companion') AND (equipped_slot IS NULL OR quantity = 1));
ALTER TABLE inventory_items ADD CONSTRAINT inventory_owner_item UNIQUE (character_id,item_uid);
CREATE UNIQUE INDEX inventory_equipped_slot ON inventory_items(character_id,equipped_slot) WHERE equipped_slot IS NOT NULL;

CREATE TABLE inventory_ledger (
    id uuid PRIMARY KEY,
    character_id uuid NOT NULL,
    item_uid uuid NOT NULL,
    transaction_id text NOT NULL,
    operation text NOT NULL CHECK (operation IN ('grant','consume','equip','unequip')),
    delta integer NOT NULL,
    quantity_after integer NOT NULL CHECK (quantity_after >= 0),
    equipped_slot text CHECK (equipped_slot IN ('weapon','armor','companion')),
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY(character_id,item_uid) REFERENCES inventory_items(character_id,item_uid),
    UNIQUE (character_id,transaction_id,item_uid),
    CHECK (
      (operation='grant' AND delta>0 AND quantity_after>=delta AND equipped_slot IS NULL) OR
      (operation='consume' AND delta<0 AND equipped_slot IS NULL) OR
      (operation='equip' AND delta=0 AND quantity_after=1 AND equipped_slot IS NOT NULL) OR
      (operation='unequip' AND delta=0 AND quantity_after=1 AND equipped_slot IS NULL)
    )
);
CREATE INDEX inventory_ledger_item ON inventory_ledger(item_uid);

CREATE TABLE quest_events (
    character_id uuid NOT NULL REFERENCES characters(id),
    step_id text NOT NULL,
    next_step_id text NOT NULL CHECK (next_step_id <> step_id),
    event text NOT NULL CHECK (event IN ('interact','gear','victory','companion')),
    target_id text NOT NULL,
    battle_id uuid REFERENCES battles(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (character_id,step_id),
    CHECK ((event='victory') = (battle_id IS NOT NULL))
);
CREATE UNIQUE INDEX quest_events_battle ON quest_events(battle_id) WHERE battle_id IS NOT NULL;

CREATE FUNCTION protect_journey_history() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'journey history is append only';
END;
$$;
CREATE TRIGGER inventory_ledger_immutable BEFORE UPDATE OR DELETE ON inventory_ledger
    FOR EACH ROW EXECUTE FUNCTION protect_journey_history();
CREATE TRIGGER quest_events_immutable BEFORE UPDATE OR DELETE ON quest_events
    FOR EACH ROW EXECUTE FUNCTION protect_journey_history();

ALTER TABLE battles ADD COLUMN loadout jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(loadout)='object');
