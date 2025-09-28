#!/usr/bin/env python3
"""Generate SQL exclusion clauses from exclusions.yaml - FIXED VERSION"""

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
    schema_name = schema.get('schema', 'public')  # Fixed: use actual schema
    sql_parts = []
    
    sql_parts.append("-- Aerospace Supplier Exclusion Filters")
    sql_parts.append("-- Generated from exclusions.yaml\n")
    
    for table_name, table_info in schema['tables'].items():
        if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
            continue
        
        conditions = []
        
        # Apply general exclusions - FIXED: handle nested structure properly
        for category_name, category_rules in exclusions['exclusions'].items():
            for column, values in category_rules.items():
                if check_column_exists(schema, table_name, column):
                    # Skip empty value lists entirely - don't generate SQL for them
                    if not values:
                        continue
                    
                    if '*' in values:
                        # Exclude all non-null values for this column
                        conditions.append(f"{column} IS NULL")
                    else:
                        # Exclude specific values
                        quoted_values = "', '".join(values)
                        conditions.append(f"({column} IS NULL OR {column} NOT IN ('{quoted_values}'))")
        
        # Apply table-specific exclusions
        table_exclusions = exclusions.get('table_exclusions', {}).get(table_name, {})
        for column, values in table_exclusions.items():
            if check_column_exists(schema, table_name, column):
                if not values:  # Skip empty lists
                    continue
                
                if '*' in values:
                    conditions.append(f"{column} IS NULL")
                else:
                    quoted_values = "', '".join(values)
                    conditions.append(f"({column} IS NULL OR {column} NOT IN ('{quoted_values}'))")
        
        # Generate override conditions (these BYPASS exclusions)
        override_conditions = []
        for override_category, override_rules in exclusions.get('overrides', {}).items():
            for column, values in override_rules.items():
                if check_column_exists(schema, table_name, column):
                    if not values:  # Skip empty lists
                        continue
                    
                    if '*' in values:
                        override_conditions.append(f"{column} IS NOT NULL")
                    elif 'aerospace' in str(values).lower() or 'aviation' in str(values).lower():
                        # Special handling for text search in overrides
                        text_conditions = []
                        for value in values:
                            text_conditions.append(f"LOWER({column}) LIKE LOWER('%{value}%')")
                        if text_conditions:
                            override_conditions.append(f"({' OR '.join(text_conditions)})")
                    else:
                        quoted_values = "', '".join(values)
                        override_conditions.append(f"{column} IN ('{quoted_values}')")
        
        # Create filtered view with proper logic
        if conditions or override_conditions:
            view_name = f"{table_name}_aerospace_filtered"
            
            # Build WHERE clause: (pass exclusions) OR (match overrides)
            where_parts = []
            
            if conditions:
                exclusions_clause = f"({' AND '.join(conditions)})"
                where_parts.append(exclusions_clause)
            
            if override_conditions:
                overrides_clause = f"({' OR '.join(override_conditions)})"
                if where_parts:
                    where_clause = f"({where_parts[0]} OR {overrides_clause})"
                else:
                    where_clause = overrides_clause
            else:
                where_clause = where_parts[0] if where_parts else "1=1"
            
            sql_parts.append(f"-- Filtered view for {table_name}")
            sql_parts.append(f"DROP VIEW IF EXISTS {schema_name}.{view_name} CASCADE;")
            sql_parts.append(f"CREATE VIEW {schema_name}.{view_name} AS")
            sql_parts.append(f"SELECT * FROM {schema_name}.{table_name}")
            sql_parts.append(f"WHERE {where_clause};")
            sql_parts.append(f"-- Row count check:")
            sql_parts.append(f"-- SELECT COUNT(*) FROM {schema_name}.{view_name};\n")
        else:
            # No exclusions for this table - create pass-through view
            view_name = f"{table_name}_aerospace_filtered"
            sql_parts.append(f"-- Pass-through view for {table_name} (no exclusions)")
            sql_parts.append(f"DROP VIEW IF EXISTS {schema_name}.{view_name} CASCADE;")
            sql_parts.append(f"CREATE VIEW {schema_name}.{view_name} AS")
            sql_parts.append(f"SELECT * FROM {schema_name}.{table_name};\n")
    
    return "\n".join(sql_parts)

def main():
    print("Generating exclusion SQL...")
    
    try:
        exclusions, schema = load_configs()
        print(f"Using schema: {schema.get('schema', 'public')}")
        
        exclusion_sql = generate_exclusion_sql(exclusions, schema)
        
        with open('aerospace_scoring/exclusions.sql', 'w') as f:
            f.write(exclusion_sql)
        
        print("✓ Exclusion SQL generated: aerospace_scoring/exclusions.sql")
        
        # Debug: show first few lines
        lines = exclusion_sql.split('\n')[:10]
        print("\nFirst 10 lines of generated SQL:")
        for line in lines:
            print(f"  {line}")
        
    except Exception as e:
        print(f"✗ Failed: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
