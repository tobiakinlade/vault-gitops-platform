-- Initialize Tax Calculator Database
-- This script runs automatically when PostgreSQL container starts

\c taxcalc;

-- Grant schema permissions first (before creating objects)
GRANT USAGE ON SCHEMA public TO PUBLIC;
GRANT CREATE ON SCHEMA public TO PUBLIC;

-- Create tax_calculations table
CREATE TABLE IF NOT EXISTS tax_calculations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    income DECIMAL(12,2) NOT NULL,
    income_tax DECIMAL(12,2) NOT NULL,
    ni_contribution DECIMAL(12,2) NOT NULL,
    take_home DECIMAL(12,2) NOT NULL,
    encrypted_ni TEXT NOT NULL,
    tax_year VARCHAR(20) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_tax_calculations_created_at 
    ON tax_calculations(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tax_calculations_tax_year 
    ON tax_calculations(tax_year);

-- Grant full permissions on the table to PUBLIC (includes Vault dynamic roles)
GRANT SELECT, INSERT, UPDATE, DELETE ON tax_calculations TO PUBLIC;

-- Grant permissions on sequences (for UUID generation)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO PUBLIC;

-- Set default privileges for any future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO PUBLIC;

-- Insert some sample data for testing (optional)
INSERT INTO tax_calculations (income, income_tax, ni_contribution, take_home, encrypted_ni, tax_year) 
VALUES 
    (20000.00, 1486.00, 892.00, 17622.00, 'sample:v1:encrypted_data_1', '2024/2025'),
    (30000.00, 3486.00, 2092.00, 24422.00, 'sample:v1:encrypted_data_2', '2024/2025'),
    (50000.00, 7486.00, 4504.00, 38010.00, 'sample:v1:encrypted_data_3', '2024/2025')
ON CONFLICT DO NOTHING;

-- Display status
\echo 'Database initialization complete!'
\echo 'Tables created: tax_calculations'
\echo 'Permissions granted: SELECT, INSERT, UPDATE, DELETE to PUBLIC'
\echo 'Sample data inserted: 3 records'
