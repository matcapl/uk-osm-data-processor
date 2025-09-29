#!/usr/bin/env python3
"""Main execution script for aerospace supplier scoring system - CORRECTED VERSION"""

import subprocess
import psycopg2
import yaml
import os
from pathlib import Path
from datetime import datetime

EXPECTED_VIEWS = [
    'planet_osm_point_aerospace_filtered',
    'planet_osm_line_aerospace_filtered',
    'planet_osm_polygon_aerospace_filtered',
    'planet_osm_point_aerospace_scored',
    'planet_osm_line_aerospace_scored',
    'planet_osm_polygon_aerospace_scored'
]

def run_step(cmd, desc):
    print(f"Running: {desc}")
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        print(f"  ✓ {desc} completed")
        if result.stdout:
            print(f"  Output: {result.stdout.strip()}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"  ✗ {desc} failed: {e.stderr or e}")
        return False

def load_db_config():
    try:
        with open('config/config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        db_config = config['database']
        return {
            'host': db_config['host'],
            'port': db_config['port'],
            'user': db_config['user'],
            'password': db_config.get('password', ''),
            'dbname': db_config['name'],
            'schema': db_config.get('schema', 'public')
        }
    except Exception as e:
        print(f"✗ Could not load config: {e}")
        return None

def check_database():
    cfg = load_db_config()
    if not cfg:
        return False
    
    try:
        conn_params = {k: v for k, v in cfg.items() if k != 'schema'}
        conn = psycopg2.connect(**conn_params)
        schema = cfg['schema']
        
        with conn.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) FROM {schema}.planet_osm_point LIMIT 1")
            count = cur.fetchone()[0]
            print(f"✓ Database connection verified ({count:,} records in planet_osm_point)")
        conn.close()
        return True
    except Exception as e:
        print(f"✗ Database connection failed: {e}")
        return False

def execute_sql():
    cfg = load_db_config()
    if not cfg:
        return False
    
    cmd = (
        f"psql -h {cfg['host']} -p {cfg['port']} "
        f"-U {cfg['user']} -d {cfg['dbname']} "
        f"-f aerospace_scoring/compute_aerospace_scores.sql"
    )
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode == 0:
        print("✓ SQL execution completed")
        return True
    print(f"✗ SQL execution failed: {result.stderr}")
    return False

def get_existing_views(conn, schema):
    cur = conn.cursor()
    cur.execute("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema=%s
          AND table_type IN ('VIEW','BASE TABLE');
    """, (schema,))
    return {r[0] for r in cur.fetchall()}

def write_diagnostics(conn, out_path, schema):
    with open(out_path, 'w') as f:
        f.write(f"Aerospace Pipeline Diagnostics\n")
        f.write(f"Generated: {datetime.now()}\n")
        f.write(f"Schema: {schema}\n\n")
        
        f.write("Available tables/views:\n")
        views = get_existing_views(conn, schema)
        for v in sorted(views):
            f.write(f"  {v}\n")
        
        f.write("\nExpected views status:\n")
        for view in EXPECTED_VIEWS:
            if view in views:
                cur = conn.cursor()
                try:
                    cur.execute(f"SELECT COUNT(*) FROM {schema}.{view}")
                    cnt = cur.fetchone()[0]
                    f.write(f"  ✓ {view}: {cnt} rows\n")
                except Exception as e:
                    f.write(f"  ✗ {view}: ERROR - {e}\n")
            else:
                f.write(f"  ✗ {view}: MISSING\n")
    
    print(f"✓ Diagnostics written to {out_path}")

def main():
    print("="*60)
    print("UK AEROSPACE SUPPLIER SCORING SYSTEM (CORRECTED)")
    print(f"Started: {datetime.now()}")
    print("="*60)

    if not check_database():
        return 1

    steps = [
        ('python3 aerospace_scoring/load_schema.py', 'Database Schema Analysis'),
        ('python3 aerospace_scoring/generate_exclusions.py', 'Generate Exclusion Rules'),
        ('python3 aerospace_scoring/generate_scoring.py', 'Generate Scoring Rules'),
        ('python3 aerospace_scoring/assemble_sql.py', 'Assemble Complete SQL')
    ]
    
    for i, (cmd, desc) in enumerate(steps, 1):
        print(f"\nStep {i}: {desc}")
        if not run_step(cmd, desc):
            return 1

    print("\nStep 5: Executing SQL")
    if not execute_sql():
        return 1

    print("\nStep 6: Diagnostics")
    cfg = load_db_config()
    if cfg:
        conn_params = {k: v for k, v in cfg.items() if k != 'schema'}
        try:
            conn = psycopg2.connect(**conn_params)
            write_diagnostics(conn, 'check.txt', cfg['schema'])
            conn.close()
        except Exception as e:
            print(f"✗ Diagnostics failed: {e}")

    print("\nStep 7: Verification")
    try:
        cfg = load_db_config()
        conn_params = {k: v for k, v in cfg.items() if k != 'schema'}
        conn = psycopg2.connect(**conn_params)
        schema = cfg['schema']
        
        cur = conn.cursor()
        cur.execute(f"SELECT COUNT(*) FROM {schema}.aerospace_supplier_candidates")
        total = cur.fetchone()[0]
        
        cur.execute(f"""
            SELECT tier_classification, COUNT(*) 
            FROM {schema}.aerospace_supplier_candidates 
            GROUP BY tier_classification 
            ORDER BY COUNT(*) DESC
        """)
        tiers = cur.fetchall()
        conn.close()
        
        print("="*60)
        print("RESULTS SUMMARY")
        print("="*60)
        print(f"Total candidates: {total:,}")
        for tier, cnt in tiers:
            print(f"  {tier}: {cnt:,}")
        print("\n✓ Completed successfully!")
        
    except Exception as e:
        print(f"✗ Verification failed: {e}")
        return 1

    return 0

if __name__ == "__main__":
    exit(main())
