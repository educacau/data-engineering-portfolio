-- Initialize NiFi Registry database
-- This script creates the database and schema for NiFi Registry

-- Create database for NiFi Registry
CREATE DATABASE nifi_registry;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE nifi_registry TO iceberg;

-- Connect to nifi_registry database
\c nifi_registry;

-- Create schema for NiFi Registry
CREATE SCHEMA IF NOT EXISTS nifi_registry;

-- Grant privileges on schema
GRANT ALL ON SCHEMA nifi_registry TO iceberg;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA nifi_registry GRANT ALL ON TABLES TO iceberg;
ALTER DEFAULT PRIVILEGES IN SCHEMA nifi_registry GRANT ALL ON SEQUENCES TO iceberg;

-- Log initialization
SELECT 'NiFi Registry database initialized successfully' AS status;
