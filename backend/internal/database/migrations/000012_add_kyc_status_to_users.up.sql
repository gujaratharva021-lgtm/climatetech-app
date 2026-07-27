ALTER TABLE users ADD COLUMN IF NOT EXISTS kyc_status VARCHAR(20) NOT NULL DEFAULT 'not_submitted';

CREATE INDEX IF NOT EXISTS idx_users_kyc_status ON users(kyc_status);
