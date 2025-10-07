#!/bin/bash
# Test suite for aerospace pipeline validation

set -e

DB_NAME="uk_osm_full"
DB_USER="a"
DB_HOST="localhost"
DB_PORT="5432"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AEROSPACE PIPELINE TEST SUITE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

PSQL="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -A"

# Test counter
PASSED=0
FAILED=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((FAILED++))
    fi
}

# ============================================================================
# TEST 1: Source Tables Exist and Have Data
# ============================================================================
echo -e "${YELLOW}[TEST 1]${NC} Source tables validation"
echo "-------------------------------------------"

for table in planet_osm_point planet_osm_polygon planet_osm_line planet_osm_roads; do
    COUNT=$($PSQL -c "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
    if [ "$COUNT" -gt "0" ]; then
        test_result 0 "$table exists with $COUNT rows"
    else
        test_result 1 "$table missing or empty"
    fi
done
echo ""

# ============================================================================
# TEST 2: Filtered Views Created
# ============================================================================
echo -e "${YELLOW}[TEST 2]${NC} Filtered views exist"
echo "-------------------------------------------"

for geom in point polygon line roads; do
    VIEW_EXISTS=$($PSQL -c "SELECT COUNT(*) FROM information_schema.views WHERE table_name='planet_osm_${geom}_aerospace_filtered';" 2>/dev/null || echo "0")
    if [ "$VIEW_EXISTS" -eq "1" ]; then
        COUNT=$($PSQL -c "SELECT COUNT(*) FROM planet_osm_${geom}_aerospace_filtered;" 2>/dev/null || echo "0")
        test_result 0 "planet_osm_${geom}_aerospace_filtered exists with $COUNT rows"
    else
        test_result 1 "planet_osm_${geom}_aerospace_filtered missing"
    fi
done
echo ""

# ============================================================================
# TEST 3: Scored Views Created with Score Column
# ============================================================================
echo -e "${YELLOW}[TEST 3]${NC} Scored views exist with aerospace_score"
echo "-------------------------------------------"

for geom in point polygon line roads; do
    VIEW_EXISTS=$($PSQL -c "SELECT COUNT(*) FROM information_schema.views WHERE table_name='planet_osm_${geom}_aerospace_scored';" 2>/dev/null || echo "0")
    if [ "$VIEW_EXISTS" -eq "1" ]; then
        # Check if aerospace_score column exists
        HAS_SCORE=$($PSQL -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='planet_osm_${geom}_aerospace_scored' AND column_name='aerospace_score';" 2>/dev/null || echo "0")
        if [ "$HAS_SCORE" -eq "1" ]; then
            COUNT=$($PSQL -c "SELECT COUNT(*) FROM planet_osm_${geom}_aerospace_scored WHERE aerospace_score >= 40;" 2>/dev/null || echo "0")
            test_result 0 "planet_osm_${geom}_aerospace_scored has $COUNT candidates (score ≥40)"
        else
            test_result 1 "planet_osm_${geom}_aerospace_scored missing aerospace_score column"
        fi
    else
        test_result 1 "planet_osm_${geom}_aerospace_scored missing"
    fi
done
echo ""

# ============================================================================
# TEST 4: Score Distribution Validation
# ============================================================================
echo -e "${YELLOW}[TEST 4]${NC} Score distribution by tier"
echo "-------------------------------------------"

for geom in point polygon line roads; do
    VIEW_EXISTS=$($PSQL -c "SELECT COUNT(*) FROM information_schema.views WHERE table_name='planet_osm_${geom}_aerospace_scored';" 2>/dev/null || echo "0")
    if [ "$VIEW_EXISTS" -eq "1" ]; then
        echo "  ${geom} distribution:"
        $PSQL -c "SELECT 
            CASE 
                WHEN aerospace_score >= 150 THEN 'Tier 1 (≥150)'
                WHEN aerospace_score >= 80 THEN 'Tier 2 (80-149)'
                WHEN aerospace_score >= 40 THEN 'Potential (40-79)'
                ELSE 'Below threshold'
            END as tier,
            COUNT(*) as count
        FROM planet_osm_${geom}_aerospace_scored
        GROUP BY tier
        ORDER BY MIN(aerospace_score) DESC;" -F $'\t' | sed 's/^/    /'
    fi
done
echo ""

# ============================================================================
# TEST 5: Staging Tables Exist
# ============================================================================
echo -e "${YELLOW}[TEST 5]${NC} Staging tables created"
echo "-------------------------------------------"

for geom in point polygon line roads; do
    TABLE_EXISTS=$($PSQL -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='aerospace_candidates_${geom}';" 2>/dev/null || echo "0")
    if [ "$TABLE_EXISTS" -eq "1" ]; then
        COUNT=$($PSQL -c "SELECT COUNT(*) FROM aerospace_candidates_${geom};" 2>/dev/null || echo "0")
        test_result 0 "aerospace_candidates_${geom} exists with $COUNT rows"
    else
        test_result 1 "aerospace_candidates_${geom} missing"
    fi
done
echo ""

# ============================================================================
# TEST 6: Required Columns Present in Staging Tables
# ============================================================================
echo -e "${YELLOW}[TEST 6]${NC} Column validation in staging tables"
echo "-------------------------------------------"

REQUIRED_COLS="osm_id,source_table,name,aerospace_score,tier_classification,confidence_level,postcode,city,website,latitude,longitude,geometry"

for geom in point polygon line roads; do
    TABLE_EXISTS=$($PSQL -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='aerospace_candidates_${geom}';" 2>/dev/null || echo "0")
    if [ "$TABLE_EXISTS" -eq "1" ]; then
        MISSING_COLS=""
        IFS=',' read -ra COLS <<< "$REQUIRED_COLS"
        for col in "${COLS[@]}"; do
            COL_EXISTS=$($PSQL -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='aerospace_candidates_${geom}' AND column_name='$col';" 2>/dev/null || echo "0")
            if [ "$COL_EXISTS" -eq "0" ]; then
                MISSING_COLS="$MISSING_COLS $col"
            fi
        done
        if [ -z "$MISSING_COLS" ]; then
            test_result 0 "aerospace_candidates_${geom} has all required columns"
        else
            test_result 1 "aerospace_candidates_${geom} missing:$MISSING_COLS"
        fi
    fi
done
echo ""

# ============================================================================
# TEST 7: Data Quality Checks
# ============================================================================
echo -e "${YELLOW}[TEST 7]${NC} Data quality validation"
echo "-------------------------------------------"

for geom in point polygon line roads; do
    TABLE_EXISTS=$($PSQL -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='aerospace_candidates_${geom}';" 2>/dev/null || echo "0")
    if [ "$TABLE_EXISTS" -eq "1" ]; then
        # Check for NULL names
        NULL_NAMES=$($PSQL -c "SELECT COUNT(*) FROM aerospace_candidates_${geom} WHERE name IS NULL;" 2>/dev/null || echo "0")
        if [ "$NULL_NAMES" -eq "0" ]; then
            test_result 0 "${geom}: No NULL names"
        else
            test_result 1 "${geom}: Found $NULL_NAMES NULL names"
        fi
        
        # Check for valid scores
        INVALID_SCORES=$($PSQL -c "SELECT COUNT(*) FROM aerospace_candidates_${geom} WHERE aerospace_score < 40;" 2>/dev/null || echo "0")
        if [ "$INVALID_SCORES" -eq "0" ]; then
            test_result 0 "${geom}: All scores ≥40"
        else
            test_result 1 "${geom}: Found $INVALID_SCORES scores below threshold"
        fi
        
        # Check geometry validity
        INVALID_GEOM=$($PSQL -c "SELECT COUNT(*) FROM aerospace_candidates_${geom} WHERE geometry IS NULL;" 2>/dev/null || echo "0")
        if [ "$INVALID_GEOM" -eq "0" ]; then
            test_result 0 "${geom}: All geometries valid"
        else
            test_result 1 "${geom}: Found $INVALID_GEOM NULL geometries"
        fi
    fi
done
echo ""

# ============================================================================
# TEST 8: Keyword Matching Validation
# ============================================================================
echo -e "${YELLOW}[TEST 8]${NC} Aerospace keyword detection"
echo "-------------------------------------------"

AEROSPACE_KEYWORDS="aerospace|aviation|aircraft|defense|defence|precision|engineering"

for geom in point polygon line roads; do
    TABLE_EXISTS=$($PSQL -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='aerospace_candidates_${geom}';" 2>/dev/null || echo "0")
    if [ "$TABLE_EXISTS" -eq "1" ]; then
        HIGH_SCORES=$($PSQL -c "SELECT COUNT(*) FROM aerospace_candidates_${geom} WHERE aerospace_score >= 100;" 2>/dev/null || echo "0")
        echo "  ${geom}: $HIGH_SCORES high-confidence candidates (score ≥100)"
    fi
done
echo ""

# ============================================================================
# TEST 9: Geographic Distribution
# ============================================================================
echo -e "${YELLOW}[TEST 9]${NC} Geographic distribution check"
echo "-------------------------------------------"

for geom in point polygon; do
    TABLE_EXISTS=$($PSQL -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name='aerospace_candidates_${geom}';" 2>/dev/null || echo "0")
    if [ "$TABLE_EXISTS" -eq "1" ]; then
        echo "  Top regions for ${geom}:"
        $PSQL -c "SELECT 
            LEFT(postcode, 2) as region,
            COUNT(*) as count
        FROM aerospace_candidates_${geom}
        WHERE postcode IS NOT NULL
        GROUP BY region
        ORDER BY count DESC
        LIMIT 5;" -F $'\t' | sed 's/^/    /'
    fi
done
echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TEST SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi