#!/usr/bin/env bash
#
# test.sh - Comprehensive aerospace scoring pipeline diagnostic
# Enhanced version with detailed column analysis and union testing

set -euo pipefail

DB_NAME="uk_osm_full"
SCHEMA="public"
OUT="pipeline_diagnostic.txt"

rm -f "$OUT"
echo "=== AEROSPACE PIPELINE DIAGNOSTIC ===" | tee -a "$OUT"
echo "Generated: $(date)" | tee -a "$OUT"
echo "" | tee -a "$OUT"

# 1. Filtered Views Existence & Data
echo "1) FILTERED VIEWS STATUS:" | tee -a "$OUT"
for tbl in point line polygon roads; do
  view="${SCHEMA}.planet_osm_${tbl}_aerospace_filtered"
  echo "   === $view ===" | tee -a "$OUT"
  
  if psql -d "$DB_NAME" -tAc "SELECT to_regclass('$view');" | grep -q "$view"; then
    count=$(psql -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM $view;")
    echo "     ✓ EXISTS - Rows: $count" | tee -a "$OUT"
  else
    echo "     ✗ MISSING" | tee -a "$OUT"
  fi
done
echo "" | tee -a "$OUT"

# 2. Scored Views Existence & Scoring Data
echo "2) SCORED VIEWS STATUS:" | tee -a "$OUT"
for tbl in point line polygon roads; do
  view="${SCHEMA}.planet_osm_${tbl}_aerospace_scored"
  echo "   === $view ===" | tee -a "$OUT"
  
  if psql -d "$DB_NAME" -tAc "SELECT to_regclass('$view');" | grep -q "$view"; then
    psql -d "$DB_NAME" -c "
      SELECT 
        'Total rows' as metric, 
        COUNT(*)::text as value 
      FROM $view
      UNION ALL
      SELECT 
        'Score >= 10', 
        COUNT(*) FILTER (WHERE aerospace_score >= 10)::text 
      FROM $view
      UNION ALL
      SELECT 
        'Max score', 
        COALESCE(MAX(aerospace_score), 0)::text 
      FROM $view
      UNION ALL
      SELECT 
        'Avg score (>0)', 
        COALESCE(ROUND(AVG(aerospace_score) FILTER (WHERE aerospace_score > 0), 1), 0)::text 
      FROM $view;
    " | sed 's/^/     /' | tee -a "$OUT"
  else
    echo "     ✗ MISSING" | tee -a "$OUT"
  fi
  echo "" | tee -a "$OUT"
done

# 3. Column Count & Schema Analysis
echo "3) SCHEMA CONSISTENCY ANALYSIS:" | tee -a "$OUT"
echo "   Column counts per scored view:" | tee -a "$OUT"
for tbl in point line polygon roads; do
  view="planet_osm_${tbl}_aerospace_scored"
  if psql -d "$DB_NAME" -tAc "SELECT to_regclass('${SCHEMA}.$view');" | grep -q "$view"; then
    col_count=$(psql -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$SCHEMA' AND table_name='$view';")
    echo "     $view: $col_count columns" | tee -a "$OUT"
  else
    echo "     $view: MISSING" | tee -a "$OUT"
  fi
done
echo "" | tee -a "$OUT"

# 4. Detailed Schema Comparison
echo "   First 10 columns comparison:" | tee -a "$OUT"
for tbl in point line polygon; do
  view="planet_osm_${tbl}_aerospace_scored"
  if psql -d "$DB_NAME" -tAc "SELECT to_regclass('${SCHEMA}.$view');" | grep -q "$view"; then
    echo "     $view:" | tee -a "$OUT"
    psql -d "$DB_NAME" -c "
      SELECT column_name, data_type, ordinal_position 
      FROM information_schema.columns 
      WHERE table_schema='$SCHEMA' AND table_name='$view' 
      ORDER BY ordinal_position LIMIT 10;
    " | sed 's/^/       /' | tee -a "$OUT"
  fi
done
echo "" | tee -a "$OUT"

# 5. Target Table Analysis
echo "4) TARGET TABLE STATUS:" | tee -a "$OUT"
target_table="${SCHEMA}.aerospace_supplier_candidates"
if psql -d "$DB_NAME" -tAc "SELECT to_regclass('$target_table');" | grep -q "aerospace_supplier_candidates"; then
  row_count=$(psql -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM $target_table;")
  col_count=$(psql -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='$SCHEMA' AND table_name='aerospace_supplier_candidates';")
  echo "   ✓ EXISTS - Rows: $row_count, Columns: $col_count" | tee -a "$OUT"
  
  echo "   Column definitions:" | tee -a "$OUT"
  psql -d "$DB_NAME" -c "
    SELECT column_name, data_type, character_maximum_length, ordinal_position 
    FROM information_schema.columns 
    WHERE table_schema='$SCHEMA' AND table_name='aerospace_supplier_candidates' 
    ORDER BY ordinal_position;
  " | sed 's/^/     /' | tee -a "$OUT"
else
  echo "   ✗ MISSING" | tee -a "$OUT"
fi
echo "" | tee -a "$OUT"

# 6. UNION Compatibility Test
echo "5) UNION COMPATIBILITY TEST:" | tee -a "$OUT"
echo "   Testing minimal UNION (osm_id, aerospace_score only):" | tee -a "$OUT"
if psql -d "$DB_NAME" -c "
  SELECT COUNT(*) as union_test_count FROM (
    SELECT osm_id, aerospace_score FROM ${SCHEMA}.planet_osm_point_aerospace_scored WHERE aerospace_score >= 10 LIMIT 2
    UNION ALL
    SELECT osm_id, aerospace_score FROM ${SCHEMA}.planet_osm_line_aerospace_scored WHERE aerospace_score >= 10 LIMIT 2
    UNION ALL
    SELECT osm_id, aerospace_score FROM ${SCHEMA}.planet_osm_polygon_aerospace_scored WHERE aerospace_score >= 10 LIMIT 2
  ) minimal_union;
" 2>&1 | sed 's/^/     /' | tee -a "$OUT"; then
  echo "     ✓ Basic UNION works" | tee -a "$OUT"
else
  echo "     ✗ Basic UNION failed" | tee -a "$OUT"
fi
echo "" | tee -a "$OUT"

# 7. Full UNION Test (SELECT *)
echo "   Testing full UNION (SELECT *):" | tee -a "$OUT"
if timeout 30 psql -d "$DB_NAME" -c "
  SELECT COUNT(*) as full_union_count FROM (
    SELECT * FROM ${SCHEMA}.planet_osm_point_aerospace_scored WHERE aerospace_score >= 10 LIMIT 1
    UNION ALL
    SELECT * FROM ${SCHEMA}.planet_osm_line_aerospace_scored WHERE aerospace_score >= 10 LIMIT 1
    UNION ALL
    SELECT * FROM ${SCHEMA}.planet_osm_polygon_aerospace_scored WHERE aerospace_score >= 10 LIMIT 1
  ) full_union;
" 2>&1 | sed 's/^/     /' | tee -a "$OUT"; then
  echo "     ✓ Full UNION works" | tee -a "$OUT"
else
  echo "     ✗ Full UNION failed - column mismatch likely" | tee -a "$OUT"
fi
echo "" | tee -a "$OUT"

# 8. INSERT Statement Validation
echo "6) INSERT STATEMENT VALIDATION:" | tee -a "$OUT"
echo "   Checking if compute_aerospace_scores.sql exists:" | tee -a "$OUT"
if [ -f "aerospace_scoring/compute_aerospace_scores.sql" ]; then
  echo "     ✓ SQL file exists" | tee -a "$OUT"
  
  # Extract INSERT column count
  echo "   Analyzing INSERT statement:" | tee -a "$OUT"
  insert_cols=$(grep -A1 "INSERT INTO.*aerospace_supplier_candidates" aerospace_scoring/compute_aerospace_scores.sql | grep -o '([^)]*' | tr ',' '\n' | wc -l)
  echo "     INSERT expects $insert_cols columns" | tee -a "$OUT"
  
  # Check for array placeholder
  if grep -q "ARRAY\[\]::text\[\] AS matched_keywords" aerospace_scoring/compute_aerospace_scores.sql; then
    echo "     ✓ Array placeholder present" | tee -a "$OUT"
  else
    echo "     ✗ Array placeholder missing" | tee -a "$OUT"
  fi
  
  # Test INSERT extraction
  echo "   Testing INSERT extraction:" | tee -a "$OUT"
  if sed -n '/INSERT INTO.*aerospace_supplier_candidates/,/;$/p' aerospace_scoring/compute_aerospace_scores.sql > /tmp/insert_test.sql 2>/dev/null; then
    echo "     ✓ INSERT extracted successfully" | tee -a "$OUT"
    rm -f /tmp/insert_test.sql
  else
    echo "     ✗ INSERT extraction failed" | tee -a "$OUT"
  fi
else
  echo "     ✗ SQL file missing" | tee -a "$OUT"
fi
echo "" | tee -a "$OUT"

# 9. Pipeline Execution Test
echo "7) PIPELINE EXECUTION TEST:" | tee -a "$OUT"
if [ -f "aerospace_scoring/run_aerospace_scoring.py" ]; then
  echo "   Running pipeline (last 20 lines of output):" | tee -a "$OUT"
  if timeout 120 uv run aerospace_scoring/run_aerospace_scoring.py 2>&1 | tail -20 | sed 's/^/     /' | tee -a "$OUT"; then
    echo "     Pipeline completed" | tee -a "$OUT"
  else
    echo "     Pipeline failed or timed out" | tee -a "$OUT"
  fi
else
  echo "   ✗ Pipeline script missing" | tee -a "$OUT"
fi
echo "" | tee -a "$OUT"

# 10. Final Status Summary
echo "8) FINAL STATUS SUMMARY:" | tee -a "$OUT"
final_count=$(psql -d "$DB_NAME" -tAc "SELECT COALESCE(COUNT(*), 0) FROM ${SCHEMA}.aerospace_supplier_candidates;" 2>/dev/null || echo "0")
scored_total=0
for tbl in point line polygon; do
  if psql -d "$DB_NAME" -tAc "SELECT to_regclass('${SCHEMA}.planet_osm_${tbl}_aerospace_scored');" | grep -q "scored" 2>/dev/null; then
    count=$(psql -d "$DB_NAME" -tAc "SELECT COUNT(*) FILTER (WHERE aerospace_score >= 10) FROM ${SCHEMA}.planet_osm_${tbl}_aerospace_scored;" 2>/dev/null || echo "0")
    scored_total=$((scored_total + count))
  fi
done

echo "   Candidates with score >= 10: $scored_total" | tee -a "$OUT"
echo "   Final table rows: $final_count" | tee -a "$OUT"
echo "   Success rate: $(( final_count * 100 / (scored_total + 1) ))%" | tee -a "$OUT"

if [ "$final_count" -eq 0 ] && [ "$scored_total" -gt 0 ]; then
  echo "   🚨 INSERT IS SILENTLY FAILING" | tee -a "$OUT"
elif [ "$final_count" -gt 0 ]; then
  echo "   ✅ PIPELINE IS WORKING" | tee -a "$OUT"
else
  echo "   ⚠️  NO DATA TO INSERT" | tee -a "$OUT"
fi

echo "" | tee -a "$OUT"
echo "=== DIAGNOSTIC COMPLETE ===" | tee -a "$OUT"
echo "Results written to: $OUT"
