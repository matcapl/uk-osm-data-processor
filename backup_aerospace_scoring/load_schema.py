# ============================================================================
# AEROSPACE SUPPLIER SCORING SYSTEM FOR UK OSM DATABASE
# ============================================================================

# File 1: load_schema.py
"""
Database schema inspector for UK OSM data
Connects to PostGIS database and exports table/column information
"""

import psycopg2
import json
import yaml
from pathlib import Path
from typing import Dict, List, Any

def connect_to_database() -> psycopg2.extensions.connection:
    """Connect to the UK OSM database."""
    try:
        # Load database configuration
        with open('../config/config.yaml', 'r') as f:
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
        print(f"Database connection failed: {e}")
        raise

def inspect_osm_tables(conn: psycopg2.extensions.connection) -> Dict[str, Any]:
    """Inspect OSM tables and their columns."""
    cur = conn.cursor()
    
    # Get schema from config
    try:
        with open('../config/config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        schema = config['database'].get('schema', 'osm_raw')
    except:
        schema = 'osm_raw'
    
    # OSM tables to inspect
    osm_tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
    
    schema_info = {
        'schema': schema,
        'tables': {},
        'summary': {
            'total_tables': 0,
            'total_columns': 0,
            'tables_with_data': 0
        }
    }
    
    for table in osm_tables:
        try:
            # Get column information
            cur.execute("""
                SELECT 
                    column_name,
                    data_type,
                    is_nullable,
                    column_default
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema, table))
            
            columns = []
            for row in cur.fetchall():
                columns.append({
                    'name': row[0],
                    'type': row[1],
                    'nullable': row[2] == 'YES',
                    'default': row[3]
                })
            
            if columns:
                # Get row count
                cur.execute(f"SELECT count(*) FROM {schema}.{table}")
                row_count = cur.fetchone()[0]
                
                # Sample some data to understand content
                cur.execute(f"SELECT * FROM {schema}.{table} LIMIT 3")
                sample_rows = cur.fetchall()
                
                # Get column names for samples
                column_names = [desc[0] for desc in cur.description]
                samples = []
                for row in sample_rows:
                    sample = {}
                    for i, col_name in enumerate(column_names):
                        sample[col_name] = str(row[i]) if row[i] is not None else None
                    samples.append(sample)
                
                schema_info['tables'][table] = {
                    'exists': True,
                    'columns': columns,
                    'column_count': len(columns),
                    'row_count': row_count,
                    'sample_data': samples
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
    
    return schema_info

def analyze_aerospace_relevant_columns(schema_info: Dict[str, Any]) -> Dict[str, List[str]]:
    """Analyze which columns are most relevant for aerospace supplier identification."""
    
    # Define aerospace-relevant column patterns
    aerospace_columns = {
        'primary_filters': [
            'landuse', 'industrial', 'man_made', 'building', 'amenity',
            'aeroway', 'military'
        ],
        'identification': [
            'name', 'operator', 'brand', 'company', 'office', 'shop'
        ],
        'contact_info': [
            'website', 'phone', 'email', 'contact:website', 'contact:phone'
        ],
        'address': [
            'addr:postcode', 'addr:street', 'addr:city', 'addr:country'
        ],
        'descriptive': [
            'description', 'industrial:type', 'manufacturing', 'product',
            'craft', 'material', 'service'
        ],
        'spatial': [
            'way', 'geom'
        ]
    }
    
    found_columns = {}
    for category, expected_cols in aerospace_columns.items():
        found_columns[category] = []
        
        for table_name, table_info in schema_info['tables'].items():
            if table_info.get('exists'):
                table_columns = [col['name'] for col in table_info['columns']]
                for col in expected_cols:
                    if col in table_columns and col not in found_columns[category]:
                        found_columns[category].append(col)
    
    return found_columns

def export_schema_analysis(schema_info: Dict[str, Any], output_dir: Path = Path('./')):
    """Export schema analysis to files."""
    output_dir.mkdir(exist_ok=True)
    
    # Export full schema info
    with open(output_dir / 'schema.json', 'w') as f:
        json.dump(schema_info, f, indent=2, default=str)
    
    # Analyze aerospace-relevant columns
    aerospace_columns = analyze_aerospace_relevant_columns(schema_info)
    
    with open(output_dir / 'aerospace_columns.yaml', 'w') as f:
        yaml.dump(aerospace_columns, f, indent=2, default_flow_style=False)
    
    # Create summary report
    with open(output_dir / 'schema_summary.txt', 'w') as f:
        f.write("UK OSM Database Schema Analysis\n")
        f.write("=" * 40 + "\n\n")
        
        summary = schema_info['summary']
        f.write(f"Total tables: {summary['total_tables']}\n")
        f.write(f"Tables with data: {summary['tables_with_data']}\n")
        f.write(f"Total columns: {summary['total_columns']}\n\n")
        
        f.write("Table Details:\n")
        f.write("-" * 20 + "\n")
        for table_name, table_info in schema_info['tables'].items():
            if table_info.get('exists'):
                f.write(f"{table_name}:\n")
                f.write(f"  Columns: {table_info['column_count']}\n")
                f.write(f"  Records: {table_info['row_count']:,}\n")
                f.write(f"  Key columns: {[col['name'] for col in table_info['columns'][:10]]}\n\n")
        
        f.write("\nAerospace-Relevant Columns:\n")
        f.write("-" * 30 + "\n")
        for category, columns in aerospace_columns.items():
            f.write(f"{category.title()}: {', '.join(columns)}\n")
    
    print(f"\nSchema analysis exported to {output_dir}/")
    print(f"- schema.json: Complete database schema")
    print(f"- aerospace_columns.yaml: Aerospace-relevant columns")
    print(f"- schema_summary.txt: Human-readable summary")

def main():
    """Main function to inspect database schema."""
    print("Inspecting UK OSM database schema...")
    
    try:
        conn = connect_to_database()
        schema_info = inspect_osm_tables(conn)
        export_schema_analysis(schema_info)
        conn.close()
        
        print("\n✓ Schema inspection completed successfully")
        
    except Exception as e:
        print(f"✗ Schema inspection failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())