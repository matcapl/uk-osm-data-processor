#!/bin/bash
# Master Pipeline Runner - Executes all four geometry pipelines and creates final table

set -e

DB_NAME="uk_osm_full"
DB_USER="a"
DB_HOST="localhost"
DB_PORT="5432"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}AEROSPACE SUPPLIER PIPELINE - MASTER EXECUTION${NC}"
echo -e "${CYAN}======================================================${NC}"
echo ""
echo "This will execute all four geometry pipelines sequentially:"
echo "  1. Polygon (buildings/facilities)"
echo "  2. Point (single locations)"
echo "  3. Line (linear features)"
echo "  4. Roads (named roads/industrial estates)"
echo ""
echo "Then combine into final aerospace_supplier_candidates table."
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

START_TIME=$(date +%s)

# ============================================================================
# STEP 1: Execute Polygon Pipeline
# ============================================================================
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}STEP 1/4: POLYGON PIPELINE${NC}"
echo -e "${BLUE}============================================${NC}"

if [ -f "07_pipeline_polygon.sh" ]; then
    bash 07_pipeline_polygon.sh
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Polygon pipeline completed"
    else
        echo -e "${RED}✗${NC} Polygon pipeline failed"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} 07_pipeline_polygon.sh not found"
    exit 1
fi

# ============================================================================
# STEP 2: Execute Point Pipeline
# ============================================================================
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}STEP 2/4: POINT PIPELINE${NC}"
echo -e "${BLUE}============================================${NC}"

if [ -f "07_pipeline_point.sh" ]; then
    bash 07_pipeline_point.sh
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Point pipeline completed"
    else
        echo -e "${RED}✗${NC} Point pipeline failed"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} 07_pipeline_point.sh not found"
    exit 1
fi

# ============================================================================
# STEP 3: Execute Line Pipeline
# ============================================================================
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}STEP 3/4: LINE PIPELINE${NC}"
echo -e "${BLUE}============================================${NC}"

if [ -f "07_pipeline_line.sh" ]; then
    bash 07_pipeline_line.sh
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Line pipeline completed"
    else
        echo -e "${RED}✗${NC} Line pipeline failed"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} 07_pipeline_line.sh not found"
    exit 1
fi

# ============================================================================
# STEP 4: Execute Roads Pipeline
# ============================================================================
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}STEP 4/4: ROADS PIPELINE${NC}"
echo -e "${BLUE}============================================${NC}"

if [ -f "07_pipeline_roads.sh" ]; then
    bash 07_pipeline_roads.sh
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Roads pipeline completed"
    else
        echo -e "${RED}✗${NC} Roads pipeline failed"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} 07_pipeline_roads.sh not found"
    exit 1
fi

# ============================================================================
# STEP 5: Create Final Unified Table
# ============================================================================
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}STEP 5: CREATE FINAL TABLE${NC}"
echo -e "${BLUE}============================================${NC}"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

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
  postcode VARCHAR(50),
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

-- Create indexes
CREATE INDEX idx_final_score ON aerospace_supplier_candidates(aerospace_score DESC);
CREATE INDEX idx_final_tier ON aerospace_supplier_candidates(tier_classification);
CREATE INDEX idx_final_confidence ON aerospace_supplier_candidates(confidence_level);
CREATE INDEX idx_final_postcode ON aerospace_supplier_candidates(postcode);
CREATE INDEX idx_final_source ON aerospace_supplier_candidates(source_table);
CREATE INDEX idx_final_geom ON aerospace_supplier_candidates USING GIST(geometry);

-- Add constraints
ALTER TABLE aerospace_supplier_candidates 
  ADD CONSTRAINT chk_score CHECK (aerospace_score >= 40),
  ADD CONSTRAINT chk_tier CHECK (tier_classification IN 
    ('tier1_candidate', 'tier2_candidate', 'potential_candidate', 'low_probability'));

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

SQL

echo -e "${GREEN}✓${NC} Final table created"
echo ""

# ============================================================================
# STEP 6: Generate Comprehensive Report
# ============================================================================
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}STEP 6: FINAL REPORT${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

\echo '========================================='
\echo 'OVERALL STATISTICS'
\echo '========================================='

SELECT 
  'Total Candidates' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates

UNION ALL

SELECT 
  'Tier 1 (≥150)' as metric,
  COUNT(*)::text || ' candidates' as value
FROM aerospace_supplier_candidates
WHERE tier_classification = 'tier1_candidate'

UNION ALL

SELECT 
  'Tier 2 (80-149)' as metric,
  COUNT(*)::text || ' candidates' as value
FROM aerospace_supplier_candidates
WHERE tier_classification = 'tier2_candidate'

UNION ALL

SELECT 
  'Potential (40-79)' as metric,
  COUNT(*)::text || ' candidates' as value
FROM aerospace_supplier_candidates
WHERE tier_classification = 'potential_candidate'

UNION ALL

SELECT 
  'With Website' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates
WHERE website IS NOT NULL

UNION ALL

SELECT 
  'With Phone' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates
WHERE phone IS NOT NULL

UNION ALL

SELECT 
  'High Confidence' as metric,
  COUNT(*)::text as value
FROM aerospace_supplier_candidates
WHERE confidence_level = 'high';

\echo ''
\echo '========================================='
\echo 'BREAKDOWN BY SOURCE TABLE'
\echo '========================================='

SELECT 
  source_table,
  COUNT(*) as candidates,
  COUNT(*) FILTER (WHERE tier_classification = 'tier1_candidate') as tier1,
  COUNT(*) FILTER (WHERE tier_classification = 'tier2_candidate') as tier2,
  ROUND(AVG(aerospace_score)) as avg_score
FROM aerospace_supplier_candidates
GROUP BY source_table
ORDER BY candidates DESC;

\echo ''
\echo '========================================='
\echo 'TOP 20 CANDIDATES (ALL TIERS)'
\echo '========================================='

SELECT 
  ROW_NUMBER() OVER (ORDER BY aerospace_score DESC) as rank,
  LEFT(name, 40) as name,
  aerospace_score as score,
  tier_classification as tier,
  source_table as source,
  postcode,
  LEFT(city, 20) as city
FROM aerospace_supplier_candidates
ORDER BY aerospace_score DESC
LIMIT 20;

\echo ''
\echo '========================================='
\echo 'GEOGRAPHIC DISTRIBUTION (TOP REGIONS)'
\echo '========================================='

SELECT 
  LEFT(postcode, 2) as region,
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE tier_classification = 'tier1_candidate') as tier1,
  COUNT(*) FILTER (WHERE tier_classification = 'tier2_candidate') as tier2,
  ROUND(AVG(aerospace_score)) as avg_score
FROM aerospace_supplier_candidates
WHERE postcode IS NOT NULL
GROUP BY region
ORDER BY total DESC
LIMIT 15;

\echo ''
\echo '========================================='
\echo 'SCORE DISTRIBUTION'
\echo '========================================='

SELECT 
  CASE 
    WHEN aerospace_score >= 200 THEN '200+'
    WHEN aerospace_score >= 150 THEN '150-199'
    WHEN aerospace_score >= 100 THEN '100-149'
    WHEN aerospace_score >= 80 THEN '80-99'
    WHEN aerospace_score >= 60 THEN '60-79'
    WHEN aerospace_score >= 40 THEN '40-59'
    ELSE 'Below 40'
  END as score_range,
  COUNT(*) as count
FROM aerospace_supplier_candidates
GROUP BY score_range
ORDER BY MIN(aerospace_score) DESC;

SQL

# ============================================================================
# Completion Summary
# ============================================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}✓ PIPELINE EXECUTION COMPLETE${NC}"
echo -e "${CYAN}======================================================${NC}"
echo ""
echo -e "${GREEN}Execution time: ${MINUTES}m ${SECONDS}s${NC}"
echo ""
echo "Results stored in: aerospace_supplier_candidates"
echo ""
echo "Next steps:"
echo "  1. Review candidates: psql -d $DB_NAME"
echo "  2. Export to CSV: Run export script"
echo "  3. Validate results: bash test_aerospace_pipelines.sh"
echo ""

# Optional Clean-up
# -- Drop filtered/scored views (regenerate anytime)

# psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

# DROP VIEW planet_osm_polygon_aerospace_filtered CASCADE;
# DROP VIEW planet_osm_polygon_aerospace_scored CASCADE;
# DROP VIEW planet_osm_point_aerospace_filtered CASCADE;
# DROP VIEW planet_osm_point_aerospace_scored CASCADE;
# DROP VIEW planet_osm_line_aerospace_filtered CASCADE;
# DROP VIEW planet_osm_line_aerospace_scored CASCADE;
# DROP VIEW planet_osm_roads_aerospace_filtered CASCADE;
# DROP VIEW planet_osm_roads_aerospace_scored CASCADE;

# SQL

# -- Keep nodes/ways ONLY if doing custom OSM analysis
# -- Otherwise delete to save 19GB:
# DROP TABLE planet_osm_nodes CASCADE;
# DROP TABLE planet_osm_ways CASCADE;
# DROP TABLE planet_osm_rels CASCADE;