-- ============================================================================
-- POWER USER QUERIES - Advanced Analysis for Aerospace Scoring
-- ============================================================================
-- Save as: power_user_queries.sql
-- Usage: psql -d uk_osm_full -f power_user_queries.sql

\timing on
\pset border 2

\echo ''
\echo '========================================================================'
\echo 'AEROSPACE SUPPLIER INTELLIGENCE DASHBOARD'
\echo '========================================================================'
\echo ''

-- ============================================================================
-- 1. EXECUTIVE SUMMARY
-- ============================================================================
\echo '1. EXECUTIVE SUMMARY'
\echo '--------------------'

WITH summary AS (
  SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE tier_classification = 'tier1_candidate') as tier1,
    COUNT(*) FILTER (WHERE tier_classification = 'tier2_candidate') as tier2,
    COUNT(*) FILTER (WHERE tier_classification = 'potential_candidate') as potential,
    COUNT(*) FILTER (WHERE website IS NOT NULL) as with_website,
    COUNT(*) FILTER (WHERE phone IS NOT NULL) as with_phone,
    COUNT(*) FILTER (WHERE website IS NOT NULL AND phone IS NOT NULL) as full_contact,
    ROUND(AVG(aerospace_score)) as avg_score,
    MAX(aerospace_score) as max_score,
    COUNT(DISTINCT LEFT(postcode, 2)) FILTER (WHERE postcode IS NOT NULL) as regions_covered
  FROM aerospace_supplier_candidates
)
SELECT 
  'Total Candidates' as metric, total::text as value FROM summary
UNION ALL SELECT 'Tier 1 (≥150)', tier1 || ' (' || ROUND(100.0 * tier1 / total) || '%)' FROM summary
UNION ALL SELECT 'Tier 2 (80-149)', tier2 || ' (' || ROUND(100.0 * tier2 / total) || '%)' FROM summary
UNION ALL SELECT 'Potential (40-79)', potential || ' (' || ROUND(100.0 * potential / total) || '%)' FROM summary
UNION ALL SELECT 'With Website', with_website || ' (' || ROUND(100.0 * with_website / total) || '%)' FROM summary
UNION ALL SELECT 'With Phone', with_phone || ' (' || ROUND(100.0 * with_phone / total) || '%)' FROM summary
UNION ALL SELECT 'Full Contact', full_contact || ' (' || ROUND(100.0 * full_contact / total) || '%)' FROM summary
UNION ALL SELECT 'Average Score', avg_score::text FROM summary
UNION ALL SELECT 'Max Score', max_score::text FROM summary
UNION ALL SELECT 'Regions Covered', regions_covered::text FROM summary;

-- ============================================================================
-- 2. TOP 20 PRIORITY TARGETS (Immediate Outreach)
-- ============================================================================
\echo ''
\echo '2. TOP 20 PRIORITY TARGETS'
\echo '---------------------------'
\echo 'High-confidence candidates with contact information ready for outreach'
\echo ''

SELECT 
  ROW_NUMBER() OVER (ORDER BY aerospace_score DESC) as rank,
  LEFT(name, 45) as company_name,
  aerospace_score as score,
  tier_classification as tier,
  COALESCE(LEFT(website, 35), 'NO WEBSITE') as website,
  COALESCE(LEFT(phone, 15), 'NO PHONE') as phone,
  postcode,
  LEFT(city, 15) as city
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 100
  AND (website IS NOT NULL OR phone IS NOT NULL)
ORDER BY aerospace_score DESC
LIMIT 20;

-- ============================================================================
-- 3. GEOGRAPHIC HEATMAP (Aerospace Clusters)
-- ============================================================================
\echo ''
\echo '3. GEOGRAPHIC HEATMAP'
\echo '---------------------'
\echo 'Aerospace candidate density by postcode area'
\echo ''

SELECT 
  LEFT(postcode, 2) as region,
  COUNT(*) as total_candidates,
  COUNT(*) FILTER (WHERE tier_classification = 'tier1_candidate') as tier1,
  COUNT(*) FILTER (WHERE tier_classification = 'tier2_candidate') as tier2,
  COUNT(*) FILTER (WHERE aerospace_score >= 150) as score_150_plus,
  ROUND(AVG(aerospace_score)) as avg_score,
  MAX(aerospace_score) as max_score,
  COUNT(*) FILTER (WHERE website IS NOT NULL)::float / COUNT(*) * 100 as pct_with_web,
  CASE 
    WHEN LEFT(postcode, 2) IN ('BS', 'GL') THEN '⭐ Primary (Bristol/Filton)'
    WHEN LEFT(postcode, 2) IN ('DE') THEN '⭐ Primary (Derby)'
    WHEN LEFT(postcode, 2) IN ('PR', 'BA') THEN '⭐ Primary (Preston/Yeovil)'
    WHEN LEFT(postcode, 2) IN ('CB', 'SO', 'BT') THEN '★ Secondary'
    ELSE '· Emerging'
  END as cluster_status
FROM aerospace_supplier_candidates
WHERE postcode IS NOT NULL
GROUP BY LEFT(postcode, 2)
HAVING COUNT(*) >= 3
ORDER BY total_candidates DESC, avg_score DESC
LIMIT 25;

-- ============================================================================
-- 4. SCORE DISTRIBUTION ANALYSIS
-- ============================================================================
\echo ''
\echo '4. SCORE DISTRIBUTION'
\echo '---------------------'

SELECT 
  CASE 
    WHEN aerospace_score >= 250 THEN '250+ (Definitive Prime)'
    WHEN aerospace_score >= 200 THEN '200-249 (Prime Contractor)'
    WHEN aerospace_score >= 150 THEN '150-199 (Tier 1)'
    WHEN aerospace_score >= 120 THEN '120-149 (Strong Tier 2)'
    WHEN aerospace_score >= 100 THEN '100-119 (Tier 2)'
    WHEN aerospace_score >= 80 THEN '80-99 (Tier 2 Lower)'
    WHEN aerospace_score >= 60 THEN '60-79 (Potential)'
    WHEN aerospace_score >= 40 THEN '40-59 (Review)'
    ELSE 'Below 40'
  END as score_range,
  COUNT(*) as count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) as percentage,
  REPEAT('█', (COUNT(*) * 50 / MAX(COUNT(*)) OVER())::int) as distribution
FROM aerospace_supplier_candidates
GROUP BY score_range
ORDER BY MIN(aerospace_score) DESC;

-- ============================================================================
-- 5. KEYWORD INTELLIGENCE (What Works)
-- ============================================================================
\echo ''
\echo '5. KEYWORD INTELLIGENCE'
\echo '-----------------------'
\echo 'Most effective keywords in high-scoring candidates'
\echo ''

WITH keywords_expanded AS (
  SELECT 
    UNNEST(matched_keywords) as keyword,
    aerospace_score,
    tier_classification
  FROM aerospace_supplier_candidates
  WHERE matched_keywords IS NOT NULL
    AND array_length(matched_keywords, 1) > 0
)
SELECT 
  keyword,
  COUNT(*) as frequency,
  ROUND(AVG(aerospace_score)) as avg_score,
  COUNT(*) FILTER (WHERE tier_classification = 'tier1_candidate') as tier1_hits,
  COUNT(*) FILTER (WHERE tier_classification = 'tier2_candidate') as tier2_hits,
  ROUND(AVG(aerospace_score) FILTER (WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate'))) as avg_score_t1_t2
FROM keywords_expanded
GROUP BY keyword
HAVING COUNT(*) >= 5
ORDER BY avg_score_t1_t2 DESC NULLS LAST, frequency DESC
LIMIT 20;

-- ============================================================================
-- 6. MISSING CONTACT INFO (Research Opportunities)
-- ============================================================================
\echo ''
\echo '6. HIGH-VALUE TARGETS WITHOUT CONTACT INFO'
\echo '-------------------------------------------'
\echo 'Tier 1/2 candidates needing website/phone research'
\echo ''

SELECT 
  LEFT(name, 50) as company_name,
  aerospace_score as score,
  tier_classification as tier,
  postcode,
  city,
  CASE 
    WHEN website IS NULL AND phone IS NULL THEN '⚠ Need Both'
    WHEN website IS NULL THEN '⚠ Need Website'
    WHEN phone IS NULL THEN '⚠ Need Phone'
  END as missing_info,
  'Google: "' || name || ' ' || COALESCE(city, '') || ' aerospace"' as search_query
FROM aerospace_supplier_candidates
WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
  AND (website IS NULL OR phone IS NULL)
ORDER BY aerospace_score DESC
LIMIT 30;

-- ============================================================================
-- 7. SUSPICIOUS RECORDS (Quality Control)
-- ============================================================================
\echo ''
\echo '7. SUSPICIOUS RECORDS NEEDING REVIEW'
\echo '-------------------------------------'

SELECT 
  'High Score + Residential' as flag,
  COUNT(*) as count,
  string_agg(DISTINCT LEFT(name, 30), '; ' ORDER BY LEFT(name, 30)) as examples
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 80
  AND (building_type IN ('house', 'apartments', 'residential') 
       OR landuse_type = 'residential')
GROUP BY flag

UNION ALL

SELECT 
  'High Score + Consumer Keywords',
  COUNT(*),
  string_agg(DISTINCT LEFT(name, 30), '; ' ORDER BY LEFT(name, 30))
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 80
  AND LOWER(name) ~* '(cafe|restaurant|hotel|pub|retail|shop|gym)'
GROUP BY flag

UNION ALL

SELECT 
  'Score >150 + No Contact',
  COUNT(*),
  string_agg(DISTINCT LEFT(name, 30), '; ' ORDER BY LEFT(name, 30))
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 150
  AND website IS NULL
  AND phone IS NULL
GROUP BY flag

UNION ALL

SELECT 
  'Tier 1 + Generic Name',
  COUNT(*),
  string_agg(DISTINCT LEFT(name, 30), '; ' ORDER BY LEFT(name, 30))
FROM aerospace_supplier_candidates
WHERE tier_classification = 'tier1_candidate'
  AND name ~* '^(unit|building|warehouse|estate)'
GROUP BY flag;

-- ============================================================================
-- 8. SUPPLY CHAIN CLUSTERING (Co-location Analysis)
-- ============================================================================
\echo ''
\echo '8. AEROSPACE CLUSTERS (Co-located Suppliers)'
\echo '---------------------------------------------'
\echo 'Industrial areas with multiple aerospace candidates'
\echo ''

WITH postcode_clusters AS (
  SELECT 
    LEFT(postcode, 4) as postcode_area,
    COUNT(*) as supplier_count,
    ROUND(AVG(aerospace_score)) as avg_score,
    MAX(aerospace_score) as max_score,
    COUNT(*) FILTER (WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')) as high_quality_count,
    string_agg(DISTINCT LEFT(name, 25), '; ' ORDER BY aerospace_score DESC) as top_companies
  FROM aerospace_supplier_candidates
  WHERE postcode IS NOT NULL
  GROUP BY LEFT(postcode, 4)
  HAVING COUNT(*) >= 3
)
SELECT 
  postcode_area,
  supplier_count as candidates,
  high_quality_count as tier1_2,
  avg_score,
  max_score,
  top_companies
FROM postcode_clusters
ORDER BY high_quality_count DESC, supplier_count DESC
LIMIT 20;

-- ============================================================================
-- 9. EXPORT-READY LISTS (For CRM/Outreach)
-- ============================================================================
\echo ''
\echo '9. TIER 1 READY FOR IMMEDIATE OUTREACH'
\echo '---------------------------------------'

SELECT 
  name as "Company Name",
  aerospace_score as "Score",
  confidence_level as "Confidence",
  website as "Website",
  phone as "Phone",
  postcode as "Postcode",
  city as "City",
  array_to_string(matched_keywords, ', ') as "Keywords"
FROM aerospace_supplier_candidates
WHERE tier_classification = 'tier1_candidate'
  AND (website IS NOT NULL OR phone IS NOT NULL)
ORDER BY aerospace_score DESC
LIMIT 50;

-- ============================================================================
-- 10. COMPARATIVE BENCHMARKS
-- ============================================================================
\echo ''
\echo '10. PERFORMANCE BENCHMARKS'
\echo '--------------------------'

SELECT 
  source_table as "Source",
  COUNT(*) as "Total",
  COUNT(*) FILTER (WHERE tier_classification = 'tier1_candidate') as "Tier 1",
  COUNT(*) FILTER (WHERE tier_classification = 'tier2_candidate') as "Tier 2",
  ROUND(AVG(aerospace_score)) as "Avg Score",
  MAX(aerospace_score) as "Max Score",
  ROUND(100.0 * COUNT(*) FILTER (WHERE website IS NOT NULL) / COUNT(*)) as "% Web"
FROM aerospace_supplier_candidates
GROUP BY source_table
ORDER BY COUNT(*) DESC;

-- ============================================================================
-- 11. ADVANCED: SCORE DECOMPOSITION
-- ============================================================================
\echo ''
\echo '11. SCORE DECOMPOSITION FOR TOP CANDIDATES'
\echo '-------------------------------------------'
\echo 'Understanding what drives high scores'
\echo ''

SELECT 
  LEFT(name, 40) as company,
  aerospace_score,
  CASE WHEN LOWER(name) ~ 'aerospace|aviation|aircraft' THEN '+100 Direct' ELSE '' END as direct_aero,
  CASE WHEN landuse_type = 'industrial' THEN '+40 Landuse' ELSE '' END as industrial,
  CASE WHEN building_type IN ('industrial', 'warehouse', 'factory') THEN '+40 Building' ELSE '' END as building,
  CASE WHEN LEFT(postcode, 2) IN ('BS', 'GL', 'DE', 'PR') THEN '+40 Cluster' ELSE '' END as geo_bonus,
  CASE WHEN website IS NOT NULL THEN '+10 Web' ELSE '' END as contact,
  matched_keywords as keywords
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 150
ORDER BY aerospace_score DESC
LIMIT 15;

-- ============================================================================
-- 12. TREND ANALYSIS (If you have historical data)
-- ============================================================================
\echo ''
\echo '12. DATA QUALITY METRICS'
\echo '------------------------'

WITH quality_metrics AS (
  SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE name IS NOT NULL) as has_name,
    COUNT(*) FILTER (WHERE postcode IS NOT NULL) as has_postcode,
    COUNT(*) FILTER (WHERE city IS NOT NULL) as has_city,
    COUNT(*) FILTER (WHERE website IS NOT NULL) as has_website,
    COUNT(*) FILTER (WHERE phone IS NOT NULL) as has_phone,
    COUNT(*) FILTER (WHERE matched_keywords IS NOT NULL AND array_length(matched_keywords, 1) > 0) as has_keywords,
    COUNT(*) FILTER (WHERE geometry IS NOT NULL) as has_geometry
  FROM aerospace_supplier_candidates
)
SELECT 
  'Name Completeness' as metric, 
  ROUND(100.0 * has_name / total, 1) || '%' as percentage,
  has_name || ' / ' || total as "Count"
FROM quality_metrics
UNION ALL
SELECT 'Postcode', ROUND(100.0 * has_postcode / total, 1) || '%', has_postcode || ' / ' || total FROM quality_metrics
UNION ALL
SELECT 'City', ROUND(100.0 * has_city / total, 1) || '%', has_city || ' / ' || total FROM quality_metrics
UNION ALL
SELECT 'Website', ROUND(100.0 * has_website / total, 1) || '%', has_website || ' / ' || total FROM quality_metrics
UNION ALL
SELECT 'Phone', ROUND(100.0 * has_phone / total, 1) || '%', has_phone || ' / ' || total FROM quality_metrics
UNION ALL
SELECT 'Keywords Matched', ROUND(100.0 * has_keywords / total, 1) || '%', has_keywords || ' / ' || total FROM quality_metrics
UNION ALL
SELECT 'Geometry', ROUND(100.0 * has_geometry / total, 1) || '%', has_geometry || ' / ' || total FROM quality_metrics;

\echo ''
\echo '========================================================================'
\echo 'DASHBOARD COMPLETE'
\echo '========================================================================'
\echo ''
\echo 'Next Actions:'
\echo '  1. Review Top 20 Priority Targets for immediate outreach'
\echo '  2. Research high-value candidates missing contact info'
\echo '  3. Investigate suspicious records'
\echo '  4. Focus on geographic clusters for deeper analysis'
\echo ''
\echo 'Export specific sections:'
\echo '  \\copy (SELECT * FROM ...) TO ''output.csv'' CSV HEADER;'
\echo ''