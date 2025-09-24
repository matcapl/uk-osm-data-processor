#!/bin/bash
# diagnostic_test.sh - Test individual components of aerospace scoring - FIXED

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Aerospace Pipeline Diagnostic Test ===${NC}"

# Step 1: Test database connection and schema detection
echo -e "${YELLOW}Step 1: Testing database connection...${NC}"
if psql -d uk_osm_full -c "SELECT current_schema(), version();" 2>/dev/null; then
    echo -e "${GREEN}✓ Database connection works${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    exit 1
fi

ACTUAL_SCHEMA="public"  # We know it's public from the diagnostic

# Step 2: Check what columns actually exist
echo -e "${YELLOW}Step 2: Checking available columns...${NC}"
echo "Columns in planet_osm_point:"
psql -d uk_osm_full -c "
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema='public' AND table_name='planet_osm_point' 
  AND column_name IN ('name', 'amenity', 'building', 'landuse', 'industrial', 'office', 'man_made', 'shop', 'tourism')
ORDER BY column_name;
"

echo "Columns in planet_osm_polygon:"
psql -d uk_osm_full -c "
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema='public' AND table_name='planet_osm_polygon' 
  AND column_name IN ('name', 'amenity', 'building', 'landuse', 'industrial', 'office', 'man_made')
ORDER BY column_name;
"

# Step 3: Row counts
echo -e "${YELLOW}Step 3: Checking row counts...${NC}"
psql -d uk_osm_full -c "
SELECT 
    'planet_osm_point' as table_name, count(*) as rows
FROM public.planet_osm_point
UNION ALL
SELECT 
    'planet_osm_polygon', count(*)
FROM public.planet_osm_polygon
ORDER BY table_name;
"

# Step 4: Test for aerospace-relevant data (column-safe)
echo -e "${YELLOW}Step 4: Checking for aerospace-relevant data...${NC}"
echo "Industrial facilities in polygons:"
psql -d uk_osm_full -c "
SELECT COUNT(*) as industrial_count
FROM public.planet_osm_polygon 
WHERE landuse = 'industrial' OR building IN ('industrial', 'warehouse', 'factory');
"

echo "Facilities with aerospace-related names in points (safe query):"
psql -d uk_osm_full -c "
SELECT name, amenity, landuse
FROM public.planet_osm_point 
WHERE name IS NOT NULL 
  AND (LOWER(name) LIKE '%aerospace%' 
       OR LOWER(name) LIKE '%aviation%'
       OR LOWER(name) LIKE '%aircraft%'
       OR LOWER(name) LIKE '%engineering%'
       OR LOWER(name) LIKE '%technology%')
LIMIT 5;
"

# Step 5: Test what data we can actually work with
echo -e "${YELLOW}Step 5: Testing available aerospace-relevant data...${NC}"
echo "Points with office/industrial tags:"
psql -d uk_osm_full -c "
SELECT COUNT(*) as office_industrial_points
FROM public.planet_osm_point 
WHERE office IS NOT NULL OR man_made IS NOT NULL;
"

echo "Sample of potentially relevant points:"
psql -d uk_osm_full -c "
SELECT name, amenity, office, man_made
FROM public.planet_osm_point 
WHERE (office IS NOT NULL OR man_made IS NOT NULL)
  AND name IS NOT NULL
LIMIT 10;
"

echo ""
echo -e "${BLUE}=== Diagnostic Complete ===${NC}"
echo -e "${YELLOW}Schema: public${NC}"
echo -e "${YELLOW}Key finding: Points table lacks 'building' column - this needs to be handled in the code${NC}"
