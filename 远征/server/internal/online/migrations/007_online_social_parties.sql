CREATE TABLE friend_requests (
    id uuid PRIMARY KEY,
    sender_character_id uuid NOT NULL REFERENCES characters(id),
    recipient_character_id uuid NOT NULL REFERENCES characters(id),
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','accepted','declined','cancelled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CHECK (sender_character_id <> recipient_character_id),
    CHECK ((status = 'pending') = (resolved_at IS NULL))
);
CREATE UNIQUE INDEX friend_pending_pair ON friend_requests(
    least(sender_character_id, recipient_character_id),
    greatest(sender_character_id, recipient_character_id)
) WHERE status = 'pending';
CREATE INDEX friend_incoming_idx ON friend_requests(recipient_character_id, created_at) WHERE status = 'pending';

CREATE TABLE friendships (
    character_a uuid NOT NULL REFERENCES characters(id),
    character_b uuid NOT NULL REFERENCES characters(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (character_a, character_b),
    CHECK (character_a < character_b)
);
CREATE INDEX friendships_b_idx ON friendships(character_b);

CREATE TABLE player_blocks (
    owner_account_id uuid NOT NULL REFERENCES accounts(id),
    blocked_account_id uuid NOT NULL REFERENCES accounts(id),
    blocked_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (owner_account_id, blocked_account_id),
    CHECK (owner_account_id <> blocked_account_id)
);

CREATE TABLE player_reports (
    id uuid PRIMARY KEY,
    reporter_account_id uuid NOT NULL REFERENCES accounts(id),
    reporter_character_id uuid NOT NULL REFERENCES characters(id),
    target_account_id uuid NOT NULL REFERENCES accounts(id),
    target_character_id uuid NOT NULL REFERENCES characters(id),
    category text NOT NULL CHECK (category IN ('harassment','spam','cheating','inappropriate_name')),
    reason text NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 200),
    room_id uuid REFERENCES room_instances(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (reporter_account_id <> target_account_id)
);
CREATE INDEX player_reports_target_idx ON player_reports(target_account_id, created_at DESC);

CREATE TABLE chat_messages (
    id bigserial PRIMARY KEY,
    channel_kind text NOT NULL CHECK (channel_kind IN ('room','nearby','party','whisper')),
    room_id uuid REFERENCES room_instances(id),
    party_id uuid,
    map_id text NOT NULL,
    sender_account_id uuid NOT NULL REFERENCES accounts(id),
    sender_character_id uuid NOT NULL REFERENCES characters(id),
    sender_nickname text NOT NULL,
    sender_role_id text NOT NULL,
    sender_x double precision NOT NULL,
    sender_y double precision NOT NULL,
    recipient_character_id uuid REFERENCES characters(id),
    content text NOT NULL CHECK (char_length(content) BETWEEN 1 AND 120),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        (channel_kind = 'whisper' AND recipient_character_id IS NOT NULL) OR
        (channel_kind <> 'whisper' AND recipient_character_id IS NULL)
    )
);
CREATE INDEX chat_messages_room_idx ON chat_messages(room_id, id DESC);
CREATE INDEX chat_messages_party_idx ON chat_messages(party_id, id DESC) WHERE party_id IS NOT NULL;

CREATE TABLE parties (
    id uuid PRIMARY KEY,
    leader_character_id uuid NOT NULL REFERENCES characters(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    version bigint NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE party_members (
    character_id uuid PRIMARY KEY REFERENCES characters(id),
    party_id uuid NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
    joined_at timestamptz NOT NULL DEFAULT now(),
    ready_session_id uuid REFERENCES sessions(id),
    UNIQUE (party_id, character_id)
);

ALTER TABLE parties ADD CONSTRAINT party_leader_is_member
    FOREIGN KEY (id, leader_character_id) REFERENCES party_members(party_id, character_id)
    DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE party_invites (
    id uuid PRIMARY KEY,
    party_id uuid NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL REFERENCES characters(id),
    recipient_id uuid NOT NULL REFERENCES characters(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','accepted','declined','expired','cancelled')),
    resolved_at timestamptz,
    CHECK (sender_id <> recipient_id),
    CHECK (expires_at > created_at),
    CHECK ((status = 'pending') = (resolved_at IS NULL))
);
CREATE UNIQUE INDEX party_pending_invite ON party_invites(party_id, recipient_id) WHERE status = 'pending';
CREATE INDEX party_incoming_invites ON party_invites(recipient_id, expires_at) WHERE status = 'pending';

CREATE FUNCTION protect_social_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'social audit history is append only';
END;
$$;
CREATE TRIGGER player_reports_immutable BEFORE UPDATE OR DELETE ON player_reports
    FOR EACH ROW EXECUTE FUNCTION protect_social_audit();
CREATE TRIGGER chat_messages_immutable BEFORE UPDATE OR DELETE ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION protect_social_audit();
