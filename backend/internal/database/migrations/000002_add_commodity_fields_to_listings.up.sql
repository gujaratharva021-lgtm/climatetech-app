-- Extends the existing listings table with energy-commodity trading fields
-- (coal/biomass/coke/carbon_credit), in place, instead of a parallel table.
-- Purely additive with safe defaults, so existing rows/listings stay valid
-- without a backfill.

ALTER TABLE listings
    ADD COLUMN IF NOT EXISTS commodity_type VARCHAR(30) NOT NULL DEFAULT 'other',
    ADD COLUMN IF NOT EXISTS quantity NUMERIC NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS unit VARCHAR(20) NOT NULL DEFAULT 'unit',
    ADD COLUMN IF NOT EXISTS min_order_qty NUMERIC NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS grade VARCHAR(500);

-- Keeps commodity_type constrained at the DB level to the values the Go
-- CommodityType.Valid() switch accepts, so a bad value can't get in via a
-- path that bypasses application validation (raw SQL, another service, etc).
ALTER TABLE listings
    ADD CONSTRAINT chk_listings_commodity_type
    CHECK (commodity_type IN ('coal', 'biomass', 'coke', 'carbon_credit', 'other'));

CREATE INDEX IF NOT EXISTS idx_listings_commodity_type ON listings (commodity_type);
