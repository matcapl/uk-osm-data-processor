-- Quick test: Can we find ANY candidates manually?
-- Run this to see if the problem is data, filters, or scoring

\echo '========================================'
\echo 'QUICK TEST: Manual Candidate Search'
\echo '========================================'
\echo ''

-- Test 1: Find features with "engineering" in the name
\echo 'Test 1: Features with "engineering" in name'
\echo '--------------------------------------------'
SELECT 
  osm_id,
  LEFT(name, 50) as name,
  landuse,
  building,
  "addr:postcode" as postcode
FROM planet_osm_polygon
WHERE LOWER(name) LIKE '%engineering%'
  AND name IS NOT NULL
LIMIT 5;

\echo ''
\echo 'Test 2: Industrial landuse features'
\echo '--------------------------------------------'
SELECT 
  osm_id,
  LEFT(name, 50) as name,
  landuse,
  building,
  "addr:postcode" as postcode
FROM planet_osm_polygon
WHERE landuse = 'industrial'
  AND name IS NOT NULL
LIMIT 5;

\echo ''
\echo 'Test 3: Industrial buildings'
\echo '--------------------------------------------'
SELECT 
  osm_id,
  LEFT(name, 50) as name,
  building,
  "addr:postcode" as postcode
FROM planet_osm_polygon
WHERE building IN ('industrial', 'warehouse', 'factory')
  AND name IS NOT NULL
LIMIT 5;

\echo ''
\echo 'Test 4: Calculate scores manually for industrial features'
\echo '--------------------------------------------'
SELECT 
  osm_id,
  LEFT(name, 40) as name,
  landuse,
  building,
  -- Simple manual score
  (
    CASE WHEN LOWER(name) LIKE '%aerospace%' THEN 100 ELSE 0 END +
    CASE WHEN LOWER(name) LIKE '%engineering%' THEN 70 ELSE 0 END +
    CASE WHEN LOWER(name) LIKE '%precision%' THEN 70 ELSE 0 END +
    CASE WHEN LOWER(name) LIKE '%technology%' THEN 70 ELSE 0 END +
    CASE WHEN LOWER(name) LIKE '%manufacturing%' THEN 50 ELSE 0 END +
    CASE WHEN landuse = 'industrial' THEN 40 ELSE 0 END +
    CASE WHEN building IN ('industrial', 'warehouse', 'factory') THEN 40 ELSE 0 END
  ) AS calculated_score
FROM planet_osm_polygon
WHERE (
  landuse = 'industrial'
  OR building IN ('industrial', 'warehouse', 'factory', 'manufacture')
)
AND name IS NOT NULL
ORDER BY calculated_score DESC
LIMIT 20;

\echo ''
\echo '========================================'
\echo 'If you see results above, the data exists!'
\echo 'Issue is likely in the view creation or INSERT.'
\echo '========================================'