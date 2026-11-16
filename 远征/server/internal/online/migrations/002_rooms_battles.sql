CREATE TABLE room_instances (
    id uuid PRIMARY KEY,
    map_id text NOT NULL,
    channel integer NOT NULL CHECK (channel > 0),
    capacity integer NOT NULL CHECK (capacity BETWEEN 1 AND 100),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(map_id, channel)
);
CREATE TABLE room_leases (
    account_id uuid PRIMARY KEY REFERENCES accounts(id),
    character_id uuid NOT NULL UNIQUE REFERENCES characters(id),
    session_id uuid NOT NULL REFERENCES sessions(id),
    room_id uuid NOT NULL REFERENCES room_instances(id),
    token uuid NOT NULL UNIQUE,
    generation bigint NOT NULL CHECK (generation > 0),
    x double precision NOT NULL,
    y double precision NOT NULL,
    move_sequence bigint NOT NULL DEFAULT 0,
    position_updated_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX room_leases_room ON room_leases(room_id,expires_at);
CREATE TABLE battles (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id),
    character_id uuid NOT NULL REFERENCES characters(id),
    room_id uuid NOT NULL REFERENCES room_instances(id),
    encounter_id text NOT NULL,
    role_id text NOT NULL,
    level integer NOT NULL CHECK(level BETWEEN 1 AND 60),
    monster_id text NOT NULL,
    seed bigint NOT NULL CHECK(seed BETWEEN 0 AND 9007199254740991),
    content_version text NOT NULL,
    ruleset_version text NOT NULL,
    authority_epoch text NOT NULL DEFAULT '',
    reward_gold bigint NOT NULL CHECK(reward_gold>=0),
    reward_experience bigint NOT NULL CHECK(reward_experience>=0),
    reward_policy text NOT NULL CHECK(reward_policy IN ('once','per_battle')),
    status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','settled','cancelled')),
    snapshot jsonb NOT NULL DEFAULT '{}',
    simulation_tick integer NOT NULL DEFAULT 0,
    confirmed_sequence integer NOT NULL DEFAULT 0,
    result text NOT NULL DEFAULT '',
    started_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    settled_at timestamptz,
    acknowledged_at timestamptz
);
CREATE UNIQUE INDEX battles_one_active ON battles(character_id) WHERE status='active';
CREATE TABLE battle_inputs (
    battle_id uuid NOT NULL REFERENCES battles(id),
    sequence integer NOT NULL CHECK(sequence BETWEEN 1 AND 6000),
    tick integer NOT NULL CHECK(tick BETWEEN 0 AND 9000),
    action jsonb NOT NULL,
    accepted boolean,
    reason text NOT NULL DEFAULT '',
    applied_tick integer,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(battle_id,sequence)
);
CREATE TABLE battle_results (
    result_id uuid PRIMARY KEY,
    battle_id uuid NOT NULL UNIQUE REFERENCES battles(id),
    character_id uuid NOT NULL REFERENCES characters(id),
    result text NOT NULL CHECK(result IN ('victory','defeat','flee','draw')),
    state_hash text NOT NULL,
    gold bigint NOT NULL CHECK(gold>=0),
    experience bigint NOT NULL CHECK(experience>=0),
    wallet_balance bigint NOT NULL,
    final_snapshot jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE battle_reward_claims (
    character_id uuid NOT NULL REFERENCES characters(id),
    encounter_id text NOT NULL,
    result_id uuid NOT NULL UNIQUE REFERENCES battle_results(result_id) DEFERRABLE INITIALLY DEFERRED,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(character_id,encounter_id)
);
