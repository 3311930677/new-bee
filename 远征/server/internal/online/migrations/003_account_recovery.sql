ALTER TABLE accounts ADD COLUMN recovery_salt bytea;
ALTER TABLE accounts ADD COLUMN recovery_hash bytea;
ALTER TABLE accounts ADD CONSTRAINT accounts_recovery_shape CHECK (
    (recovery_salt IS NULL AND recovery_hash IS NULL) OR
    (recovery_salt IS NOT NULL AND recovery_hash IS NOT NULL AND
     octet_length(recovery_salt)=32 AND octet_length(recovery_hash)=32)
);
CREATE TABLE security_notifications (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts(id),
    kind text NOT NULL CHECK(kind IN ('recovery_code_replaced','password_reset')),
    created_at timestamptz NOT NULL DEFAULT now(),
    acknowledged_at timestamptz
);
CREATE INDEX security_notifications_account ON security_notifications(account_id,created_at);
