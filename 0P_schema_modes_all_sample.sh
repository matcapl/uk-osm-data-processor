#!/usr/bin/env bash
set -euo pipefail

DB="uk_osm_full"
OUTPUT="all_tables_schema_modes_sampled.csv"
TABLES=(
  planet_osm_point
  planet_osm_line
  planet_osm_polygon
  planet_osm_roads
  planet_osm_point_aerospace_filtered
  planet_osm_line_aerospace_filtered
  planet_osm_polygon_aerospace_filtered
  planet_osm_roads_aerospace_filtered
  planet_osm_point_aerospace_scored
  planet_osm_line_aerospace_scored
  planet_osm_polygon_aerospace_scored
  planet_osm_roads_aerospace_scored
)

# Header
echo "table_name,column_name,data_type,mode_value" > "${OUTPUT}"

for tbl in "${TABLES[@]}"; do
  exists=$(psql -d "${DB}" -At -c "
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema='public' AND table_name='${tbl}';
  ")
  if [ "$exists" != "1" ]; then
    echo "Skipping ${tbl}: does not exist"
    continue
  fi

  echo "Processing ${tbl} (sampled)..." >&2

  psql -d "${DB}" -At -F',' -c "
    WITH cols AS (
      SELECT ordinal_position, column_name, data_type
      FROM information_schema.columns
      WHERE table_schema='public' AND table_name='${tbl}'
    ),
    sample_data AS (
      SELECT *
      FROM public.\"${tbl}\"
      TABLESAMPLE BERNOULLI(1)  -- ~1% random rows (adjust as needed)
      LIMIT 10000               -- cap at 10k rows
    ),
    modes AS (
      SELECT
        c.column_name,
        (
          SELECT val
          FROM (
            SELECT (row_to_json(s) ->> c.column_name) AS val, COUNT(*) AS cnt
            FROM sample_data s
            WHERE (row_to_json(s) ->> c.column_name) IS NOT NULL
            GROUP BY val
            ORDER BY cnt DESC
            LIMIT 1
          ) AS m
        ) AS mode_value
      FROM cols c
    )
    SELECT
      '${tbl}' AS table_name,
      c.column_name,
      c.data_type,
      COALESCE(m.mode_value, '') AS mode_value
    FROM cols c
    LEFT JOIN modes m ON m.column_name = c.column_name
    ORDER BY c.ordinal_position;
  " >> "${OUTPUT}"
done

echo "Written sampled schema/mode report to ${OUTPUT}"
