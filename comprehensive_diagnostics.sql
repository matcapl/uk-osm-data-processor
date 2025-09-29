-- =====================================================
-- COMPREHENSIVE DATABASE DIAGNOSTICS
-- Run this to understand what data exists and permissions
-- =====================================================

-- 1. CHECK CURRENT USER AND SCHEMA
SELECT 
    current_user as connected_user,
    current_database() as database_name,
    current_schema() as current_schema;

-- 2. CHECK ALL SCHEMAS AND THEIR TABLES
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE tablename LIKE 'planet_osm_%'
   OR tablename LIKE '%aerospace%'
ORDER BY schemaname, tablename;

-- 3. CHECK VIEWS CREATED BY AEROSPACE PIPELINE
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views
WHERE viewname LIKE '%aerospace%'
ORDER BY schemaname, viewname;

-- 4. CHECK IF FILTERED VIEWS HAVE ANY DATA
-- Replace 'public' with your actual schema if different
SELECT 'planet_osm_point_aerospace_filtered' as view_name, COUNT(*) as row_count
FROM public.planet_osm_point_aerospace_filtered
UNION ALL
SELECT 'planet_osm_line_aerospace_filtered', COUNT(*)
FROM public.planet_osm_line_aerospace_filtered
UNION ALL
SELECT 'planet_osm_polygon_aerospace_filtered', COUNT(*)
FROM public.planet_osm_polygon_aerospace_filtered
UNION ALL
SELECT 'planet_osm_roads_aerospace_filtered', COUNT(*)
FROM public.planet_osm_roads_aerospace_filtered;

-- 5. CHECK IF SCORED VIEWS HAVE ANY DATA
SELECT 'planet_osm_point_aerospace_scored' as view_name, COUNT(*) as row_count
FROM public.planet_osm_point_aerospace_scored
UNION ALL
SELECT 'planet_osm_line_aerospace_scored', COUNT(*)
FROM public.planet_osm_line_aerospace_scored
UNION ALL
SELECT 'planet_osm_polygon_aerospace_scored', COUNT(*)
FROM public.planet_osm_polygon_aerospace_scored;

-- 6. TEST: What industrial/office data exists in source tables?
SELECT 
    'Industrial landuse' as category,
    COUNT(*) as count
FROM public.planet_osm_polygon
WHERE landuse = 'industrial'

UNION ALL

SELECT 
    'Industrial buildings',
    COUNT(*)
FROM public.planet_osm_polygon
WHERE building IN ('industrial', 'warehouse', 'factory')

UNION ALL

SELECT 
    'Office facilities',
    COUNT(*)
FROM public.planet_osm_polygon
WHERE office IS NOT NULL

UNION ALL

SELECT 
    'Manufacturing facilities',
    COUNT(*)
FROM public.planet_osm_polygon
WHERE man_made IN ('works', 'factory')

UNION ALL

SELECT 
    'Names with aerospace keywords',
    COUNT(*)
FROM public.planet_osm_polygon
WHERE name IS NOT NULL 
  AND (LOWER(name) LIKE '%aerospace%' 
    OR LOWER(name) LIKE '%aviation%' 
    OR LOWER(name) LIKE '%aircraft%'
    OR LOWER(name) LIKE '%engineering%');

-- 7. SAMPLE: Show some industrial/office records
SELECT 
    osm_id,
    name,
    landuse,
    building,
    office,
    man_made,
    tags->'addr:postcode' as postcode
FROM public.planet_osm_polygon
WHERE landuse = 'industrial' 
   OR building IN ('industrial', 'warehouse', 'factory')
   OR office IS NOT NULL
LIMIT 20;

-- 8. CHECK: Does aerospace_supplier_candidates table exist?
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename = 'aerospace_supplier_candidates';

-- 9. IF TABLE EXISTS: Check why it's empty
SELECT COUNT(*) as total_in_candidates
FROM public.aerospace_supplier_candidates;

-- 10. CHECK PERMISSIONS for user 'a'
SELECT 
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'a'
  AND table_name LIKE '%aerospace%'
ORDER BY table_schema, table_name, privilege_type;

-- 11. TEST THE FILTER LOGIC: Count records that PASS the exclusions
-- This simulates what the filtered view should contain
SELECT COUNT(*) as records_passing_filters
FROM public.planet_osm_polygon
WHERE (
    -- Pass exclusions
    (landuse IS NULL OR landuse NOT IN ('residential', 'retail', 'commercial'))
    AND (amenity IS NULL OR amenity NOT IN ('restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy'))
    AND shop IS NULL
    AND tourism IS NULL
)
OR (
    -- OR match overrides
    landuse = 'industrial'
    OR building IN ('industrial', 'warehouse', 'factory')
    OR office IS NOT NULL
    OR man_made IN ('works', 'factory')
);

-- 12. TEST SCORING: Check if any records would get a positive score
SELECT 
    osm_id,
    name,
    landuse,
    building,
    office,
    CASE 
        WHEN landuse = 'industrial' THEN 50
        WHEN building IN ('industrial', 'warehouse', 'factory') THEN 50
        WHEN office IS NOT NULL THEN 70
        WHEN man_made IN ('works', 'factory') THEN 70
        ELSE 0
    END as test_score
FROM public.planet_osm_polygon
WHERE (
    landuse = 'industrial'
    OR building IN ('industrial', 'warehouse', 'factory')
    OR office IS NOT NULL
    OR man_made IN ('works', 'factory')
)
LIMIT 20;

-- 13. CRITICAL: Check if the INSERT into aerospace_supplier_candidates worked
-- Look for any errors in recent table operations
SELECT 
    schemaname,
    tablename,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows
FROM pg_stat_user_tables
WHERE tablename LIKE '%aerospace%';