ALTER TABLE accounts
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'erased')),
  ADD COLUMN IF NOT EXISTS erased_at timestamptz;

CREATE TABLE account_privacy_requests (
  id uuid PRIMARY KEY,
  account_id uuid NOT NULL REFERENCES accounts(id),
  request_type text NOT NULL CHECK (request_type IN ('export', 'erasure')),
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'scheduled')),
  details jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(details) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX account_privacy_requests_acct_idx ON account_privacy_requests (account_id, created_at DESC);

CREATE TABLE moderation_actions (
  id bigserial PRIMARY KEY,
  report_id uuid NOT NULL REFERENCES player_reports(id),
  operator_label text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('dismissed', 'warned', 'muted', 'suspended')),
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX moderation_actions_report_idx ON moderation_actions (report_id, id DESC);

CREATE FUNCTION reject_moderation_actions_mutation()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'moderation_actions is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER moderation_actions_immutable
  BEFORE UPDATE OR DELETE ON moderation_actions
  FOR EACH ROW EXECUTE FUNCTION reject_moderation_actions_mutation();
