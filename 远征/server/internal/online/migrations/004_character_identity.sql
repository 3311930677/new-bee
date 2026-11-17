ALTER TABLE characters ADD COLUMN gender_id text NOT NULL DEFAULT 'unspecified'
    CHECK (gender_id IN ('unspecified','male','female'));
ALTER TABLE characters ADD COLUMN avatar_id text NOT NULL DEFAULT 'role_default'
    CHECK (avatar_id IN ('role_default','role_zs','role_ck','role_fs','role_fz'));
