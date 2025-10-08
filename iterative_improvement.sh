#!/bin/bash
# Iterative Improvement Loop
# Run this weekly/monthly to continuously improve scoring

set -e

DB_NAME="uk_osm_full"
DB_USER="a"
DB_HOST="localhost"
DB_PORT="5432"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ITERATION=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="./iterations/${ITERATION}"
mkdir -p "$RESULTS_DIR"

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}ITERATIVE IMPROVEMENT - ITERATION ${ITERATION}${NC}"
echo -e "${CYAN}======================================================${NC}"
echo ""

# ==============================================================================
# STEP 1: Baseline Metrics
# ==============================================================================
echo -e "${YELLOW}[STEP 1]${NC} Capture baseline metrics..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A > "${RESULTS_DIR}/baseline_metrics.txt" <<'SQL'
SELECT 'total_candidates:' || COUNT(*) FROM aerospace_supplier_candidates
UNION ALL
SELECT 'tier1:' || COUNT(*) FROM aerospace_supplier_candidates WHERE tier_classification = 'tier1_candidate'
UNION ALL
SELECT 'tier2:' || COUNT(*) FROM aerospace_supplier_candidates WHERE tier_classification = 'tier2_candidate'
UNION ALL
SELECT 'potential:' || COUNT(*) FROM aerospace_supplier_candidates WHERE tier_classification = 'potential_candidate'
UNION ALL
SELECT 'avg_score:' || ROUND(AVG(aerospace_score)) FROM aerospace_supplier_candidates
UNION ALL
SELECT 'with_website:' || COUNT(*) FROM aerospace_supplier_candidates WHERE website IS NOT NULL;
SQL

cat "${RESULTS_DIR}/baseline_metrics.txt"
echo ""

# ==============================================================================
# STEP 2: Identify Improvement Opportunities
# ==============================================================================
echo -e "${YELLOW}[STEP 2]${NC} Analyze improvement opportunities..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > "${RESULTS_DIR}/opportunities.txt" <<'SQL'

\echo 'FALSE POSITIVE PATTERNS:'
\echo '========================'

-- Most common words in low-scoring candidates that might be noise
WITH word_analysis AS (
  SELECT 
    LOWER(REGEXP_SPLIT_TO_TABLE(name, '\s+')) as word,
    COUNT(*) as freq,
    AVG(aerospace_score) as avg_score
  FROM aerospace_supplier_candidates
  WHERE aerospace_score BETWEEN 40 AND 60  -- Borderline cases
    AND name IS NOT NULL
  GROUP BY word
  HAVING COUNT(*) >= 3
)
SELECT 
  word,
  freq,
  ROUND(avg_score) as avg_score,
  CASE 
    WHEN avg_score < 50 THEN '→ Consider negative keyword'
    WHEN word ~* '(ltd|limited|company|group)' THEN '→ Noise word'
    ELSE '→ OK'
  END as recommendation
FROM word_analysis
WHERE LENGTH(word) > 3
ORDER BY freq DESC
LIMIT 20;

\echo ''
\echo 'MISSING SIGNALS:'
\echo '================'

-- High-confidence keywords appearing in Tier 1 but not scored highly
SELECT DISTINCT
  word,
  COUNT(*) as appearances_in_tier1
FROM (
  SELECT LOWER(REGEXP_SPLIT_TO_TABLE(name, '\s+')) as word
  FROM aerospace_supplier_candidates
  WHERE tier_classification = 'tier1_candidate'
) subq
WHERE LENGTH(word) > 4
  AND word !~* '(ltd|limited|company|group|the|and)'
GROUP BY word
HAVING COUNT(*) >= 2
ORDER BY appearances_in_tier1 DESC
LIMIT 15;

SQL

echo -e "${GREEN}✓${NC} Analysis saved: ${RESULTS_DIR}/opportunities.txt"
echo ""

# ==============================================================================
# STEP 3: A/B Test Score Adjustments
# ==============================================================================
echo -e "${YELLOW}[STEP 3]${NC} Testing score adjustments..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > "${RESULTS_DIR}/ab_test_results.txt" <<'SQL'

\echo 'A/B TEST: What if we adjusted thresholds?'
\echo '=========================================='
\echo ''

-- Test different threshold scenarios
WITH scenarios AS (
  SELECT 
    aerospace_score,
    tier_classification as current_tier,
    CASE 
      WHEN aerospace_score >= 180 THEN 'tier1_candidate'
      WHEN aerospace_score >= 100 THEN 'tier2_candidate'
      WHEN aerospace_score >= 50 THEN 'potential_candidate'
      ELSE 'low_probability'
    END as stricter_tier,
    CASE 
      WHEN aerospace_score >= 130 THEN 'tier1_candidate'
      WHEN aerospace_score >= 70 THEN 'tier2_candidate'
      WHEN aerospace_score >= 35 THEN 'potential_candidate'
      ELSE 'low_probability'
    END as looser_tier
  FROM aerospace_supplier_candidates
)
SELECT 
  'Current Thresholds' as scenario,
  COUNT(*) FILTER (WHERE current_tier = 'tier1_candidate') as tier1,
  COUNT(*) FILTER (WHERE current_tier = 'tier2_candidate') as tier2,
  COUNT(*) FILTER (WHERE current_tier = 'potential_candidate') as potential
FROM scenarios

UNION ALL

SELECT 
  'Stricter (+20% threshold)',
  COUNT(*) FILTER (WHERE stricter_tier = 'tier1_candidate'),
  COUNT(*) FILTER (WHERE stricter_tier = 'tier2_candidate'),
  COUNT(*) FILTER (WHERE stricter_tier = 'potential_candidate')
FROM scenarios

UNION ALL

SELECT 
  'Looser (-15% threshold)',
  COUNT(*) FILTER (WHERE looser_tier = 'tier1_candidate'),
  COUNT(*) FILTER (WHERE looser_tier = 'tier2_candidate'),
  COUNT(*) FILTER (WHERE looser_tier = 'potential_candidate')
FROM scenarios;

\echo ''
\echo 'Impact on candidates per postcode region:'
\echo '------------------------------------------'

SELECT 
  LEFT(postcode, 2) as region,
  COUNT(*) as current_total,
  COUNT(*) FILTER (WHERE aerospace_score >= 100) as if_stricter,
  COUNT(*) FILTER (WHERE aerospace_score >= 70) as if_looser
FROM aerospace_supplier_candidates
WHERE postcode IS NOT NULL
GROUP BY region
HAVING COUNT(*) >= 5
ORDER BY current_total DESC
LIMIT 10;

SQL

echo -e "${GREEN}✓${NC} A/B test results: ${RESULTS_DIR}/ab_test_results.txt"
echo ""

# ==============================================================================
# STEP 4: Generate Recommended Changes
# ==============================================================================
echo -e "${YELLOW}[STEP 4]${NC} Generate recommendations..."

RECOMMENDATIONS_FILE="${RESULTS_DIR}/recommendations.md"
touch "$RECOMMENDATIONS_FILE"

echo "# Scoring Improvement Recommendations" > "$RECOMMENDATIONS_FILE"
echo "## Generated: $(date)" >> "$RECOMMENDATIONS_FILE"
echo "" >> "$RECOMMENDATIONS_FILE"

echo "## 1. Keywords to Add" >> "$RECOMMENDATIONS_FILE"
echo "Based on analysis of Tier 1 candidates, consider adding these high-confidence keywords to scoring.yaml (from MISSING SIGNALS):" >> "$RECOMMENDATIONS_FILE"
echo "" >> "$RECOMMENDATIONS_FILE"
echo "| Keyword | Appearances in Tier 1 |" >> "$RECOMMENDATIONS_FILE"
echo "|---------|-----------------------|" >> "$RECOMMENDATIONS_FILE"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A >> "$RECOMMENDATIONS_FILE" <<'SQL'
SELECT word || '|' || appearances_in_tier1
FROM (
  SELECT DISTINCT
    word,
    COUNT(*) as appearances_in_tier1
  FROM (
    SELECT LOWER(REGEXP_SPLIT_TO_TABLE(name, '\s+')) as word
    FROM aerospace_supplier_candidates
    WHERE tier_classification = 'tier1_candidate'
  ) subq
  WHERE LENGTH(word) > 4
    AND word !~* '(ltd|limited|company|group|the|and)'
  GROUP BY word
  HAVING COUNT(*) >= 2
  ORDER BY appearances_in_tier1 DESC
  LIMIT 15
) final;
SQL

echo "" >> "$RECOMMENDATIONS_FILE"
echo "Recommended scoring weight: +20-30 points per match, depending on specificity." >> "$RECOMMENDATIONS_FILE"
echo "" >> "$RECOMMENDATIONS_FILE"

echo "## 2. Negative Keywords to Add" >> "$RECOMMENDATIONS_FILE"
echo "Based on false positive patterns in borderline low-scoring candidates, consider adding these as negative keywords to scoring.yaml:" >> "$RECOMMENDATIONS_FILE"
echo "" >> "$RECOMMENDATIONS_FILE"
echo "| Word | Frequency | Avg Score | Recommendation |" >> "$RECOMMENDATIONS_FILE"
echo "|------|-----------|-----------|----------------|" >> "$RECOMMENDATIONS_FILE"

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A >> "$RECOMMENDATIONS_FILE" <<'SQL'
WITH word_analysis AS (
  SELECT 
    LOWER(REGEXP_SPLIT_TO_TABLE(name, '\s+')) as word,
    COUNT(*) as freq,
    AVG(aerospace_score) as avg_score
  FROM aerospace_supplier_candidates
  WHERE aerospace_score BETWEEN 40 AND 60
    AND name IS NOT NULL
  GROUP BY word
  HAVING COUNT(*) >= 3
)
SELECT 
  word || '|' || freq || '|' || ROUND(avg_score) || '|' ||
  CASE 
    WHEN avg_score < 50 THEN 'Consider negative keyword'
    WHEN word ~* '(ltd|limited|company|group)' THEN 'Noise word'
    ELSE 'OK'
  END
FROM word_analysis
WHERE LENGTH(word) > 3
ORDER BY freq DESC
LIMIT 20;
SQL

echo "" >> "$RECOMMENDATIONS_FILE"
echo "Recommended scoring penalty: -10 to -20 points for noise words." >> "$RECOMMENDATIONS_FILE"
echo "" >> "$RECOMMENDATIONS_FILE"

echo "## 3. Threshold Adjustments" >> "$RECOMMENDATIONS_FILE"
echo "Based on A/B testing of score thresholds, here are the impacts:" >> "$RECOMMENDATIONS_FILE"
echo "" >> "$RECOMMENDATIONS_FILE"

# Extract and format A/B test summary
awk '/A\/B TEST/{p=1} p{print} /Impact on candidates/{p=0}' "${RESULTS_DIR}/ab_test_results.txt" | sed 's/^/    /' >> "$RECOMMENDATIONS_FILE"

echo "" >> "$RECOMMENDATIONS_FILE"
echo "Recommendation: If current Tier 1 seems too loose, adopt stricter thresholds (+20%). Monitor regional impacts to avoid losing coverage in key areas like DE (Derby)." >> "$RECOMMENDATIONS_FILE"
echo "" >> "$RECOMMENDATIONS_FILE"

echo "## 4. Other Improvements" >> "$RECOMMENDATIONS_FILE"
echo "- Enrich missing websites: $(grep 'with_website' "${RESULTS_DIR}/baseline_metrics.txt" | cut -d: -f2) / $(grep 'total_candidates' "${RESULTS_DIR}/baseline_metrics.txt" | cut -d: -f2) have websites. Consider web scraping or API calls to find more." >> "$RECOMMENDATIONS_FILE"
echo "- Geographic focus: Prioritize scoring boosts for candidates within 60 miles of known Tier 1 facilities (e.g., Rolls-Royce Derby at PO Box 31, Moor Lane, Derby DE24 8BJ)." >> "$RECOMMENDATIONS_FILE"
echo "- Integrate external data: Use UK SIC codes like 30300 (Aerospace manufacturing) for filtering. Scrape Google Maps for industrial sites near facilities." >> "$RECOMMENDATIONS_FILE"
echo "" >> "$RECOMMENDATIONS_FILE"

echo -e "${GREEN}✓${NC} Recommendations generated: ${RECOMMENDATIONS_FILE}"
cat "$RECOMMENDATIONS_FILE"
echo ""

# ==============================================================================
# STEP 5: Export Candidates for Manual Review
# ==============================================================================
echo -e "${YELLOW}[STEP 5]${NC} Export top candidates for validation..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\COPY (SELECT * FROM aerospace_supplier_candidates WHERE aerospace_score >= 100 ORDER BY aerospace_score DESC LIMIT 100) TO '${RESULTS_DIR}/top_candidates.csv' CSV HEADER;"

echo -e "${GREEN}✓${NC} Exported top 100 candidates to ${RESULTS_DIR}/top_candidates.csv for manual review."
echo "Use this to validate and feed back into scoring refinements."
echo ""

# ==============================================================================
# Completion
# ==============================================================================
echo -e "${CYAN}======================================================${NC}"
echo -e "${GREEN}Iteration ${ITERATION} complete!${NC}"
echo -e "${CYAN}Review files in ${RESULTS_DIR}${NC}"
echo -e "${CYAN}======================================================${NC}"