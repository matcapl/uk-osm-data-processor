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

    ddl_parts: List[str] = [
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

def generate_tier_classification_case(thresholds: dict) -> str:
    """Generate CASE statement for tier classification."""
    tiers = thresholds.get('tier_thresholds', {})
    lines = ["    CASE"]
    
    # Sort tiers by threshold value (highest first)
    sorted_tiers = sorted(tiers.items(), key=lambda x: x[1], reverse=True)
    
    for tier_name, threshold in sorted_tiers:
        lines.append(f"        WHEN aerospace_score >= {threshold} THEN '{tier_name}'")
    
    lines.append("        ELSE 'UNCLASSIFIED'")
    lines.append("    END AS tier_classification")
    
    return "\n".join(lines)

def generate_confidence_case(thresholds: dict) -> str:
    """Generate CASE statement for confidence scoring."""
    confidence = thresholds.get('confidence_thresholds', {})
    lines = ["    CASE"]
    
    # Sort confidence levels by threshold value (highest first) 
    sorted_confidence = sorted(confidence.items(), key=lambda x: x[1], reverse=True)
    
    for conf_name, threshold in sorted_confidence:
        lines.append(f"        WHEN aerospace_score >= {threshold} THEN '{conf_name}'")
    
    lines.append("        ELSE 'LOW'")
    lines.append("    END AS confidence_level")
    
    return "\n".join(lines)

def generate_insert_statement(schema: dict, seed_columns: dict, thresholds: dict) -> str:
    """Generate INSERT statement combining data from all OSM tables."""
    output_table = seed_columns['output_table']['name']
    
    # Get column mappings
    id_cols = seed_columns.get('identification_columns', [])
    contact_cols = seed_columns.get('contact_columns', [])
    address_cols = seed_columns.get('address_columns', [])
    class_cols = seed_columns.get('classification_columns', [])
    desc_cols = seed_columns.get('descriptive_columns', [])
    spatial_cols = seed_columns.get('spatial_columns', [])
    scoring_cols = seed_columns.get('scoring_columns', [])
    meta_cols = seed_columns.get('metadata_columns', [])
    
    # Build column list for SELECT
    select_columns = []
    
    # Add identification columns
    for col in id_cols:
        if 'source_expression' in col:
            select_columns.append(f"    {col['source_expression']} AS {col['column_name']}")
        else:
            select_columns.append(f"    NULL AS {col['column_name']}")
    
    # Add other column groups
    for col_group in [contact_cols, address_cols, class_cols, desc_cols, spatial_cols]:
        for col in col_group:
            if 'source_expression' in col:
                select_columns.append(f"    {col['source_expression']} AS {col['column_name']}")
            else:
                select_columns.append(f"    NULL AS {col['column_name']}")
    
    # Add scoring columns with calculations
    for col in scoring_cols:
        if col['column_name'] == 'aerospace_score':
            select_columns.append("    COALESCE(aerospace_score, 0) AS aerospace_score")
        elif col['column_name'] == 'tier_classification':
            select_columns.append(generate_tier_classification_case(thresholds))
        elif col['column_name'] == 'confidence_level':
            select_columns.append(generate_confidence_case(thresholds))
        else:
            select_columns.append(f"    NULL AS {col['column_name']}")
    
    # Add metadata columns
    for col in meta_cols:
        if col['column_name'] == 'created_at':
            select_columns.append("    NOW() AS created_at")
        elif col['column_name'] == 'updated_at':
            select_columns.append("    NOW() AS updated_at")
        else:
            select_columns.append(f"    NULL AS {col['column_name']}")
    
    # Generate the main INSERT statement
    parts = [
        f"INSERT INTO {output_table} (",
        ",\n".join(f"    {col['column_name']}" for col_group in [id_cols, contact_cols, address_cols, class_cols, desc_cols, spatial_cols, scoring_cols, meta_cols] for col in col_group),
        ")",
        "",
        "-- Combine data from all filtered OSM tables",
        "SELECT"
    ]
    
    parts.append(",\n".join(select_columns))
    parts.append("FROM (")
    parts.append("")
    
    # Add UNION ALL for each table (note: proper spacing around UNION ALL)
    osm_tables = ['planet_osm_point', 'planet_osm_polygon', 'planet_osm_line']
    union_parts = []
    
    for i, table in enumerate(osm_tables):
        union_parts.append(f"    SELECT * FROM filtered_{table}_aerospace_scored")
    
    parts.append("\n    UNION ALL\n".join(union_parts))
    parts.append("")
    parts.append(") combined_osm")
    parts.append("WHERE aerospace_score > 0;")
    
    return "\n".join(parts)

# generate_tier_classification_case, generate_confidence_case,
# and generate_insert_statement are assumed unchanged besides UNION fix below.

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
    # Re-generate insert_statement here, with UNION spacing fixed
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
    parts.append(exclusions_sql)
    parts.append("")

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
