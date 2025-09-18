#!/bin/bash
# ========================================
# UK OSM Import Automation - Phase 5: Data Import
# File: 05_import_data.sh
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== UK OSM Import Automation - Phase 5: Data Import ===${NC}"

# Create or update the style file if missing
STYLE_FILE="config/uk_full_retention.style"
if [ ! -f "$STYLE_FILE" ]; then
    echo -e "${YELLOW}Creating missing style file: $STYLE_FILE${NC}"
    cat > "$STYLE_FILE" << 'EOF'
# OSM2PGSQL Style File for Full UK Data Retention
# This style file ensures maximum data retention

# Way tags - comprehensive list for all data types
way   access        text     linear
way   addr:city     text     linear
way   addr:country  text     linear
way   addr:housenumber text  linear
way   addr:postcode text     linear
way   addr:street   text     linear
way   admin_level   text     linear
way   amenity       text     linear
way   area          text     linear  # Import area=yes/no
way   barrier       text     linear
way   bicycle       text     linear
way   boundary      text     linear
way   bridge        text     linear
way   building      text     linear
way   building:levels text   linear
way   building:use  text     linear
way   commercial    text     linear
way   construction  text     linear
way   covered       text     linear
way   cuisine       text     linear
way   description   text     linear
way   ele           text     linear
way   emergency     text     linear
way   foot          text     linear
way   highway       text     linear
way   historic      text     linear
way   horse         text     linear
way   industrial    text     linear
way   landuse       text     linear
way   layer         text     linear
way   leisure       text     linear
way   man_made      text     linear
way   military      text     linear
way   name          text     linear
way   name:en       text     linear
way   natural       text     linear
way   office        text     linear
way   oneway        text     linear
way   operator      text     linear
way   place         text     linear
way   power         text     linear
way   public_transport text  linear
way   railway       text     linear
way   ref           text     linear
way   religion      text     linear
way   residential   text     linear
way   route         text     linear
way   service       text     linear
way   shop          text     linear
way   surface       text     linear
way   tourism       text     linear
way   tracktype     text     linear
way   tunnel        text     linear
way   water         text     linear
way   waterway      text     linear
way   website       text     linear
way   wheelchair    text     linear
way   width         text     linear
way   z_order       int4     linear # Internal OSM2PGSQL field

# Point tags - for nodes
node  addr:city     text     
node  addr:country  text     
node  addr:housenumber text  
node  addr:postcode text     
node  addr:street   text     
node  amenity       text     
node  barrier       text     
node  emergency     text     
node  highway       text     
node  historic      text     
node  landuse       text     
node  leisure       text     
node  man_made      text     
node  name          text     
node  name:en       text     
node  natural       text     
node  office        text     
node  place         text     
node  power         text     
node  public_transport text  
node  railway       text     
node  ref           text     
node  religion      text     
node  shop          text     
node  tourism       text     
node  waterway      text     
node  website       text     
node  wheelchair    text     
EOF
fi

# Create the main import script (completed version)
cat > scripts/import/import_osm_data.py << 'EOF'
#!/usr/bin/env python3
"""
OSM Data Import using osm2pgsql
Imports UK OSM data into PostgreSQL with maximum data retention
"""

import sys
import os
import time
import subprocess
sys.path.append('scripts/utils')

from osm_utils import setup_logging, load_config, run_command, check_disk_space
import logging
from pathlib import Path
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

def check_prerequisites(config):
    """Check all prerequisites for import."""
    logging.info("Checking prerequisites...")
    
    # Check disk space
    if not check_disk_space('.', config.get('system', {}).get('min_free_space_gb', 100)):
        logging.error("Insufficient disk space")
        return False
    
    # Check if data file exists
    data_dir = Path(config['download']['data_dir'])
    osm_file = data_dir / 'great-britain-latest.osm.pbf'
    if not osm_file.exists():
        logging.error(f"OSM data file not found: {osm_file}")
        logging.error("Please run 03_download_data.sh first")
        return False
    
    # Check required commands
    required_commands = ['osm2pgsql', 'psql']
    for cmd in required_commands:
        if not subprocess.run(['which', cmd], capture_output=True).returncode == 0:
            logging.error(f"Required command not found: {cmd}")
            return False
    
    # Check database connectivity
    db_config = config['database']
    try:
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config.get('user', 'postgres'),
            database=db_config['name']
        )
        conn.close()
        logging.info("✓ Database connection verified")
    except Exception as e:
        logging.error(f"Cannot connect to database: {e}")
        return False
    
    logging.info("✓ All prerequisites met")
    return True

def prepare_import_environment(config):
    """Prepare environment for import."""
    logging.info("Preparing import environment...")
    
    # Create temporary directory
    temp_dir = Path(config.get('system', {}).get('temp_dir', './tmp'))
    temp_dir.mkdir(exist_ok=True)
    
    # Set environment variables for osm2pgsql
    env = os.environ.copy()
    env['PGHOST'] = config['database']['host']
    env['PGPORT'] = str(config['database']['port'])
    env['PGUSER'] = config['database'].get('user', 'postgres')
    env['PGDATABASE'] = config['database']['name']
    
    if config['database'].get('password'):
        env['PGPASSWORD'] = config['database']['password']
    
    return env

def build_osm2pgsql_command(config):
    """Build the osm2pgsql command with optimal settings."""
    
    data_dir = Path(config['download']['data_dir'])
    osm_file = data_dir / 'great-britain-latest.osm.pbf'
    style_file = Path(config['import']['style_file'])
    
    # Dynamic adjustments based on system
    import platform
    total_ram_gb = int(subprocess.run(["free", "-g"], capture_output=True, text=True).stdout.splitlines()[1].split()[1]) if platform.system() == "Linux" else 8
    cache_size = min(config['import']['cache_size_mb'], total_ram_gb * 512)  # Cap cache at 0.5GB per GB RAM
    num_processes = min(config['import']['num_processes'], os.cpu_count() or 4)
    
    # Base command
    cmd_parts = [
        'osm2pgsql',
        '--create',
        '--slim',
        f"--cache {cache_size}",
        f"--number-processes {num_processes}",
        '--hstore',
        '--hstore-all',
        '--extra-attributes',
        '--keep-coastlines',
        f"--database {config['database']['name']}",
        f"--username {config['database'].get('user', 'postgres')}",
        '--prefix planet_osm',
        f"--style {style_file}",
        '--proj 3857',
        '--verbose',
        # Disable automatic indexing to save space and time
        '--disable-parallel-indexing',
        str(osm_file)
    ]
    
    return ' '.join(cmd_parts)

def perform_import(config, env):
    """Execute the data import."""
    logging.info("Starting OSM data import...")
    start_time = time.time()
    
    cmd = build_osm2pgsql_command(config)
    try:
        result = subprocess.run(cmd, shell=True, env=env, check=True, capture_output=False)
        duration = (time.time() - start_time) / 60
        logging.info(f"✓ Import completed in {duration:.2f} minutes")
        return True
    except subprocess.CalledProcessError as e:
        logging.error(f"osm2pgsql import failed: {e.stderr}")
        return False

def fallback_ogr2ogr_import(config):
    """Fallback import using ogr2ogr if osm2pgsql fails."""
    logging.warning("Attempting fallback import with ogr2ogr...")
    
    data_dir = Path(config['download']['data_dir'])
    osm_file = data_dir / 'great-britain-latest.osm.pbf'
    temp_sqlite = data_dir / 'uk_temp.sqlite'
    
    # Convert to SQLite
    run_command(f"ogr2ogr -f SQLite {temp_sqlite} {osm_file}")
    
    # List layers and import each without indexes
    layers = ['points', 'lines', 'multipolygons', 'multilinestrings', 'other_relations']
    db_config = config['database']
    pg_conn_str = f"PG:\"host={db_config['host']} user={db_config.get('user', 'postgres')} dbname={db_config['name']} active_schema={db_config.get('schema', 'osm_raw')}\""
    
    for layer in layers:
        run_command(f"ogr2ogr -f PostgreSQL {pg_conn_str} {temp_sqlite} {layer} -nln {layer}_raw -lco SPATIAL_INDEX=NO --config PG_USE_COPY YES -overwrite")
    
    # Clean up
    temp_sqlite.unlink(missing_ok=True)
    logging.info("✓ Fallback import completed")
    return True

def post_import_cleanup(config):
    """Cleanup and re-enable database settings post-import."""
    logging.info("Performing post-import cleanup...")
    
    db_config = config['database']
    try:
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config.get('user', 'postgres'),
            database=db_config['name']
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur = conn.cursor()
        
        # Re-enable autovacuum
        cur.execute(f"ALTER DATABASE {db_config['name']} SET autovacuum = on")
        logging.info("✓ Re-enabled autovacuum")
        
        # Run vacuum analyze
        cur.execute("VACUUM ANALYZE")
        logging.info("✓ Ran VACUUM ANALYZE")
        
        cur.close()
        conn.close()
    except Exception as e:
        logging.warning(f"Post-import cleanup partial failure: {e}")

def main():
    setup_logging()
    config = load_config()
    
    if not check_prerequisites(config):
        sys.exit(1)
    
    env = prepare_import_environment(config)
    
    if not perform_import(config, env):
        logging.warning("Primary import failed - trying fallback...")
        if not fallback_ogr2ogr_import(config):
            sys.exit(1)
    
    post_import_cleanup(config)
    
    logging.info("Data import process completed successfully!")
    sys.exit(0)

if __name__ == "__main__":
    main()
EOF

# Make the Python script executable
chmod +x scripts/import/import_osm_data.py

# Run the import
echo -e "${YELLOW}Running data import...${NC}"
read -p "Proceed with import? This may take 2-6 hours and use significant resources (Y/n): " PROCEED
if [[ $PROCEED != "n" && $PROCEED != "N" ]]; then
    if command -v uv &> /dev/null; then
        uv run scripts/import/import_osm_data.py
    else
        python3 scripts/import/import_osm_data.py
    fi
    echo -e "${GREEN}=== Phase 5 Complete: Data Imported ===${NC}"
    echo -e "${YELLOW}Next step: Run ./06_verify_import.sh${NC}"
else
    echo -e "${YELLOW}Import skipped. Run this script again when ready.${NC}"
fi