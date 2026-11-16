CREATE TABLE accounts (
    id uuid PRIMARY KEY,
    username text NOT NULL UNIQUE,
    password_hash bytea NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version bigint NOT NULL DEFAULT 1
);
CREATE TABLE characters (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id),
    nickname text NOT NULL,
    nickname_key text NOT NULL UNIQUE,
    role_id text NOT NULL CHECK (role_id IN ('zs','ck','fs','fz')),
    appearance_id text NOT NULL DEFAULT 'default',
    level integer NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 60),
    experience bigint NOT NULL DEFAULT 0 CHECK (experience >= 0),
    map_id text NOT NULL DEFAULT 'lorin_wilds',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    version bigint NOT NULL DEFAULT 1
);
CREATE INDEX characters_account ON characters(account_id);
CREATE TABLE sessions (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id),
    access_hash bytea NOT NULL UNIQUE,
    refresh_hash bytea NOT NULL UNIQUE,
    access_expires_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    active_character_id uuid REFERENCES characters(id),
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version bigint NOT NULL DEFAULT 1
);
CREATE INDEX sessions_account ON sessions(account_id);
CREATE TABLE wallets (
    character_id uuid PRIMARY KEY REFERENCES characters(id),
    gold bigint NOT NULL DEFAULT 0 CHECK (gold >= 0),
    expedition bigint NOT NULL DEFAULT 0 CHECK (expedition >= 0),
    soul bigint NOT NULL DEFAULT 0 CHECK (soul >= 0),
    honor bigint NOT NULL DEFAULT 0 CHECK (honor >= 0),
    version bigint NOT NULL DEFAULT 1,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE wallet_ledger (
    id uuid PRIMARY KEY,
    character_id uuid NOT NULL REFERENCES characters(id),
    transaction_id text NOT NULL,
    currency text NOT NULL CHECK (currency IN ('gold','expedition','soul','honor')),
    delta bigint NOT NULL,
    balance_after bigint NOT NULL CHECK (balance_after >= 0),
    reason text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(character_id, transaction_id, currency)
);
CREATE TABLE inventory_items (
    item_uid uuid PRIMARY KEY,
    character_id uuid NOT NULL REFERENCES characters(id),
    template_id text NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    bound boolean NOT NULL DEFAULT true,
    source_transaction text NOT NULL,
    properties jsonb NOT NULL DEFAULT '{}',
    version bigint NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE FUNCTION protect_wallet_ledger() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'wallet ledger is append only';
END;
$$;
CREATE TRIGGER wallet_ledger_immutable BEFORE UPDATE OR DELETE ON wallet_ledger
    FOR EACH ROW EXECUTE FUNCTION protect_wallet_ledger();
CREATE INDEX inventory_character ON inventory_items(character_id);
CREATE TABLE character_progress (
    character_id uuid PRIMARY KEY REFERENCES characters(id),
    story_step text NOT NULL DEFAULT 's01',
    flags jsonb NOT NULL DEFAULT '{}',
    version bigint NOT NULL DEFAULT 1,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE command_receipts (
    account_id uuid NOT NULL REFERENCES accounts(id),
    operation text NOT NULL,
    request_id text NOT NULL,
    payload_hash bytea NOT NULL,
    response jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, operation, request_id)
);
CREATE TABLE audit_events (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id uuid REFERENCES accounts(id),
    character_id uuid REFERENCES characters(id),
    action text NOT NULL,
    details jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);
