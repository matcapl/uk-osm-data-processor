#!/bin/bash
# Aerospace Scoring Pipeline - ROADS geometry
# Processes planet_osm_roads for aerospace supplier candidates
# Note: Roads table is primarily for routing, so we only capture very strong signals

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
echo -e "${BLUE}ROADS PIPELINE - Aerospace Scoring${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================================
# STEP 1: Create Filtered View
# ============================================================================
echo -e "${YELLOW}[STEP 1]${NC} Creating filtered view..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

DROP VIEW IF EXISTS planet_osm_roads_aerospace_filtered CASCADE;

CREATE VIEW planet_osm_roads_aerospace_filtered AS
SELECT *
FROM planet_osm_roads
WHERE 
  -- Only keep roads with explicit aerospace/industrial indicators
  (
    LOWER(COALESCE(name, '')) ~ '(aerospace|aviation|aircraft|airbus|boeing|rolls.royce|bae|industrial.estate|business.park|technology.park)'
    OR LOWER(COALESCE(operator, '')) ~ '(aerospace|aviation|aircraft)'
    OR aeroway IS NOT NULL
    OR landuse = 'industrial'
    OR industrial IS NOT NULL
    OR LOWER(COALESCE(tags::text, '')) ~ '(aerospace|aviation|aircraft|defense|defence)'
  )
  -- Exclude minor roads unless explicitly aerospace-named
  AND (
    highway IN ('primary', 'secondary', 'tertiary', 'unclassified', 'residential', 'service')
    OR LOWER(COALESCE(name, '')) ~ '(aerospace|aviation|aircraft)'
  );

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM planet_osm_roads_aerospace_filtered;")
echo -e "${GREEN}✓${NC} Filtered view created: $COUNT roads"
echo ""

# ============================================================================
# STEP 2: Create Scored View
# ============================================================================
echo -e "${YELLOW}[STEP 2]${NC} Creating scored view..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

DROP VIEW IF EXISTS planet_osm_roads_aerospace_scored CASCADE;

CREATE VIEW planet_osm_roads_aerospace_scored AS
SELECT 
  *,
  (
    -- AEROWAY: +120 (strong signal)
    CASE WHEN aeroway IS NOT NULL THEN 120 ELSE 0 END +
    
    -- DIRECT AEROSPACE IN NAME: +100
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(aerospace|aviation|aircraft)' THEN 100 ELSE 0 END +
    CASE WHEN LOWER(COALESCE(operator, '')) ~ '(aerospace|aviation)' THEN 100 ELSE 0 END +
    
    -- TIER-1 COMPANIES: +100
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(airbus|boeing|rolls.royce|bae.systems|leonardo|thales|safran)' THEN 100 ELSE 0 END +
    
    -- INDUSTRIAL/BUSINESS PARKS: +60
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(industrial.estate|business.park|technology.park|science.park)' THEN 60 ELSE 0 END +
    CASE WHEN landuse = 'industrial' THEN 60 ELSE 0 END +
    
    -- DEFENSE/MILITARY: +80
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(defense|defence|military|air.base|raf)' THEN 80 ELSE 0 END +
    CASE WHEN military IS NOT NULL THEN 80 ELSE 0 END +
    
    -- ENGINEERING/TECH: +50
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(engineering|technology|precision|advanced)' THEN 50 ELSE 0 END +
    CASE WHEN industrial IS NOT NULL THEN 50 ELSE 0 END +
    
    -- MANUFACTURING: +40
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(manufacturing|factory|works)' THEN 40 ELSE 0 END +
    CASE WHEN man_made IN ('works', 'factory') THEN 40 ELSE 0 END +
    
    -- UK AEROSPACE CLUSTERS: +20
    CASE WHEN "addr:postcode" ~ '^(BA|BS|GL|DE|PR|YO|CB|RG|SL|BH|SO)' THEN 20 ELSE 0 END +
    
    -- CONTACT/WEBSITE: +10
    CASE WHEN website IS NOT NULL THEN 10 ELSE 0 END +
    CASE WHEN tags ? 'phone' THEN 5 ELSE 0 END
    
  ) AS aerospace_score
FROM planet_osm_roads_aerospace_filtered
WHERE (
  name IS NOT NULL 
  OR aeroway IS NOT NULL 
  OR landuse = 'industrial'
  OR industrial IS NOT NULL
);

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM planet_osm_roads_aerospace_scored WHERE aerospace_score >= 40;")
echo -e "${GREEN}✓${NC} Scored view created: $COUNT candidates"
echo ""

# ============================================================================
# STEP 3: Create Staging Table & Insert
# ============================================================================
echo -e "${YELLOW}[STEP 3]${NC} Creating staging table and inserting..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

DROP TABLE IF EXISTS aerospace_candidates_roads CASCADE;

CREATE TABLE aerospace_candidates_roads (
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

INSERT INTO aerospace_candidates_roads (
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
)
SELECT 
  osm_id,
  'planet_osm_roads',
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
  NULL, -- roads typically don't have office type
  COALESCE(tags->'description', tags->'note'),
  ARRAY(
    SELECT kw FROM (VALUES ('aerospace'), ('aviation'), ('aircraft'), ('industrial'), 
                           ('business park'), ('technology'), ('aeroway')) AS t(kw)
    WHERE LOWER(COALESCE(name, '') || ' ' || COALESCE(tags::text, '')) LIKE '%' || kw || '%'
  ),
  tags,
  way,
  ST_Y(ST_Centroid(way)),
  ST_X(ST_Centroid(way)),
  way::geometry
FROM planet_osm_roads_aerospace_scored
WHERE aerospace_score >= 40
ORDER BY aerospace_score DESC;

CREATE INDEX IF NOT EXISTS idx_roads_score ON aerospace_candidates_roads(aerospace_score DESC);
CREATE INDEX IF NOT EXISTS idx_roads_tier ON aerospace_candidates_roads(tier_classification);
CREATE INDEX IF NOT EXISTS idx_roads_geom ON aerospace_candidates_roads USING GIST(geometry);

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_candidates_roads;")
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
FROM aerospace_candidates_roads
GROUP BY tier_classification
ORDER BY max_score DESC;

\echo ''
\echo 'Top 5 Roads Candidates:'
SELECT name, aerospace_score, landuse_type FROM aerospace_candidates_roads ORDER BY aerospace_score DESC LIMIT 5;
SQL

echo ""
echo -e "${GREEN}✓ ROADS PIPELINE COMPLETE${NC}"