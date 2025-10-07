-- ============================================================================
-- DIAGNOSTIC QUERIES - Run these to find why you're getting 0 candidates
-- ============================================================================
-- Run with: psql -d uk_osm_full -f diagnose_pipeline.sql

\echo '========================================'
\echo 'DIAGNOSTIC 1: Check Source Tables'
\echo '========================================'

-- Do the source tables have data?
SELECT 'planet_osm_polygon' as table_name, COUNT(*) as total_rows FROM planet_osm_polygon
UNION ALL
SELECT 'planet_osm_point', COUNT(*) FROM planet_osm_point
UNION ALL
SELECT 'planet_osm_line', COUNT(*) FROM planet_osm_line
UNION ALL
SELECT 'planet_osm_roads', COUNT(*) FROM planet_osm_roads;

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 2: Sample Industrial Features'
\echo '========================================'

-- Show sample of industrial/manufacturing features
SELECT 
  osm_id,
  name,
  landuse,
  building,
  industrial,
  office,
  amenity,
  tags->'craft' as craft
FROM planet_osm_polygon
WHERE (
  landuse = 'industrial'
  OR building IN ('industrial', 'warehouse', 'factory', 'manufacture')
  OR industrial IS NOT NULL
  OR office IN ('company', 'engineering')
)
LIMIT 10;

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 3: Check for Aerospace Keywords'
\echo '========================================'

-- Are there ANY features with aerospace keywords?
SELECT 
  'Direct aerospace in name' as check_type,
  COUNT(*) as count
FROM planet_osm_polygon
WHERE LOWER(COALESCE(name, '')) ~ '(aerospace|aviation|aircraft)'

UNION ALL

SELECT 
  'Has "engineering" in name',
  COUNT(*)
FROM planet_osm_polygon
WHERE LOWER(COALESCE(name, '')) LIKE '%engineering%'

UNION ALL

SELECT 
  'Has industrial landuse',
  COUNT(*)
FROM planet_osm_polygon
WHERE landuse = 'industrial'

UNION ALL

SELECT 
  'Has industrial building',
  COUNT(*)
FROM planet_osm_polygon
WHERE building IN ('industrial', 'warehouse', 'factory');

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 4: Check Filtered Views'
\echo '========================================'

-- Do the filtered views exist and have data?
SELECT 
  'planet_osm_polygon_aerospace_filtered' as view_name,
  CASE WHEN COUNT(*) > 0 THEN 'EXISTS' ELSE 'MISSING' END as status,
  COUNT(*) as row_count
FROM planet_osm_polygon_aerospace_filtered
WHERE EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'planet_osm_polygon_aerospace_filtered')

UNION ALL

SELECT 
  'planet_osm_point_aerospace_filtered',
  CASE WHEN COUNT(*) > 0 THEN 'EXISTS' ELSE 'MISSING' END,
  COUNT(*)
FROM planet_osm_point_aerospace_filtered
WHERE EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'planet_osm_point_aerospace_filtered');

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 5: Check Scored Views'
\echo '========================================'

-- Do scored views exist?
SELECT 
  viewname as view_name,
  definition as view_definition_preview
FROM pg_views
WHERE viewname LIKE '%aerospace_scored'
ORDER BY viewname;

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 6: Manual Score Calculation'
\echo '========================================'

-- Let's manually calculate scores for a sample
SELECT 
  osm_id,
  name,
  landuse,
  building,
  industrial,
  -- Manual score calculation (simplified)
  (
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(aerospace|aviation|aircraft)' THEN 100 ELSE 0 END +
    CASE WHEN LOWER(COALESCE(name, '')) ~ '(engineering|precision|technology)' THEN 70 ELSE 0 END +
    CASE WHEN landuse = 'industrial' THEN 40 ELSE 0 END +
    CASE WHEN building IN ('industrial', 'warehouse', 'factory') THEN 40 ELSE 0 END +
    CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END
  ) AS manual_score
FROM planet_osm_polygon
WHERE (
  landuse = 'industrial'
  OR building IN ('industrial', 'warehouse', 'factory')
  OR industrial IS NOT NULL
  OR LOWER(COALESCE(name, '')) ~ '(engineering|manufacturing|precision)'
)
AND name IS NOT NULL
LIMIT 20;

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 7: Check Scored View Contents'
\echo '========================================'

-- If scored views exist, what's in them?
SELECT 
  COUNT(*) as total_in_scored_view,
  COUNT(*) FILTER (WHERE aerospace_score >= 40) as above_threshold,
  COUNT(*) FILTER (WHERE aerospace_score >= 80) as tier2_or_better,
  COUNT(*) FILTER (WHERE aerospace_score >= 150) as tier1,
  MIN(aerospace_score) as min_score,
  MAX(aerospace_score) as max_score,
  ROUND(AVG(aerospace_score)) as avg_score
FROM planet_osm_polygon_aerospace_scored;

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 8: Sample High Scorers'
\echo '========================================'

-- Show top scoring features (if any)
SELECT 
  osm_id,
  name,
  aerospace_score,
  landuse,
  building,
  industrial,
  office
FROM planet_osm_polygon_aerospace_scored
ORDER BY aerospace_score DESC
LIMIT 10;

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 9: Check Why Features Fail Threshold'
\echo '========================================'

-- Show features that score but fail the threshold
SELECT 
  COUNT(*) as total_scored,
  COUNT(*) FILTER (WHERE aerospace_score < 40) as below_threshold,
  COUNT(*) FILTER (WHERE aerospace_score = 0) as zero_score,
  COUNT(*) FILTER (WHERE name IS NULL) as no_name,
  COUNT(*) FILTER (WHERE name IS NULL AND aerospace_score >= 40) as no_name_but_high_score
FROM planet_osm_polygon_aerospace_scored;

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 10: Check Staging Tables'
\echo '========================================'

-- Do staging tables exist and have data?
SELECT 
  'aerospace_candidates_polygon' as table_name,
  COUNT(*) as row_count
FROM aerospace_candidates_polygon
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'aerospace_candidates_polygon')

UNION ALL

SELECT 
  'aerospace_candidates_point',
  COUNT(*)
FROM aerospace_candidates_point
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'aerospace_candidates_point')

UNION ALL

SELECT 
  'aerospace_supplier_candidates (FINAL)',
  COUNT(*)
FROM aerospace_supplier_candidates
WHERE EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'aerospace_supplier_candidates');

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 11: Check Tags Structure'
\echo '========================================'

-- Verify tags column is hstore and has data
SELECT 
  'Tags column type' as check_type,
  data_type as value
FROM information_schema.columns
WHERE table_name = 'planet_osm_polygon'
  AND column_name = 'tags'

UNION ALL

SELECT 
  'Sample tags content',
  LEFT(tags::text, 100)
FROM planet_osm_polygon
WHERE tags IS NOT NULL
LIMIT 1;

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC 12: Test Regex Patterns'
\echo '========================================'

-- Test if our regex patterns work
SELECT 
  'Regex test: aerospace' as test,
  COUNT(*) as matches
FROM planet_osm_polygon
WHERE LOWER(COALESCE(name, '')) ~ 'aerospace'

UNION ALL

SELECT 
  'Regex test: engineering',
  COUNT(*)
FROM planet_osm_polygon
WHERE LOWER(COALESCE(name, '')) ~ 'engineering'

UNION ALL

SELECT 
  'Regex test: precision',
  COUNT(*)
FROM planet_osm_polygon
WHERE LOWER(COALESCE(name, '')) ~ 'precision'

UNION ALL

SELECT 
  'LIKE test: engineering',
  COUNT(*)
FROM planet_osm_polygon
WHERE LOWER(COALESCE(name, '')) LIKE '%engineering%';

\echo ''
\echo '========================================'
\echo 'DIAGNOSTIC COMPLETE'
\echo '========================================'
\echo ''
\echo 'Next steps based on results:'
\echo '  - If source tables empty: Data import issue'
\echo '  - If filtered views empty: Exclusion filters too aggressive'
\echo '  - If scored views have data but staging empty: INSERT issue'
\echo '  - If scores all below 40: Scoring rules need adjustment'
\echo ''