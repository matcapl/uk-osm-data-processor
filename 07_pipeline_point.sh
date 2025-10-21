#!/bin/bash
# Aerospace Scoring Pipeline - POINT geometry
# Processes planet_osm_point for aerospace supplier candidates

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
echo -e "${BLUE}POINT PIPELINE - Aerospace Scoring${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================================
# STEP 1: Create Filtered View (Exclusions)
# ============================================================================
echo -e "${YELLOW}[STEP 1]${NC} Creating filtered view..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

DROP VIEW IF EXISTS planet_osm_point_aerospace_filtered CASCADE;

CREATE VIEW planet_osm_point_aerospace_filtered AS
SELECT *
FROM planet_osm_point
WHERE 
  -- EXCLUDE consumer amenities
  (amenity IS NULL OR amenity NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 
                                       'school', 'hospital', 'bank', 'pharmacy', 'fuel', 
                                       'parking', 'atm', 'post_box', 'telephone', 'bench', 'hotel', 'inn', 'hall'))
  AND (shop IS NULL)
  AND (tourism IS NULL)
  AND (leisure IS NULL)
  AND (highway IS NULL OR highway NOT IN ('bus_stop', 'crossing', 'traffic_signals'))
  
  -- OVERRIDE: Keep aerospace/defense keywords
  OR (
    LOWER(COALESCE(name, '')) ~ '(aerospace|aircraft|airbus|boeing|rolls.royce|bae.systems|thales|safran)'
    OR LOWER(COALESCE(operator, '')) ~ '(aerospace)'
    OR LOWER(COALESCE(tags::text, '')) ~ '(aerospace)'
  );

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM planet_osm_point_aerospace_filtered;")
echo -e "${GREEN}✓${NC} Filtered view created: $COUNT points"
echo ""

# ============================================================================
# STEP 2: Create Scored View
# ============================================================================
echo -e "${YELLOW}[STEP 2]${NC} Creating scored view..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

DROP VIEW IF EXISTS planet_osm_point_aerospace_scored CASCADE;

CREATE VIEW planet_osm_point_aerospace_scored AS
SELECT 
  *,
  (
    -- DIRECT AEROSPACE: +100
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(aerospace|avionics|aero)' THEN 100 ELSE 0 END +
    CASE WHEN LOWER(COALESCE(operator, '')) ~ '(aerospace|aero)' THEN 100 ELSE 0 END +
    
    -- TIER-1 COMPANIES: +100
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(airbus|boeing|rolls.royce|bae.systems|leonardo|thales|safran|gkn|meggitt|cobham|moog|parker.hannifin)' THEN 100 ELSE 0 END +
    CASE WHEN LOWER(COALESCE(operator, '')) ~ '(airbus|boeing|rolls.royce|bae.systems|leonardo|thales|safran|gkn|meggitt|cobham|moog|parker.hannifin|itp.aero|marshall.aerospace)' THEN 100 ELSE 0 END +

    -- DEFENSE/MILITARY: +20
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(defense|defence|military|radar|missile|weapons)' THEN 20 ELSE 0 END +
    CASE WHEN military IS NOT NULL THEN 20 ELSE 0 END +
    
    -- HIGH-TECH: +70
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(precision|advanced|technology|systems|electronics|engineering|manufacturing)' THEN 70 ELSE 0 END +
    CASE WHEN office IN ('engineering', 'research', 'technology', 'it') THEN 70 ELSE 0 END +
    
    -- RESEARCH: +60
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(research|development|laboratory|r&d|institute|university)' THEN 60 ELSE 0 END +
    CASE WHEN amenity IN ('research_institute', 'university', 'college') THEN 60 ELSE 0 END +
    
    -- MANUFACTURING KEYWORDS: +50
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(machining|casting|forging|composite|materials|fabrication|CNC)' THEN 50 ELSE 0 END +
    CASE WHEN man_made IN ('works', 'factory', 'crane') THEN 50 ELSE 0 END +
    
    -- INDUSTRIAL: +40
    CASE WHEN landuse = 'industrial' THEN 40 ELSE 0 END +
    CASE WHEN man_made IS NOT NULL THEN 30 ELSE 0 END +
    
    -- ENGINEERING: +30
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(engineering|technical)' THEN 30 ELSE 0 END +
    CASE WHEN office IN ('company', 'industrial') THEN 30 ELSE 0 END +
    
    -- UK AEROSPACE CLUSTERS: +20
    CASE WHEN "addr:postcode" ~ '^(BA|BS|GL|DE|PR|YO|CB|RG|SL|BH|SO)' THEN 20 ELSE 0 END +
    
    -- CONTACT INFO: +10
    CASE WHEN website IS NOT NULL THEN 10 ELSE 0 END +
    CASE WHEN tags ? 'phone' THEN 10 ELSE 0 END +
    CASE WHEN tags ? 'email' THEN 5 ELSE 0 END

    -- PENALTY for non-supplier keywords: -80 points
    - CASE WHEN LOWER(COALESCE(name, '') || ' ' || COALESCE(tags::text, '')) 
            ~ '(aerobic|anaerobic|club|laboratory)' THEN 80 ELSE 0 END

  ) AS aerospace_score
FROM planet_osm_point_aerospace_filtered
WHERE (name IS NOT NULL OR operator IS NOT NULL);

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM planet_osm_point_aerospace_scored WHERE aerospace_score >= 40;")
echo -e "${GREEN}✓${NC} Scored view created: $COUNT candidates"
echo ""

# ============================================================================
# STEP 3: Create Staging Table & Insert
# ============================================================================
echo -e "${YELLOW}[STEP 3]${NC} Creating staging table and inserting..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

DROP TABLE IF EXISTS aerospace_candidates_point CASCADE;

CREATE TABLE aerospace_candidates_point (
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

INSERT INTO aerospace_candidates_point (
  osm_id, source_table, name, operator, aerospace_score, tier_classification,
  confidence_level, phone, email, website, postcode, street_address, city,
  landuse_type, building_type, industrial_type, office_type, description,
  matched_keywords, tags_raw, way, latitude, longitude, geometry
)
SELECT 
  osm_id,
  'planet_osm_point',
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
  NULL, -- points don't have building type
  tags->'craft',
  office,
  COALESCE(tags->'description', tags->'note'),
  ARRAY(
    SELECT kw FROM (VALUES ('aerospace'), ('aviation'), ('aircraft'), ('defense'), 
                           ('precision'), ('engineering'), ('manufacturing')) AS t(kw)
    WHERE LOWER(COALESCE(name, '') || ' ' || COALESCE(tags::text, '')) LIKE '%' || kw || '%'
  ),
  tags,
  way,
  ST_Y(way),
  ST_X(way),
  way::geometry
FROM planet_osm_point_aerospace_scored
WHERE aerospace_score >= 40
ORDER BY aerospace_score DESC;

CREATE INDEX IF NOT EXISTS idx_point_score ON aerospace_candidates_point(aerospace_score DESC);
CREATE INDEX IF NOT EXISTS idx_point_tier ON aerospace_candidates_point(tier_classification);
CREATE INDEX IF NOT EXISTS idx_point_geom ON aerospace_candidates_point USING GIST(geometry);

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_candidates_point;")
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
  MIN(aerospace_score) as min_score,
  MAX(aerospace_score) as max_score
FROM aerospace_candidates_point
GROUP BY tier_classification
ORDER BY min_score DESC;

\echo ''
\echo 'Top 5 Point Candidates:'
SELECT name, aerospace_score, postcode FROM aerospace_candidates_point ORDER BY aerospace_score DESC LIMIT 5;
SQL

echo ""
echo -e "${GREEN}✓ POINT PIPELINE COMPLETE${NC}"