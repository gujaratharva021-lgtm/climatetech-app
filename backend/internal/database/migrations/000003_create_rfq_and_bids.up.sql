-- Phase 2: RFQ (Request For Quote) + reverse-auction bids. Buyers post an
-- RFQ (what they need); sellers respond with Bids; the buyer accepts one via
-- the app (RFQHandler.AcceptBid), which marks it accepted, rejects the rest,
-- and awards the RFQ — all in one transaction.
--
-- No DB-level foreign keys, matching this project's existing convention
-- (see listings -> sellers, which is app-enforced rather than FK-enforced).

CREATE TABLE IF NOT EXISTS rfqs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL,
    commodity_type VARCHAR(30) NOT NULL DEFAULT 'other'
        CHECK (commodity_type IN ('coal', 'biomass', 'coke', 'carbon_credit', 'other')),
    quantity NUMERIC NOT NULL,
    unit VARCHAR(20) NOT NULL DEFAULT 'unit',
    target_price NUMERIC NOT NULL DEFAULT 0,
    grade VARCHAR(500),
    location VARCHAR(150),
    deadline TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'awarded', 'cancelled', 'expired')),
    awarded_bid_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_rfqs_buyer_id ON rfqs (buyer_id);
CREATE INDEX IF NOT EXISTS idx_rfqs_commodity_type ON rfqs (commodity_type);
CREATE INDEX IF NOT EXISTS idx_rfqs_deleted_at ON rfqs (deleted_at);
-- Matches BrowseRFQs' hot query (status = 'open' AND deadline > now()) as a
-- single composite index rather than two separate ones ANDed together.
CREATE INDEX IF NOT EXISTS idx_rfqs_status_deadline ON rfqs (status, deadline);

CREATE TABLE IF NOT EXISTS bids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rfq_id UUID NOT NULL,
    seller_id UUID NOT NULL,
    price NUMERIC NOT NULL,
    quantity NUMERIC NOT NULL,
    message VARCHAR(1000),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected', 'withdrawn')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_bids_rfq_id ON bids (rfq_id);
CREATE INDEX IF NOT EXISTS idx_bids_seller_id ON bids (seller_id);
CREATE INDEX IF NOT EXISTS idx_bids_status ON bids (status);
CREATE INDEX IF NOT EXISTS idx_bids_deleted_at ON bids (deleted_at);
