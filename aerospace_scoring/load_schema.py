#!/usr/bin/env python3
"""
Database schema inspector for UK OSM data - COLUMN-AWARE VERSION
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

def detect_actual_schema(conn: psycopg2.extensions.connection) -> str:
    """Detect which schema actually contains the OSM tables."""
    cur = conn.cursor()
    
    # Check common schema names
    schemas_to_check = ['public', 'osm_raw', 'osm']
    osm_tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
    
    for schema in schemas_to_check:
        try:
            for table in osm_tables:
                cur.execute("""
                    SELECT COUNT(*) FROM information_schema.tables 
                    WHERE table_schema = %s AND table_name = %s
                """, (schema, table))
                
                if cur.fetchone()[0] > 0:
                    print(f"✓ Found OSM tables in schema: {schema}")
                    return schema
        except Exception:
            continue
    
    return 'public'  # Default based on your system

def inspect_osm_tables(conn: psycopg2.extensions.connection) -> Dict[str, Any]:
    """Inspect OSM tables and their columns - with column awareness."""
    cur = conn.cursor()
    
    actual_schema = 'public'  # We know from diagnostic
    osm_tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
    
    schema_info = {
        'schema': actual_schema,
        'tables': {},
        'summary': {'total_tables': 0, 'total_columns': 0, 'tables_with_data': 0}
    }
    
    # Key columns we care about for aerospace scoring
    important_columns = [
        'name', 'operator', 'amenity', 'building', 'landuse', 
        'industrial', 'office', 'man_made', 'shop', 'tourism', 
        'website', 'phone', 'addr:postcode', 'addr:street', 'addr:city',
        'description', 'military', 'craft', 'railway', 'waterway',
        'natural', 'barrier', 'leisure'
    ]
    
    for table in osm_tables:
        try:
            # Get ALL columns
            cur.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (actual_schema, table))
            
            all_columns = []
            important_found = []
            
            for row in cur.fetchall():
                col_info = {
                    'name': row[0],
                    'type': row[1],
                    'nullable': row[2] == 'YES'
                }
                all_columns.append(col_info)
                
                # Track important columns for aerospace analysis
                if row[0] in important_columns:
                    important_found.append(row[0])
            
            if all_columns:
                # Get row count
                cur.execute(f"SELECT count(*) FROM {actual_schema}.{table}")
                row_count = cur.fetchone()[0]
                
                # Sample data to understand content
                sample_data = []
                if row_count > 0:
                    # Sample query with only existing important columns
                    existing_important = [col for col in important_found if col in ['name', 'amenity', 'landuse', 'office', 'industrial']]
                    if existing_important:
                        sample_columns = ', '.join(existing_important)
                        try:
                            cur.execute(f"""
                                SELECT {sample_columns}
                                FROM {actual_schema}.{table} 
                                WHERE name IS NOT NULL
                                LIMIT 3
                            """)
                            sample_data = cur.fetchall()
                        except Exception as e:
                            print(f"  Warning: Could not sample data from {table}: {e}")
                
                schema_info['tables'][table] = {
                    'exists': True,
                    'columns': all_columns,
                    'column_count': len(all_columns),
                    'row_count': row_count,
                    'important_columns_found': important_found,
                    'sample_data': sample_data
                }
                
                if row_count > 0:
                    schema_info['summary']['tables_with_data'] += 1
                
                schema_info['summary']['total_columns'] += len(all_columns)
                schema_info['summary']['total_tables'] += 1
                
                print(f"✓ {table}: {len(all_columns)} columns, {row_count:,} rows")
                print(f"  Important columns found: {len(important_found)}/{len(important_columns)}")
                print(f"  Key columns: {', '.join(important_found[:8])}")
                
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
    print("Inspecting UK OSM database schema with column awareness...")
    
    try:
        conn = connect_to_database()
        schema_info = inspect_osm_tables(conn)
        
        # Export schema info
        with open('aerospace_scoring/schema.json', 'w') as f:
            json.dump(schema_info, f, indent=2, default=str)
        
        conn.close()
        print(f"\n✓ Schema inspection completed")
        print(f"✓ Using schema: {schema_info['schema']}")
        print(f"✓ Schema saved to aerospace_scoring/schema.json")
        
        # Show summary
        summary = schema_info['summary']
        total_records = sum(t.get('row_count', 0) for t in schema_info['tables'].values() if isinstance(t, dict))
        print(f"\nSummary:")
        print(f"  Tables with data: {summary['tables_with_data']}")
        print(f"  Total records: {total_records:,}")
        print(f"  Schema: {schema_info['schema']}")
        
        # Show column analysis
        print(f"\nColumn Analysis:")
        for table_name, table_info in schema_info['tables'].items():
            if isinstance(table_info, dict) and table_info.get('exists'):
                important_cols = table_info.get('important_columns_found', [])
                print(f"  {table_name}: {len(important_cols)} aerospace-relevant columns")
        
    except Exception as e:
        print(f"✗ Schema inspection failed: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
