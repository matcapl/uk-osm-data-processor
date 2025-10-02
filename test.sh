#!/usr/bin/env bash
set -euo pipefail

OUT="pipeline_debug.log"
: >"$OUT"

SCHEMA="public"
SQL="aerospace_scoring/compute_aerospace_scores.sql"

echo "=== PIPELINE DEBUG ===" | tee -a "$OUT"
echo "Generated: $(date)"        | tee -a "$OUT"
echo                              | tee -a "$OUT"

# 1) Apply the assembled SQL to create filtered/scored views and table
echo "1) Applying SQL"             | tee -a "$OUT"
psql -q -f "$SQL" >>"$OUT" 2>&1
echo "✓ SQL applied"               | tee -a "$OUT"
echo                              | tee -a "$OUT"

# 2) Count rows in filtered views
echo "2) Filtered view counts"     | tee -a "$OUT"
for V in point line polygon; do
  psql -q -c "
    SELECT
      'filtered_${V}' AS stage,
      COUNT(*) AS cnt
    FROM ${SCHEMA}.planet_osm_${V}_aerospace_filtered;
  " | tee -a "$OUT"
done
echo                              | tee -a "$OUT"

# 3) Count rows in scored views (all rows, then above threshold)
echo "3) Scored view counts"       | tee -a "$OUT"
THRESH=$(grep -m1 "WHERE aerospace_score >=" "$SQL" | sed -E 's/.*>= ([0-9]+).*/\1/')
echo "Threshold = $THRESH"         | tee -a "$OUT"
for V in point line polygon; do
  psql -q -c "
    SELECT
      'scored_${V}'       AS stage,
      COUNT(*)            AS total,
      COUNT(*) FILTER (WHERE aerospace_score >= $THRESH) AS above_thresh
    FROM ${SCHEMA}.planet_osm_${V}_aerospace_scored;
  " | tee -a "$OUT"
done
echo                              | tee -a "$OUT"

# 4) Count rows from the INSERT SELECT subquery without applying INSERT
echo "4) INSERT SELECT counts (dry-run)" | tee -a "$OUT"
sed -n '/-- STEP 4: Insert candidates/,/ORDER BY/p' "$SQL" \
  | sed "s/INSERT INTO.*//" \
  | sed "/ORDER BY/Q" \
  > /tmp/insert_dry.sql

psql -q -c "\
  SELECT
    COUNT(*) AS would_insert
  FROM (
    $(cat /tmp/insert_dry.sql)
  ) sub;
" | tee -a "$OUT"

rm -f /tmp/insert_dry.sql
echo                              | tee -a "$OUT"

# 5) Final candidate count
echo "5) Final table count"        | tee -a "$OUT"
psql -q -c "
  SELECT
    COUNT(*) AS inserted_candidates
  FROM ${SCHEMA}.aerospace_supplier_candidates;
" | tee -a "$OUT"

echo                              | tee -a "$OUT"
echo "=== DEBUG COMPLETE ==="      | tee -a "$OUT"
