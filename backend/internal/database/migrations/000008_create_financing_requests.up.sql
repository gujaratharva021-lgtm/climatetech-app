-- Phase 8a: Trade Finance (tracking, not a lending integration -- see
-- models.FinancingRequest doc comment for why). A financing request tracks
-- either party's ask to finance an order's invoice value; an admin moves
-- it through the status state machine (FinancingHandler.allowedFinancingTransitions).
--
-- No DB-level foreign key to orders, matching this project's existing
-- convention.

CREATE TABLE IF NOT EXISTS financing_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    requester_id UUID NOT NULL,
    requester_role VARCHAR(10) NOT NULL CHECK (requester_role IN ('buyer', 'seller')),
    requested_amount NUMERIC NOT NULL,
    purpose VARCHAR(500),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'under_review', 'approved', 'rejected', 'disbursed', 'repaid', 'defaulted')),
    lender_name VARCHAR(150),
    approved_amount NUMERIC NOT NULL DEFAULT 0,
    interest_rate NUMERIC NOT NULL DEFAULT 0,
    admin_notes VARCHAR(1000),
    disbursed_at TIMESTAMPTZ,
    repaid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_financing_requests_order_id ON financing_requests (order_id);
CREATE INDEX IF NOT EXISTS idx_financing_requests_requester_id ON financing_requests (requester_id);
CREATE INDEX IF NOT EXISTS idx_financing_requests_status ON financing_requests (status);
CREATE INDEX IF NOT EXISTS idx_financing_requests_deleted_at ON financing_requests (deleted_at);
-- Matches CreateFinancingRequest's duplicate-financing guard (order_id +
-- status IN active-statuses).
CREATE INDEX IF NOT EXISTS idx_financing_requests_order_status ON financing_requests (order_id, status);
