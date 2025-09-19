-- Manual Database Setup for UK OSM Import (macOS)
-- Run these commands if automated setup fails

-- Create user (run as current user with superuser privileges)
CREATE USER a WITH CREATEDB;

-- Create database
CREATE DATABASE uk_osm_full OWNER a;

-- Connect to the new database
\c uk_osm_full

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Verify PostGIS
SELECT PostGIS_Full_Version();

-- Create schema
CREATE SCHEMA IF NOT EXISTS osm_raw;
SET search_path = osm_raw, public;

-- Optimize for import (session-level)
SET maintenance_work_mem = '2GB';
SET work_mem = '256MB';
SET synchronous_commit = off;
SET full_page_writes = off;
SET checkpoint_completion_target = 0.9;
SET wal_buffers = '16MB';

-- Disable autovacuum temporarily
ALTER DATABASE uk_osm_full SET autovacuum = off;

-- Test geometry operations
CREATE TABLE test_geom (id SERIAL PRIMARY KEY, geom GEOMETRY(POINT, 4326));
INSERT INTO test_geom (geom) VALUES (ST_GeomFromText('POINT(-2.2426 53.4808)', 4326)); -- Manchester
SELECT ST_AsText(geom) FROM test_geom;
DROP TABLE test_geom;

\echo 'Database setup complete!'
