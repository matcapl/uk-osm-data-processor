#!/bin/bash
# Validation and Iterative Refinement Workflow
# Use this after initial pipeline run to improve accuracy

set -e

DB_NAME="uk_osm_full"
DB_USER="a"
DB_HOST="localhost"
DB_PORT="5432"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}VALIDATION & REFINEMENT WORKFLOW${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""

# ==============================================================================
# PHASE 1: Quality Analysis
# ==============================================================================
echo -e "${YELLOW}[PHASE 1]${NC} Quality Analysis"
echo "-------------------------------------------"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

\echo 'Score Distribution:'
\echo '-------------------'
SELECT 
  CASE 
    WHEN aerospace_score >= 200 THEN '200+ (Definitive)'
    WHEN aerospace_score >= 150 THEN '150-199 (Tier 1)'
    WHEN aerospace_score >= 100 THEN '100-149 (Strong Tier 2)'
    WHEN aerospace_score >= 80 THEN '80-99 (Tier 2)'
    WHEN aerospace_score >= 60 THEN '60-79 (Potential)'
    WHEN aerospace_score >= 40 THEN '40-59 (Review)'
    ELSE 'Below 40'
  END as score_range,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) as percentage
FROM aerospace_supplier_candidates
GROUP BY score_range
ORDER BY MIN(aerospace_score) DESC;

\echo ''
\echo 'Contact Info Completeness:'
\echo '--------------------------'
SELECT 
  tier_classification,
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE website IS NOT NULL) as has_website,
  COUNT(*) FILTER (WHERE phone IS NOT NULL) as has_phone,
  COUNT(*) FILTER (WHERE postcode IS NOT NULL) as has_postcode,
  ROUND(100.0 * COUNT(*) FILTER (WHERE website IS NOT NULL) / COUNT(*), 1) as pct_website
FROM aerospace_supplier_candidates
GROUP BY tier_classification
ORDER BY total DESC;

\echo ''
\echo 'Geographic Distribution:'
\echo '------------------------'
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

SQL

echo ""

# ==============================================================================
# PHASE 2: Red Flags Detection
# ==============================================================================
echo -e "${YELLOW}[PHASE 2]${NC} Red Flags Detection"
echo "-------------------------------------------"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

\echo 'Suspicious High Scorers (Manual Review Needed):'
\echo '------------------------------------------------'

-- High scores but residential indicators
SELECT 
  'High score + residential' as flag_type,
  COUNT(*) as count
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 100
  AND (building_type IN ('house', 'apartments', 'residential')
       OR landuse_type = 'residential');

-- High scores but consumer amenities
SELECT 
  'High score + consumer business' as flag_type,
  COUNT(*) as count
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 80
  AND name ~* '(cafe|restaurant|hotel|pub|retail|shop|gym|salon)';

-- Very high scores but no contact info
SELECT 
  'Score >150 + no contact' as flag_type,
  COUNT(*) as count
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 150
  AND website IS NULL
  AND phone IS NULL;

\echo ''
\echo 'Sample Suspicious Records:'
\echo '--------------------------'
SELECT 
  osm_id,
  LEFT(name, 40) as name,
  aerospace_score,
  tier_classification,
  building_type,
  landuse_type
FROM aerospace_supplier_candidates
WHERE (
  (aerospace_score >= 100 AND building_type IN ('house', 'apartments', 'residential'))
  OR (aerospace_score >= 80 AND name ~* '(cafe|restaurant|hotel|pub|retail)')
  OR (aerospace_score >= 150 AND website IS NULL AND phone IS NULL)
)
LIMIT 20;

SQL

echo ""

# ==============================================================================
# PHASE 3: Keyword Effectiveness Analysis
# ==============================================================================
echo -e "${YELLOW}[PHASE 3]${NC} Keyword Effectiveness"
echo "-------------------------------------------"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

\echo 'Most Common Keywords in High Scorers:'
\echo '--------------------------------------'

-- This analyzes which keywords appear most in Tier 1/2 candidates
WITH keyword_analysis AS (
  SELECT 
    LOWER(REGEXP_SPLIT_TO_TABLE(name, '\s+')) as word,
    tier_classification,
    aerospace_score
  FROM aerospace_supplier_candidates
  WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
    AND name IS NOT NULL
)
SELECT 
  word,
  COUNT(*) as frequency,
  ROUND(AVG(aerospace_score)) as avg_score,
  COUNT(*) FILTER (WHERE tier_classification = 'tier1_candidate') as tier1_count
FROM keyword_analysis
WHERE LENGTH(word) > 3  -- Skip short words
  AND word !~ '^(the|and|ltd|limited|company)$'  -- Skip common words
GROUP BY word
HAVING COUNT(*) >= 5
ORDER BY frequency DESC
LIMIT 30;

SQL

echo ""

# ==============================================================================
# PHASE 4: Generate Sample for Manual Validation
# ==============================================================================
echo -e "${YELLOW}[PHASE 4]${NC} Generate Validation Sample"
echo "-------------------------------------------"

SAMPLE_FILE="validation_sample_$(date +%Y%m%d_%H%M%S).csv"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\echo 'Creating stratified sample for manual validation...'
\copy (
  -- Stratified sample: 10 from each tier
  (
    SELECT 
      osm_id,
      name,
      aerospace_score,
      tier_classification,
      website,
      phone,
      postcode,
      city,
      array_to_string(matched_keywords, '; ') as keywords,
      'VALIDATE_ME' as validation_status,
      '' as is_aerospace_supplier,
      '' as notes
    FROM aerospace_supplier_candidates
    WHERE tier_classification = 'tier1_candidate'
    ORDER BY RANDOM()
    LIMIT 10
  )
  UNION ALL
  (
    SELECT 
      osm_id, name, aerospace_score, tier_classification,
      website, phone, postcode, city,
      array_to_string(matched_keywords, '; '),
      'VALIDATE_ME', '', ''
    FROM aerospace_supplier_candidates
    WHERE tier_classification = 'tier2_candidate'
    ORDER BY RANDOM()
    LIMIT 10
  )
  UNION ALL
  (
    SELECT 
      osm_id, name, aerospace_score, tier_classification,
      website, phone, postcode, city,
      array_to_string(matched_keywords, '; '),
      'VALIDATE_ME', '', ''
    FROM aerospace_supplier_candidates
    WHERE tier_classification = 'potential_candidate'
    ORDER BY RANDOM()
    LIMIT 10
  )
  ORDER BY tier_classification DESC, aerospace_score DESC
) TO './exports/${SAMPLE_FILE}' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Sample saved: ./exports/${SAMPLE_FILE}"
echo ""

# ==============================================================================
# PHASE 5: Create Refinement Report
# ==============================================================================
echo -e "${YELLOW}[PHASE 5]${NC} Refinement Recommendations"
echo "-------------------------------------------"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'SQL'

\echo 'RECOMMENDATIONS FOR IMPROVEMENT:'
\echo '================================='
\echo ''

-- Check for potential false positives
\echo '1. FALSE POSITIVE RISK:'
\echo '   Review these patterns that may need stronger negative filters:'

SELECT 
  'Names containing consumer words' as issue,
  COUNT(*) as affected_records,
  string_agg(DISTINCT LEFT(name, 30), ', ') as examples
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 60
  AND name ~* '(cafe|restaurant|hotel|retail|shop)'
GROUP BY issue

UNION ALL

SELECT 
  'High scores in residential areas' as issue,
  COUNT(*) as affected_records,
  string_agg(DISTINCT LEFT(name, 30), ', ') as examples
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 80
  AND landuse_type = 'residential'
GROUP BY issue;

\echo ''
\echo '2. MISSING DATA OPPORTUNITIES:'
\echo '   Consider web scraping for candidates with high scores but missing:'

SELECT 
  tier_classification,
  COUNT(*) FILTER (WHERE website IS NULL) as missing_website,
  COUNT(*) FILTER (WHERE phone IS NULL) as missing_phone,
  COUNT(*) FILTER (WHERE city IS NULL) as missing_city
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 80
GROUP BY tier_classification;

\echo ''
\echo '3. GEOGRAPHIC INSIGHTS:'
\echo '   Consider adding bonuses for these under-represented aerospace areas:'

-- Find areas with known aerospace but low candidate counts
WITH area_scores AS (
  SELECT 
    LEFT(postcode, 2) as region,
    COUNT(*) as candidate_count,
    AVG(aerospace_score) as avg_score
  FROM aerospace_supplier_candidates
  WHERE postcode IS NOT NULL
  GROUP BY region
)
SELECT 
  region,
  candidate_count,
  ROUND(avg_score) as avg_score,
  CASE 
    WHEN region IN ('BS', 'GL', 'DE', 'PR') THEN 'Known aerospace hub'
    WHEN region IN ('CB', 'SO', 'LE') THEN 'Emerging cluster'
    ELSE 'Check potential'
  END as status
FROM area_scores
WHERE candidate_count < 5
  AND region IN ('BS', 'GL', 'DE', 'PR', 'CB', 'SO', 'BT', 'LE', 'CF')
ORDER BY candidate_count;

SQL

echo ""

# ==============================================================================
# PHASE 6: Export High-Priority Review Lists
# ==============================================================================
echo -e "${YELLOW}[PHASE 6]${NC} Export Review Lists"
echo "-------------------------------------------"

REVIEW_DIR="./exports/review_$(date +%Y%m%d)"
mkdir -p "$REVIEW_DIR"

# Export 1: High scores needing verification
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\copy (
  SELECT 
    osm_id, name, aerospace_score, tier_classification,
    website, phone, postcode, city,
    building_type, landuse_type,
    array_to_string(matched_keywords, '; ') as keywords,
    'REVIEW: High score but suspicious' as reason
  FROM aerospace_supplier_candidates
  WHERE (
    (aerospace_score >= 100 AND building_type IN ('house', 'apartments', 'residential'))
    OR (aerospace_score >= 150 AND website IS NULL AND phone IS NULL)
    OR (aerospace_score >= 80 AND name ~* '(cafe|restaurant|hotel|pub|retail)')
  )
  ORDER BY aerospace_score DESC
) TO '${REVIEW_DIR}/suspicious_high_scores.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Exported: ${REVIEW_DIR}/suspicious_high_scores.csv"

# Export 2: Tier 1 candidates for priority research
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\copy (
  SELECT 
    name, aerospace_score, website, phone, postcode, city,
    array_to_string(matched_keywords, '; ') as keywords,
    CASE 
      WHEN website IS NOT NULL THEN 'Research online'
      WHEN phone IS NOT NULL THEN 'Call to verify'
      ELSE 'Google search + LinkedIn'
    END as action_needed
  FROM aerospace_supplier_candidates
  WHERE tier_classification = 'tier1_candidate'
  ORDER BY aerospace_score DESC
) TO '${REVIEW_DIR}/tier1_priority_research.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Exported: ${REVIEW_DIR}/tier1_priority_research.csv"

# Export 3: Borderline cases (near thresholds)
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\copy (
  SELECT 
    name, aerospace_score, tier_classification,
    website, postcode, city,
    array_to_string(matched_keywords, '; ') as keywords,
    'Borderline - needs review' as reason
  FROM aerospace_supplier_candidates
  WHERE aerospace_score BETWEEN 75 AND 85  -- Near Tier 2 threshold
     OR aerospace_score BETWEEN 145 AND 155  -- Near Tier 1 threshold
  ORDER BY aerospace_score DESC
) TO '${REVIEW_DIR}/borderline_cases.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Exported: ${REVIEW_DIR}/borderline_cases.csv"

echo ""
echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}VALIDATION WORKFLOW COMPLETE${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""
echo "Next Steps:"
echo "  1. Review: ./exports/${SAMPLE_FILE}"
echo "     - Open in Excel/Numbers"
echo "     - Mark each: YES/NO/MAYBE in 'is_aerospace_supplier'"
echo "     - Add notes"
echo ""
echo "  2. Calculate Accuracy:"
echo "     - Count: YES / Total = Precision"
echo "     - Target: >70% for Tier 2, >90% for Tier 1"
echo ""
echo "  3. Identify Patterns:"
echo "     - What do false positives have in common?"
echo "     - What keywords appear in wrong classifications?"
echo ""
echo "  4. Refine Scoring:"
echo "     - Add negative keywords for false positives"
echo "     - Boost scoring for verified patterns"
echo "     - Re-run pipeline"
echo ""
echo "  5. High Priority:"
echo "     - Research Tier 1 candidates: ${REVIEW_DIR}/tier1_priority_research.csv"
echo "     - Fix suspicious records: ${REVIEW_DIR}/suspicious_high_scores.csv"
echo ""