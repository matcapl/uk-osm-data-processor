#!/usr/bin/env python3
"""Main execution script for aerospace supplier scoring system"""

import subprocess
import sys
import psycopg2
import yaml
from pathlib import Path
from datetime import datetime

def run_step(cmd, description):
    print(f"Running: {description}")
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        print(f"  ✓ {description} completed")
        return True
    except subprocess.CalledProcessError as e:
        print(f"  ✗ {description} failed: {e}")
        return False

def check_database():
    try:
        with open('config/config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        schema = config['database'].get('schema', 'public')
        
        db_config = config['database']
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config['user'],
            database=db_config['name']
        )
        
        cur = conn.cursor()
        cur.execute(f"SELECT COUNT(*) FROM {schema}.planet_osm_point LIMIT 1")
        conn.close()
        print("✓ Database connection verified")
        return True
    except Exception as e:
        print(f"✗ Database connection failed: {e}")
        return False

def debug_pipeline_before_insert():
    """Debug the pipeline state before final INSERT"""
    try:
        with open('config/config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        
        schema = config['database'].get('schema', 'public')
        db_config = config['database']
        conn = psycopg2.connect(
            host=db_config['host'], port=db_config['port'],
            user=db_config['user'], database=db_config['name']
        )
        conn.autocommit = True
        cur = conn.cursor()
        
        print("="*60)
        print("PIPELINE DEBUG - BEFORE FINAL INSERT")
        print("="*60)
        
        # Check filtered views
        filtered_tables = ['planet_osm_point_aerospace_filtered', 'planet_osm_polygon_aerospace_filtered']
        for table in filtered_tables:
            try:
                cur.execute(f"SELECT COUNT(*) FROM {schema}.{table}")
                count = cur.fetchone()[0]
                print(f"Filtered view {table}: {count:,} rows")
            except Exception as e:
                print(f"ERROR checking {table}: {e}")
        
        # Check scored views
        scored_tables = ['planet_osm_point_aerospace_scored', 'planet_osm_polygon_aerospace_scored']
        for table in scored_tables:
            try:
                cur.execute(f"SELECT COUNT(*), MAX(aerospace_score), MIN(aerospace_score) FROM {schema}.{table}")
                count, max_score, min_score = cur.fetchone()
                print(f"Scored view {table}: {count:,} rows, scores {min_score}-{max_score}")
                
                if count > 0:
                    # Show sample
                    cur.execute(f"SELECT name, aerospace_score FROM {schema}.{table} ORDER BY aerospace_score DESC LIMIT 3")
                    samples = cur.fetchall()
                    print(f"  Top samples: {samples}")
                    
            except Exception as e:
                print(f"ERROR checking {table}: {e}")
        
        # Test the UNION query
        try:
            cur.execute(f"""
                SELECT COUNT(*) FROM (
                    SELECT aerospace_score FROM {schema}.planet_osm_point_aerospace_scored
                    UNION ALL
                    SELECT aerospace_score FROM {schema}.planet_osm_polygon_aerospace_scored
                    UNION ALL  
                    SELECT aerospace_score FROM {schema}.planet_osm_line_aerospace_scored
                ) combined WHERE aerospace_score >= 0
            """)
            total_candidates = cur.fetchone()[0]
            print(f"Total candidates before INSERT: {total_candidates:,}")
            
        except Exception as e:
            print(f"ERROR testing UNION query: {e}")
        
        conn.close()
        print("="*60)
        
    except Exception as e:
        print(f"DEBUG failed: {e}")

def execute_sql():
    try:
        with open('config/config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        
        db_config = config['database']
        cmd = f"psql -h {db_config['host']} -p {db_config['port']} -U {db_config['user']} -d {db_config['name']} -f aerospace_scoring/compute_aerospace_scores.sql"
        
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ SQL execution completed")
            return True
        else:
            print(f"✗ SQL execution failed: {result.stderr}")
            return False
    except Exception as e:
        print(f"✗ Failed to execute SQL: {e}")
        return False

def main():
    print("="*60)
    print("UK AEROSPACE SUPPLIER SCORING SYSTEM")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    # Check prerequisites
    if not check_database():
        return 1
    
    # Run pipeline steps
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
    
    # Debug: dump the assembled SQL
    print("\n––– Assembled SQL –––")
    print(Path('aerospace_scoring/compute_aerospace_scores.sql').read_text())
    print("––––––––––––––––––\n")

    debug_pipeline_before_insert()

    # Execute SQL
    print(f"\nStep 5: Executing SQL")
    if not execute_sql():
        return 1
    
    # Verify results
    print(f"\nStep 6: Verification")
    try:
        with open('config/config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        
        db_config = config['database']
        conn = psycopg2.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config['user'],
            database=db_config['name']
        )
        
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM aerospace_supplier_candidates")
        total = cur.fetchone()[0]
        
        cur.execute("SELECT tier_classification, COUNT(*) FROM aerospace_supplier_candidates GROUP BY tier_classification ORDER BY COUNT(*) DESC")
        tiers = cur.fetchall()
        
        conn.close()
        
        print("="*60)
        print("RESULTS SUMMARY")
        print("="*60)
        print(f"Total candidates: {total:,}")
        print("\nTier breakdown:")
        for tier, count in tiers:
            print(f"  {tier}: {count:,}")
        
        print(f"\n✓ Aerospace supplier scoring completed!")
        print(f"Results in table: aerospace_supplier_candidates")
        
    except Exception as e:
        print(f"✗ Verification failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
