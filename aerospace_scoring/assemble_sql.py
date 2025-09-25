#!/usr/bin/env python3
"""Assemble complete SQL script for aerospace supplier scoring"""

import yaml
from pathlib import Path
from datetime import datetime

def load_table_name():
    seed = yaml.safe_load(open('aerospace_scoring/seed_columns.yaml'))
    return seed['output_table']['name']  # e.g. "aerospace_supplier_candidates"

def inline_sql(path, header):
    return f"-- {header}\n{Path(path).read_text()}"

def generate_ddl(table):
    return f"""-- STEP 3: Create output table
DROP TABLE IF EXISTS public.{table} CASCADE;
CREATE TABLE public.{table} (
  osm_id BIGINT,
  osm_type VARCHAR(50),
  name TEXT,
  operator TEXT,
  website TEXT,
  landuse_type TEXT,
  geometry GEOMETRY,
  aerospace_score INTEGER,
  tier_classification VARCHAR(50),
  matched_keywords TEXT[],
  source_table VARCHAR(50),
  created_at TIMESTAMP
);
CREATE INDEX ON public.{table}(aerospace_score);
CREATE INDEX ON public.{table}(tier_classification);
CREATE INDEX ON public.{table} USING GIST(geometry);
"""

def generate_insert(table):
    cols = [
        'osm_id','osm_type','name','operator','website',
        'landuse_type','geometry','aerospace_score',
        'tier_classification','matched_keywords',
        'source_table','created_at'
    ]

    unions = []
    for typ in ['point','polygon','line']:
        view = f"public.planet_osm_{typ}_aerospace_scored"
        unions.append(f"""SELECT
  osm_id,
  '{typ}' AS osm_type,
  COALESCE(name,operator) AS name,
  operator,
  website,
  landuse AS landuse_type,
  way AS geometry,
  aerospace_score,
  CASE
    WHEN aerospace_score>=150 THEN 'tier1_candidate'
    WHEN aerospace_score>=80  THEN 'tier2_candidate'
    WHEN aerospace_score>=40  THEN 'potential_candidate'
    WHEN aerospace_score>=10  THEN 'low_probability'
    ELSE 'excluded'
  END AS tier_classification,
  matched_keywords,
  source_table,
  NOW() AS created_at
FROM {view}
WHERE aerospace_score >= 10""")

    union_sql = "\nUNION ALL\n".join(unions)
    col_list = ", ".join(cols)

    return f"""-- STEP 4: Insert final results
INSERT INTO public.{table} ({col_list})
{union_sql}
ON CONFLICT DO NOTHING;
"""

def assemble_sql():
    table = load_table_name()
    sql_parts = [
        "-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM",
        f"-- Generated on: {datetime.now():%Y-%m-%d %H:%M:%S}",
        inline_sql('aerospace_scoring/exclusions.sql', 'STEP 1: Exclusion Filters'),
        inline_sql('aerospace_scoring/scoring.sql',    'STEP 2: Scoring Rules'),
        generate_ddl(table),
        generate_insert(table),
        "-- STEP 5: Analysis queries",
        f"SELECT 'Total candidates' AS metric, COUNT(*) AS value FROM public.{table};",
        f"SELECT tier_classification, COUNT(*) AS cnt FROM public.{table} GROUP BY tier_classification ORDER BY cnt DESC;"
    ]
    full_sql = "\n\n".join(sql_parts)
    Path('aerospace_scoring/compute_aerospace_scores.sql').write_text(full_sql)
    print("✓ compute_aerospace_scores.sql assembled")

if __name__=='__main__':
    assemble_sql()
