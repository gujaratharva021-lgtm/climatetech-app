DROP INDEX IF EXISTS idx_listings_commodity_type;

ALTER TABLE listings
    DROP CONSTRAINT IF EXISTS chk_listings_commodity_type;

ALTER TABLE listings
    DROP COLUMN IF EXISTS commodity_type,
    DROP COLUMN IF EXISTS quantity,
    DROP COLUMN IF EXISTS unit,
    DROP COLUMN IF EXISTS min_order_qty,
    DROP COLUMN IF EXISTS grade;
