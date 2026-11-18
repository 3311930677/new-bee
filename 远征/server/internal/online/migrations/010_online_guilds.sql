CREATE TABLE guilds (
    id uuid PRIMARY KEY,
    name text NOT NULL UNIQUE CHECK (char_length(name) BETWEEN 2 AND 16),
    motto text NOT NULL DEFAULT '' CHECK (char_length(motto) <= 80),
    announcement text NOT NULL DEFAULT '' CHECK (char_length(announcement) <= 200),
    leader_character_id uuid NOT NULL REFERENCES characters(id),
    member_cap integer NOT NULL DEFAULT 30 CHECK (member_cap >= 30 AND member_cap <= 60),
    weekly_coop_points integer NOT NULL DEFAULT 0 CHECK (weekly_coop_points >= 0),
    decor_level integer NOT NULL DEFAULT 1 CHECK (decor_level >= 1 AND decor_level <= 10),
    decor_banner text NOT NULL DEFAULT 'oak_banner',
    decor_monument text NOT NULL DEFAULT 'hearthstone',
    last_leader_active_at timestamptz NOT NULL DEFAULT now(),
    disbanded_at timestamptz,
    version bigint NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX guilds_active ON guilds(disbanded_at, created_at DESC) WHERE disbanded_at IS NULL;

CREATE TABLE guild_members (
    guild_id uuid NOT NULL REFERENCES guilds(id),
    character_id uuid PRIMARY KEY REFERENCES characters(id),
    account_id uuid NOT NULL REFERENCES accounts(id),
    rank text NOT NULL CHECK (rank IN ('leader','officer','member')),
    can_invite boolean NOT NULL DEFAULT false,
    can_manage_warehouse boolean NOT NULL DEFAULT false,
    can_edit_announcement boolean NOT NULL DEFAULT false,
    contribution_points integer NOT NULL DEFAULT 0 CHECK (contribution_points >= 0),
    joined_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX guild_members_guild ON guild_members(guild_id, rank, joined_at);

CREATE TABLE guild_invites (
    id uuid PRIMARY KEY,
    guild_id uuid NOT NULL REFERENCES guilds(id),
    inviter_character_id uuid NOT NULL REFERENCES characters(id),
    target_character_id uuid NOT NULL REFERENCES characters(id),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','cancelled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CHECK (inviter_character_id <> target_character_id),
    CHECK ((status = 'pending') = (resolved_at IS NULL))
);
CREATE UNIQUE INDEX guild_invites_pending_unique ON guild_invites(guild_id, target_character_id) WHERE status = 'pending';

CREATE TABLE guild_warehouse (
    guild_id uuid NOT NULL REFERENCES guilds(id),
    template_id text NOT NULL,
    quantity integer NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (guild_id, template_id)
);

CREATE TABLE guild_audit_logs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    guild_id uuid NOT NULL REFERENCES guilds(id),
    actor_character_id uuid REFERENCES characters(id),
    target_character_id uuid REFERENCES characters(id),
    action text NOT NULL CHECK (action IN (
        'create','join','leave','kick','permission','announcement','decorate',
        'warehouse_deposit','warehouse_withdraw','weekly_task','leader_handoff','leader_claim_inactive','disband'
    )),
    template_id text NOT NULL DEFAULT '',
    quantity integer NOT NULL DEFAULT 0,
    details jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(details) = 'object'),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX guild_audit_logs_guild ON guild_audit_logs(guild_id, id DESC);

CREATE FUNCTION protect_guild_audit_logs() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'guild audit logs are append only';
END;
$$;
CREATE TRIGGER guild_audit_logs_immutable BEFORE UPDATE OR DELETE ON guild_audit_logs
    FOR EACH ROW EXECUTE FUNCTION protect_guild_audit_logs();

CREATE TABLE guild_member_cooldowns (
    character_id uuid PRIMARY KEY REFERENCES characters(id),
    cooldown_until timestamptz NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
