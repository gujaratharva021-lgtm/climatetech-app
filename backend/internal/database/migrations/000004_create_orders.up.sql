-- Phase 3: Orders & Fulfillment. An order is created either from an awarded
-- RFQ bid (OrderHandler.CreateOrderFromRFQ) or a direct listing purchase
-- (OrderHandler.CreateOrderFromListing), then moves through
-- placed -> confirmed -> shipped -> delivered (or cancelled while still
-- placed). This is the anchor Phase 4 (payment/escrow) and Phase 5
-- (logistics) build on.
--
-- No DB-level foreign keys, matching this project's existing convention.

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_id UUID NOT NULL,
    seller_id UUID NOT NULL,
    source VARCHAR(20) NOT NULL CHECK (source IN ('rfq', 'listing')),
    rfq_id UUID,
    bid_id UUID,
    listing_id UUID,
    commodity_type VARCHAR(30) NOT NULL DEFAULT 'other'
        CHECK (commodity_type IN ('coal', 'biomass', 'coke', 'carbon_credit', 'other')),
    quantity NUMERIC NOT NULL,
    unit VARCHAR(20) NOT NULL DEFAULT 'unit',
    price_per_unit NUMERIC NOT NULL,
    total_amount NUMERIC NOT NULL,
    delivery_address VARCHAR(500) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'placed'
        CHECK (status IN ('placed', 'confirmed', 'shipped', 'delivered', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_orders_buyer_id ON orders (buyer_id);
CREATE INDEX IF NOT EXISTS idx_orders_seller_id ON orders (seller_id);
CREATE INDEX IF NOT EXISTS idx_orders_rfq_id ON orders (rfq_id);
CREATE INDEX IF NOT EXISTS idx_orders_listing_id ON orders (listing_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status);
CREATE INDEX IF NOT EXISTS idx_orders_deleted_at ON orders (deleted_at);
