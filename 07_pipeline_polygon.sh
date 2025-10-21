#!/bin/bash
# Aerospace Scoring Pipeline - POLYGON geometry
# Processes planet_osm_polygon for aerospace supplier candidates

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
echo -e "${BLUE}POLYGON PIPELINE - Aerospace Scoring${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# ============================================================================
# STEP 1: Create Filtered View (Exclusions)
# ============================================================================
echo -e "${YELLOW}[STEP 1]${NC} Creating filtered view..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

-- Drop existing view
DROP VIEW IF EXISTS planet_osm_polygon_aerospace_filtered CASCADE;

-- Create filtered view with exclusions
CREATE VIEW planet_osm_polygon_aerospace_filtered AS
SELECT *
FROM planet_osm_polygon
WHERE 
  -- EXCLUDE residential/retail/leisure
  (amenity IS NULL OR amenity NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 
                                       'school', 'hospital', 'bank', 'pharmacy', 'fuel', 
                                       'parking', 'place_of_worship', 'library', 'hotel', 'inn', 'hall', 'village'))
  AND (shop IS NULL)
  AND (tourism IS NULL)
  AND (leisure IS NULL OR leisure NOT IN ('park', 'playground', 'sports_centre', 
                                           'swimming_pool', 'golf_course'))
  AND (building IS NULL OR building NOT IN ('house', 'apartments', 'residential', 
                                             'hotel', 'retail', 'supermarket'))
  AND (landuse IS NULL OR landuse NOT IN ('residential', 'retail', 'farmland', 
                                           'forest', 'meadow', 'quarry'))
  
  -- OVERRIDE: Keep if aerospace keywords present (even if excluded above)
  OR (
    LOWER(COALESCE(name, '')) ~ '(aerospace|airbus|boeing|bae.systems|safran|aero)'
    OR LOWER(COALESCE(operator, '')) ~ '(aerospace|aero)'
    OR LOWER(COALESCE(tags::text, '')) ~ '(aerospace)'
  );

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM planet_osm_polygon_aerospace_filtered;")
echo -e "${GREEN}✓${NC} Filtered view created: $COUNT polygons"
echo ""

# ============================================================================
# STEP 2: Create Scored View (Aerospace Scoring)
# ============================================================================
echo -e "${YELLOW}[STEP 2]${NC} Creating scored view with aerospace relevance..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

-- Drop existing view
DROP VIEW IF EXISTS planet_osm_polygon_aerospace_scored CASCADE;

-- Create scored view with comprehensive aerospace scoring
CREATE VIEW planet_osm_polygon_aerospace_scored AS
SELECT 
  *,
  (
    -- DIRECT AEROSPACE: +100 points
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(aerospace|avionics|aero)' THEN 100 ELSE 0 END +
    CASE WHEN LOWER(COALESCE(operator, '')) ~ '(aerospace|aero)' THEN 100 ELSE 0 END +
    CASE WHEN LOWER(COALESCE(tags::text, '')) ~ 'aerospace' THEN 100 ELSE 0 END +
    
    -- TIER-1 COMPANIES: +100 points
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(airbus|boeing|rolls.royce|bae.systems|thales|safran|gkn|meggitt|cobham|itp.aero)' THEN 100 ELSE 0 END +

    -- TIER-1 OEM & SUPPLIER COMPANIES: +100 points
    CASE WHEN LOWER(COALESCE(name, '')) ~ 
      '(airbus|boeing|lockheed.martin|bae.systems|rolls.royce|rtx|raytheon|collins.aerospace|pratt.whitney|ge.aviation|ge.aerospace|safran|thales|leonardo|northrop.grumman|general.dynamics|honeywell|gkn.aerospace|spirit.aerosystems|meggitt|cobham|itp.aero|parker.hannifin|moog|senior.aerospace|marshall.aerospace|precision.castparts|pcc|triumph.group|woodward|eaton.aerospace|liebherr.aerospace|aar.corp|magellan.aerospace|martin.baker|ultra.electronics|elbit.systems|babcock.international|qinetiq|short.brothers|bombardier|dowty|messier.dowty|westland|agustawestland|transdigm|howmet.aerospace|l3harris|curtiss.wright|crane.aerospace|textron|huntington.ingalls|aerovironment|embraer|cae|standardaero|hexcel|mercury.systems|planet.labs|vse.corp|intuitive.machines|astronics|ducommun|mitsubishi.heavy|sikorsky|gulfstream|bell.textron|mtu.aero|goodrich|eurofighter|cfm.international|general.electric|itp.aero|aim.altitude|sl.engineering|automatic.industrial.machines|general.engineering.treatments)' 
    THEN 100 ELSE 0 END +

    -- MAJOR AIRCRAFT PROGRAMME NAMES: +50 points
    CASE WHEN LOWER(COALESCE(name, '')) ~ 
      '(737.max|787.dreamliner|777x|a320.neo|a350.xwb|a330.neo|f.35|f.22|eurofighter|typhoon|trent.xwb|trent.1000|trent.7000|leap.engine|ge9x|kc.46|ch.47.chinook|p.8.poseidon|a400m|h160|f.15ex|hawk.trainer|type.26|global.hawk|james.webb|stryker|b.21.raider)'
    THEN 50 ELSE 0 END +

    -- DEFENSE/MILITARY: +50 points
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(defense|defence|military|radar|missile|weapons|ballistic)' THEN 50 ELSE 0 END +
    CASE WHEN military IS NOT NULL THEN 50 ELSE 0 END +
    CASE WHEN landuse = 'military' THEN 50 ELSE 0 END +
    
    -- HIGH-TECH MANUFACTURING: +70 points
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(precision|advanced|technology|systems|electronics|engineering|manufacturing|CNC)' THEN 70 ELSE 0 END +
    CASE WHEN industrial IN ('engineering', 'electronics', 'precision', 'high_tech') THEN 70 ELSE 0 END +
    CASE WHEN office IN ('engineering', 'research', 'technology') THEN 70 ELSE 0 END +
    
    -- RESEARCH & DEVELOPMENT: +5 points
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(research|development|laboratory|r&d|institute)' THEN 5 ELSE 0 END +
    CASE WHEN office = 'research' THEN 5 ELSE 0 END +
    CASE WHEN amenity IN ('research_institute', 'university') THEN 5 ELSE 0 END +
    
    -- MANUFACTURING KEYWORDS: +50 points
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(machining|casting|forging|composite|materials|fabrication|tooling)' THEN 50 ELSE 0 END +
    CASE WHEN man_made IN ('works', 'factory') THEN 50 ELSE 0 END +
    
    -- GENERAL MANUFACTURING: +40 points
    CASE WHEN landuse = 'industrial' THEN 40 ELSE 0 END +
    CASE WHEN building IN ('industrial', 'warehouse', 'manufacture', 'factory') THEN 40 ELSE 0 END +
    CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END +
    
    -- ENGINEERING/TECHNICAL: +30 points
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(engineering|technical|specialist)' THEN 30 ELSE 0 END +
    CASE WHEN office IN ('company', 'industrial') THEN 30 ELSE 0 END +
    
    -- UK AEROSPACE CLUSTERS: +20 points (based on postcode area)
    CASE WHEN "addr:postcode" ~ '^(BA|BS|GL|DE|PR|YO|CB|RG|SL|BH|SO)' THEN 20 ELSE 0 END +
    
    -- CONTACT INFO PRESENT: +10 points
    CASE WHEN website IS NOT NULL THEN 10 ELSE 0 END +
    CASE WHEN tags ? 'phone' OR tags ? 'contact:phone' THEN 10 ELSE 0 END +
    CASE WHEN tags ? 'email' OR tags ? 'contact:email' THEN 5 ELSE 0 END
    
    -- PENALTY for non-supplier keywords: -80 points
    - CASE WHEN LOWER(COALESCE(name, '') || ' ' || COALESCE(tags::text, '')) 
            ~ '(aerobic|anaerobic|club|laboratory)' THEN 80 ELSE 0 END
     
  ) AS aerospace_score
FROM planet_osm_polygon_aerospace_filtered
WHERE 
  -- Must have a name or operator
  (name IS NOT NULL OR operator IS NOT NULL OR "addr:postcode" IS NOT NULL)
  -- Exclude tiny polygons (likely errors)
  AND ST_Area(way) > 50;

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM planet_osm_polygon_aerospace_scored WHERE aerospace_score >= 40;")
echo -e "${GREEN}✓${NC} Scored view created: $COUNT candidates (score ≥40)"
echo ""

# ============================================================================
# STEP 3: Create Staging Table
# ============================================================================
echo -e "${YELLOW}[STEP 3]${NC} Creating staging table..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

-- Drop existing table
DROP TABLE IF EXISTS aerospace_candidates_polygon CASCADE;

-- Create staging table with complete schema
CREATE TABLE aerospace_candidates_polygon (
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

SQL

echo -e "${GREEN}✓${NC} Staging table created"
echo ""

# ============================================================================
# STEP 4: Insert Scored Candidates
# ============================================================================
echo -e "${YELLOW}[STEP 4]${NC} Inserting candidates into staging table..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

INSERT INTO aerospace_candidates_polygon (
  osm_id,
  source_table,
  name,
  operator,
  aerospace_score,
  tier_classification,
  confidence_level,
  phone,
  email,
  website,
  postcode,
  street_address,
  city,
  landuse_type,
  building_type,
  industrial_type,
  office_type,
  description,
  matched_keywords,
  tags_raw,
  way,
  latitude,
  longitude,
  geometry
)
SELECT 
  osm_id,
  'planet_osm_polygon' as source_table,
  COALESCE(name, operator, tags->'brand') as name,
  operator,
  aerospace_score,
  -- Tier classification
  CASE 
    WHEN aerospace_score >= 150 THEN 'tier1_candidate'
    WHEN aerospace_score >= 80 THEN 'tier2_candidate'
    WHEN aerospace_score >= 40 THEN 'potential_candidate'
    ELSE 'low_probability'
  END as tier_classification,
  -- Confidence level
  CASE 
    WHEN aerospace_score >= 150 THEN 'high'
    WHEN aerospace_score >= 100 THEN 'medium-high'
    WHEN aerospace_score >= 70 THEN 'medium'
    ELSE 'low'
  END as confidence_level,
  -- Contact information
  tags->'phone' as phone,
  tags->'email' as email,
  website,
  -- Address
  "addr:postcode" as postcode,
  "addr:street" as street_address,
  COALESCE("addr:city", tags->'addr:town') as city,
  -- Classification
  landuse as landuse_type,
  building as building_type,
  COALESCE(industrial, tags->'craft') as industrial_type,
  office as office_type,
  COALESCE(tags->'description', tags->'note') as description,
  -- Matched keywords
  ARRAY(
    SELECT keyword FROM (VALUES 
      ('aerospace'), ('aviation'), ('aircraft'), ('defense'), ('defence'),
      ('precision'), ('engineering'), ('manufacturing'), ('industrial')
    ) AS kw(keyword)
    WHERE LOWER(COALESCE(name, '') || ' ' || COALESCE(operator, '') || ' ' || COALESCE(tags::text, '')) LIKE '%' || keyword || '%'
  ) as matched_keywords,
  tags as tags_raw,
  way,
  ST_Y(ST_Centroid(way)) as latitude,
  ST_X(ST_Centroid(way)) as longitude,
  way::geometry as geometry
FROM planet_osm_polygon_aerospace_scored
WHERE aerospace_score >= 40
ORDER BY aerospace_score DESC;

SQL

COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_candidates_polygon;")
echo -e "${GREEN}✓${NC} Inserted $COUNT candidates"
echo ""

# ============================================================================
# STEP 5: Create Indexes
# ============================================================================
echo -e "${YELLOW}[STEP 5]${NC} Creating indexes..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

CREATE INDEX IF NOT EXISTS idx_polygon_score ON aerospace_candidates_polygon(aerospace_score DESC);
CREATE INDEX IF NOT EXISTS idx_polygon_tier ON aerospace_candidates_polygon(tier_classification);
CREATE INDEX IF NOT EXISTS idx_polygon_postcode ON aerospace_candidates_polygon(postcode);
CREATE INDEX IF NOT EXISTS idx_polygon_geom ON aerospace_candidates_polygon USING GIST(geometry);

SQL

echo -e "${GREEN}✓${NC} Indexes created"
echo ""

# ============================================================================
# STEP 6: Summary Report
# ============================================================================
echo -e "${YELLOW}[STEP 6]${NC} Summary report"
echo "-------------------------------------------"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

-- Overall statistics
SELECT 
  'Total Candidates' as metric,
  COUNT(*)::text as value
FROM aerospace_candidates_polygon

UNION ALL

SELECT 
  'Tier 1 (≥150)' as metric,
  COUNT(*)::text as value
FROM aerospace_candidates_polygon
WHERE tier_classification = 'tier1_candidate'

UNION ALL

SELECT 
  'Tier 2 (80-149)' as metric,
  COUNT(*)::text as value
FROM aerospace_candidates_polygon
WHERE tier_classification = 'tier2_candidate'

UNION ALL

SELECT 
  'Potential (40-79)' as metric,
  COUNT(*)::text as value
FROM aerospace_candidates_polygon
WHERE tier_classification = 'potential_candidate'

UNION ALL

SELECT 
  'With Contact Info' as metric,
  COUNT(*)::text as value
FROM aerospace_candidates_polygon
WHERE website IS NOT NULL OR phone IS NOT NULL;

-- Top 10 candidates
\echo ''
\echo 'Top 10 Candidates (Polygon):'
\echo '-------------------------------------------'

SELECT 
  LEFT(name, 50) as name,
  aerospace_score as score,
  tier_classification as tier,
  postcode,
  city
FROM aerospace_candidates_polygon
ORDER BY aerospace_score DESC
LIMIT 10;

-- Regional distribution
\echo ''
\echo 'Top Regions:'
\echo '-------------------------------------------'

SELECT 
  LEFT(postcode, 2) as region,
  COUNT(*) as count,
  ROUND(AVG(aerospace_score)) as avg_score
FROM aerospace_candidates_polygon
WHERE postcode IS NOT NULL
GROUP BY region
ORDER BY count DESC
LIMIT 10;

SQL

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ POLYGON PIPELINE COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"