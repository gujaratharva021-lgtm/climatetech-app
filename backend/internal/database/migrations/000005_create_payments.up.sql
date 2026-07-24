-- Phase 4: Payment & Escrow. A Payment is created when checkout starts
-- (PaymentHandler.CreatePaymentOrder), moves to 'paid' once Razorpay
-- confirms via signature-verified callback or webhook, and later to
-- 'released' (see ReleaseEscrow's doc comment for what that does and does
-- not do) or 'refunded'.
--
-- No DB-level foreign key to orders, matching this project's existing
-- convention.

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    razorpay_order_id VARCHAR(100) NOT NULL,
    razorpay_payment_id VARCHAR(100),
    razorpay_signature VARCHAR(255),
    refund_id VARCHAR(100),
    amount NUMERIC NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'INR',
    status VARCHAR(20) NOT NULL DEFAULT 'created'
        CHECK (status IN ('created', 'paid', 'released', 'refunded', 'failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments (order_id);
CREATE INDEX IF NOT EXISTS idx_payments_razorpay_order_id ON payments (razorpay_order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments (status);
CREATE INDEX IF NOT EXISTS idx_payments_deleted_at ON payments (deleted_at);
