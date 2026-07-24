-- Phase 6: Live Price Index. A snapshot is one (commodity_type, unit,
-- source) price band recorded at a point in time -- source is 'listing'
-- (current asking prices) or 'transacted' (actual order prices from the
-- preceding 30 days at recording time). Recorded by the background ticker
-- in cmd/server/main.go and/or the admin manual-trigger endpoint; see
-- services.PriceIndexService.RecordDailySnapshot.
--
-- No DB-level foreign keys, matching this project's existing convention.

CREATE TABLE IF NOT EXISTS price_index_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commodity_type VARCHAR(30) NOT NULL
        CHECK (commodity_type IN ('coal', 'biomass', 'coke', 'carbon_credit', 'other')),
    unit VARCHAR(20) NOT NULL,
    source VARCHAR(20) NOT NULL CHECK (source IN ('listing', 'transacted')),
    avg_price NUMERIC NOT NULL,
    min_price NUMERIC NOT NULL,
    max_price NUMERIC NOT NULL,
    sample_size INTEGER NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_price_index_snapshots_commodity_type ON price_index_snapshots (commodity_type);
CREATE INDEX IF NOT EXISTS idx_price_index_snapshots_recorded_at ON price_index_snapshots (recorded_at);
CREATE INDEX IF NOT EXISTS idx_price_index_snapshots_deleted_at ON price_index_snapshots (deleted_at);
-- Matches GetPriceHistory's hot query (commodity_type + source + recorded_at range).
CREATE INDEX IF NOT EXISTS idx_price_index_snapshots_lookup ON price_index_snapshots (commodity_type, source, recorded_at);
