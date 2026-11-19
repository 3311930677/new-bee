CREATE TABLE pvp_seasons (
  id text PRIMARY KEY,
  name text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  rules_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz
);

CREATE TABLE pvp_ratings (
  character_id uuid NOT NULL REFERENCES characters(id),
  mode text NOT NULL CHECK (mode IN ('1v1', '2v2', '3v3')),
  season_id text NOT NULL REFERENCES pvp_seasons(id),
  rating integer NOT NULL DEFAULT 1000 CHECK (rating >= 0),
  peak_rating integer NOT NULL DEFAULT 1000 CHECK (peak_rating >= 0),
  tier text NOT NULL DEFAULT 'bronze',
  wins integer NOT NULL DEFAULT 0 CHECK (wins >= 0),
  losses integer NOT NULL DEFAULT 0 CHECK (losses >= 0),
  draws integer NOT NULL DEFAULT 0 CHECK (draws >= 0),
  streak integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (character_id, mode, season_id)
);

CREATE INDEX pvp_ratings_leaderboard_idx
  ON pvp_ratings (season_id, mode, rating DESC, wins DESC, updated_at ASC);

CREATE TABLE pvp_honor_wallets (
  character_id uuid PRIMARY KEY REFERENCES characters(id),
  honor_balance integer NOT NULL DEFAULT 0 CHECK (honor_balance >= 0),
  weekly_honor_earned integer NOT NULL DEFAULT 0 CHECK (weekly_honor_earned >= 0),
  week_key text NOT NULL DEFAULT '',
  claimed_seasons jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pvp_honor_ledger (
  id bigserial PRIMARY KEY,
  character_id uuid NOT NULL REFERENCES characters(id),
  transaction_id text NOT NULL,
  delta integer NOT NULL,
  balance_after integer NOT NULL CHECK (balance_after >= 0),
  reason text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(details) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX pvp_honor_ledger_tx_uidx ON pvp_honor_ledger (character_id, transaction_id);
CREATE INDEX pvp_honor_ledger_char_idx ON pvp_honor_ledger (character_id, id DESC);

CREATE FUNCTION reject_pvp_honor_ledger_mutation()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'pvp_honor_ledger is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pvp_honor_ledger_immutable
  BEFORE UPDATE OR DELETE ON pvp_honor_ledger
  FOR EACH ROW EXECUTE FUNCTION reject_pvp_honor_ledger_mutation();

CREATE TABLE pvp_queues (
  id uuid PRIMARY KEY,
  mode text NOT NULL CHECK (mode IN ('1v1', '2v2', '3v3')),
  entry_type text NOT NULL CHECK (entry_type IN ('solo', 'party')),
  leader_character_id uuid NOT NULL REFERENCES characters(id),
  party_id uuid REFERENCES parties(id) ON DELETE SET NULL,
  member_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  avg_rating integer NOT NULL DEFAULT 1000 CHECK (avg_rating >= 0),
  allow_random_fill boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'matched', 'cancelled')),
  matched_match_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX pvp_queues_active_idx ON pvp_queues (mode, status, created_at);

CREATE TABLE pvp_challenges (
  id uuid PRIMARY KEY,
  mode text NOT NULL CHECK (mode IN ('1v1', '2v2', '3v3')),
  challenger_id uuid NOT NULL REFERENCES characters(id),
  target_id uuid NOT NULL REFERENCES characters(id),
  challenger_party_id uuid REFERENCES parties(id) ON DELETE SET NULL,
  target_party_id uuid REFERENCES parties(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
  match_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX pvp_challenges_target_idx ON pvp_challenges (target_id, status, created_at DESC);

CREATE TABLE pvp_matches (
  id uuid PRIMARY KEY,
  season_id text NOT NULL REFERENCES pvp_seasons(id),
  mode text NOT NULL CHECK (mode IN ('1v1', '2v2', '3v3')),
  match_kind text NOT NULL CHECK (match_kind IN ('sparring', 'ranked')),
  status text NOT NULL DEFAULT 'ready' CHECK (status IN ('ready', 'active', 'completed', 'aborted')),
  seed bigint NOT NULL,
  config_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  participants jsonb NOT NULL DEFAULT '[]'::jsonb,
  battle_inputs jsonb NOT NULL DEFAULT '[]'::jsonb,
  battle_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  battle_tick integer NOT NULL DEFAULT 0 CHECK (battle_tick >= 0),
  confirmed_sequence integer NOT NULL DEFAULT 0 CHECK (confirmed_sequence >= 0),
  state_hash text NOT NULL DEFAULT '',
  last_action_tick integer NOT NULL DEFAULT 0 CHECK (last_action_tick >= 0),
  timeout_defaults_applied integer NOT NULL DEFAULT 0 CHECK (timeout_defaults_applied >= 0),
  winner_side text NOT NULL DEFAULT '' CHECK (winner_side IN ('', 'ally', 'enemy', 'draw')),
  result_reason text NOT NULL DEFAULT '',
  rating_deltas jsonb NOT NULL DEFAULT '{}'::jsonb,
  honor_awards jsonb NOT NULL DEFAULT '{}'::jsonb,
  settled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX pvp_matches_status_idx ON pvp_matches (status, created_at DESC);

CREATE TABLE pvp_match_participants (
  match_id uuid NOT NULL REFERENCES pvp_matches(id),
  character_id uuid NOT NULL REFERENCES characters(id),
  account_id uuid NOT NULL REFERENCES accounts(id),
  side text NOT NULL CHECK (side IN ('ally', 'enemy')),
  slot_index integer NOT NULL DEFAULT 0 CHECK (slot_index >= 0 AND slot_index < 3),
  party_id uuid,
  was_random_fill boolean NOT NULL DEFAULT false,
  ready boolean NOT NULL DEFAULT false,
  connected boolean NOT NULL DEFAULT true,
  disconnected_at timestamptz,
  last_command_tick integer NOT NULL DEFAULT 0,
  timeout_defaults integer NOT NULL DEFAULT 0,
  forfeited boolean NOT NULL DEFAULT false,
  rating_before integer NOT NULL DEFAULT 1000,
  rating_after integer NOT NULL DEFAULT 1000,
  honor_delta integer NOT NULL DEFAULT 0,
  PRIMARY KEY (match_id, character_id)
);

CREATE INDEX pvp_match_participants_char_idx ON pvp_match_participants (character_id, match_id);
