CREATE TABLE coop_queues (
    character_id uuid PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
    account_id uuid NOT NULL REFERENCES accounts(id),
    dungeon_id text NOT NULL,
    difficulty text NOT NULL DEFAULT 'standard' CHECK (difficulty IN ('standard','heroic')),
    goal text NOT NULL DEFAULT 'first_clear' CHECK (goal IN ('first_clear','materials','mentor')),
    party_id uuid REFERENCES parties(id) ON DELETE SET NULL,
    friends_only boolean NOT NULL DEFAULT false,
    role_id text NOT NULL CHECK (role_id IN ('zs','ck','fs','fz')),
    character_level int NOT NULL CHECK (character_level BETWEEN 1 AND 60),
    status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','matched','cancelled')),
    matched_instance_id uuid,
    queued_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX coop_queues_match_idx ON coop_queues(dungeon_id, difficulty, status, queued_at) WHERE status = 'queued';

CREATE TABLE coop_instances (
    id uuid PRIMARY KEY,
    dungeon_id text NOT NULL,
    difficulty text NOT NULL DEFAULT 'standard' CHECK (difficulty IN ('standard','heroic')),
    goal text NOT NULL DEFAULT 'first_clear' CHECK (goal IN ('first_clear','materials','mentor')),
    party_id uuid REFERENCES parties(id) ON DELETE SET NULL,
    leader_character_id uuid NOT NULL REFERENCES characters(id),
    status text NOT NULL DEFAULT 'ready' CHECK (status IN ('ready','active','completed','retreated','failed','expired')),
    stage_index int NOT NULL DEFAULT 0 CHECK (stage_index >= 0),
    checkpoint_stage int NOT NULL DEFAULT 0 CHECK (checkpoint_stage >= 0),
    room_state jsonb NOT NULL DEFAULT '{}'::jsonb,
    battle_id uuid,
    battle_seed bigint NOT NULL DEFAULT 0,
    battle_status text NOT NULL DEFAULT 'idle' CHECK (battle_status IN ('idle','active','finished','retreated')),
    battle_result text NOT NULL DEFAULT '',
    battle_snapshot jsonb,
    battle_inputs jsonb NOT NULL DEFAULT '[]'::jsonb,
    battle_tick int NOT NULL DEFAULT 0 CHECK (battle_tick >= 0),
    battle_confirmed_seq int NOT NULL DEFAULT 0 CHECK (battle_confirmed_seq >= 0),
    authority_epoch text,
    member_count int NOT NULL CHECK (member_count BETWEEN 1 AND 4),
    scale_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
    content_version text NOT NULL,
    ruleset_version text NOT NULL,
    version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz
);
CREATE INDEX coop_instances_status_idx ON coop_instances(status, updated_at DESC);

CREATE TABLE coop_instance_members (
    instance_id uuid NOT NULL REFERENCES coop_instances(id) ON DELETE CASCADE,
    character_id uuid NOT NULL REFERENCES characters(id),
    account_id uuid NOT NULL REFERENCES accounts(id),
    character_name text NOT NULL,
    role_id text NOT NULL CHECK (role_id IN ('zs','ck','fs','fz')),
    character_level int NOT NULL CHECK (character_level BETWEEN 1 AND 60),
    synced_level int NOT NULL CHECK (synced_level BETWEEN 1 AND 60),
    is_mentor boolean NOT NULL DEFAULT false,
    ready boolean NOT NULL DEFAULT false,
    status text NOT NULL DEFAULT 'ready' CHECK (status IN ('ready','active','disconnected','left','completed')),
    disconnected_at timestamptz,
    last_seen_at timestamptz NOT NULL DEFAULT now(),
    mechanics_done int NOT NULL DEFAULT 0 CHECK (mechanics_done >= 0),
    stages_participated int NOT NULL DEFAULT 0 CHECK (stages_participated >= 0),
    damage_dealt bigint NOT NULL DEFAULT 0 CHECK (damage_dealt >= 0),
    healing_done bigint NOT NULL DEFAULT 0 CHECK (healing_done >= 0),
    rescues_done int NOT NULL DEFAULT 0 CHECK (rescues_done >= 0),
    afk_seconds int NOT NULL DEFAULT 0 CHECK (afk_seconds >= 0),
    retreat_vote boolean NOT NULL DEFAULT false,
    joined_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (instance_id, character_id)
);
CREATE INDEX coop_members_char_idx ON coop_instance_members(character_id, joined_at DESC);

CREATE TABLE coop_instance_drops (
    id uuid PRIMARY KEY,
    instance_id uuid NOT NULL REFERENCES coop_instances(id) ON DELETE CASCADE,
    character_id uuid NOT NULL REFERENCES characters(id),
    account_id uuid NOT NULL REFERENCES accounts(id),
    source_stage text NOT NULL,
    item_template_id text NOT NULL,
    quantity int NOT NULL CHECK (quantity > 0),
    gold_amount bigint NOT NULL DEFAULT 0 CHECK (gold_amount >= 0),
    experience_amount bigint NOT NULL DEFAULT 0 CHECK (experience_amount >= 0),
    is_first_clear boolean NOT NULL DEFAULT false,
    is_mentor_bonus boolean NOT NULL DEFAULT false,
    request_id text,
    claimed_at timestamptz,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (instance_id, character_id, source_stage, item_template_id)
);
CREATE INDEX coop_drops_char_unclaimed_idx ON coop_instance_drops(character_id, created_at DESC) WHERE claimed_at IS NULL;

CREATE TABLE world_boss_events (
    id uuid PRIMARY KEY,
    event_key text NOT NULL UNIQUE,
    boss_id text NOT NULL,
    map_id text NOT NULL,
    room_id uuid REFERENCES room_instances(id),
    state text NOT NULL DEFAULT 'scheduled' CHECK (state IN ('scheduled','active','defeated','closed')),
    max_hp bigint NOT NULL CHECK (max_hp > 0),
    current_hp bigint NOT NULL CHECK (current_hp >= 0),
    stage int NOT NULL DEFAULT 0 CHECK (stage >= 0),
    starts_at timestamptz NOT NULL,
    ends_at timestamptz NOT NULL,
    closed_reason text,
    version bigint NOT NULL DEFAULT 1 CHECK (version > 0)
);
CREATE INDEX world_boss_active_idx ON world_boss_events(map_id, state, ends_at);

CREATE TABLE world_boss_participations (
    event_id uuid NOT NULL REFERENCES world_boss_events(id) ON DELETE CASCADE,
    character_id uuid NOT NULL REFERENCES characters(id),
    account_id uuid NOT NULL REFERENCES accounts(id),
    objective_steps int NOT NULL DEFAULT 0 CHECK (objective_steps >= 0),
    damage_dealt bigint NOT NULL DEFAULT 0 CHECK (damage_dealt >= 0),
    support_score bigint NOT NULL DEFAULT 0 CHECK (support_score >= 0),
    reward_tier text NOT NULL DEFAULT 'none' CHECK (reward_tier IN ('none','assist','stage','defeat')),
    reward_gold bigint NOT NULL DEFAULT 0 CHECK (reward_gold >= 0),
    reward_exp bigint NOT NULL DEFAULT 0 CHECK (reward_exp >= 0),
    reward_item_id text,
    reward_qty int NOT NULL DEFAULT 0 CHECK (reward_qty >= 0),
    rewarded_at timestamptz,
    request_id text,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, character_id),
    UNIQUE (event_id, account_id)
);

CREATE OR REPLACE FUNCTION protect_coop_drop_immutable() RETURNS trigger AS $$
BEGIN
    IF NEW.id <> OLD.id OR NEW.instance_id <> OLD.instance_id OR NEW.character_id <> OLD.character_id OR NEW.account_id <> OLD.account_id OR NEW.item_template_id <> OLD.item_template_id OR NEW.quantity <> OLD.quantity OR NEW.gold_amount <> OLD.gold_amount OR NEW.experience_amount <> OLD.experience_amount THEN
        RAISE EXCEPTION 'coop_instance_drops reward values are immutable';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER coop_instance_drops_immutable_update
    BEFORE UPDATE ON coop_instance_drops
    FOR EACH ROW EXECUTE FUNCTION protect_coop_drop_immutable();
