CREATE TABLE npc_interactions (
    character_id uuid NOT NULL REFERENCES characters(id),
    npc_id text NOT NULL,
    interaction_count integer NOT NULL DEFAULT 1 CHECK (interaction_count > 0),
    last_dialogue text NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (character_id, npc_id)
);
CREATE INDEX npc_interactions_character ON npc_interactions(character_id);
