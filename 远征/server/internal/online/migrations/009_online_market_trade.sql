CREATE TABLE market_orders (
    order_id uuid PRIMARY KEY,
    seller_character_id uuid NOT NULL REFERENCES characters(id),
    seller_account_id uuid NOT NULL REFERENCES accounts(id),
    category text NOT NULL CHECK (category IN ('commodity','equipment')),
    template_id text NOT NULL,
    source_item_uid uuid NOT NULL,
    item_bound boolean NOT NULL DEFAULT false CHECK (item_bound = false),
    item_properties jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(item_properties) = 'object'),
    item_origin text NOT NULL,
    unit_price bigint NOT NULL CHECK (unit_price > 0),
    initial_qty integer NOT NULL CHECK (initial_qty > 0),
    remaining_qty integer NOT NULL CHECK (remaining_qty >= 0 AND remaining_qty <= initial_qty),
    listing_fee bigint NOT NULL CHECK (listing_fee >= 0),
    tax_bps integer NOT NULL CHECK (tax_bps >= 0 AND tax_bps <= 1000),
    status text NOT NULL CHECK (status IN ('open','partial','filled','cancelled','expired','paused')),
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (category <> 'equipment' OR initial_qty = 1)
);
CREATE INDEX market_orders_active ON market_orders(status, category, template_id, created_at DESC)
    WHERE status IN ('open','partial');
CREATE INDEX market_orders_seller ON market_orders(seller_character_id, status, created_at DESC);

CREATE TABLE market_fills (
    fill_id uuid PRIMARY KEY,
    order_id uuid NOT NULL REFERENCES market_orders(order_id),
    buyer_character_id uuid NOT NULL REFERENCES characters(id),
    buyer_account_id uuid NOT NULL REFERENCES accounts(id),
    seller_character_id uuid NOT NULL REFERENCES characters(id),
    seller_account_id uuid NOT NULL REFERENCES accounts(id),
    template_id text NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price bigint NOT NULL CHECK (unit_price > 0),
    gross_gold bigint NOT NULL CHECK (gross_gold > 0 AND gross_gold = quantity * unit_price),
    tax_gold bigint NOT NULL CHECK (tax_gold >= 0 AND tax_gold < gross_gold),
    seller_net_gold bigint NOT NULL CHECK (seller_net_gold > 0 AND seller_net_gold + tax_gold = gross_gold),
    buyer_item_uid uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (buyer_account_id <> seller_account_id)
);
CREATE INDEX market_fills_template ON market_fills(template_id, created_at DESC);

CREATE FUNCTION protect_market_fills() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'market fills are append only';
END;
$$;
CREATE TRIGGER market_fills_immutable BEFORE UPDATE OR DELETE ON market_fills
    FOR EACH ROW EXECUTE FUNCTION protect_market_fills();

CREATE TABLE market_payouts (
    payout_id uuid PRIMARY KEY,
    character_id uuid NOT NULL REFERENCES characters(id),
    account_id uuid NOT NULL REFERENCES accounts(id),
    order_id uuid REFERENCES market_orders(order_id),
    fill_id uuid REFERENCES market_fills(fill_id),
    kind text NOT NULL CHECK (kind IN ('sale_proceeds','order_return','order_expire_return','trade_return')),
    gold_amount bigint NOT NULL DEFAULT 0 CHECK (gold_amount >= 0),
    template_id text NOT NULL DEFAULT '',
    quantity integer NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    item_properties jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(item_properties) = 'object'),
    item_origin text NOT NULL DEFAULT '',
    status text NOT NULL CHECK (status IN ('pending','claimed','expired')),
    expires_at timestamptz NOT NULL,
    claimed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (gold_amount > 0 OR quantity > 0)
);
CREATE INDEX market_payouts_pending ON market_payouts(character_id, status, created_at DESC);

CREATE FUNCTION protect_market_payout_values() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.character_id <> OLD.character_id OR NEW.account_id <> OLD.account_id
       OR NEW.kind <> OLD.kind OR NEW.gold_amount <> OLD.gold_amount
       OR NEW.template_id <> OLD.template_id OR NEW.quantity <> OLD.quantity
       OR NEW.item_properties <> OLD.item_properties THEN
        RAISE EXCEPTION 'market payout amounts are immutable';
    END IF;
    IF OLD.status = 'claimed' AND NEW.status <> 'claimed' THEN
        RAISE EXCEPTION 'claimed payout cannot revert';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER market_payouts_immutable BEFORE UPDATE ON market_payouts
    FOR EACH ROW EXECUTE FUNCTION protect_market_payout_values();

CREATE TABLE trade_sessions (
    trade_id uuid PRIMARY KEY,
    initiator_character_id uuid NOT NULL REFERENCES characters(id),
    initiator_account_id uuid NOT NULL REFERENCES accounts(id),
    partner_character_id uuid NOT NULL REFERENCES characters(id),
    partner_account_id uuid NOT NULL REFERENCES accounts(id),
    initiator_gold bigint NOT NULL DEFAULT 0 CHECK (initiator_gold >= 0),
    partner_gold bigint NOT NULL DEFAULT 0 CHECK (partner_gold >= 0),
    initiator_confirmed boolean NOT NULL DEFAULT false,
    partner_confirmed boolean NOT NULL DEFAULT false,
    revision bigint NOT NULL DEFAULT 1,
    status text NOT NULL CHECK (status IN ('active','completed','cancelled')),
    expires_at timestamptz NOT NULL,
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (initiator_account_id <> partner_account_id)
);
CREATE INDEX trade_sessions_active ON trade_sessions(status, created_at DESC) WHERE status = 'active';

CREATE TABLE trade_offers (
    offer_id uuid PRIMARY KEY,
    trade_id uuid NOT NULL REFERENCES trade_sessions(trade_id),
    character_id uuid NOT NULL REFERENCES characters(id),
    source_item_uid uuid NOT NULL,
    template_id text NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    item_properties jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(item_properties) = 'object'),
    item_origin text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX trade_offers_session ON trade_offers(trade_id, character_id);

CREATE TABLE economy_alerts (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alert_type text NOT NULL CHECK (alert_type IN ('price_outlier','rapid_flip','self_trade_attempt','wash_volume','sandbox_fault')),
    severity text NOT NULL CHECK (severity IN ('warn','high')),
    account_id uuid REFERENCES accounts(id),
    character_id uuid REFERENCES characters(id),
    order_id uuid REFERENCES market_orders(order_id),
    trade_id uuid REFERENCES trade_sessions(trade_id),
    details jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(details) = 'object'),
    reviewed boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX economy_alerts_recent ON economy_alerts(reviewed, created_at DESC);
