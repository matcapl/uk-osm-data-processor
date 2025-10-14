#!/bin/bash
# Weekly Intelligence Report Generator
# Automatically generates executive summary and actionable insights

set -e

DB_NAME="uk_osm_full"
DB_USER="a"
DB_HOST="localhost"
DB_PORT="5432"

REPORT_DATE=$(date +%Y-%m-%d)
REPORT_DIR="./reports/weekly"
REPORT_FILE="${REPORT_DIR}/aerospace_intel_${REPORT_DATE}.md"

mkdir -p "$REPORT_DIR"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Generating Weekly Intelligence Report...${NC}"

# ==============================================================================
# Generate Report
# ==============================================================================

cat > "$REPORT_FILE" <<EOF
# UK Aerospace Supplier Intelligence Report
**Generated:** ${REPORT_DATE}  
**Database:** ${DB_NAME}  
**Coverage:** Great Britain

---

## Executive Summary

EOF

# Get summary metrics
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -F'|' >> "$REPORT_FILE" <<'SQL'
SELECT '- **Total Candidates:** ' || COUNT(*) FROM aerospace_supplier_candidates
UNION ALL
SELECT '- **Tier 1 (High Confidence):** ' || COUNT(*) || ' (' || ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM aerospace_supplier_candidates)) || '%)' 
FROM aerospace_supplier_candidates WHERE tier_classification = 'tier1_candidate'
UNION ALL
SELECT '- **Tier 2 (Target Segment):** ' || COUNT(*) || ' (' || ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM aerospace_supplier_candidates)) || '%)' 
FROM aerospace_supplier_candidates WHERE tier_classification = 'tier2_candidate'
UNION ALL
SELECT '- **With Contact Information:** ' || COUNT(*) || ' (' || ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM aerospace_supplier_candidates)) || '%)' 
FROM aerospace_supplier_candidates WHERE website IS NOT NULL OR phone IS NOT NULL
UNION ALL
SELECT '- **Geographic Coverage:** ' || COUNT(DISTINCT LEFT(postcode, 2)) || ' postcode areas' 
FROM aerospace_supplier_candidates WHERE postcode IS NOT NULL
UNION ALL
SELECT '- **Average Confidence Score:** ' || ROUND(AVG(aerospace_score)) 
FROM aerospace_supplier_candidates;
SQL

cat >> "$REPORT_FILE" <<'EOF'

---

## 🎯 Priority Actions This Week

### 1. Immediate Outreach Targets (Top 10)

High-confidence aerospace suppliers ready for contact:

EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "$REPORT_FILE" <<'SQL'
SELECT 
  '**' || ROW_NUMBER() OVER (ORDER BY aerospace_score DESC) || '. ' || name || '**  ' ||
  CHR(10) || '   - Score: ' || aerospace_score || ' | ' ||
  COALESCE('Website: ' || website, 'No website') || '  ' ||
  CHR(10) || '   - Location: ' || COALESCE(city, 'Unknown') || ' (' || COALESCE(postcode, 'No postcode') || ')  ' ||
  CHR(10)
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 120
  AND (website IS NOT NULL OR phone IS NOT NULL)
ORDER BY aerospace_score DESC
LIMIT 10;
SQL

cat >> "$REPORT_FILE" <<'EOF'

### 2. Research Required (High Potential, Missing Contact)

EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "$REPORT_FILE" <<'SQL'
SELECT 
  '- **' || name || '** (Score: ' || aerospace_score || ') - ' ||
  COALESCE(city, 'Unknown location') || '  ' ||
  CHR(10) || '  → Google: "' || name || ' ' || COALESCE(city, '') || ' aerospace"'
FROM aerospace_supplier_candidates
WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
  AND website IS NULL
  AND phone IS NULL
ORDER BY aerospace_score DESC
LIMIT 10;
SQL

cat >> "$REPORT_FILE" <<'EOF'

---

## 📊 Geographic Intelligence

### Top 5 Aerospace Clusters

EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "$REPORT_FILE" <<'SQL'
SELECT 
  '**' || LEFT(postcode, 2) || '** - ' || COUNT(*) || ' candidates (Avg score: ' || 
  ROUND(AVG(aerospace_score)) || ') - ' ||
  COUNT(*) FILTER (WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')) || ' high quality'
FROM aerospace_supplier_candidates
WHERE postcode IS NOT NULL
GROUP BY LEFT(postcode, 2)
ORDER BY COUNT(*) DESC
LIMIT 5;
SQL

cat >> "$REPORT_FILE" <<'EOF'

### Cluster Analysis

| Region | Total | Tier 1 | Tier 2 | Avg Score | Status |
|--------|-------|--------|--------|-----------|--------|
EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -F'|' >> "$REPORT_FILE" <<'SQL'
SELECT 
  '| ' || LEFT(postcode, 2) || ' | ' ||
  COUNT(*) || ' | ' ||
  COUNT(*) FILTER (WHERE tier_classification = 'tier1_candidate') || ' | ' ||
  COUNT(*) FILTER (WHERE tier_classification = 'tier2_candidate') || ' | ' ||
  ROUND(AVG(aerospace_score)) || ' | ' ||
  CASE 
    WHEN LEFT(postcode, 2) IN ('BS', 'GL', 'DE', 'PR', 'BA') THEN '⭐ Primary'
    WHEN LEFT(postcode, 2) IN ('CB', 'SO', 'BT', 'LE') THEN '★ Secondary'
    ELSE 'Emerging'
  END || ' |'
FROM aerospace_supplier_candidates
WHERE postcode IS NOT NULL
GROUP BY LEFT(postcode, 2)
HAVING COUNT(*) >= 5
ORDER BY COUNT(*) DESC
LIMIT 15;
SQL

cat >> "$REPORT_FILE" <<'EOF'

---

## 🔍 Quality Insights

### Score Distribution

EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "$REPORT_FILE" <<'SQL'
SELECT 
  '- **' ||
  CASE 
    WHEN aerospace_score >= 200 THEN '200+ (Definitive)'
    WHEN aerospace_score >= 150 THEN '150-199 (Tier 1)'
    WHEN aerospace_score >= 100 THEN '100-149 (Strong Tier 2)'
    WHEN aerospace_score >= 80 THEN '80-99 (Tier 2)'
    WHEN aerospace_score >= 60 THEN '60-79 (Potential)'
    ELSE '40-59 (Review)'
  END || ':** ' || COUNT(*) || ' candidates (' || 
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER()) || '%)'
FROM aerospace_supplier_candidates
GROUP BY 
  CASE 
    WHEN aerospace_score >= 200 THEN 1
    WHEN aerospace_score >= 150 THEN 2
    WHEN aerospace_score >= 100 THEN 3
    WHEN aerospace_score >= 80 THEN 4
    WHEN aerospace_score >= 60 THEN 5
    ELSE 6
  END
ORDER BY 1;
SQL

cat >> "$REPORT_FILE" <<'EOF'

### Data Completeness

EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "$REPORT_FILE" <<'SQL'
WITH metrics AS (
  SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE website IS NOT NULL) as has_web,
    COUNT(*) FILTER (WHERE phone IS NOT NULL) as has_phone,
    COUNT(*) FILTER (WHERE postcode IS NOT NULL) as has_postcode,
    COUNT(*) FILTER (WHERE city IS NOT NULL) as has_city
  FROM aerospace_supplier_candidates
)
SELECT 
  '- **Website:** ' || ROUND(100.0 * has_web / total) || '% (' || has_web || '/' || total || ')'
FROM metrics
UNION ALL
SELECT '- **Phone:** ' || ROUND(100.0 * has_phone / total) || '% (' || has_phone || '/' || total || ')' FROM metrics
UNION ALL
SELECT '- **Postcode:** ' || ROUND(100.0 * has_postcode / total) || '% (' || has_postcode || '/' || total || ')' FROM metrics
UNION ALL
SELECT '- **City:** ' || ROUND(100.0 * has_city / total) || '% (' || has_city || '/' || total || ')' FROM metrics;
SQL

cat >> "$REPORT_FILE" <<'EOF'

---

## ⚠️ Quality Control Alerts

EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "$REPORT_FILE" <<'SQL'
WITH alerts AS (
  SELECT 
    'High scores but residential indicators' as alert,
    COUNT(*) as count
  FROM aerospace_supplier_candidates
  WHERE aerospace_score >= 100
    AND (building_type IN ('house', 'apartments', 'residential') OR landuse_type = 'residential')
  
  UNION ALL
  
  SELECT 
    'High scores but consumer keywords',
    COUNT(*)
  FROM aerospace_supplier_candidates
  WHERE aerospace_score >= 80
    AND LOWER(name) ~* '(cafe|restaurant|hotel|pub|retail)'
  
  UNION ALL
  
  SELECT 
    'Tier 1 without any contact info',
    COUNT(*)
  FROM aerospace_supplier_candidates
  WHERE tier_classification = 'tier1_candidate'
    AND website IS NULL
    AND phone IS NULL
)
SELECT '- **' || alert || ':** ' || count || ' cases'
FROM alerts
WHERE count > 0;
SQL

cat >> "$REPORT_FILE" <<'EOF'

---

## 📈 Trending Keywords

Top keywords in high-confidence candidates:

EOF

psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t >> "$REPORT_FILE" <<'SQL'
WITH keyword_freq AS (
  SELECT 
    UNNEST(matched_keywords) as kw,
    aerospace_score
  FROM aerospace_supplier_candidates
  WHERE matched_keywords IS NOT NULL
    AND tier_classification IN ('tier1_candidate', 'tier2_candidate')
)
SELECT '- **' || kw || '** (' || COUNT(*) || ' mentions, avg score: ' || ROUND(AVG(aerospace_score)) || ')'
FROM keyword_freq
GROUP BY kw
HAVING COUNT(*) >= 3
ORDER BY AVG(aerospace_score) DESC, COUNT(*) DESC
LIMIT 15;
SQL

cat >> "$REPORT_FILE" <<'EOF'

---

## 🎬 Next Steps

### This Week's Focus:

1. **Outreach:** Contact top 10 priority targets listed above
2. **Research:** Fill in missing contact info for high-score candidates
3. **Validation:** Manually verify 20 random Tier 2 candidates
4. **Geographic:** Deep-dive into top 3 clusters for co-location patterns

### Data Improvement:

- Add Companies House SIC code matching
- Implement certification keyword detection (AS9100, NADCAP)
- Enhance postcode-based clustering analysis
- Cross-reference with ADS membership directory

### Quality Monitoring:

- Review and resolve quality control alerts
- Update negative filters for false positives
- Refine geographic bonuses based on cluster performance

---

## 📁 Data Files

Generated exports available in `./exports/`:
- `all_candidates_[date].csv` - Complete candidate list
- `tier1_candidates_[date].csv` - High-priority targets
- `tier2_candidates_[date].csv` - Core target segment
- `validation_sample_[date].csv` - Random sample for quality checks

---

**Report End**  
*For questions or custom analysis, run: `psql -d uk_osm_full -f power_user_queries.sql`*
EOF

# ==============================================================================
# Generate accompanying CSV exports
# ==============================================================================

echo -e "${BLUE}Generating export files...${NC}"

# Top 50 for outreach
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL >/dev/null
\copy (
  SELECT 
    name, aerospace_score, tier_classification,
    website, phone, postcode, city,
    array_to_string(matched_keywords, '; ') as keywords
  FROM aerospace_supplier_candidates
  WHERE aerospace_score >= 100
    AND (website IS NOT NULL OR phone IS NOT NULL)
  ORDER BY aerospace_score DESC
  LIMIT 50
) TO '${REPORT_DIR}/weekly_outreach_targets_${REPORT_DATE}.csv' WITH CSV HEADER;
SQL

# Research targets
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL >/dev/null
\copy (
  SELECT 
    name, aerospace_score, tier_classification,
    postcode, city,
    'https://www.google.com/search?q=' || REPLACE(name, ' ', '+') || '+' || COALESCE(city, '') || '+aerospace' as google_search
  FROM aerospace_supplier_candidates
  WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
    AND website IS NULL
  ORDER BY aerospace_score DESC
  LIMIT 100
) TO '${REPORT_DIR}/weekly_research_needed_${REPORT_DATE}.csv' WITH CSV HEADER;
SQL

# Quality control issues
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<SQL >/dev/null
\copy (
  SELECT 
    name, aerospace_score, tier_classification,
    building_type, landuse_type, postcode,
    CASE 
      WHEN building_type IN ('house', 'apartments', 'residential') THEN 'Residential building'
      WHEN landuse_type = 'residential' THEN 'Residential landuse'
      WHEN LOWER(name) ~* '(cafe|restaurant|hotel|pub)' THEN 'Consumer keyword in name'
      WHEN website IS NULL AND phone IS NULL THEN 'No contact info'
      ELSE 'Review needed'
    END as issue
  FROM aerospace_supplier_candidates
  WHERE (
    (aerospace_score >= 80 AND (building_type IN ('house', 'apartments', 'residential') OR landuse_type = 'residential'))
    OR (aerospace_score >= 80 AND LOWER(name) ~* '(cafe|restaurant|hotel|pub|retail)')
    OR (tier_classification = 'tier1_candidate' AND website IS NULL AND phone IS NULL)
  )
  ORDER BY aerospace_score DESC
) TO '${REPORT_DIR}/weekly_quality_review_${REPORT_DATE}.csv' WITH CSV HEADER;
SQL

echo -e "${GREEN}✓${NC} Report generated: ${REPORT_FILE}"
echo -e "${GREEN}✓${NC} Outreach targets: ${REPORT_DIR}/weekly_outreach_targets_${REPORT_DATE}.csv"
echo -e "${GREEN}✓${NC} Research needed: ${REPORT_DIR}/weekly_research_needed_${REPORT_DATE}.csv"
echo -e "${GREEN}✓${NC} Quality review: ${REPORT_DIR}/weekly_quality_review_${REPORT_DATE}.csv"

# ==============================================================================
# Convert to HTML (optional, if pandoc installed)
# ==============================================================================

if command -v pandoc &> /dev/null; then
    echo ""
    echo -e "${BLUE}Converting to HTML...${NC}"
    pandoc "$REPORT_FILE" -o "${REPORT_FILE%.md}.html" \
        --standalone \
        --css=https://cdn.jsdelivr.net/npm/water.css@2/out/water.css \
        --metadata title="UK Aerospace Supplier Intelligence Report"
    echo -e "${GREEN}✓${NC} HTML report: ${REPORT_FILE%.md}.html"
fi

# ==============================================================================
# Print summary to console
# ==============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}WEEKLY REPORT SUMMARY${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Quick metrics
TOTAL=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_supplier_candidates;")
TIER1=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE tier_classification = 'tier1_candidate';")
TIER2=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE tier_classification = 'tier2_candidate';")
READY=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE aerospace_score >= 100 AND (website IS NOT NULL OR phone IS NOT NULL);")

echo "Total Candidates: $TOTAL"
echo "Tier 1: $TIER1"
echo "Tier 2: $TIER2"
echo "Ready for Outreach: $READY"
echo ""
echo "📄 Full Report: ${REPORT_FILE}"
echo ""
echo "Next: Review the markdown report or open the HTML version in your browser."
echo ""