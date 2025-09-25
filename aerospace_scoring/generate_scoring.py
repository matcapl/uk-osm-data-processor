#!/usr/bin/env python3
"""Generate SQL scoring expressions from scoring.yaml - FIXED VERSION"""

import yaml
import json
from pathlib import Path

def load_configs():
    with open('aerospace_scoring/scoring.yaml', 'r') as f:
        scoring = yaml.safe_load(f)
    
    with open('aerospace_scoring/negative_signals.yaml', 'r') as f:
        negative_signals = yaml.safe_load(f)
    
    with open('aerospace_scoring/schema.json', 'r') as f:
        schema = json.load(f)
    
    return scoring, negative_signals, schema

def check_column_exists(schema, table, column):
    table_info = schema.get('tables', {}).get(table, {})
    if not table_info.get('exists'):
        return False
    columns = table_info.get('columns', [])
    return any(col['name'] == column for col in columns)

def generate_scoring_sql(scoring, negative_signals, schema):
    schema_name = schema.get('schema', 'public')
    sql_parts = []
    
    sql_parts.append("-- Aerospace Supplier Scoring SQL")
    sql_parts.append("-- Generated from scoring.yaml and negative_signals.yaml\n")
    
    for table_name, table_info in schema['tables'].items():
        if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
            continue
        
        print(f"Processing {table_name}...")
        
        # Get available columns for this table
        available_columns = [col['name'] for col in table_info.get('columns', [])]
        
        # Build scoring expressions that only use existing columns
        scoring_expressions = []
        
        # Text-based aerospace keyword matching
        text_fields = [col for col in ['name', 'operator'] if col in available_columns]
        if text_fields:
            aerospace_keywords = ['aerospace', 'aviation', 'aircraft', 'airbus', 'boeing', 'bae', 'rolls royce']
            
            for field in text_fields:
                keyword_conditions = []
                for keyword in aerospace_keywords:
                    keyword_conditions.append(f"{field} ILIKE '%{keyword}%'")
                
                if keyword_conditions:
                    scoring_expressions.append(f"CASE WHEN ({' OR '.join(keyword_conditions)}) THEN 100 ELSE 0 END")
        
        # Industrial facility bonuses
        if 'landuse' in available_columns:
            scoring_expressions.append("CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END")
        
        if 'building' in available_columns:
            scoring_expressions.append("CASE WHEN building IN ('industrial', 'warehouse', 'factory', 'office') THEN 40 ELSE 0 END")
        
        if 'office' in available_columns:
            scoring_expressions.append("CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END")
        
        if 'industrial' in available_columns:
            scoring_expressions.append("CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END")
        
        if 'man_made' in available_columns:
            scoring_expressions.append("CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END")
        
        # Technology/engineering name bonuses
        if 'name' in available_columns:
            tech_keywords = ['technology', 'engineering', 'systems', 'electronics', 'precision']
            tech_conditions = []
            for keyword in tech_keywords:
                tech_conditions.append(f"name ILIKE '%{keyword}%'")
            
            if tech_conditions:
                scoring_expressions.append(f"CASE WHEN ({' OR '.join(tech_conditions)}) THEN 35 ELSE 0 END")
        
        # Generate final score expression
        if scoring_expressions:
            final_score = f"({' + '.join(scoring_expressions)})"
        else:
            final_score = "10"  # Give minimal score to industrial facilities
        
        # Create scored view
        view_name = f"{table_name}_aerospace_scored"
        sql_parts.append(f"-- Scored view for {table_name}")
        sql_parts.append(f"DROP VIEW IF EXISTS {schema_name}.{view_name} CASCADE;")
        sql_parts.append(f"CREATE VIEW {schema_name}.{view_name} AS")
        sql_parts.append(f"SELECT *,")
        sql_parts.append(f"    {final_score} AS aerospace_score,")
        sql_parts.append(f"    ARRAY[]::text[] AS matched_keywords,")
        sql_parts.append(f"    '{table_name}' AS source_table")
        sql_parts.append(f"FROM {schema_name}.{table_name}_aerospace_filtered")
        sql_parts.append(f"WHERE {final_score} > 0;")
        sql_parts.append("")
    
    return "\n".join(sql_parts)

def main():
    print("Generating scoring SQL...")
    
    try:
        scoring, negative_signals, schema = load_configs()
        scoring_sql = generate_scoring_sql(scoring, negative_signals, schema)
        
        with open('aerospace_scoring/scoring.sql', 'w') as f:
            f.write(scoring_sql)
        
        print("✓ Scoring SQL generated: aerospace_scoring/scoring.sql")
        
    except Exception as e:
        print(f"✗ Failed: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
