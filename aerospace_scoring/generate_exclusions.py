#!/usr/bin/env python3
"""Generate SQL exclusion clauses from exclusions.yaml"""

import yaml
import json
from pathlib import Path

def load_configs():
    with open('aerospace_scoring/exclusions.yaml', 'r') as f:
        exclusions = yaml.safe_load(f)
    
    with open('aerospace_scoring/schema.json', 'r') as f:
        schema = json.load(f)
    
    return exclusions, schema

def check_column_exists(schema, table, column):
    table_info = schema.get('tables', {}).get(table, {})
    if not table_info.get('exists'):
        return False
    columns = table_info.get('columns', [])
    return any(col['name'] == column for col in columns)

def generate_exclusion_sql(exclusions, schema):
    schema_name = schema.get('schema', 'osm_raw')
    sql_parts = []
    
    sql_parts.append("-- Aerospace Supplier Exclusion Filters")
    sql_parts.append("-- Generated from exclusions.yaml\n")
    
    for table_name, table_info in schema['tables'].items():
        if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
            continue
        
        conditions = []
        
        # Apply general exclusions
        for category, rules in exclusions['exclusions'].items():
            for rule in rules:
                for column, values in rule.items():
                    if check_column_exists(schema, table_name, column):
                        if '*' in values:
                            conditions.append(f"{column} IS NULL")
                        else:
                            quoted_values = "', '".join(values)
                            conditions.append(f"{column} NOT IN ('{quoted_values}')")
        
        # Create filtered view
        if conditions:
            view_name = f"{table_name}_aerospace_filtered"
            where_clause = ' AND '.join(conditions)
            
            sql_parts.append(f"-- Filtered view for {table_name}")
            sql_parts.append(f"CREATE OR REPLACE VIEW {schema_name}.{view_name} AS")
            sql_parts.append(f"SELECT * FROM {schema_name}.{table_name}")
            sql_parts.append(f"WHERE {where_clause};\n")
    
    return "\n".join(sql_parts)

def main():
    print("Generating exclusion SQL...")
    
    try:
        exclusions, schema = load_configs()
        exclusion_sql = generate_exclusion_sql(exclusions, schema)
        
        with open('aerospace_scoring/exclusions.sql', 'w') as f:
            f.write(exclusion_sql)
        
        print("✓ Exclusion SQL generated: aerospace_scoring/exclusions.sql")
        
    except Exception as e:
        print(f"✗ Failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
