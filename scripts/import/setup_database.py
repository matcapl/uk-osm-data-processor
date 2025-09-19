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
