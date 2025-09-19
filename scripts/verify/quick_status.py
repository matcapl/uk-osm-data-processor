#!/usr/bin/env python3
"""
Quick status check for UK OSM database
"""

import sys
import os
sys.path.append('scripts/utils')

from osm_utils import setup_logging, load_config
import logging
import psycopg2

def main():
    setup_logging()
    config = load_config()
    
    db_config = config['database']
    schema = db_config.get('schema', 'osm_raw')
    
    try:
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config.get('user', 'a'),
            database=db_config['name']
        )
        cur = conn.cursor()
        
        print("UK OSM Database Status")
        print("=" * 30)
        
        # Quick counts
        tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
        total = 0
        
        for table in tables:
            try:
                cur.execute(f"SELECT count(*) FROM {schema}.{table}")
                count = cur.fetchone()[0]
                total += count
                print(f"{table:20}: {count:,}")
            except:
                print(f"{table:20}: ERROR")
        
        print(f"{'TOTAL':20}: {total:,}")
        
        # Database size
        cur.execute("SELECT pg_size_pretty(pg_database_size(%s))", (db_config['name'],))
        size = cur.fetchone()[0]
        print(f"{'Database size':20}: {size}")
        
        conn.close()
        
    except Exception as e:
        print(f"Error: {e}")
        return False
    
    return True

if __name__ == "__main__":
    main()
