#!/bin/bash
# ========================================
# UK OSM Import Automation - Phase 4: Database Setup
# File: 04_setup_database.sh
# ========================================

# NOTE: To make this work:
# 1. Generated optimized postgresql.conf and restarted PostgreSQL manually.
# 2. Commented out temporary import optimization block in Python script.
# 3. Database and schema created via Python; manual SQL import not needed.
# 4. Verified PostGIS extensions and geometry test succeeded.


set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== UK OSM Import Automation - Phase 4: Database Setup ===${NC}"

# Create database setup script
cat > scripts/import/setup_database.py << 'EOF'
#!/usr/bin/env python3
"""
PostgreSQL/PostGIS Database Setup for UK OSM Import
"""

import sys
import os
sys.path.append('scripts/utils')

from osm_utils import setup_logging, load_config, run_command
import logging
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

def get_current_user():
    """Get current system user."""
    import getpass
    return getpass.getuser()

def create_database_user(config):
    """Create database user if it doesn't exist."""
    db_config = config['database']
    current_user = get_current_user()
    
    try:
        # On macOS with Homebrew PostgreSQL, connect as current user who has superuser privileges
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=current_user,
            database='postgres'
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur = conn.cursor()
        
        # Check if user exists
        cur.execute("SELECT 1 FROM pg_user WHERE usename = %s", (db_config['user'],))
        if not cur.fetchone():
            logging.info(f"Creating database user: {db_config['user']}")
            cur.execute(f"CREATE USER {db_config['user']} WITH CREATEDB")
        else:
            logging.info(f"Database user {db_config['user']} already exists")
        
        cur.close()
        conn.close()
        return True
        
    except Exception as e:
        # Try with the target user directly (may already exist with permissions)
        try:
            conn = psycopg2.connect(
                host=db_config['host'],
                port=db_config['port'],
                user=db_config['user'],
                database='postgres'
            )
            conn.close()
            logging.info(f"User {db_config['user']} already has access")
            return True
        except:
            logging.warning(f"Could not create user (may need manual setup): {e}")
            return False

def create_database(config):
    """Create the main database."""
    db_config = config['database']
    current_user = get_current_user()
    
    try:
        # Try to connect as current user first (macOS default)
        try:
            conn = psycopg2.connect(
                host=db_config['host'],
                port=db_config['port'],
                user=current_user,
                database='postgres'
            )
        except:
            # Fallback to target user
            conn = psycopg2.connect(
                host=db_config['host'],
                port=db_config['port'],
                user=db_config['user'],
                database='postgres'
            )
        
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur = conn.cursor()
        
        # Check if database exists
        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (db_config['name'],))
        if not cur.fetchone():
            logging.info(f"Creating database: {db_config['name']}")
            cur.execute(f"CREATE DATABASE {db_config['name']} OWNER {db_config['user']}")
        else:
            logging.info(f"Database {db_config['name']} already exists")
        
        cur.close()
        conn.close()
        return True
        
    except Exception as e:
        logging.error(f"Failed to create database: {e}")
        return False

def setup_postgis(config):
    """Enable PostGIS extensions."""
    db_config = config['database']
    
    try:
        # Connect to the target database
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config.get('user', 'postgres'),
            database=db_config['name']
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cur = conn.cursor()
        
        logging.info("Enabling PostGIS extensions...")
        
        # Enable extensions
        extensions = ['postgis', 'hstore', 'postgis_topology']
        for ext in extensions:
            try:
                cur.execute(f"CREATE EXTENSION IF NOT EXISTS {ext}")
                logging.info(f"✓ {ext} extension enabled")
            except Exception as e:
                logging.warning(f"Could not enable {ext}: {e}")
        
        # Verify PostGIS
        cur.execute("SELECT PostGIS_Full_Version()")
        version = cur.fetchone()[0]
        logging.info(f"PostGIS version: {version[:100]}...")
        
        cur.close()
        conn.close()
        return True
        
    except Exception as e:
        logging.error(f"Failed to setup PostGIS: {e}")
        return False

def create_schema(config):
    """Create schema for organized data storage."""
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
        
        schema_name = db_config.get('schema', 'osm_raw')
        logging.info(f"Creating schema: {schema_name}")
        
        cur.execute(f"CREATE SCHEMA IF NOT EXISTS {schema_name}")
        cur.execute(f"SET search_path = {schema_name}, public")
        
        cur.close()
        conn.close()
        return True
        
    except Exception as e:
        logging.error(f"Failed to create schema: {e}")
        return False

def optimize_for_import(config):
    """Optimize PostgreSQL settings for large data import."""
    db_config = config['database']
    
    try:
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config.get('user', 'postgres'),
            database=db_config['name']
        )
        cur = conn.cursor()
        
        logging.info("Optimizing database for import...")
        
        # Temporary settings for import performance
        # optimization_settings = [
        #    "SET maintenance_work_mem = '2GB'",
        #    "SET work_mem = '256MB'",
        #    "SET synchronous_commit = off",
        #    "SET full_page_writes = off",
        #    "SET checkpoint_completion_target = 0.9",
        #    "SET wal_buffers = '16MB'",
        #    "SET random_page_cost = 1.1"
        # ]
        #
        # for setting in optimization_settings:
        #    try:
        #        cur.execute(setting)
        #        logging.info(f"Applied: {setting}")
        #    except Exception as e:
        #        logging.warning(f"Could not apply setting {setting}: {e}")
        
        # Disable autovacuum for target database during import
        # cur.execute(f'ALTER DATABASE "{db_config["name"]}" SET autovacuum = off')
        # logging.info("Disabled autovacuum for import")
        
        conn.commit()
        cur.close()
        conn.close()
        return True
        
    except Exception as e:
        logging.error(f"Failed to optimize database: {e}")
        return False

def test_connection(config):
    """Test database connection and permissions."""
    db_config = config['database']
    
    try:
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config.get('user', 'postgres'),
            database=db_config['name']
        )
        cur = conn.cursor()
        
        # Test basic operations
        cur.execute("SELECT version()")
        pg_version = cur.fetchone()[0]
        
        cur.execute("SELECT PostGIS_Version()")
        postgis_version = cur.fetchone()[0]
        
        cur.execute("CREATE TABLE test_table (id SERIAL PRIMARY KEY, geom GEOMETRY(POINT, 4326))")
        cur.execute("INSERT INTO test_table (geom) VALUES (ST_GeomFromText('POINT(0 0)', 4326))")
        cur.execute("SELECT ST_AsText(geom) FROM test_table")
        test_result = cur.fetchone()[0]
        cur.execute("DROP TABLE test_table")
        
        conn.commit()
        cur.close()
        conn.close()
        
        logging.info(f"✓ PostgreSQL: {pg_version.split(',')[0]}")
        logging.info(f"✓ PostGIS: {postgis_version}")
        logging.info(f"✓ Geometry test: {test_result}")
        
        return True
        
    except Exception as e:
        logging.error(f"Database connection test failed: {e}")
        return False

def main():
    setup_logging()
    config = load_config()
    
    logging.info("Starting database setup for UK OSM import...")
    
    steps = [
        ("Creating database user", lambda: create_database_user(config)),
        ("Creating database", lambda: create_database(config)),
        ("Setting up PostGIS", lambda: setup_postgis(config)),
        ("Creating schema", lambda: create_schema(config)),
        ("Optimizing for import", lambda: optimize_for_import(config)),
        ("Testing connection", lambda: test_connection(config))
    ]
    
    for step_name, step_func in steps:
        logging.info(f"Step: {step_name}")
        if not step_func():
            logging.error(f"Failed: {step_name}")
            return False
        logging.info(f"✓ Completed: {step_name}")
    
    logging.info("Database setup completed successfully!")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOF

# Create PostgreSQL configuration optimization script
cat > scripts/import/optimize_postgresql.py << 'EOF'
#!/usr/bin/env python3
"""
PostgreSQL Configuration Optimizer for OSM Import
"""

import sys
import os
import subprocess
import platform
sys.path.append('scripts/utils')

from osm_utils import setup_logging, run_command
import logging

def get_system_info():
    """Get system information for optimization."""
    try:
        # Get total RAM
        if platform.system() == "Linux":
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if 'MemTotal:' in line:
                        total_ram_kb = int(line.split()[1])
                        total_ram_gb = total_ram_kb // (1024 * 1024)
                        break
        elif platform.system() == "Darwin":  # macOS
            result = run_command("sysctl -n hw.memsize")
            total_ram_gb = int(result.stdout.strip()) // (1024**3)
        else:
            total_ram_gb = 8  # Default assumption
        
        # Get CPU cores
        cpu_cores = os.cpu_count() or 4
        
        return total_ram_gb, cpu_cores
        
    except Exception as e:
        logging.warning(f"Could not detect system specs: {e}")
        return 8, 4  # Safe defaults

def generate_postgresql_conf(total_ram_gb, cpu_cores):
    """Generate optimized PostgreSQL configuration."""
    
    # Calculate optimal settings based on system resources
    shared_buffers_gb = max(1, min(total_ram_gb // 4, 8))  # 25% of RAM, max 8GB
    work_mem_mb = max(64, min(total_ram_gb * 1024 // 32, 512))  # Conservative work_mem
    maintenance_work_mem_gb = max(1, min(total_ram_gb // 2, 4))  # Up to 4GB
    effective_cache_size_gb = max(2, total_ram_gb * 3 // 4)  # 75% of RAM
    
    config = f"""
# PostgreSQL Configuration Optimized for OSM Import
# Generated automatically - backup your original postgresql.conf first

# Memory Settings
shared_buffers = {shared_buffers_gb}GB
work_mem = {work_mem_mb}MB
maintenance_work_mem = {maintenance_work_mem_gb}GB
effective_cache_size = {effective_cache_size_gb}GB

# Checkpoint and WAL Settings
checkpoint_completion_target = 0.9
checkpoint_timeout = 15min
max_wal_size = 4GB
min_wal_size = 1GB
wal_buffers = 16MB

# Connection Settings
max_connections = 100

# Query Planner Settings
random_page_cost = 1.1
effective_io_concurrency = {min(cpu_cores * 2, 200)}

# Logging (optional - for debugging)
log_min_duration_statement = 1000
log_checkpoints = on
log_lock_waits = on

# Background Writer
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0

# Vacuum and Analyze
autovacuum = on
autovacuum_max_workers = {max(2, cpu_cores // 2)}
autovacuum_naptime = 30s
"""
    
    return config

def find_postgresql_config():
    """Find PostgreSQL configuration file location."""
    try:
        # Try to find config through PostgreSQL (macOS approach)
        result = run_command("psql -c 'SHOW config_file;' -t postgres")
        config_path = result.stdout.strip()
        if os.path.exists(config_path):
            return config_path
    except:
        pass
    
    # Common macOS locations (prioritized for macOS)
    common_paths = [
        '/opt/homebrew/var/postgres/postgresql.conf',  # Apple Silicon Homebrew
        '/usr/local/var/postgres/postgresql.conf',     # Intel Homebrew
        '/opt/homebrew/var/postgresql@*/postgresql.conf',  # Specific versions
        '/usr/local/var/postgresql@*/postgresql.conf',
        '/etc/postgresql/*/main/postgresql.conf',      # Linux fallback
        '/var/lib/pgsql/data/postgresql.conf'          # Linux fallback
    ]
    
    import glob
    for pattern in common_paths:
        matches = glob.glob(pattern)
        if matches:
            return matches[0]
    
    return None

def main():
    setup_logging()
    
    total_ram_gb, cpu_cores = get_system_info()
    logging.info(f"System detected: {total_ram_gb}GB RAM, {cpu_cores} CPU cores")
    
    config_content = generate_postgresql_conf(total_ram_gb, cpu_cores)
    
    # Save optimized configuration
    config_path = "config/postgresql_optimized.conf"
    with open(config_path, 'w') as f:
        f.write(config_content)
    
    logging.info(f"Generated optimized configuration: {config_path}")
    
    # Try to find actual PostgreSQL config
    pg_config_path = find_postgresql_config()
    if pg_config_path:
        logging.info(f"PostgreSQL config found at: {pg_config_path}")
        print(f"""
To apply these optimizations:

1. Backup current config:
   sudo cp {pg_config_path} {pg_config_path}.backup

2. Apply optimizations (choose one):
   
   Option A - Append to existing config:
   sudo cat {config_path} >> {pg_config_path}
   
   Option B - Manual edit:
   sudo nano {pg_config_path}
   (Copy settings from {config_path})

3. Restart PostgreSQL:
   sudo systemctl restart postgresql

Note: These settings are optimized for import operations.
Consider reverting to more conservative settings after import.
        """)
    else:
        logging.warning("Could not locate PostgreSQL configuration file")
        print(f"Generated optimized settings in: {config_path}")
        print("Please manually apply these settings to your postgresql.conf file")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOF

# Make scripts executable
chmod +x scripts/import/setup_database.py
chmod +x scripts/import/optimize_postgresql.py

# Create SQL file for manual database setup (fallback)
cat > sql/manual_database_setup.sql << 'EOF'
-- Manual Database Setup for UK OSM Import (macOS)
-- Run these commands if automated setup fails

-- Create user (run as current user with superuser privileges)
CREATE USER a WITH CREATEDB;

-- Create database
CREATE DATABASE uk_osm_full OWNER a;

-- Connect to the new database
\c uk_osm_full

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Verify PostGIS
SELECT PostGIS_Full_Version();

-- Create schema
CREATE SCHEMA IF NOT EXISTS osm_raw;
SET search_path = osm_raw, public;

-- Optimize for import (session-level)
SET maintenance_work_mem = '2GB';
SET work_mem = '256MB';
SET synchronous_commit = off;
SET full_page_writes = off;
SET checkpoint_completion_target = 0.9;
SET wal_buffers = '16MB';

-- Disable autovacuum temporarily
ALTER DATABASE uk_osm_full SET autovacuum = off;

-- Test geometry operations
CREATE TABLE test_geom (id SERIAL PRIMARY KEY, geom GEOMETRY(POINT, 4326));
INSERT INTO test_geom (geom) VALUES (ST_GeomFromText('POINT(-2.2426 53.4808)', 4326)); -- Manchester
SELECT ST_AsText(geom) FROM test_geom;
DROP TABLE test_geom;

\echo 'Database setup complete!'
EOF

# Run the database setup
echo -e "${YELLOW}Starting PostgreSQL/PostGIS database setup...${NC}"

# Check if PostgreSQL is running
if ! pgrep -x postgres >/dev/null && ! brew services list | grep postgresql | grep started >/dev/null; then
    echo -e "${YELLOW}PostgreSQL doesn't appear to be running. Attempting to start...${NC}"
    
    # Try different methods to start PostgreSQL (macOS focused)
    if command -v brew >/dev/null; then
        brew services start postgresql || echo "Could not start with brew services"
    elif command -v systemctl >/dev/null; then
        sudo systemctl start postgresql || echo "Could not start with systemctl"
    else
        echo -e "${YELLOW}Please start PostgreSQL manually${NC}"
    fi
    
    sleep 3
fi

# Run PostgreSQL configuration optimizer
echo -e "${YELLOW}Generating PostgreSQL optimization settings...${NC}"
if command -v uv &> /dev/null; then
    uv run scripts/import/optimize_postgresql.py
else
    python3 scripts/import/optimize_postgresql.py
fi

echo ""
read -p "Do you want to apply PostgreSQL optimizations now? This requires sudo and PostgreSQL restart (y/N): " APPLY_OPTIMIZATIONS

if [[ $APPLY_OPTIMIZATIONS == "y" || $APPLY_OPTIMIZATIONS == "Y" ]]; then
    echo -e "${YELLOW}Please follow the instructions above to apply PostgreSQL optimizations.${NC}"
    echo -e "${YELLOW}On macOS, you may need to restart PostgreSQL with:${NC}"
    echo -e "${BLUE}brew services restart postgresql${NC}"
    echo -e "${YELLOW}Press Enter when ready to continue with database setup...${NC}"
    read
fi

# Run the database setup script
echo -e "${YELLOW}Running automated database setup...${NC}"
if command -v uv &> /dev/null; then
    uv run scripts/import/setup_database.py
else
    python3 scripts/import/setup_database.py
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database setup completed successfully${NC}"
    
    # Show database info
    echo -e "${BLUE}=== Database Setup Summary ===${NC}"
    echo -e "${GREEN}Database: uk_osm_full${NC}"
    echo -e "${GREEN}User: ?${NC}"
    echo -e "${GREEN}Schema: ?${NC}"
    echo -e "${GREEN}Extensions: PostGIS, hstore${NC}"
    
    echo -e "${GREEN}=== Phase 4 Complete: Database Ready ===${NC}"
    echo -e "${YELLOW}Next step: Run ./05_import_data.sh${NC}"
    
else
    echo -e "${RED}✗ Database setup failed${NC}"
    echo -e "${YELLOW}Trying manual setup...${NC}"
    
    echo -e "${YELLOW}Please run the following SQL commands manually:${NC}"
    echo -e "${BLUE}psql -f sql/manual_database_setup.sql postgres${NC}"
    echo ""
    echo -e "${YELLOW}Or connect to PostgreSQL and run commands from:${NC}"
    echo -e "${BLUE}sql/manual_database_setup.sql${NC}"
    
    read -p "Press Enter when manual setup is complete..."
    echo -e "${YELLOW}Next step: Run ./05_import_data.sh${NC}"
fi