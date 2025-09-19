#!/usr/bin/env python3
"""
Alternative OSM Import using ogr2ogr
Fallback method if osm2pgsql has issues
"""

import sys
import os
sys.path.append('scripts/utils')

from osm_utils import setup_logging, load_config, run_command
import logging
from pathlib import Path

def main():
    setup_logging()
    config = load_config()
    
    logging.info("=== Alternative Import Method using ogr2ogr ===")
    
    data_dir = Path(config['download']['data_dir'])
    osm_file = data_dir / 'great-britain-latest.osm.pbf'
    
    if not osm_file.exists():
        logging.error(f"OSM file not found: {osm_file}")
        return False
    
    # Convert PBF to temporary SQLite first
    temp_sqlite = data_dir / 'uk_temp.sqlite'
    logging.info("Converting PBF to SQLite...")
    
    try:
        cmd = f'ogr2ogr -f SQLite "{temp_sqlite}" "{osm_file}"'
        run_command(cmd)
        logging.info("✓ Conversion to SQLite completed")
    except Exception as e:
        logging.error(f"PBF to SQLite conversion failed: {e}")
        return False
    
    # List available layers
    try:
        result = run_command(f'ogrinfo "{temp_sqlite}"')
        logging.info("Available layers:")
        for line in result.stdout.split('\n'):
            if line.startswith('  '):
                logging.info(f"  {line.strip()}")
    except Exception as e:
        logging.warning(f"Could not list layers: {e}")
    
    # Import each layer to PostgreSQL
    db_config = config['database']
    pg_conn_str = f"PG:host={db_config['host']} user={db_config['user']} dbname={db_config['name']} active_schema={db_config['schema']}"
    
    layers = ['points', 'lines', 'multipolygons', 'multilinestrings', 'other_relations']
    
    for layer in layers:
        try:
            logging.info(f"Importing layer: {layer}")
            cmd = f'''ogr2ogr -f PostgreSQL "{pg_conn_str}" "{temp_sqlite}" {layer} \
                -nln {layer}_raw \
                -lco SPATIAL_INDEX=NO \
                -lco CREATE_SCHEMA=NO \
                --config PG_USE_COPY YES \
                -overwrite'''
            
            run_command(cmd)
            logging.info(f"✓ Layer {layer} imported")
            
        except Exception as e:
            logging.warning(f"Could not import layer {layer}: {e}")
    
    # Cleanup
    if temp_sqlite.exists():
        temp_sqlite.unlink()
        logging.info("✓ Temporary SQLite file cleaned up")
    
    logging.info("=== Alternative import completed ===")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
