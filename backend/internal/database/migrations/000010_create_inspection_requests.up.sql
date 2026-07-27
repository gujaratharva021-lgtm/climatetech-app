CREATE TABLE IF NOT EXISTS inspection_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    requester_id UUID NOT NULL,
    requester_role VARCHAR(10) NOT NULL,
    inspection_type VARCHAR(20) NOT NULL,
    notes VARCHAR(1000),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    inspector_id UUID,
    scheduled_date TIMESTAMPTZ,
    result VARCHAR(20),
    grade VARCHAR(50),
    report_notes VARCHAR(1000),
    report_file_url VARCHAR(500),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_inspection_requests_order_id ON inspection_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_inspection_requests_requester_id ON inspection_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_inspection_requests_status ON inspection_requests(status);
CREATE INDEX IF NOT EXISTS idx_inspection_requests_inspector_id ON inspection_requests(inspector_id);
CREATE INDEX IF NOT EXISTS idx_inspection_requests_deleted_at ON inspection_requests(deleted_at);