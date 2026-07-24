-- Phase 8b: Carbon Credit specifics. A certificate tracks a registry-issued
-- batch of credits a seller owns (see models.CarbonCreditCertificate doc
-- comment for why this doesn't connect to a real registry API); a
-- retirement permanently claims a quantity from it, verified against the
-- retiring buyer's actual delivered purchases (CarbonCertificateHandler.RetireCredits).
--
-- No DB-level foreign keys, matching this project's existing convention.

CREATE TABLE IF NOT EXISTS carbon_credit_certificates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL,
    listing_id UUID,
    registry VARCHAR(100) NOT NULL,
    project_name VARCHAR(200) NOT NULL,
    project_id VARCHAR(100),
    project_type VARCHAR(50),
    vintage_year INTEGER NOT NULL,
    serial_number_range VARCHAR(200),
    total_quantity NUMERIC NOT NULL,
    remaining_quantity NUMERIC NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'fully_retired')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_carbon_certs_seller_id ON carbon_credit_certificates (seller_id);
-- Partial unique index: one certificate per listing, but allows any number
-- of not-yet-attached certificates (listing_id IS NULL) to coexist.
CREATE UNIQUE INDEX IF NOT EXISTS idx_carbon_certs_listing_id ON carbon_credit_certificates (listing_id) WHERE listing_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_carbon_certs_status ON carbon_credit_certificates (status);
CREATE INDEX IF NOT EXISTS idx_carbon_certs_deleted_at ON carbon_credit_certificates (deleted_at);

-- No deleted_at column here: retirement records are permanent by design
-- (see models.CreditRetirement doc comment) -- not even soft-deletable.
CREATE TABLE IF NOT EXISTS credit_retirements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    certificate_id UUID NOT NULL,
    retired_by_user_id UUID NOT NULL,
    quantity NUMERIC NOT NULL,
    beneficiary_name VARCHAR(200),
    retirement_reason VARCHAR(500),
    reference_number VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_credit_retirements_certificate_id ON credit_retirements (certificate_id);
CREATE INDEX IF NOT EXISTS idx_credit_retirements_retired_by_user_id ON credit_retirements (retired_by_user_id);
