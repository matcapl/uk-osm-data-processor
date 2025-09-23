# ============================================================================
# ASSEMBLY AND EXECUTION SCRIPTS
# ============================================================================

# File: aerospace_scoring/assemble_sql.py
"""
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
    
    ddl_parts = []
    ddl_parts.append(f"-- Create aerospace supplier candidates table")
    ddl_parts.append(f"-- {description}")
    ddl_parts.append(f"DROP TABLE IF EXISTS {table_name} CASCADE;")
    ddl_parts.append(f"CREATE TABLE {table_name} (")
    
    # Collect all column definitions
    all_columns = []
    
    for column_group in ['identification_columns', 'contact_columns', 'address_columns', 
                        'classification_columns', 'descriptive_columns', 'spatial_columns',
                        'scoring_columns', 'metadata_columns']:
        
        columns = seed_columns.get(column_group, [])
        for col in columns:
            col_name = col['column_name']
            data_type = col['data_type']
            description = col.get('description', '')
            
            # Handle special data types
            if data_type == 'geometry':
                col_def = f"    {col_name} GEOMETRY"
            elif data_type == 'text[]':
                col_def = f"    {col_name} TEXT[]"
            else:
                col_def = f"    {col_name} {data_type.upper()}"
            
            all_columns.append(col_def)
    
    ddl_parts.append(",\n".join(all_columns))
    ddl_parts.append(");")
    
    # Add indexes
    ddl_parts.append(f"\n-- Create indexes for performance")
    ddl_parts.append(f"CREATE INDEX idx_{table_name}_score ON {table_name}(aerospace_score);")
    ddl_parts.append(f"CREATE INDEX idx_{table_name}_tier ON {table_name}(tier_classification);")
    ddl_parts.append(f"CREATE INDEX idx_{table_name}_postcode ON {table_name}(postcode);")
    ddl_parts.append(f"CREATE INDEX idx_{table_name}_geom ON {table_name} USING GIST(geometry);")
    
    return "\n".join(ddl_parts)

def generate_insert_statement(schema: Dict[str, Any], seed_columns: Dict[str, Any], 
                             thresholds: Dict[str, Any]) -> str:
    """Generate INSERT statement that combines data from all tables."""
    
    schema_name = schema.get('schema', 'osm_raw')
    table_name = seed_columns['output_table']['name']
    
    # Build column mappings
    insert_columns = []
    select_expressions = []
    
    # Process each column group
    for column_group in ['identification_columns', 'contact_columns', 'address_columns',
                        'classification_columns', 'descriptive_columns', 'spatial_columns']:
        
        columns = seed_columns.get(column_group, [])
        for col in columns:
            col_name = col['column_name']
            insert_columns.append(col_name)
            
            if 'source_expression' in col:
                # Use computed expression
                select_expressions.append(f"    {col['source_expression']} AS {col_name}")
            else:
                # Map from source column with fallbacks
                source_col = col['source_column']
                fallback_cols = col.get('fallback_columns', [])
                
                if fallback_cols:
                    # Create COALESCE expression for fallbacks
                    coalesce_cols = [source_col] + fallback_cols
                    expr = f"COALESCE({', '.join(coalesce_cols)})"
                else:
                    expr = source_col
                
                select_expressions.append(f"    {expr} AS {col_name}")
    
    # Add computed columns
    computed_columns = ['aerospace_score', 'matched_keywords', 'source_table']
    for col in computed_columns:
        insert_columns.append(col)
        # These are computed in the scoring views
    
    # Add tier classification based on thresholds
    tier_classification_expr = generate_tier_classification_case(thresholds)
    insert_columns.append('tier_classification')
    select_expressions.append(f"    {tier_classification_expr} AS tier_classification")
    
    # Add confidence level
    confidence_expr = generate_confidence_case(thresholds)
    insert_columns.append('confidence_level')
    select_expressions.append(f"    {confidence_expr} AS confidence_level")
    
    # Add metadata
    insert_columns.extend(['created_at', 'data_source', 'processing_notes'])
    select_expressions.extend([
        "    NOW() AS created_at",
        "    'UK OSM' AS data_source",
        "    CASE WHEN aerospace_score >= 150 THEN 'High confidence aerospace supplier' " +
        "WHEN aerospace_score >= 80 THEN 'Strong candidate' " +
        "WHEN aerospace_score >= 40 THEN 'Potential candidate' " +
        "ELSE 'Low probability' END AS processing_notes"
    ])
    
    # Build UNION query for all tables
    union_parts = []
    for table_name_src in ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon']:
        view_name = f"{table_name_src}_aerospace_scored"
        joined = ",\n".join(select_expressions)
        select_sql = "SELECT\n" + joined + f"\nFROM {schema_name}.{view_name}"
        union_parts.append(select_sql)
    
    insert_sql = f"""
-- Insert aerospace supplier candidates from all tables
INSERT INTO {table_name} ({', '.join(insert_columns)})
{' UNION ALL '.join(union_parts)}
WHERE aerospace_score >= {thresholds['thresholds']['minimum_requirements'].get('min_score', 10)}
ORDER BY aerospace_score DESC
LIMIT {thresholds['thresholds']['output_limits'].get('max_total_results', 5000)};
"""
    
    return insert_sql

def generate_tier_classification_case(thresholds: Dict[str, Any]) -> str:
    """Generate CASE expression for tier classification."""
    classification = thresholds['thresholds']['classification']
    
    case_parts = []
    for tier, config in classification.items():
        min_score = config.get('min_score')
        max_score = config.get('max_score')
        
        if min_score and max_score:
            condition = f"aerospace_score BETWEEN {min_score} AND {max_score}"
        elif min_score:
            condition = f"aerospace_score >= {min_score}"
        elif max_score:
            condition = f"aerospace_score <= {max_score}"
        else:
            continue
        
        case_parts.append(f"WHEN {condition} THEN '{tier}'")
    
    case_parts.append("ELSE 'unclassified'")
    
    lines = ["CASE"]
    for part in case_parts:
        lines.append("    " + part)
    lines.append("END")
    return "\n".join(lines)

def generate_confidence_case(thresholds: Dict[str, Any]) -> str:
    """Generate confidence level based on score and data quality."""
    return """CASE
        WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
        WHEN aerospace_score >= 80 AND name IS NOT NULL THEN 'medium'
        WHEN aerospace_score >= 40 THEN 'low'
        ELSE 'very_low'
    END"""

def load_generated_sql_files() -> tuple[str, str]:
    """Load previously generated SQL files."""
    try:
        with open('./exclusions.sql', 'r') as f:
            exclusions_sql = f.read()
    except FileNotFoundError:
        exclusions_sql = "-- Exclusions SQL not found - run generate_exclusions.py first"
    
    try:
        with open('./scoring.sql', 'r') as f:
            scoring_sql = f.read()
    except FileNotFoundError:
        scoring_sql = "-- Scoring SQL not found - run generate_scoring.py first"
    
    return exclusions_sql, scoring_sql

def assemble_complete_sql(schema: Dict[str, Any], thresholds: Dict[str, Any],
                          seed_columns: Dict[str, Any]) -> str:
    """Assemble the complete SQL script."""

    # Load component SQL files
    exclusions_sql, scoring_sql = load_generated_sql_files()

    # Generate components
    table_ddl = generate_output_table_ddl(seed_columns)
    insert_statement = generate_insert_statement(schema, seed_columns, thresholds)

    # Begin assembling
    sql_parts: List[str] = []

    # 0. Search path
    sql_parts.append("SET search_path = public;\n")

    # 1. Header
    sql_parts.append("-- " + "=" * 80)
    sql_parts.append("-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM")
    sql_parts.append(f"-- Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    sql_parts.append("-- " + "=" * 80)
    sql_parts.append("")

    # 2. Configuration summary
    sql_parts.append("-- CONFIGURATION SUMMARY:")
    sql_parts.append(f"-- Target schema: public")
    sql_parts.append(f"-- Output table: {seed_columns['output_table']['name']}")
    max_results = thresholds['thresholds']['output_limits'].get('max_total_results', 5000)
    sql_parts.append(f"-- Max results: {max_results}")
    sql_parts.append("")

    # 3. Step 1: Create output table
    sql_parts.append("-- STEP 1: Create output table")
    sql_parts.append(table_ddl)
    sql_parts.append("")

    # 4. Step 2: Exclusions
    sql_parts.append("-- STEP 2: Apply exclusion filters")
    sql_parts.append(exclusions_sql)
    sql_parts.append("")

    # 5. Step 3: Scoring views
    sql_parts.append("-- STEP 3: Apply scoring rules")
    # Turn each scoring SELECT into a CREATE VIEW
    scoring_lines = scoring_sql.splitlines()
    view_sql_parts: List[str] = []
    view_name = None
    buffer: List[str] = []
    for line in scoring_lines:
        if line.strip().startswith("-- Scoring for"):
            # flush previous buffer
            if buffer and view_name:
                view_sql_parts.append(f"CREATE VIEW {view_name}_aerospace_scored AS")
                view_sql_parts.extend(buffer)
                view_sql_parts.append("")  # blank line
            buffer = []
            view_name = line.strip().split()[-1]
        else:
            # accumulate SELECT/WHERE/etc.
            if view_name:
                buffer.append(line)
    # flush last
    if buffer and view_name:
        view_sql_parts.append(f"CREATE VIEW {view_name}_aerospace_scored AS")
        view_sql_parts.extend(buffer)
        view_sql_parts.append("")

    sql_parts.extend(view_sql_parts)

    # 6. Step 4: Final insert
    sql_parts.append("-- STEP 4: Insert results into final table")
    sql_parts.append(insert_statement)
    sql_parts.append("")

    return "\n".join(sql_parts)


if __name__ == "__main__":
    # Load configs and schema
    thresholds, seed_cols, scoring_cfg, exclusions_cfg = load_all_configs()
    schema = load_schema()
    sql = assemble_complete_sql(schema, thresholds, seed_cols)
    out_path = Path("./compute_aerospace_complete.sql")
    out_path.write_text(sql)
    print(f"✓ Complete SQL written to {out_path}")
