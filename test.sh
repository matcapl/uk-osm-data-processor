#!/bin/bash
#
# test.sh — Comprehensive INSERT failure diagnostic for aerospace scoring
# Identifies exactly where and why the INSERT is failing silently

set -euo pipefail

OUT="insert_failure_diagnostic.txt"
: >"$OUT"

echo "=== INSERT FAILURE DIAGNOSTIC ===" | tee -a "$OUT"
echo "Generated: $(date)" | tee -a "$OUT"
echo >>"$OUT"

# 1) Run pipeline and capture any errors
echo "1) PIPELINE EXECUTION WITH ERROR CAPTURE:" | tee -a "$OUT"
uv run aerospace_scoring/run_aerospace_scoring.py 2>&1 | tee -a "$OUT"
echo >>"$OUT"

# 2) Re-apply SQL with verbose error reporting
echo "2) APPLYING SQL WITH VERBOSE ERRORS:" | tee -a "$OUT"
psql -d uk_osm_full -v ON_ERROR_STOP=1 -f aerospace_scoring/compute_aerospace_scores.sql 2>&1 | tee -a "$OUT" || {
  echo "   SQL EXECUTION FAILED - see errors above" | tee -a "$OUT"
}
echo >>"$OUT"

# 3) Verify scored views exist and contain data
echo "3) SCORED VIEW DATA ANALYSIS:" | tee -a "$OUT"
for tbl in point line polygon; do
  view="public.planet_osm_${tbl}_aerospace_scored"
  echo "   === $view ===" | tee -a "$OUT"
  
  # Check if view exists
  if psql -d uk_osm_full -tAc "SELECT to_regclass('$view');" | grep -q "$view"; then
    # Get row count and score distribution
    psql -d uk_osm_full -c "
      SELECT 
        'Total rows' as metric, 
        COUNT(*)::text as value 
      FROM $view
      UNION ALL
      SELECT 
        'Score > 0', 
        COUNT(*)::text 
      FROM $view 
      WHERE aerospace_score > 0
      UNION ALL
      SELECT 
        'Score >= 10', 
        COUNT(*)::text 
      FROM $view 
      WHERE aerospace_score >= 10
      UNION ALL
      SELECT 
        'Max score', 
        MAX(aerospace_score)::text 
      FROM $view
      UNION ALL
      SELECT 
        'Min score', 
        MIN(aerospace_score)::text 
      FROM $view;
    " | sed 's/^/     /' | tee -a "$OUT"
    
    # Show top 3 scoring records
    echo "     Top 3 records:" | tee -a "$OUT"
    psql -d uk_osm_full -c "
      SELECT osm_id, name, aerospace_score, source_table 
      FROM $view 
      ORDER BY aerospace_score DESC 
      LIMIT 3;
    " | sed 's/^/       /' | tee -a "$OUT"
    
  else
    echo "     VIEW MISSING" | tee -a "$OUT"
  fi
  echo | tee -a "$OUT"
done

# 4) Test the INSERT query components separately
echo "4) INSERT QUERY COMPONENT TESTING:" | tee -a "$OUT"

# Test the UNION ALL source query
echo "   a) Testing UNION ALL source query:" | tee -a "$OUT"
psql -d uk_osm_full -c "
  SELECT 
    source_table,
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE aerospace_score >= 10) as above_threshold,
    MAX(aerospace_score) as max_score,
    MIN(aerospace_score) as min_score
  FROM (
    SELECT *, 'point' as source_check FROM public.planet_osm_point_aerospace_scored
    UNION ALL
    SELECT *, 'polygon' as source_check FROM public.planet_osm_polygon_aerospace_scored  
    UNION ALL
    SELECT *, 'line' as source_check FROM public.planet_osm_line_aerospace_scored
  ) combined
  GROUP BY source_table;
" | sed 's/^/     /' | tee -a "$OUT"

# Test threshold filtering
echo "   b) Testing threshold filtering (score >= 10):" | tee -a "$OUT"
psql -d uk_osm_full -c "
  SELECT COUNT(*) as records_passing_threshold
  FROM (
    SELECT * FROM public.planet_osm_point_aerospace_scored
    UNION ALL
    SELECT * FROM public.planet_osm_polygon_aerospace_scored  
    UNION ALL
    SELECT * FROM public.planet_osm_line_aerospace_scored
  ) combined
  WHERE aerospace_score >= 10;
" | sed 's/^/     /' | tee -a "$OUT"

# 5) Check target table structure vs source data
echo "5) TABLE STRUCTURE COMPATIBILITY:" | tee -a "$OUT"

echo "   a) Target table columns:" | tee -a "$OUT"
psql -d uk_osm_full -c "
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_name = 'aerospace_supplier_candidates'
    AND table_schema = 'public'
  ORDER BY ordinal_position;
" | sed 's/^/     /' | tee -a "$OUT"

echo "   b) Source data column sample:" | tee -a "$OUT"
psql -d uk_osm_full -c "
  SELECT 
    osm_id,
    CASE WHEN name IS NULL THEN 'NULL' ELSE 'HAS_VALUE' END as name_status,
    CASE WHEN operator IS NULL THEN 'NULL' ELSE 'HAS_VALUE' END as operator_status,
    CASE WHEN tags->'contact:website' IS NULL THEN 'NULL' ELSE 'HAS_VALUE' END as website_status,
    aerospace_score,
    source_table
  FROM public.planet_osm_point_aerospace_scored
  WHERE aerospace_score >= 10
  LIMIT 3;
" | sed 's/^/     /' | tee -a "$OUT"

# 6) Test a minimal INSERT to isolate the problem
echo "6) MINIMAL INSERT TEST:" | tee -a "$OUT"

# Try inserting just one record manually
echo "   Testing single record INSERT:" | tee -a "$OUT"
psql -d uk_osm_full -c "
  BEGIN;
  
  -- Try to insert one record with minimal columns
  INSERT INTO public.aerospace_supplier_candidates 
    (osm_id, name, aerospace_score, created_at, source_table)
  SELECT 
    osm_id, 
    COALESCE(name, 'TEST_RECORD'), 
    aerospace_score, 
    NOW(), 
    source_table
  FROM public.planet_osm_point_aerospace_scored
  WHERE aerospace_score >= 10
  LIMIT 1;
  
  -- Check if it worked
  SELECT COUNT(*) as inserted_count FROM public.aerospace_supplier_candidates;
  
  ROLLBACK;
" 2>&1 | sed 's/^/     /' | tee -a "$OUT"

# 7) Extract and test the actual INSERT query from the SQL file
echo "7) ACTUAL INSERT QUERY EXECUTION TEST:" | tee -a "$OUT"

# Extract just the INSERT statement and test it
echo "   Extracting INSERT statement from compute_aerospace_scores.sql:" | tee -a "$OUT"
sed -n '/INSERT INTO.*aerospace_supplier_candidates/,/;$/p' aerospace_scoring/compute_aerospace_scores.sql > /tmp/insert_test.sql

echo "   Testing extracted INSERT:" | tee -a "$OUT"
psql -d uk_osm_full -c "BEGIN; $(cat /tmp/insert_test.sql) SELECT COUNT(*) as test_insert_count FROM public.aerospace_supplier_candidates; ROLLBACK;" 2>&1 | sed 's/^/     /' | tee -a "$OUT"

# 8) Final summary
echo "8) DIAGNOSTIC SUMMARY:" | tee -a "$OUT"
current_count=$(psql -d uk_osm_full -tAc "SELECT COUNT(*) FROM public.aerospace_supplier_candidates;")
echo "   Current aerospace_supplier_candidates count: $current_count" | tee -a "$OUT"

# Check if table exists at all
if psql -d uk_osm_full -tAc "SELECT to_regclass('public.aerospace_supplier_candidates');" | grep -q "aerospace_supplier_candidates"; then
  echo "   Target table exists: YES" | tee -a "$OUT"
else
  echo "   Target table exists: NO" | tee -a "$OUT"
fi

echo >>"$OUT"
echo "=== DIAGNOSTIC COMPLETE ===" | tee -a "$OUT"
echo "Results written to: $OUT"

# Clean up temp file
rm -f /tmp/insert_test.sql
