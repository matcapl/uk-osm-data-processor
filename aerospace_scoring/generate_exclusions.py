#!/usr/bin/env python3
"""Generate SQL exclusion clauses - MINIMAL WORKING VERSION"""

import yaml
import json
from pathlib import Path

def main():
    print("Generating minimal exclusion SQL...")
    
    try:
        # Load schema to get actual table info
        with open('aerospace_scoring/schema.json', 'r') as f:
            schema = json.load(f)
        
        schema_name = schema.get('schema', 'public')
        sql_parts = []
        
        sql_parts.append("-- Minimal Aerospace Exclusion Filters")
        sql_parts.append("-- Creates pass-through views with minimal filtering\n")
        
        # Create simple pass-through views for each table
        for table_name, table_info in schema['tables'].items():
            if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
                continue
            
            view_name = f"{table_name}_aerospace_filtered"
            
            # Very minimal exclusion - only exclude obvious restaurants/cafes
            if table_name == 'planet_osm_point':
                where_clause = "(amenity IS NULL OR amenity NOT IN ('restaurant', 'cafe', 'pub', 'fast_food'))"
            else:
                where_clause = "1=1"  # Keep everything
            
            sql_parts.append(f"-- Filtered view for {table_name}")
            sql_parts.append(f"DROP VIEW IF EXISTS {schema_name}.{view_name} CASCADE;")
            sql_parts.append(f"CREATE VIEW {schema_name}.{view_name} AS")
            sql_parts.append(f"SELECT * FROM {schema_name}.{table_name}")
            sql_parts.append(f"WHERE {where_clause};")
            sql_parts.append("")
        
        # Save the SQL
        with open('aerospace_scoring/exclusions.sql', 'w') as f:
            f.write("\n".join(sql_parts))
        
        print("✓ Minimal exclusion SQL generated")
        
        # Show what we generated
        print("\nGenerated SQL preview:")
        for line in sql_parts[:15]:
            print(f"  {line}")
        
        return 0
        
    except Exception as e:
        print(f"✗ Failed: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    exit(main())
