CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id),
    vehicle_type VARCHAR(30) NOT NULL,
    reg_number VARCHAR(50) NOT NULL UNIQUE,
    capacity_kg NUMERIC(10,2) NOT NULL DEFAULT 0,
    capacity_unit VARCHAR(10) NOT NULL DEFAULT 'kg',
    base_location VARCHAR(255),
    price_per_km NUMERIC(10,2) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'available',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_vehicles_owner_id ON vehicles(owner_id);
CREATE INDEX idx_vehicles_status ON vehicles(status);
CREATE INDEX idx_vehicles_deleted_at ON vehicles(deleted_at);
