#!/bin/bash
# Aerospace Scoring Pipeline - LINE geometry
# Processes planet_osm_line for aerospace supplier candidates

set -e

DB_NAME="uk_osm_full"
DB_USER="a"
DB_HOST="localhost"
DB_PORT="5432"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}LINE PIPELINE - Aerospace Scoring${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================================
# STEP 1: Create Filtered View
# ============================================================================
echo -e "${YELLOW}[STEP 1]${NC} Creating filtered view..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

DROP VIEW IF EXISTS planet_osm_line_aerospace_filtered CASCADE;

CREATE VIEW planet_osm_line_aerospace_filtered AS
SELECT *
FROM planet_osm_line
WHERE 
  -- EXCLUDE roads, footpaths, railways (unless aerospace-related)
  (highway IS NULL OR highway NOT IN ('footway', 'cycleway', 'path', 'steps', 'pedestrian'))
  AND (railway IS NULL OR railway NOT IN ('abandoned', 'disused', 'station', 'halt'))
  AND (waterway IS NULL)
  AND (barrier IS NULL)
  AND (amenity IS NULL OR amenity NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'parking'))
  AND (leisure IS NULL)
  AND (tourism IS NULL)
  
  -- OVERRIDE: Keep aerospace/aeroway/industrial features
  OR (
    aeroway IS NOT NULL
    OR LOWER(COALESCE(name, '')) ~ '(aerospace|aviation|aircraft|airfield|runway|taxiway|apron)'
    OR LOWER(COALESCE(operator, '')) ~ '(aerospace|aviation|aircraft)'
    OR industrial IS NOT NULL
    OR landuse = 'industrial'
  );

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM planet_osm_line_aerospace_filtered;")
echo -e "${GREEN}✓${NC} Filtered view created: $COUNT lines"
echo ""

# ============================================================================
# STEP 2: Create Scored View
# ============================================================================
echo -e "${YELLOW}[STEP 2]${NC} Creating scored view..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

DROP VIEW IF EXISTS planet_osm_line_aerospace_scored CASCADE;

CREATE VIEW planet_osm_line_aerospace_scored AS
SELECT 
  *,
  (
    -- AEROWAY features: +100
    CASE WHEN aeroway IN ('runway', 'taxiway', 'apron') THEN 100 ELSE 0 END +
    CASE WHEN aeroway = 'aerodrome' THEN 80 ELSE 0 END +
    
    -- DIRECT AEROSPACE: +100
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(aerospace|aviation|aircraft|airfield)' THEN 100 ELSE 0 END +
    CASE WHEN LOWER(COALESCE(operator, '')) ~ '(aerospace|aviation|aircraft)' THEN 100 ELSE 0 END +
    
    -- TIER-1 COMPANIES: +100
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(airbus|boeing|rolls.royce|bae.systems|leonardo)' THEN 100 ELSE 0 END +
    
    -- DEFENSE/MILITARY: +80
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(defense|defence|military|air.base)' THEN 80 ELSE 0 END +
    CASE WHEN military IS NOT NULL THEN 80 ELSE 0 END +
    CASE WHEN landuse = 'military' THEN 80 ELSE 0 END +
    
    -- HIGH-TECH: +70
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(precision|technology|systems|engineering)' THEN 70 ELSE 0 END +
    CASE WHEN industrial IN ('engineering', 'electronics') THEN 70 ELSE 0 END +
    
    -- INDUSTRIAL: +50
    CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END +
    CASE WHEN industrial IS NOT NULL THEN 50 ELSE 0 END +
    CASE WHEN building IN ('industrial', 'warehouse') THEN 50 ELSE 0 END +
    
    -- MANUFACTURING: +40
    CASE WHEN man_made IN ('works', 'factory') THEN 40 ELSE 0 END +
    
    -- OFFICE/COMPANY: +30
    CASE WHEN office IN ('company', 'engineering', 'industrial') THEN 30 ELSE 0 END +
    
    -- UK AEROSPACE CLUSTERS: +20
    CASE WHEN "addr:postcode" ~ '^(BA|BS|GL|DE|PR|YO|CB|RG|SL)' THEN 20 ELSE 0 END +
    
    -- CONTACT INFO: +10
    CASE WHEN website IS NOT NULL THEN 10 ELSE 0 END +
    CASE WHEN tags ? 'phone' THEN 5 ELSE 0 END
    
  ) AS aerospace_score
FROM planet_osm_line_aerospace_filtered
WHERE (name IS NOT NULL OR aeroway IS NOT NULL OR industrial IS NOT NULL);

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM planet_osm_line_aerospace_scored WHERE aerospace_score >= 40;")
echo -e "${GREEN}✓${NC} Scored view created: $COUNT candidates"
echo ""

# ============================================================================
# STEP 3: Create Staging Table & Insert
# ============================================================================
echo -e "${YELLOW}[STEP 3]${NC} Creating staging table and inserting..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

DROP TABLE IF EXISTS aerospace_candidates_line CASCADE;

CREATE TABLE aerospace_candidates_line (
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

INSERT INTO aerospace_candidates_line (
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
)
SELECT 
  osm_id,
  'planet_osm_line',
  COALESCE(name, operator, tags->'brand'),
  operator,
  aerospace_score,
  CASE 
    WHEN aerospace_score >= 150 THEN 'tier1_candidate'
    WHEN aerospace_score >= 80 THEN 'tier2_candidate'
    WHEN aerospace_score >= 40 THEN 'potential_candidate'
    ELSE 'low_probability'
  END,
  CASE 
    WHEN aerospace_score >= 150 THEN 'high'
    WHEN aerospace_score >= 100 THEN 'medium-high'
    WHEN aerospace_score >= 70 THEN 'medium'
    ELSE 'low'
  END,
  tags->'phone',
  tags->'email',
  website,
  "addr:postcode",
  "addr:street",
  COALESCE("addr:city", tags->'addr:town'),
  landuse,
  building,
  industrial,
  office,
  COALESCE(tags->'description', tags->'note'),
  ARRAY(
    SELECT kw FROM (VALUES ('aerospace'), ('aviation'), ('aircraft'), ('runway'), 
                           ('aeroway'), ('industrial'), ('manufacturing')) AS t(kw)
    WHERE LOWER(COALESCE(name, '') || ' ' || COALESCE(tags::text, '')) LIKE '%' || kw || '%'
  ),
  tags,
  way,
  ST_Y(ST_Centroid(way)),
  ST_X(ST_Centroid(way)),
  way::geometry
FROM planet_osm_line_aerospace_scored
WHERE aerospace_score >= 40
ORDER BY aerospace_score DESC;

CREATE INDEX IF NOT EXISTS idx_line_score ON aerospace_candidates_line(aerospace_score DESC);
CREATE INDEX IF NOT EXISTS idx_line_tier ON aerospace_candidates_line(tier_classification);
CREATE INDEX IF NOT EXISTS idx_line_geom ON aerospace_candidates_line USING GIST(geometry);

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_candidates_line;")
echo -e "${GREEN}✓${NC} Inserted $COUNT candidates"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${YELLOW}[SUMMARY]${NC} Results"
echo "-------------------------------------------"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'
SELECT 
  tier_classification,
  COUNT(*) as count,
  MAX(aerospace_score) as max_score
FROM aerospace_candidates_line
GROUP BY tier_classification
ORDER BY max_score DESC;

\echo ''
\echo 'Top 5 Line Candidates:'
SELECT name, aerospace_score, landuse_type FROM aerospace_candidates_line ORDER BY aerospace_score DESC LIMIT 5;
SQL

echo ""
echo -e "${GREEN}✓ LINE PIPELINE COMPLETE${NC}"