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

cat > "${RESULTS_DIR}/recommendations.md" <<EOF
# Scoring Improvement Recommendations

Generated: $(date)

## 1. Keywords to Add

Based on analysis of Tier 1 candidates, consider adding these to scoring.yaml:

EOF

# Extract high-value keywords from Tier 1
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -F',' > "${RESULTS_DIR}/tier1_keywords.csv" <<'SQL'
SELECT DISTINCT
  LOWER(REGEXP_SPLIT_TO_TABLE(name, '\s+')) as word,
  COUNT(*) as freq
FROM aerospace_supplier_candidates
WHERE tier_classification = 'tier1_candidate'
  AND name IS NOT NULL
GROUP BY word
HAVING COUNT(*) >= 2
  AND LENGTH(word) > 4
  AND word !~* '(ltd|limited|company|group|the|and|centre|center)'
ORDER BY freq DESC
LIMIT 20;
SQL

echo "High-frequency words in Tier 1 names:" >> "${RESULTS_DIR}/recommendations.md"
echo '```' >> "${RESULTS_DIR}/recommendations.md"
cat "${RESULTS_DIR}/tier1_keywords.csv" >> "${RESULTS_DIR}/recommendations.md"
echo '```' >> "${RESULTS_DIR}/recommendations.md"
echo "" >> "${RESULTS_DIR}/recommendations.md"

cat >> "${RESULTS_DIR}/recommendations.md" <<'EOF'

## 2. Negative Filters to Add

False positive patterns detected:

EOF

# Find false positive patterns
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "${RESULTS_DIR}/recommendations.md" <<'SQL'
SELECT '- ' || word || ' (appears ' || COUNT(*) || ' times in low scorers)'
FROM (
  SELECT LOWER(REGEXP_SPLIT_TO_TABLE(name, '\s+')) as word
  FROM aerospace_supplier_candidates
  WHERE aerospace_score BETWEEN 40 AND 60
    AND name ~* '(cafe|restaurant|hotel|retail|shop|gym|centre)'
) subq
WHERE LENGTH(word) > 3
GROUP BY word
HAVING COUNT(*) >= 2
ORDER BY COUNT(*) DESC
LIMIT 10;
SQL

cat >> "${RESULTS_DIR}/recommendations.md" <<'EOF'

## 3. Geographic Adjustments

Current distribution shows these regions may need bonus adjustments:

EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "${RESULTS_DIR}/recommendations.md" <<'SQL'
SELECT 
  '- ' || LEFT(postcode, 2) || 
  ': ' || COUNT(*) || ' candidates (avg score: ' || ROUND(AVG(aerospace_score)) || ')'
FROM aerospace_supplier_candidates
WHERE postcode IS NOT NULL
GROUP BY LEFT(postcode, 2)
HAVING COUNT(*) >= 10
ORDER BY AVG(aerospace_score) DESC
LIMIT 15;
SQL

cat >> "${RESULTS_DIR}/recommendations.md" <<'EOF'

## 4. Quality Metrics

Current performance:

EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "${RESULTS_DIR}/recommendations.md" <<'SQL'
SELECT '- Total candidates: ' || COUNT(*) FROM aerospace_supplier_candidates
UNION ALL
SELECT '- Tier 1: ' || COUNT(*) || ' (' || ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM aerospace_supplier_candidates)) || '%)' 
FROM aerospace_supplier_candidates WHERE tier_classification = 'tier1_candidate'
UNION ALL
SELECT '- Tier 2: ' || COUNT(*) || ' (' || ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM aerospace_supplier_candidates)) || '%)' 
FROM aerospace_supplier_candidates WHERE tier_classification = 'tier2_candidate'
UNION ALL
SELECT '- With contact info: ' || COUNT(*) || ' (' || ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM aerospace_supplier_candidates)) || '%)' 
FROM aerospace_supplier_candidates WHERE website IS NOT NULL OR phone IS NOT NULL;
SQL

cat >> "${RESULTS_DIR}/recommendations.md" <<'EOF'

## 5. Action Items

### High Priority
1. Review suspicious high scorers (see suspicious_high_scores.csv)
2. Validate sample of Tier 1 candidates manually
3. Add discovered keywords to scoring.yaml
4. Strengthen negative filters for false positive patterns

### Medium Priority
1. Adjust geographic bonuses based on distribution
2. Research missing known suppliers
3. Add certification keywords (AS9100, NADCAP, etc.)

### Low Priority
1. Consider lowering Tier 2 threshold if precision is high
2. Add proximity-to-airport scoring
3. Implement co-location bonus

## 6. Next Iteration

After making changes:
1. Re-run all pipelines
2. Compare metrics to this baseline
3. Validate improvement in precision/recall
4. Document changes in iteration log

EOF

echo -e "${GREEN}✓${NC} Recommendations: ${RESULTS_DIR}/recommendations.md"
echo ""

# ==============================================================================
# STEP 5: Export Comparison Dataset
# ==============================================================================
echo -e "${YELLOW}[STEP 5]${NC} Export comparison dataset..."

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL
\copy (
  SELECT 
    osm_id,
    name,
    aerospace_score,
    tier_classification,
    confidence_level,
    postcode,
    city,
    website,
    array_to_string(matched_keywords, '; ') as keywords,
    source_table,
    '${ITERATION}' as iteration_id
  FROM aerospace_supplier_candidates
  ORDER BY aerospace_score DESC
) TO '${RESULTS_DIR}/full_results.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Full results: ${RESULTS_DIR}/full_results.csv"
echo ""

# ==============================================================================
# STEP 6: Compare to Previous Iteration (if exists)
# ==============================================================================
echo -e "${YELLOW}[STEP 6]${NC} Compare to previous iteration..."

PREV_ITERATION=$(ls -t iterations/ | grep -v $(basename $RESULTS_DIR) | head -1)

if [ ! -z "$PREV_ITERATION" ]; then
    echo "Previous iteration found: $PREV_ITERATION"
    
    PREV_METRICS="iterations/${PREV_ITERATION}/baseline_metrics.txt"
    if [ -f "$PREV_METRICS" ]; then
        echo "" > "${RESULTS_DIR}/comparison.txt"
        echo "COMPARISON TO PREVIOUS ITERATION" >> "${RESULTS_DIR}/comparison.txt"
        echo "=================================" >> "${RESULTS_DIR}/comparison.txt"
        echo "" >> "${RESULTS_DIR}/comparison.txt"
        echo "Previous (${PREV_ITERATION}):" >> "${RESULTS_DIR}/comparison.txt"
        cat "$PREV_METRICS" >> "${RESULTS_DIR}/comparison.txt"
        echo "" >> "${RESULTS_DIR}/comparison.txt"
        echo "Current (${ITERATION}):" >> "${RESULTS_DIR}/comparison.txt"
        cat "${RESULTS_DIR}/baseline_metrics.txt" >> "${RESULTS_DIR}/comparison.txt"
        
        echo -e "${GREEN}✓${NC} Comparison: ${RESULTS_DIR}/comparison.txt"
        cat "${RESULTS_DIR}/comparison.txt"
    fi
else
    echo "No previous iteration found (this is the first run)"
fi

echo ""

# ==============================================================================
# STEP 7: Generate Summary Report
# ==============================================================================
echo -e "${YELLOW}[STEP 7]${NC} Generate summary report..."

cat > "${RESULTS_DIR}/SUMMARY.txt" <<EOF
=================================================================
ITERATION SUMMARY: ${ITERATION}
=================================================================

FILES GENERATED:
- baseline_metrics.txt      : Current performance metrics
- opportunities.txt          : Improvement opportunities identified
- ab_test_results.txt        : Impact of threshold changes
- recommendations.md         : Actionable recommendations
- full_results.csv           : Complete candidate export
- tier1_keywords.csv         : High-value keywords extracted
- comparison.txt             : Comparison to previous run (if available)

QUICK STATS:
$(cat ${RESULTS_DIR}/baseline_metrics.txt)

TOP RECOMMENDATIONS:
$(head -n 30 ${RESULTS_DIR}/recommendations.md | tail -n 20)

NEXT STEPS:
1. Review ${RESULTS_DIR}/recommendations.md
2. Manually validate 20-30 Tier 1 candidates
3. Update scoring.yaml with new keywords/filters
4. Re-run pipeline: bash 07_run_all_pipelines.sh
5. Run this script again to measure improvement

=================================================================
EOF

cat "${RESULTS_DIR}/SUMMARY.txt"

echo ""
echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}✓ ITERATION ${ITERATION} COMPLETE${NC}"
echo -e "${CYAN}======================================================${NC}"
echo ""
echo "All results saved to: ${RESULTS_DIR}/"
echo ""
echo "Review the recommendations and update your scoring configuration."
echo "Then re-run the pipeline to measure improvement."
echo ""