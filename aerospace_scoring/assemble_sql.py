#!/usr/bin/env python3
"""Assemble complete SQL script for aerospace supplier scoring – FINAL VERSION"""

import yaml
import json
from pathlib import Path
from datetime import datetime

def load_configs():
    """Load thresholds, seed_columns, and schema metadata."""
    configs = {}
    for name in ['thresholds', 'seed_columns']:
        with open(f'aerospace_scoring/{name}.yaml', 'r') as f:
            configs[name] = yaml.safe_load(f)
    with open('aerospace_scoring/schema.json', 'r') as f:
        configs['schema'] = json.load(f)
    return configs

def generate_output_table_ddl(seed_columns, schema_name):
    tbl = seed_columns['output_table']['name']
    cols = seed_columns['output_table'].get('columns', [])
    if not cols:
        raise ValueError("seed_columns.yaml must include output_table.columns")
    col_defs = [f"    {c['name']} {c['type']}" for c in cols]
    ddl = [
        f"-- Create aerospace supplier candidates table in {schema_name}",
        f"DROP TABLE IF EXISTS {schema_name}.{tbl} CASCADE;",
        f"CREATE TABLE {schema_name}.{tbl} (",
        ",\n".join(col_defs),
        ");",
        "",
        "-- Indexes",
        f"CREATE INDEX idx_{tbl}_score ON {schema_name}.{tbl}(aerospace_score);",
        f"CREATE INDEX idx_{tbl}_tier ON {schema_name}.{tbl}(tier_classification);",
        f"CREATE INDEX idx_{tbl}_postcode ON {schema_name}.{tbl}(postcode);",
        f"CREATE INDEX idx_{tbl}_geom ON {schema_name}.{tbl} USING GIST(geometry);"
    ]
    return "\n".join(ddl)

def generate_insert_sql(schema, thresholds, seed_columns):
    """
    Generate INSERT SQL using correct CTE+JOIN logic.
    """
    schema_name = schema.get('schema', 'public')
    tbl = seed_columns['output_table']['name']
    min_score = thresholds.get('filter_minimum_score', 10)
    max_cands = thresholds.get('max_candidates', 5000)

    tier_case = """CASE
        WHEN aerospace_score >= 150 THEN 'tier1_candidate'
        WHEN aerospace_score >= 80 THEN 'tier2_candidate'
        WHEN aerospace_score >= 40 THEN 'potential_candidate'
        WHEN aerospace_score >= 10 THEN 'low_probability'
        ELSE 'excluded'
    END"""

    confidence_case = """CASE
        WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
        WHEN aerospace_score >= 80 THEN 'medium'
        WHEN aerospace_score >= 40 THEN 'low'
        ELSE 'very_low'
    END"""

    cols = seed_columns['output_table']['columns']
    col_names = ", ".join(c['name'] for c in cols)

    select_exprs = []
    for c in cols:
        n = c['name']
        if n == 'osm_id':
            select_exprs.append("k.osm_id")
        elif n == 'osm_type':
            select_exprs.append("k.source_table AS osm_type")
        elif n == 'aerospace_score':
            select_exprs.append("k.aerospace_score")
        elif n == 'tier_classification':
            select_exprs.append(f"{tier_case} AS tier_classification")
        elif n == 'confidence_level':
            select_exprs.append(f"{confidence_case} AS confidence_level")
        elif n == 'created_at':
            select_exprs.append("NOW() AS created_at")
        elif n == 'phone':
            select_exprs.append(
                "COALESCE("
                "p.tags->'phone', p.tags->'contact:phone', "
                "l.tags->'phone', l.tags->'contact:phone', "
                "g.tags->'phone', g.tags->'contact:phone'"
                ") AS phone"
            )
        else:
            select_exprs.append(f"COALESCE(p.{n}, l.{n}, g.{n}) AS {n}")

    insert = [
        f"-- Insert aerospace supplier candidates into {schema_name}.{tbl}",
        "WITH candidate_keys AS (",
        f"  SELECT osm_id, aerospace_score, source_table FROM {schema_name}.planet_osm_point_aerospace_scored",
        f"  UNION ALL",
        f"  SELECT osm_id, aerospace_score, source_table FROM {schema_name}.planet_osm_line_aerospace_scored",
        f"  UNION ALL",
        f"  SELECT osm_id, aerospace_score, source_table FROM {schema_name}.planet_osm_polygon_aerospace_scored",
        "), unique_keys AS (",
        "  SELECT osm_id, source_table, MAX(aerospace_score) AS aerospace_score",
        "  FROM candidate_keys",
        "  GROUP BY osm_id, source_table",
        ")",
        f"INSERT INTO {schema_name}.{tbl} ({col_names})",
        "SELECT",
        "  " + ",\n  ".join(select_exprs),
        f"FROM unique_keys k",
        f"LEFT JOIN {schema_name}.planet_osm_point_aerospace_scored   p ON k.osm_id = p.osm_id AND k.source_table='point'",
        f"LEFT JOIN {schema_name}.planet_osm_line_aerospace_scored    l ON k.osm_id = l.osm_id AND k.source_table='line'",
        f"LEFT JOIN {schema_name}.planet_osm_polygon_aerospace_scored g ON k.osm_id = g.osm_id AND k.source_table='polygon'",
        f"WHERE k.aerospace_score >= {min_score}",
        f"ORDER BY k.aerospace_score DESC",
        f"LIMIT {max_cands};"
    ]
    return "\n".join(insert)

def assemble_complete_sql(configs):
    schema = configs['schema']
    schema_name = schema.get('schema', 'public')
    thresholds = configs['thresholds']
    seed_columns = configs['seed_columns']

    try:
        excl = Path('aerospace_scoring/exclusions.sql').read_text()
    except FileNotFoundError:
        excl = "-- Run generate_exclusions.py first"
    try:
        score = Path('aerospace_scoring/scoring.sql').read_text()
    except FileNotFoundError:
        score = "-- Run generate_scoring.py first"

    ddl = generate_output_table_ddl(seed_columns, schema_name)
    ins = generate_insert_sql(schema, thresholds, seed_columns)
    tbl = seed_columns['output_table']['name']

    header = [
        "-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM",
        f"-- Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"-- Schema: {schema_name}",
        ""
    ]
    steps = [
        "-- STEP 1: Apply exclusion filters", excl, "",
        "-- STEP 2: Apply scoring rules", score, "",
        "-- STEP 3: Create output table", ddl, "",
        "-- STEP 4: Insert final results", ins, "",
        "-- STEP 5: Analysis queries",
        f"SELECT 'Total candidates' AS metric, COUNT(*) AS value FROM {schema_name}.{tbl};",
        f"SELECT 'With contact info', COUNT(*) FROM {schema_name}.{tbl} WHERE website IS NOT NULL OR phone IS NOT NULL;",
        f"SELECT 'High confidence', COUNT(*) FROM {schema_name}.{tbl} WHERE confidence_level = 'high';",
        "",
        "-- Classification breakdown",
        f"SELECT tier_classification, COUNT(*) AS count, AVG(aerospace_score) AS avg_score FROM {schema_name}.{tbl} GROUP BY tier_classification ORDER BY avg_score DESC;",
        "",
        "-- Top candidates",
        f"SELECT name, tier_classification, aerospace_score, postcode FROM {schema_name}.{tbl} WHERE tier_classification IN ('tier1_candidate','tier2_candidate') ORDER BY aerospace_score DESC LIMIT 20;"
    ]

    return "\n".join(header + steps)

def main():
    print("Assembling complete SQL script…")
    try:
        cfg = load_configs()
        sql = assemble_complete_sql(cfg)
        Path('aerospace_scoring/compute_aerospace_scores.sql').write_text(sql)
        print("✓ SQL script assembled: aerospace_scoring/compute_aerospace_scores.sql")
    except Exception as e:
        print(f"✗ Failed: {e}")
        return 1
    return 0

if __name__ == "__main__":
    exit(main())
