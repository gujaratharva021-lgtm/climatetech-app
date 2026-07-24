-- Phase 5: Logistics. A Shipment is the seller-maintained tracking record
-- for an order (carrier/vehicle/driver, manually-updated status and
-- location -- no real carrier API integrated yet). Deliberately separate
-- from Order.Status: updating shipment status here does not itself confirm
-- delivery on the order, since that's still the buyer's call via
-- OrderHandler.DeliverOrder.
--
-- No DB-level foreign key to orders, matching this project's existing
-- convention.

CREATE TABLE IF NOT EXISTS shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    carrier_name VARCHAR(150) NOT NULL,
    vehicle_number VARCHAR(50),
    driver_name VARCHAR(150),
    driver_phone VARCHAR(20),
    tracking_number VARCHAR(100),
    current_location VARCHAR(200),
    status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'dispatched', 'in_transit', 'delivered', 'failed')),
    estimated_delivery_date TIMESTAMPTZ,
    proof_of_delivery_url VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- One shipment per order.
CREATE UNIQUE INDEX IF NOT EXISTS idx_shipments_order_id ON shipments (order_id);
CREATE INDEX IF NOT EXISTS idx_shipments_status ON shipments (status);
CREATE INDEX IF NOT EXISTS idx_shipments_deleted_at ON shipments (deleted_at);
