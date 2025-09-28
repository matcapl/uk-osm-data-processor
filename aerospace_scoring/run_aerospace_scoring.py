#!/usr/bin/env python3
"""Main execution script for aerospace supplier scoring system"""

import subprocess
import psycopg2
import yaml
import getpass
import os
from pathlib import Path
from datetime import datetime

# Expected views
EXPECTED_VIEWS = [
    'planet_osm_point_aerospace_filtered',
    'planet_osm_line_aerospace_filtered',
    'planet_osm_polygon_aerospace_filtered',
    'planet_osm_point_aerospace_scored',
    'planet_osm_line_aerospace_scored',
    'planet_osm_polygon_aerospace_scored'
]

# Schemas and users to test
SCHEMAS = ['public', 'osm_raw']
USERS = ['a', 'ukosm_user', 'postgres']

def run_step(cmd, desc):
    print(f"Running: {desc}")
    try:
        subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        print(f"  ✓ {desc} completed")
        return True
    except subprocess.CalledProcessError as e:
        print(f"  ✗ {desc} failed: {e.stderr or e}")
        return False

def load_db_cfg():
    db = yaml.safe_load(Path('config/config.yaml').read_text())['database']
    return {
        'host': db['host'],
        'port': db['port'],
        'user': db['user'],
        'password': db.get('password',''),
        'dbname': db['name']
    }

def check_database():
    cfg = load_db_cfg()
    try:
        conn = psycopg2.connect(**cfg)
        schema = yaml.safe_load(Path('config/config.yaml').read_text())['database'].get('schema','public')
        with conn.cursor() as cur:
            cur.execute(f"SELECT 1 FROM {schema}.planet_osm_point LIMIT 1;")
        conn.close()
        print("✓ Database connection verified")
        return True
    except Exception as e:
        print(f"✗ Database connection failed: {e}")
        return False

def execute_sql():
    cfg = yaml.safe_load(Path('config/config.yaml').read_text())['database']
    cmd = (
        f"psql -h {cfg['host']} -p {cfg['port']} "
        f"-U {cfg['user']} -d {cfg['name']} "
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

def write_diagnostics(conn, out_path):
    cfg = yaml.safe_load(Path('config/config.yaml').read_text())['database']
    with open(out_path, 'w') as f:
        f.write(f"Logged at: {datetime.now()}\n\n")
        for schema in SCHEMAS:
            for user in USERS:
                f.write(f"--- Schema: {schema} | User: {user} ---\n")
                # reconnect as that user
                params = {
                    'host': cfg['host'],
                    'port': cfg['port'],
                    'dbname': cfg['name'],
                    'user': user,
                    'password': cfg.get('password','')
                }
                try:
                    c = psycopg2.connect(**params)
                    vs = get_existing_views(c, schema)
                    f.write("Available tables/views:\n")
                    for v in sorted(vs):
                        f.write(f"  {v}\n")
                    f.write("Counts & columns:\n")
                    for view in EXPECTED_VIEWS:
                        if view in vs:
                            cur = c.cursor()
                            cur.execute(f"SELECT COUNT(*) FROM {schema}.{view};")
                            cnt = cur.fetchone()[0]
                            f.write(f"  {view}: {cnt} rows\n")
                            cur.execute("""
                                SELECT column_name
                                FROM information_schema.columns
                                WHERE table_schema=%s AND table_name=%s
                                ORDER BY ordinal_position
                            """, (schema, view))
                            cols = [r[0] for r in cur.fetchall()]
                            f.write(f"    columns: {','.join(cols)}\n")
                        else:
                            f.write(f"  {view}: DOES NOT EXIST\n")
                    c.close()
                except Exception as e:
                    f.write(f"  ERROR connecting as {user}: {e}\n")
                f.write("\n")
    print(f"✓ Diagnostics written to {out_path}")

def main():
    print("="*60)
    print("UK AEROSPACE SUPPLIER SCORING SYSTEM")
    print(f"Started: {datetime.now()}")
    print("="*60)

    if not check_database():
        return 1

    steps = [
        ('uv run aerospace_scoring/load_schema.py', 'Database Schema Analysis'),
        ('uv run aerospace_scoring/generate_exclusions.py', 'Generate Exclusion Rules'),
        ('uv run aerospace_scoring/generate_scoring.py', 'Generate Scoring Rules'),
        ('uv run aerospace_scoring/assemble_sql.py', 'Assemble Complete SQL')
    ]
    for i, (cmd, desc) in enumerate(steps, 1):
        print(f"\nStep {i}: {desc}")
        if not run_step(cmd, desc):
            return 1

    print("\nStep 5: Executing SQL")
    if not execute_sql():
        return 1

    print("\nStep 6: Diagnostics")
    # use a dummy conn just for get_existing_views() signature
    base_conn = psycopg2.connect(**load_db_cfg())
    write_diagnostics(base_conn, 'check.txt')
    base_conn.close()

    print("\nStep 7: Verification")
    try:
        conn = psycopg2.connect(**load_db_cfg())
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM aerospace_supplier_candidates;")
        total = cur.fetchone()[0]
        cur.execute(
            "SELECT tier_classification, COUNT(*) FROM aerospace_supplier_candidates "
            "GROUP BY tier_classification ORDER BY COUNT(*) DESC"
        )
        tiers = cur.fetchall()
        conn.close()
        print("="*60)
        print("RESULTS SUMMARY")
        print("="*60)
        print(f"Total candidates: {total:,}")
        for tier, cnt in tiers:
            print(f"  {tier}: {cnt:,}")
        print("\n✓ Completed")
    except Exception as e:
        print(f"✗ Verification failed: {e}")
        return 1

    return 0

if __name__ == "__main__":
    exit(main())
