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
