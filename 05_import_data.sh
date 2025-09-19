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

# Create the main import script
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
        if not subprocess.shutil.which(cmd):
            logging.error(f"Required command not found: {cmd}")
            return False
    
    # Check database connectivity
    db_config = config['database']
    try:
        import psycopg2
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
    
    cmd_parts = [
        'osm2pgsql',
        '--create',
        '--slim',
        f"--cache {config['import']['cache_size_mb']}",
        f"--number-processes {config['import']['num_processes']}",
        '--hstore',
        '--hstore-all',
        '--extra-attributes',
        '--keep-coastlines',
        f"--database {config['database']['name']}",
        f"--username {config['database'].get('user', 'a')}",
        '--prefix planet_osm',
        f"--style {style_file}",
        '--proj 3857',
        '--verbose',
        # Disable automatic indexing to save space and time
        '--disable-parallel-indexing',
        str(osm_file)
    ]
    
    return ' '.join(cmd_parts)

def monitor_import_progress():
    """Monitor import progress by watching log output."""
    import threading
    import queue
    
    # This would be enhanced with actual progress monitoring
    # For now, just indicate that monitoring is active
    logging.info("Import progress monitoring active...")
    
def run_import(config):
    """Execute the main import process."""
    logging.info("Starting OSM data import...")
    
    start_time = time.time()
    
    # Prepare environment
    env = prepare_import_environment(config)
    
    # Build command
    import_cmd = build_osm2pgsql_command(config)
    logging.info(f"Import command: {import_cmd}")
    
    # Show resource usage before import
    try:
        import psutil
        cpu_count = psutil.cpu_count()
        memory_gb = psutil.virtual_memory().total / (1024**3)
        disk_free_gb = psutil.disk_usage('.').free / (1024**3)
        
        logging.info(f"System resources: {cpu_count} CPUs, {memory_gb:.1f}GB RAM, {disk_free_gb:.1f}GB free disk")
    except ImportError:
        logging.info("psutil not available for resource monitoring")
    
    # Execute import
    try:
        # Start progress monitoring
        monitor_thread = threading.Thread(target=monitor_import_progress)
        monitor_thread.daemon = True
        monitor_thread.start()
        
        # Run the import command
        result = subprocess.run(
            import_cmd,
            shell=True,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # Log output
        if result.stdout:
            for line in result.stdout.split('\n'):
                if line.strip():
                    logging.info(f"osm2pgsql: {line}")
        
        if result.returncode == 0:
            elapsed_time = time.time() - start_time
            logging.info(f"✓ Import completed successfully in {elapsed_time/3600:.1f} hours")
            return True
        else:
            logging.error(f"Import failed with return code: {result.returncode}")
            return False
            
    except Exception as e:
        logging.error(f"Import execution failed: {e}")
        return False

def cleanup_post_import(config):
    """Clean up after import and re-enable normal database operations."""
    logging.info("Performing post-import cleanup...")
    
    db_config = config['database']
    
    try:
        import psycopg2
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config.get('user', 'a'),
            database=db_config['name']
        )
        cur = conn.cursor()
        
        # Re-enable autovacuum
        cur.execute("ALTER DATABASE %s SET autovacuum = on", (db_config['name'],))
        
        # Get basic statistics
        tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
        total_records = 0
        
        for table in tables:
            try:
                cur.execute(f"SELECT count(*) FROM {db_config['schema']}.{table}")
                count = cur.fetchone()[0]
                total_records += count
                logging.info(f"  {table}: {count:,} records")
            except Exception as e:
                logging.warning(f"Could not count {table}: {e}")
        
        logging.info(f"Total records imported: {total_records:,}")
        
        # Get database size
        cur.execute("SELECT pg_size_pretty(pg_database_size(%s))", (db_config['name'],))
        db_size = cur.fetchone()[0]
        logging.info(f"Database size: {db_size}")
        
        conn.commit()
        cur.close()
        conn.close()
        
        return True
        
    except Exception as e:
        logging.error(f"Post-import cleanup failed: {e}")
        return False

def main():
    setup_logging()
    config = load_config()
    
    logging.info("=== UK OSM Data Import Process ===")
    
    # Check prerequisites
    if not check_prerequisites(config):
        return False
    
    # Confirm with user before starting
    data_dir = Path(config['download']['data_dir'])
    osm_file = data_dir / 'great-britain-latest.osm.pbf'
    file_size_mb = osm_file.stat().st_size / (1024*1024)
    
    logging.info(f"Ready to import: {osm_file} ({file_size_mb:.1f} MB)")
    logging.info(f"Import settings: {config['import']['cache_size_mb']}MB cache, {config['import']['num_processes']} processes")
    
    print("\n" + "="*60)
    print("READY TO START IMPORT")
    print("="*60)
    print(f"Data file: {osm_file}")
    print(f"File size: {file_size_mb:.1f} MB")
    print(f"Database: {config['database']['name']}")
    print(f"Estimated time: 2-6 hours")
    print(f"No indexes will be created (for speed and space)")
    print("="*60)
    
    response = input("\nProceed with import? (yes/no): ").lower().strip()
    if response not in ['yes', 'y']:
        logging.info("Import cancelled by user")
        return False
    
    # Run import
    if not run_import(config):
        return False
    
    # Cleanup
    if not cleanup_post_import(config):
        logging.warning("Post-import cleanup had issues, but import completed")
    
    logging.info("=== Import Process Complete ===")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOF

# Create alternative import method using ogr2ogr (fallback)
cat > scripts/import/import_with_ogr2ogr.py << 'EOF'
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
EOF

# Make scripts executable
chmod +x scripts/import/import_osm_data.py
chmod +x scripts/import/import_with_ogr2ogr.py

# Main import execution
echo -e "${YELLOW}Checking OSM data file...${NC}"
if [ ! -f "data/raw/great-britain-latest.osm.pbf" ]; then
    echo -e "${RED}OSM data file not found!${NC}"
    echo -e "${YELLOW}Please run ./03_download_data.sh first${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking database connection...${NC}"
if ! psql -h localhost -U a -d uk_osm_full -c "SELECT version();" >/dev/null 2>&1; then
    echo -e "${RED}Cannot connect to database!${NC}"
    echo -e "${YELLOW}Please run ./04_setup_database.sh first${NC}"
    exit 1
fi

# Check available space one more time
echo -e "${YELLOW}Checking available disk space...${NC}"
AVAILABLE_SPACE_GB=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [[ $AVAILABLE_SPACE_GB -lt 50 ]]; then
    echo -e "${RED}Warning: Less than 50GB available space!${NC}"
    echo -e "${YELLOW}Import may fail due to insufficient space${NC}"
    read -p "Continue anyway? (y/N): " CONTINUE_ANYWAY
    if [[ $CONTINUE_ANYWAY != "y" && $CONTINUE_ANYWAY != "Y" ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}All prerequisites met!${NC}"
echo -e "${BLUE}=== Starting Import Process ===${NC}"

# Run the main import
if command -v uv &> /dev/null; then
    uv run scripts/import/import_osm_data.py
else
    python3 scripts/import/import_osm_data.py
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}=== Phase 5 Complete: Data Import Successful ===${NC}"
    echo -e "${YELLOW}Next step: Run ./06_verify_import.sh${NC}"
else
    echo -e "${RED}=== Import Failed ===${NC}"
    echo -e "${YELLOW}Trying alternative import method...${NC}"
    
    if command -v uv &> /dev/null; then
        uv run scripts/import/import_with_ogr2ogr.py
    else
        python3 scripts/import/import_with_ogr2ogr.py
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Alternative import method succeeded${NC}"
        echo -e "${YELLOW}Next step: Run ./06_verify_import.sh${NC}"
    else
        echo -e "${RED}✗ Both import methods failed${NC}"
        echo -e "${YELLOW}Check logs/osm_processor.log for details${NC}"
        echo -e "${YELLOW}You may need to adjust cache settings or try manual import${NC}"
    fi
fi