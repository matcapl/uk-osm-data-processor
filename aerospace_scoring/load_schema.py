#!/usr/bin/env python3
"""
Database schema inspector for UK OSM data
Run this first to analyze your database structure
"""

import psycopg2
import json
import yaml
from pathlib import Path
from typing import Dict, List, Any

def connect_to_database() -> psycopg2.extensions.connection:
    """Connect to the UK OSM database."""
    try:
        with open('config/config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        db_config = config['database']
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config['user'],
            database=db_config['name']
        )
        return conn
    except Exception as e:
        print(f"✗ Database connection failed: {e}")
        raise

def inspect_osm_tables(conn: psycopg2.extensions.connection) -> Dict[str, Any]:
    """Inspect OSM tables and their columns."""
    cur = conn.cursor()
    
    # OSM tables to inspect
    osm_tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
    
    schema_info = {
        'schema': 'osm_raw',
        'tables': {},
        'summary': {'total_tables': 0, 'total_columns': 0, 'tables_with_data': 0}
    }
    
    try:
        with open('config/config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        schema_info['schema'] = config['database'].get('schema', 'osm_raw')
    except:
        pass
    
    for table in osm_tables:
        try:
            # Get column information
            cur.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema_info['schema'], table))
            
            columns = []
            for row in cur.fetchall():
                columns.append({
                    'name': row[0],
                    'type': row[1],
                    'nullable': row[2] == 'YES'
                })
            
            if columns:
                # Get row count
                cur.execute(f"SELECT count(*) FROM {schema_info['schema']}.{table}")
                row_count = cur.fetchone()[0]
                
                schema_info['tables'][table] = {
                    'exists': True,
                    'columns': columns,
                    'column_count': len(columns),
                    'row_count': row_count
                }
                
                if row_count > 0:
                    schema_info['summary']['tables_with_data'] += 1
                
                schema_info['summary']['total_columns'] += len(columns)
                schema_info['summary']['total_tables'] += 1
                
                print(f"✓ {table}: {len(columns)} columns, {row_count:,} rows")
            else:
                schema_info['tables'][table] = {'exists': False}
                print(f"✗ {table}: not found")
                
        except Exception as e:
            schema_info['tables'][table] = {'exists': False, 'error': str(e)}
            print(f"✗ {table}: error - {e}")
    
    cur.close()
    return schema_info

def main():
    """Main function to inspect database schema."""
    print("Inspecting UK OSM database schema...")
    
    try:
        conn = connect_to_database()
        schema_info = inspect_osm_tables(conn)
        
        # Export schema info
        with open('aerospace_scoring/schema.json', 'w') as f:
            json.dump(schema_info, f, indent=2, default=str)
        
        conn.close()
        print("\n✓ Schema inspection completed")
        print("✓ Schema saved to aerospace_scoring/schema.json")
        
    except Exception as e:
        print(f"✗ Schema inspection failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
