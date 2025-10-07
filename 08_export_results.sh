#!/bin/bash
# Export aerospace candidates to CSV files

set -e

DB_NAME="uk_osm_full"
DB_USER="a"
DB_HOST="localhost"
DB_PORT="5432"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OUTPUT_DIR="./exports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}EXPORT AEROSPACE CANDIDATES${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}✓${NC} Output directory: $OUTPUT_DIR"
echo ""

# ============================================================================
# Export 1: All Candidates
# ============================================================================
echo -e "${YELLOW}[1/5]${NC} Exporting all candidates..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\copy (
  SELECT 
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
    array_to_string(matched_keywords, '; ') as keywords,
    latitude,
    longitude,
    created_at
  FROM aerospace_supplier_candidates
  ORDER BY aerospace_score DESC
) TO '${OUTPUT_DIR}/all_candidates_${TIMESTAMP}.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Exported: all_candidates_${TIMESTAMP}.csv"

# ============================================================================
# Export 2: Tier 1 Candidates
# ============================================================================
echo -e "${YELLOW}[2/5]${NC} Exporting Tier 1 candidates (≥150)..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\copy (
  SELECT 
    name,
    aerospace_score,
    confidence_level,
    phone,
    email,
    website,
    postcode,
    city,
    array_to_string(matched_keywords, '; ') as keywords,
    landuse_type,
    building_type,
    industrial_type
  FROM aerospace_supplier_candidates
  WHERE tier_classification = 'tier1_candidate'
  ORDER BY aerospace_score DESC
) TO '${OUTPUT_DIR}/tier1_candidates_${TIMESTAMP}.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Exported: tier1_candidates_${TIMESTAMP}.csv"

# ============================================================================
# Export 3: Tier 2 Candidates
# ============================================================================
echo -e "${YELLOW}[3/5]${NC} Exporting Tier 2 candidates (80-149)..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\copy (
  SELECT 
    name,
    aerospace_score,
    confidence_level,
    phone,
    email,
    website,
    postcode,
    city,
    array_to_string(matched_keywords, '; ') as keywords,
    landuse_type,
    building_type,
    industrial_type
  FROM aerospace_supplier_candidates
  WHERE tier_classification = 'tier2_candidate'
  ORDER BY aerospace_score DESC
) TO '${OUTPUT_DIR}/tier2_candidates_${TIMESTAMP}.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Exported: tier2_candidates_${TIMESTAMP}.csv"

# ============================================================================
# Export 4: Candidates with Contact Info
# ============================================================================
echo -e "${YELLOW}[4/5]${NC} Exporting candidates with contact info..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\copy (
  SELECT 
    name,
    aerospace_score,
    tier_classification,
    phone,
    email,
    website,
    postcode,
    city,
    array_to_string(matched_keywords, '; ') as keywords
  FROM aerospace_supplier_candidates
  WHERE website IS NOT NULL OR phone IS NOT NULL OR email IS NOT NULL
  ORDER BY aerospace_score DESC
) TO '${OUTPUT_DIR}/candidates_with_contact_${TIMESTAMP}.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Exported: candidates_with_contact_${TIMESTAMP}.csv"

# ============================================================================
# Export 5: Regional Summary
# ============================================================================
echo -e "${YELLOW}[5/5]${NC} Exporting regional summary..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\copy (
  SELECT 
    LEFT(postcode, 2) as region,
    COUNT(*) as total_candidates,
    COUNT(*) FILTER (WHERE tier_classification = 'tier1_candidate') as tier1_count,
    COUNT(*) FILTER (WHERE tier_classification = 'tier2_candidate') as tier2_count,
    COUNT(*) FILTER (WHERE tier_classification = 'potential_candidate') as potential_count,
    ROUND(AVG(aerospace_score), 2) as avg_score,
    MAX(aerospace_score) as max_score,
    COUNT(*) FILTER (WHERE website IS NOT NULL) as with_website,
    COUNT(*) FILTER (WHERE phone IS NOT NULL) as with_phone
  FROM aerospace_supplier_candidates
  WHERE postcode IS NOT NULL
  GROUP BY region
  ORDER BY total_candidates DESC
) TO '${OUTPUT_DIR}/regional_summary_${TIMESTAMP}.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Exported: regional_summary_${TIMESTAMP}.csv"

# ============================================================================
# Create Export Summary
# ============================================================================
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}EXPORT SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"

TOTAL=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_supplier_candidates;")
TIER1=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE tier_classification = 'tier1_candidate';")
TIER2=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE tier_classification = 'tier2_candidate';")
WITH_CONTACT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE website IS NOT NULL OR phone IS NOT NULL;")

echo ""
echo "Files exported to: $OUTPUT_DIR"
echo ""
echo "Records exported:"
echo "  - All candidates: $TOTAL"
echo "  - Tier 1: $TIER1"
echo "  - Tier 2: $TIER2"
echo "  - With contact info: $WITH_CONTACT"
echo ""
echo "CSV files created:"
echo "  1. all_candidates_${TIMESTAMP}.csv"
echo "  2. tier1_candidates_${TIMESTAMP}.csv"
echo "  3. tier2_candidates_${TIMESTAMP}.csv"
echo "  4. candidates_with_contact_${TIMESTAMP}.csv"
echo "  5. regional_summary_${TIMESTAMP}.csv"
echo ""
echo -e "${GREEN}✓ Export complete${NC}"