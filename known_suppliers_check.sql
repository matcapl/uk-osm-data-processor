-- Check coverage of known UK aerospace suppliers
-- Run: psql -d uk_osm_full -f known_suppliers_check.sql

\echo '========================================================'
\echo 'KNOWN UK AEROSPACE SUPPLIER COVERAGE CHECK'
\echo '========================================================'
\echo ''

-- Create temporary table of known major suppliers
CREATE TEMP TABLE known_aerospace_suppliers AS
SELECT * FROM (VALUES
  -- Tier 1 Primes
  ('Airbus UK', 'Bristol', 'BS', 200),
  ('Rolls-Royce', 'Derby', 'DE', 200),
  ('BAE Systems', 'Preston', 'PR', 200),
  ('Leonardo Helicopters', 'Yeovil', 'BA', 200),
  ('GKN Aerospace', 'Redditch', 'B9', 200),
  
  -- Major Tier 2
  ('Spirit AeroSystems', 'Belfast', 'BT', 150),
  ('Meggitt', 'Coventry', 'CV', 150),
  ('Cobham', 'Wimborne', 'BH', 150),
  ('Senior Aerospace', 'Various', NULL, 150),
  ('Gardner Aerospace', 'Various', NULL, 150),
  ('UTC Aerospace Systems', 'Various', NULL, 150),
  ('Moog Aircraft', 'Tewkesbury', 'GL', 150),
  ('Parker Aerospace', 'Various', NULL, 150),
  
  -- Significant Tier 2/3
  ('Marshall Aerospace', 'Cambridge', 'CB', 120),
  ('Safran Seats', 'Various', NULL, 120),
  ('Triumph Actuation', 'Various', NULL, 120),
  ('Collins Aerospace', 'Various', NULL, 120),
  ('Magellan Aerospace', 'Various', NULL, 120)
) AS t(company_name, location, postcode_prefix, expected_score);

\echo '1. COVERAGE ANALYSIS'
\echo '--------------------'
\echo 'Checking how many known suppliers we found...'
\echo ''

-- Direct name matches
SELECT 
  k.company_name as known_supplier,
  k.location,
  k.postcode_prefix,
  CASE 
    WHEN c.name IS NOT NULL THEN '✓ FOUND'
    ELSE '✗ MISSING'
  END as status,
  c.aerospace_score,
  c.tier_classification
FROM known_aerospace_suppliers k
LEFT JOIN aerospace_supplier_candidates c
  ON LOWER(c.name) LIKE '%' || LOWER(SPLIT_PART(k.company_name, ' ', 1)) || '%'
ORDER BY k.expected_score DESC, k.company_name;

\echo ''
\echo '2. COVERAGE SUMMARY'
\echo '-------------------'

SELECT 
  'Total Known Suppliers' as metric,
  COUNT(*)::text as value
FROM known_aerospace_suppliers

UNION ALL

SELECT 
  'Found in Database' as metric,
  COUNT(DISTINCT k.company_name)::text as value
FROM known_aerospace_suppliers k
INNER JOIN aerospace_supplier_candidates c
  ON LOWER(c.name) LIKE '%' || LOWER(SPLIT_PART(k.company_name, ' ', 1)) || '%'

UNION ALL

SELECT 
  'Coverage %' as metric,
  ROUND(100.0 * COUNT(DISTINCT k.company_name) / 
    (SELECT COUNT(*) FROM known_aerospace_suppliers))::text || '%' as value
FROM known_aerospace_suppliers k
INNER JOIN aerospace_supplier_candidates c
  ON LOWER(c.name) LIKE '%' || LOWER(SPLIT_PART(k.company_name, ' ', 1)) || '%';

\echo ''
\echo '3. NEAR MATCHES (Potential Facilities)'
\echo '---------------------------------------'
\echo 'Companies with similar names or in known locations:'
\echo ''

-- Find facilities near known supplier locations
SELECT DISTINCT
  c.name,
  c.aerospace_score,
  c.postcode,
  c.city,
  k.company_name as near_to
FROM aerospace_supplier_candidates c
CROSS JOIN known_aerospace_suppliers k
WHERE (
  -- Same postcode area
  (k.postcode_prefix IS NOT NULL AND LEFT(c.postcode, 2) = k.postcode_prefix)
  -- Or partial name match
  OR LOWER(c.name) LIKE '%' || LOWER(SPLIT_PART(k.company_name, ' ', 1)) || '%'
)
AND c.aerospace_score >= 100
ORDER BY c.aerospace_score DESC
LIMIT 30;

\echo ''
\echo '4. EXPECTED vs ACTUAL SCORES'
\echo '-----------------------------'
\echo 'For suppliers we found, how do scores compare?'
\echo ''

SELECT 
  k.company_name,
  k.expected_score,
  COALESCE(MAX(c.aerospace_score), 0) as actual_score,
  CASE 
    WHEN MAX(c.aerospace_score) >= k.expected_score THEN '✓ Good'
    WHEN MAX(c.aerospace_score) >= k.expected_score * 0.7 THEN '~ Close'
    WHEN MAX(c.aerospace_score) IS NULL THEN '✗ Not Found'
    ELSE '✗ Too Low'
  END as score_status
FROM known_aerospace_suppliers k
LEFT JOIN aerospace_supplier_candidates c
  ON LOWER(c.name) LIKE '%' || LOWER(SPLIT_PART(k.company_name, ' ', 1)) || '%'
GROUP BY k.company_name, k.expected_score
ORDER BY k.expected_score DESC;

\echo ''
\echo '5. RECOMMENDATIONS'
\echo '------------------'
\echo ''

-- Missing high-value suppliers
SELECT 
  'Missing High-Value Suppliers:' as recommendation,
  COUNT(*)::text || ' known Tier-1 suppliers not found' as details
FROM known_aerospace_suppliers k
LEFT JOIN aerospace_supplier_candidates c
  ON LOWER(c.name) LIKE '%' || LOWER(SPLIT_PART(k.company_name, ' ', 1)) || '%'
WHERE k.expected_score >= 150
  AND c.name IS NULL

UNION ALL

-- Check specific locations
SELECT 
  'Check These Locations:' as recommendation,
  string_agg(DISTINCT k.location || ' (' || k.postcode_prefix || ')', ', ') as details
FROM known_aerospace_suppliers k
LEFT JOIN aerospace_supplier_candidates c
  ON k.postcode_prefix IS NOT NULL 
  AND LEFT(c.postcode, 2) = k.postcode_prefix
  AND c.aerospace_score >= 100
WHERE k.postcode_prefix IS NOT NULL
GROUP BY 'Check These Locations:'
HAVING COUNT(c.*) < 3;

\echo ''
\echo '========================================================'
\echo 'ANALYSIS COMPLETE'
\echo '========================================================'
\echo ''
\echo 'Action Items:'
\echo '  1. Missing Suppliers: Verify OSM data completeness'
\echo '  2. Low Scores: Review scoring for known suppliers'
\echo '  3. Location Gaps: Check if geographic bonuses are sufficient'
\echo ''
\echo 'Next: Add more known suppliers to this list and re-run'
\echo ''

-- Cleanup
DROP TABLE known_aerospace_suppliers;