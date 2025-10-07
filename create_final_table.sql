-- Create final unified table from staging tables
-- Run this with: psql -d uk_osm_full -f create_final_table.sql

\echo '========================================='
\echo 'Creating Final Unified Table'
\echo '========================================='

-- Drop existing table
DROP TABLE IF EXISTS aerospace_supplier_candidates CASCADE;

-- Create final table
CREATE TABLE aerospace_supplier_candidates (
  id SERIAL PRIMARY KEY,
  osm_id BIGINT,
  source_table VARCHAR(50),
  name TEXT,
  operator TEXT,
  aerospace_score INTEGER,
  tier_classification VARCHAR(50),
  confidence_level VARCHAR(50),
  phone TEXT,
  email TEXT,
  website TEXT,
  postcode VARCHAR(20),
  street_address TEXT,
  city TEXT,
  landuse_type TEXT,
  building_type TEXT,
  industrial_type TEXT,
  office_type TEXT,
  description TEXT,
  matched_keywords TEXT[],
  tags_raw HSTORE,
  way GEOMETRY,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  geometry GEOMETRY,
  created_at TIMESTAMP DEFAULT NOW()
);

\echo 'Inserting from staging tables...'

-- Insert from polygon (highest priority)
INSERT INTO aerospace_supplier_candidates (
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
)
SELECT 
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
FROM aerospace_candidates_polygon;

\echo 'Inserted from polygon staging table'

-- Insert from point (exclude duplicates)
INSERT INTO aerospace_supplier_candidates (
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
)
SELECT 
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
FROM aerospace_candidates_point
WHERE osm_id NOT IN (SELECT osm_id FROM aerospace_candidates_polygon);

\echo 'Inserted from point staging table'

-- Insert from line (exclude duplicates)
INSERT INTO aerospace_supplier_candidates (
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
)
SELECT 
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
FROM aerospace_candidates_line
WHERE osm_id NOT IN (
  SELECT osm_id FROM aerospace_candidates_polygon 
  UNION 
  SELECT osm_id FROM aerospace_candidates_point
);

\echo 'Inserted from line staging table'

-- Insert from roads (exclude duplicates)
INSERT INTO aerospace_supplier_candidates (
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
)
SELECT 
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
FROM aerospace_candidates_roads
WHERE osm_id NOT IN (
  SELECT osm_id FROM aerospace_candidates_polygon 
  UNION 
  SELECT osm_id FROM aerospace_candidates_point
  UNION
  SELECT osm_id FROM aerospace_candidates_line
);

\echo 'Inserted from roads staging table'

-- Create indexes
CREATE INDEX idx_final_score ON aerospace_supplier_candidates(aerospace_score DESC);
CREATE INDEX idx_final_tier ON aerospace_supplier_candidates(tier_classification);
CREATE INDEX idx_final_confidence ON aerospace_supplier_candidates(confidence_level);
CREATE INDEX idx_final_postcode ON aerospace_supplier_candidates(postcode);
CREATE INDEX idx_final_source ON aerospace_supplier_candidates(source_table);
CREATE INDEX idx_final_geom ON aerospace_supplier_candidates USING GIST(geometry);

\echo 'Indexes created'

-- Add constraints
ALTER TABLE aerospace_supplier_candidates 
  ADD CONSTRAINT chk_score CHECK (aerospace_score >= 40),
  ADD CONSTRAINT chk_tier CHECK (tier_classification IN 
    ('tier1_candidate', 'tier2_candidate', 'potential_candidate', 'low_probability'));

\echo ''
\echo '========================================='
\echo 'FINAL RESULTS'
\echo '========================================='

-- Show summary
SELECT 
  'Total Candidates' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates

UNION ALL

SELECT 
  'From Polygon' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates
WHERE source_table = 'planet_osm_polygon'

UNION ALL

SELECT 
  'From Point' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates
WHERE source_table = 'planet_osm_point'

UNION ALL

SELECT 
  'From Line' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates
WHERE source_table = 'planet_osm_line'

UNION ALL

SELECT 
  'From Roads' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates
WHERE source_table = 'planet_osm_roads'

UNION ALL

SELECT 
  'Tier 2 or Better (≥80)' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 80

UNION ALL

SELECT 
  'Potential (40-79)' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 40 AND aerospace_score < 80;

\echo ''
\echo 'Top 20 Candidates:'
\echo '-------------------'

SELECT 
  ROW_NUMBER() OVER (ORDER BY aerospace_score DESC) as rank,
  LEFT(name, 45) as name,
  aerospace_score as score,
  tier_classification as tier,
  source_table as source,
  postcode
FROM aerospace_supplier_candidates
ORDER BY aerospace_score DESC
LIMIT 20;

\echo ''
\echo '✓ Complete!'