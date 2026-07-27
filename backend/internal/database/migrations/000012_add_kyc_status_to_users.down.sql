DROP INDEX IF EXISTS idx_users_kyc_status;
ALTER TABLE users DROP COLUMN IF EXISTS kyc_status;
