#!/usr/bin/env python3
"""
assemble_sql.py

Assemble complete SQL script for aerospace supplier scoring
Combines exclusions, scoring, thresholds, and table creation
"""

import yaml
import json
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime


def load_all_configs() -> tuple[Dict[str, Any], Dict[str, Any], Dict[str, Any], Dict[str, Any]]:
    """Load all YAML configuration files."""
    config_files = {
        'thresholds': 'thresholds.yaml',
        'seed_columns': 'seed_columns.yaml',
        'scoring': 'scoring.yaml',
        'exclusions': 'exclusions.yaml'
    }
    configs = {}
    for name, filename in config_files.items():
        with open(f'./{filename}', 'r') as f:
            configs[name] = yaml.safe_load(f)
    return configs['thresholds'], configs['seed_columns'], configs['scoring'], configs['exclusions']


def load_schema() -> Dict[str, Any]:
    """Load database schema."""
    with open('./schema.json', 'r') as f:
        return json.load(f)


def generate_output_table_ddl(seed_columns: Dict[str, Any]) -> str:
    """Generate CREATE TABLE statement for output table."""
    table_name = seed_columns['output_table']['name']
    description = seed_columns['output_table']['description']

    ddl_parts = [
        f"-- Create aerospace supplier candidates table",
        f"-- {description}",
        f"DROP TABLE IF EXISTS {table_name} CASCADE;",
        f"CREATE TABLE {table_name} ("
    ]

    all_columns: List[str] = []
    for group in [
        'identification_columns', 'contact_columns', 'address_columns',
        'classification_columns', 'descriptive_columns', 'spatial_columns',
        'scoring_columns', 'metadata_columns'
    ]:
        for col in seed_columns.get(group, []):
            name = col['column_name']
            dt = col['data_type'].upper()
            if dt == 'GEOMETRY':
                col_def = f"    {name} GEOMETRY"
            elif dt == 'TEXT[]':
                col_def = f"    {name} TEXT[]"
            else:
                col_def = f"    {name} {dt}"
            all_columns.append(col_def)

    ddl_parts.append(",\n".join(all_columns))
    ddl_parts.append(");")
    ddl_parts.extend([
        "",
        "-- Create indexes for performance",
        f"CREATE INDEX idx_{table_name}_score ON {table_name}(aerospace_score);",
        f"CREATE INDEX idx_{table_name}_tier ON {table_name}(tier_classification);",
        f"CREATE INDEX idx_{table_name}_postcode ON {table_name}(postcode);",
        f"CREATE INDEX idx_{table_name}_geom ON {table_name} USING GIST(geometry);"
    ])
    return "\n".join(ddl_parts)


def generate_tier_classification_case(thresholds: Dict[str, Any]) -> str:
    """Generate CASE expression for tier classification."""
    cls = thresholds['thresholds']['classification']
    parts: List[str] = ["CASE"]
    for tier, cfg in cls.items():
        min_s = cfg.get('min_score')
        max_s = cfg.get('max_score')
        if min_s is not None and max_s is not None:
            cond = f"aerospace_score BETWEEN {min_s} AND {max_s}"
        elif min_s is not None:
            cond = f"aerospace_score >= {min_s}"
        elif max_s is not None:
            cond = f"aerospace_score <= {max_s}"
        else:
            continue
        parts.append(f"    WHEN {cond} THEN '{tier}'")
    parts.append("    ELSE 'unclassified'")
    parts.append("END")
    return "\n".join(parts)


def generate_confidence_case(thresholds: Dict[str, Any]) -> str:
    """Generate confidence level CASE."""
    return """CASE
    WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
    WHEN aerospace_score >= 80 THEN 'medium'
    WHEN aerospace_score >= 40 THEN 'low'
    ELSE 'very_low'
END"""


def generate_insert_statement(schema: Dict[str, Any], seed_columns: Dict[str, Any],
                              thresholds: Dict[str, Any]) -> str:
    """Generate INSERT statement combining all scored views."""
    schema_name = schema.get('schema', 'osm_raw')
    out_table = seed_columns['output_table']['name']

    insert_cols: List[str] = []
    select_exprs: List[str] = []

    for group in [
        'identification_columns', 'contact_columns', 'address_columns',
        'classification_columns', 'descriptive_columns', 'spatial_columns'
    ]:
        for col in seed_columns.get(group, []):
            cn = col['column_name']
            insert_cols.append(cn)
            if 'source_expression' in col:
                select_exprs.append(f"    {col['source_expression']} AS {cn}")
            else:
                sc = col['source_column']
                fbs = col.get('fallback_columns', [])
                if fbs:
                    co = ", ".join([sc] + fbs)
                    select_exprs.append(f"    COALESCE({co}) AS {cn}")
                else:
                    select_exprs.append(f"    {sc} AS {cn}")

    # Add computed and classification columns
    for cn in ['aerospace_score', 'matched_keywords']:
        insert_cols.append(cn)
        select_exprs.append(f"    {cn}")

    insert_cols.append('tier_classification')
    select_exprs.append(f"    {generate_tier_classification_case(thresholds)} AS tier_classification")

    insert_cols.append('confidence_level')
    select_exprs.append(f"    {generate_confidence_case(thresholds)} AS confidence_level")

    # Metadata
    insert_cols.extend(['created_at', 'data_source', 'processing_notes'])
    select_exprs.append("    NOW() AS created_at")
    select_exprs.append("    'UK OSM' AS data_source")
    select_exprs.append(
        "    CASE WHEN aerospace_score >= 150 THEN 'High confidence' "
        "WHEN aerospace_score >= 80 THEN 'Strong candidate' "
        "WHEN aerospace_score >= 40 THEN 'Potential' "
        "ELSE 'Low probability' END AS processing_notes"
    )

    # Union all scored views
    unions: List[str] = []
    for t in ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']:
        view = f"{t}_aerospace_scored"
        unions.append("SELECT\n" + ",\n".join(select_exprs) + f"\nFROM {schema_name}.{view}")

    min_score = thresholds['thresholds']['minimum_requirements'].get('min_score', 0)
    limit = thresholds['thresholds']['output_limits'].get('max_total_results', 5000)

    insert_sql = (
        f"-- Insert aerospace supplier candidates\n"
        f"INSERT INTO {out_table} ({', '.join(insert_cols)})\n"
        + "UNION ALL\n".join(unions) + "\n"
        f"WHERE aerospace_score >= {min_score}\n"
        f"ORDER BY aerospace_score DESC\n"
        f"LIMIT {limit};"
    )

    return insert_sql


def load_generated_sql_files() -> tuple[str, str]:
    """Load exclusions.sql and scoring.sql contents."""
    try:
        excl = Path('./exclusions.sql').read_text()
    except FileNotFoundError:
        excl = "-- exclusions.sql not found"
    try:
        score = Path('./scoring.sql').read_text()
    except FileNotFoundError:
        score = "-- scoring.sql not found"
    return excl, score


def assemble_complete_sql(schema: Dict[str, Any], thresholds: Dict[str, Any],
                          seed_columns: Dict[str, Any]) -> str:
    """Assemble the full compute_aerospace_complete.sql script."""
    exclusions_sql, scoring_sql = load_generated_sql_files()
    table_ddl = generate_output_table_ddl(seed_columns)
    insert_stmt = generate_insert_statement(schema, seed_columns, thresholds)

    parts: List[str] = []
    parts.append("SET search_path = public;\n")
    parts.extend([
        "-- " + "="*80,
        "-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM",
        f"-- Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "-- " + "="*80,
        ""
    ])

    parts.append("-- STEP 1: Create output table")
    parts.append(table_ddl)
    parts.append("")

    parts.append("-- STEP 2: Apply exclusion filters")
    parts.append("BEGIN;")
    parts.append(exclusions_sql)
    parts.append("COMMIT;\n")

    parts.append("-- STEP 3: Apply scoring rules")
    # Convert scoring_sql into CREATE VIEW statements
    s_lines = scoring_sql.splitlines()
    view_buf: List[str] = []
    view_name = None
    temp: List[str] = []
    for line in s_lines:
        if line.strip().startswith("-- Scoring for"):
            if temp and view_name:
                view_buf.append(f"CREATE VIEW {view_name}_aerospace_scored AS")
                view_buf.extend(temp)
                view_buf.append("")
            temp = []
            view_name = line.strip().split()[-1]
        else:
            if view_name:
                temp.append(line)
    if temp and view_name:
        view_buf.append(f"CREATE VIEW {view_name}_aerospace_scored AS")
        view_buf.extend(temp)
        view_buf.append("")
    parts.extend(view_buf)

    parts.append("-- STEP 4: Insert results into final table")
    parts.append(insert_stmt)
    parts.append("")

    return "\n".join(parts)


if __name__ == "__main__":
    thresholds, seed_cols, scoring_cfg, exclusions_cfg = load_all_configs()
    schema = load_schema()
    sql = assemble_complete_sql(schema, thresholds, seed_cols)
    Path("./compute_aerospace_complete.sql").write_text(sql)
    print("✓ Complete SQL written to compute_aerospace_complete.sql")
