#!/usr/bin/env python3
"""Assemble complete SQL script for aerospace supplier scoring – Iteration 9 Redo"""

import yaml
import json
from pathlib import Path
from datetime import datetime


def load_configs():
    configs = {}
    for name in ['thresholds', 'seed_columns']:
        with open(f'aerospace_scoring/{name}.yaml') as f:
            configs[name] = yaml.safe_load(f)
    with open('aerospace_scoring/schema.json') as f:
        configs['schema'] = json.load(f)
    return configs


def generate_output_table_ddl(seed_columns, schema_name):
    tbl = seed_columns['output_table']['name']
    cols = seed_columns['output_table']['columns']
    col_defs = [f"    {c['name']} {c['type']}" for c in cols]
    return "\n".join([
        f"-- STEP 3: Output table DDL",
        f"DROP TABLE IF EXISTS {schema_name}.{tbl} CASCADE;",
        f"CREATE TABLE {schema_name}.{tbl} (",
        ",\n".join(col_defs),
        ");",
        "",
        "-- Indexes",
        f"CREATE INDEX idx_{tbl}_score    ON {schema_name}.{tbl}(aerospace_score);",
        f"CREATE INDEX idx_{tbl}_tier     ON {schema_name}.{tbl}(tier_classification);",
        f"CREATE INDEX idx_{tbl}_postcode ON {schema_name}.{tbl}(postcode);",
        f"CREATE INDEX idx_{tbl}_geom     ON {schema_name}.{tbl} USING GIST(geometry);",
        ""
    ])


def generate_insert_sql(schema_name, thresholds, seed_columns):
    tbl = seed_columns['output_table']['name']
    min_score = thresholds.get('filter_minimum_score',
                thresholds.get('minimum_score', 10))
    max_cands = thresholds.get('max_candidates',
                thresholds.get('candidate_limit', 5000))

    cols = [c['name'] for c in seed_columns['output_table']['columns']]

    sql = []
    sql.append("-- STEP 4: Insert candidates")
    sql.append(f"-- min_score = {min_score}")
    sql.append(f"INSERT INTO {schema_name}.{tbl} ({', '.join(cols)})")

    # Build SELECT blocks
    core = [
        "osm_id",
        "'{view}' AS source_table",
        "name",
        "operator",
        "aerospace_score",
        """CASE
            WHEN aerospace_score >= 150 THEN 'tier1_candidate'
            WHEN aerospace_score >= 80  THEN 'tier2_candidate'
            WHEN aerospace_score >= 40  THEN 'potential_candidate'
            ELSE 'low_probability'
           END AS tier_classification""",
        """CASE
            WHEN aerospace_score >= 150
             AND (tags->'website' IS NOT NULL OR tags->'phone' IS NOT NULL)
            THEN 'high'
            WHEN aerospace_score >= 80  THEN 'medium'
            WHEN aerospace_score >= 40  THEN 'low'
            ELSE 'very_low'
           END AS confidence_level""",
        "tags->'phone'         AS phone",
        "tags->'email'         AS email",
        "tags->'website'       AS website",
        "tags->'addr:postcode' AS postcode",
        "tags->'addr:street'   AS street_address",
        "tags->'addr:city'     AS city"
    ]
    extras = [
        "NULL AS landuse_type",
        "NULL AS building_type",
        "NULL AS industrial_type",
        "NULL AS office_type",
        "NULL AS description",
        "ARRAY[]::text[] AS matched_keywords",
        "tags                 AS tags_raw",
        "ST_Y(ST_Transform(ST_Centroid(way),4326)) AS latitude",
        "ST_X(ST_Transform(ST_Centroid(way),4326)) AS longitude",
        "ST_Transform(ST_Centroid(way),4326) AS geometry",
        "NOW()               AS created_at"
    ]

    blocks = []
    for v in ['point', 'line', 'polygon']:
        sel = [c.format(view=v) for c in core] + extras
        blocks.append(
            "SELECT " + ", ".join(sel) + "\n"
            f"FROM {schema_name}.planet_osm_{v}_aerospace_scored\n"
            f"WHERE aerospace_score >= {min_score}"
        )

    sql.append("\nUNION ALL\n".join(blocks))
    sql.append("ORDER BY aerospace_score DESC")
    sql.append(f"LIMIT {max_cands};")
    return "\n".join(sql)


def assemble_complete_sql(cfg):
    schema_name = cfg['schema']['schema']
    thresholds = cfg['thresholds']
    seed_columns = cfg['seed_columns']

    excl = Path('aerospace_scoring/exclusions.sql').read_text()
    score = Path('aerospace_scoring/scoring.sql').read_text()

    parts = [
        "-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM",
        f"-- Generated on: {datetime.now():%Y-%m-%d %H:%M:%S}",
        f"-- Schema: {schema_name}\n",
        "-- STEP 1: Exclusions",
        excl,
        "",
        "-- STEP 2: Scoring (scored-view creation)",
        score,
        "",
        generate_output_table_ddl(seed_columns, schema_name),
        generate_insert_sql(schema_name, thresholds, seed_columns),
        "",
        "-- STEP 5: Verification queries",
        f"SELECT 'Total candidates'    AS metric, COUNT(*)     AS value FROM {schema_name}.{seed_columns['output_table']['name']};",
        f"SELECT 'With contact info'  AS metric, COUNT(*)     AS value FROM {schema_name}.{seed_columns['output_table']['name']} WHERE phone IS NOT NULL OR email IS NOT NULL;",
        f"SELECT 'High confidence'   AS metric, COUNT(*)     AS value FROM {schema_name}.{seed_columns['output_table']['name']} WHERE confidence_level='high';",
        "",
        f"SELECT tier_classification, COUNT(*) AS count, AVG(aerospace_score) AS avg_score",
        f"  FROM {schema_name}.{seed_columns['output_table']['name']} GROUP BY tier_classification ORDER BY avg_score DESC;",
        "",
        f"SELECT name, tier_classification, aerospace_score, postcode",
        f"  FROM {schema_name}.{seed_columns['output_table']['name']} WHERE tier_classification IN ('tier1_candidate','tier2_candidate')",
        f"  ORDER BY aerospace_score DESC LIMIT 20;"
    ]
    return "\n".join(parts)


def main():
    try:
        cfg = load_configs()
        sql = assemble_complete_sql(cfg)
        Path('aerospace_scoring/compute_aerospace_scores.sql').write_text(sql)
        print("✓ SQL script assembled: aerospace_scoring/compute_aerospace_scores.sql")
    except Exception as e:
        print(f"✗ Assemble failed: {e}")
        exit(1)


if __name__ == "__main__":
    main()
