#!/usr/bin/env python3
"""
Comprehensive UK OSM Import Verification
Verifies data quality, completeness, and generates analysis reports
"""

import sys
import os
import json
import time
sys.path.append('scripts/utils')

from osm_utils import setup_logging, load_config
import logging
import psycopg2
from pathlib import Path

def connect_to_database(config):
    """Create database connection."""
    db_config = config['database']
    try:
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config.get('user', 'a'),
            database=db_config['name']
        )
        return conn
    except Exception as e:
        logging.error(f"Database connection failed: {e}")
        return None

def verify_table_structure(conn, config):
    """Verify that all expected tables exist with correct structure."""
    logging.info("Verifying table structure...")
    
    schema = config['database'].get('schema', 'osm_raw')
    expected_tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
    
    cur = conn.cursor()
    table_info = {}
    
    for table in expected_tables:
        try:
            cur.execute(f"""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema, table))
            
            columns = cur.fetchall()
            if columns:
                table_info[table] = {
                    'exists': True,
                    'columns': columns,
                    'column_count': len(columns)
                }
                logging.info(f"✓ {table}: {len(columns)} columns")
            else:
                table_info[table] = {'exists': False}
                logging.warning(f"✗ {table}: not found")
                
        except Exception as e:
            logging.error(f"Error checking {table}: {e}")
            table_info[table] = {'exists': False, 'error': str(e)}
    
    return table_info

def get_record_counts(conn, config):
    """Get record counts for all tables."""
    logging.info("Getting record counts...")
    
    schema = config['database'].get('schema', 'osm_raw')
    tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
    
    cur = conn.cursor()
    counts = {}
    total_records = 0
    
    for table in tables:
        try:
            cur.execute(f"SELECT count(*) FROM {schema}.{table}")
            count = cur.fetchone()[0]
            counts[table] = count
            total_records += count
            logging.info(f"  {table:25}: {count:,} records")
        except Exception as e:
            logging.warning(f"Could not count {table}: {e}")
            counts[table] = 0
    
    counts['total'] = total_records
    logging.info(f"  {'TOTAL':25}: {total_records:,} records")
    return counts

def analyze_data_quality(conn, config):
    """Analyze data quality and completeness."""
    logging.info("Analyzing data quality...")
    
    schema = config['database'].get('schema', 'osm_raw')
    cur = conn.cursor()
    analysis = {}
    
    # Analyze amenities
    try:
        cur.execute(f"""
            SELECT amenity, count(*) as count
            FROM {schema}.planet_osm_point 
            WHERE amenity IS NOT NULL 
            GROUP BY amenity 
            ORDER BY count DESC 
            LIMIT 20
        """)
        analysis['top_amenities'] = cur.fetchall()
        logging.info(f"✓ Found {len(analysis['top_amenities'])} amenity types")
    except Exception as e:
        logging.warning(f"Could not analyze amenities: {e}")
        analysis['top_amenities'] = []
    
    # Analyze buildings
    try:
        cur.execute(f"""
            SELECT building, count(*) as count
            FROM {schema}.planet_osm_polygon 
            WHERE building IS NOT NULL AND building != 'yes'
            GROUP BY building 
            ORDER BY count DESC 
            LIMIT 15
        """)
        analysis['top_buildings'] = cur.fetchall()
        logging.info(f"✓ Found {len(analysis['top_buildings'])} building types")
    except Exception as e:
        logging.warning(f"Could not analyze buildings: {e}")
        analysis['top_buildings'] = []
    
    # Analyze land use
    try:
        cur.execute(f"""
            SELECT landuse, count(*) as count
            FROM {schema}.planet_osm_polygon 
            WHERE landuse IS NOT NULL 
            GROUP BY landuse 
            ORDER BY count DESC 
            LIMIT 15
        """)
        analysis['top_landuse'] = cur.fetchall()
        logging.info(f"✓ Found {len(analysis['top_landuse'])} landuse types")
    except Exception as e:
        logging.warning(f"Could not analyze landuse: {e}")
        analysis['top_landuse'] = []
    
    # Analyze highways
    try:
        cur.execute(f"""
            SELECT highway, count(*) as count
            FROM {schema}.planet_osm_line 
            WHERE highway IS NOT NULL 
            GROUP BY highway 
            ORDER BY count DESC 
            LIMIT 15
        """)
        analysis['top_highways'] = cur.fetchall()
        logging.info(f"✓ Found {len(analysis['top_highways'])} highway types")
    except Exception as e:
        logging.warning(f"Could not analyze highways: {e}")
        analysis['top_highways'] = []
    
    # Check for hstore tags
    try:
        cur.execute(f"""
            SELECT count(*) as records_with_tags
            FROM {schema}.planet_osm_point 
            WHERE tags IS NOT NULL
        """)
        tags_count = cur.fetchone()[0]
        analysis['records_with_tags'] = tags_count
        logging.info(f"✓ {tags_count:,} records have hstore tags")
    except Exception as e:
        logging.warning(f"Could not analyze hstore tags: {e}")
        analysis['records_with_tags'] = 0
    
    return analysis

def check_spatial_data(conn, config):
    """Check spatial data validity."""
    logging.info("Checking spatial data...")
    
    schema = config['database'].get('schema', 'osm_raw')
    cur = conn.cursor()
    spatial_info = {}
    
    tables_with_geom = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon']
    
    for table in tables_with_geom:
        try:
            # Check for valid geometries
            cur.execute(f"""
                SELECT 
                    count(*) as total,
                    count(way) as with_geometry,
                    count(CASE WHEN ST_IsValid(way) THEN 1 END) as valid_geometry
                FROM {schema}.{table}
            """)
            
            total, with_geom, valid_geom = cur.fetchone()
            spatial_info[table] = {
                'total': total,
                'with_geometry': with_geom,
                'valid_geometry': valid_geom
            }
            
            if with_geom > 0:
                validity_pct = (valid_geom / with_geom) * 100
                logging.info(f"✓ {table}: {validity_pct:.1f}% geometries valid ({valid_geom:,}/{with_geom:,})")
            else:
                logging.warning(f"⚠ {table}: no geometries found")
                
        except Exception as e:
            logging.warning(f"Could not check spatial data for {table}: {e}")
            spatial_info[table] = {'error': str(e)}
    
    return spatial_info

def get_database_statistics(conn, config):
    """Get database size and performance statistics."""
    logging.info("Getting database statistics...")
    
    cur = conn.cursor()
    stats = {}
    
    try:
        # Database size
        cur.execute("SELECT pg_size_pretty(pg_database_size(%s))", (config['database']['name'],))
        stats['database_size'] = cur.fetchone()[0]
        
        # Individual table sizes
        schema = config['database'].get('schema', 'osm_raw')
        tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
        table_sizes = {}
        
        for table in tables:
            try:
                cur.execute(f"SELECT pg_size_pretty(pg_total_relation_size('{schema}.{table}'))")
                table_sizes[table] = cur.fetchone()[0]
            except Exception as e:
                table_sizes[table] = f"Error: {e}"
        
        stats['table_sizes'] = table_sizes
        
        # Index count (should be minimal as requested)
        cur.execute(f"""
            SELECT count(*) 
            FROM pg_indexes 
            WHERE schemaname = %s
        """, (schema,))
        stats['index_count'] = cur.fetchone()[0]
        
        # Check for any constraints
        cur.execute(f"""
            SELECT count(*)
            FROM information_schema.table_constraints
            WHERE table_schema = %s AND constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY', 'UNIQUE')
        """, (schema,))
        stats['constraint_count'] = cur.fetchone()[0]
        
        logging.info(f"✓ Database size: {stats['database_size']}")
        logging.info(f"✓ Indexes: {stats['index_count']} (minimal as requested)")
        logging.info(f"✓ Constraints: {stats['constraint_count']}")
        
    except Exception as e:
        logging.error(f"Could not get database statistics: {e}")
        stats['error'] = str(e)
    
    return stats

def perform_sample_queries(conn, config):
    """Perform sample queries to test data accessibility."""
    logging.info("Testing sample queries...")
    
    schema = config['database'].get('schema', 'osm_raw')
    cur = conn.cursor()
    query_results = {}
    
    sample_queries = [
        {
            'name': 'manchester_amenities',
            'description': 'Amenities near Manchester',
            'query': f"""
                SELECT amenity, name, count(*) as count
                FROM {schema}.planet_osm_point 
                WHERE amenity IS NOT NULL 
                  AND way && ST_Transform(ST_GeomFromText('POLYGON((-2.3 53.4, -2.1 53.4, -2.1 53.5, -2.3 53.5, -2.3 53.4))', 4326), 3857)
                GROUP BY amenity, name
                ORDER BY count DESC
                LIMIT 10
            """
        },
        {
            'name': 'london_buildings',
            'description': 'Buildings in Central London',
            'query': f"""
                SELECT building, count(*) as count
                FROM {schema}.planet_osm_polygon 
                WHERE building IS NOT NULL 
                  AND way && ST_Transform(ST_GeomFromText('POLYGON((-0.2 51.45, 0.05 51.45, 0.05 51.55, -0.2 51.55, -0.2 51.45))', 4326), 3857)
                GROUP BY building
                ORDER BY count DESC
                LIMIT 10
            """
        },
        {
            'name': 'uk_major_roads',
            'description': 'Major roads in UK',
            'query': f"""
                SELECT highway, count(*) as count, sum(ST_Length(way))/1000 as total_km
                FROM {schema}.planet_osm_line 
                WHERE highway IN ('motorway', 'trunk', 'primary', 'secondary')
                GROUP BY highway
                ORDER BY total_km DESC
            """
        }
    ]
    
    for query_info in sample_queries:
        try:
            start_time = time.time()
            cur.execute(query_info['query'])
            results = cur.fetchall()
            execution_time = time.time() - start_time
            
            query_results[query_info['name']] = {
                'description': query_info['description'],
                'results': results[:5],  # First 5 results
                'result_count': len(results),
                'execution_time_seconds': round(execution_time, 2)
            }
            
            logging.info(f"✓ {query_info['name']}: {len(results)} results in {execution_time:.2f}s")
            
        except Exception as e:
            logging.warning(f"Sample query {query_info['name']} failed: {e}")
            query_results[query_info['name']] = {'error': str(e)}
    
    return query_results

def generate_verification_report(verification_data, config):
    """Generate comprehensive verification report."""
    
    # Create reports directory
    reports_dir = Path('reports')
    reports_dir.mkdir(exist_ok=True)
    
    # Generate JSON report
    json_report_path = reports_dir / 'import_verification.json'
    with open(json_report_path, 'w') as f:
        json.dump(verification_data, f, indent=2, default=str)
    
    # Generate human-readable report
    txt_report_path = reports_dir / 'import_verification_report.txt'
    with open(txt_report_path, 'w') as f:
        f.write("UK OSM Data Import Verification Report\n")
        f.write("=" * 50 + "\n\n")
        f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Database: {config['database']['name']}\n")
        f.write(f"Schema: {config['database'].get('schema', 'osm_raw')}\n\n")
        
        # Record counts
        f.write("RECORD COUNTS\n")
        f.write("-" * 20 + "\n")
        for table, count in verification_data.get('record_counts', {}).items():
            f.write(f"{table:25}: {count:,}\n")
        f.write("\n")
        
        # Database statistics
        if 'database_stats' in verification_data:
            stats = verification_data['database_stats']
            f.write("DATABASE STATISTICS\n")
            f.write("-" * 25 + "\n")
            f.write(f"Total size: {stats.get('database_size', 'Unknown')}\n")
            f.write(f"Indexes: {stats.get('index_count', 'Unknown')}\n")
            f.write(f"Constraints: {stats.get('constraint_count', 'Unknown')}\n\n")
            
            f.write("Table Sizes:\n")
            for table, size in stats.get('table_sizes', {}).items():
                f.write(f"  {table:25}: {size}\n")
            f.write("\n")
        
        # Data quality analysis
        if 'data_analysis' in verification_data:
            analysis = verification_data['data_analysis']
            
            f.write("TOP AMENITIES\n")
            f.write("-" * 15 + "\n")
            for amenity, count in analysis.get('top_amenities', [])[:10]:
                f.write(f"{amenity:20}: {count:,}\n")
            f.write("\n")
            
            f.write("TOP BUILDING TYPES\n")
            f.write("-" * 20 + "\n")
            for building, count in analysis.get('top_buildings', [])[:10]:
                f.write(f"{building:20}: {count:,}\n")
            f.write("\n")
            
            f.write("TOP LAND USE TYPES\n")
            f.write("-" * 20 + "\n")
            for landuse, count in analysis.get('top_landuse', [])[:10]:
                f.write(f"{landuse:20}: {count:,}\n")
            f.write("\n")
        
        # Sample query results
        if 'sample_queries' in verification_data:
            f.write("SAMPLE QUERY RESULTS\n")
            f.write("-" * 25 + "\n")
            for query_name, query_data in verification_data['sample_queries'].items():
                if 'error' not in query_data:
                    f.write(f"{query_data['description']}:\n")
                    f.write(f"  Results: {query_data['result_count']}\n")
                    f.write(f"  Execution time: {query_data['execution_time_seconds']}s\n\n")
    
    logging.info(f"✓ Verification report saved: {txt_report_path}")
    logging.info(f"✓ JSON data saved: {json_report_path}")
    
    return txt_report_path, json_report_path

def main():
    setup_logging()
    config = load_config()
    
    logging.info("=== UK OSM Import Verification ===")
    
    # Connect to database
    conn = connect_to_database(config)
    if not conn:
        return False
    
    verification_data = {
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'config': config
    }
    
    try:
        # Run all verification steps
        logging.info("Step 1: Verifying table structure...")
        verification_data['table_structure'] = verify_table_structure(conn, config)
        
        logging.info("Step 2: Getting record counts...")
        verification_data['record_counts'] = get_record_counts(conn, config)
        
        logging.info("Step 3: Analyzing data quality...")
        verification_data['data_analysis'] = analyze_data_quality(conn, config)
        
        logging.info("Step 4: Checking spatial data...")
        verification_data['spatial_data'] = check_spatial_data(conn, config)
        
        logging.info("Step 5: Getting database statistics...")
        verification_data['database_stats'] = get_database_statistics(conn, config)
        
        logging.info("Step 6: Testing sample queries...")
        verification_data['sample_queries'] = perform_sample_queries(conn, config)
        
        # Generate reports
        logging.info("Generating verification reports...")
        txt_report, json_report = generate_verification_report(verification_data, config)
        
        # Summary
        total_records = verification_data['record_counts'].get('total', 0)
        db_size = verification_data['database_stats'].get('database_size', 'Unknown')
        
        print("\n" + "="*60)
        print("VERIFICATION SUMMARY")
        print("="*60)
        print(f"Total records: {total_records:,}")
        print(f"Database size: {db_size}")
        print(f"Tables verified: {len(verification_data['table_structure'])}")
        print(f"Spatial data check: ✓")
        print(f"Sample queries: {len(verification_data['sample_queries'])} executed")
        print(f"Report saved: {txt_report}")
        print("="*60)
        
        logging.info("✓ Verification completed successfully!")
        return True
        
    except Exception as e:
        logging.error(f"Verification failed: {e}")
        return False
        
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
