CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vehicle_id UUID NOT NULL REFERENCES vehicles(id),
    booked_by_user_id UUID NOT NULL REFERENCES users(id),
    pickup_location VARCHAR(255) NOT NULL,
    drop_location VARCHAR(255) NOT NULL,
    cargo_details TEXT,
    weight_kg NUMERIC(10,2) NOT NULL DEFAULT 0,
    scheduled_pickup TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    estimated_cost NUMERIC(10,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_bookings_vehicle_id ON bookings(vehicle_id);
CREATE INDEX idx_bookings_booked_by_user_id ON bookings(booked_by_user_id);
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_deleted_at ON bookings(deleted_at);
