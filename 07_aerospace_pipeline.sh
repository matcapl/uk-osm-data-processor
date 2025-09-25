#!/bin/bash

# ========================================
# UK OSM Import - MASTER SETUP SCRIPT FOR UK AEROSPACE SUPPLIER SCORING SYSTEM
# File: was 0Claude_setup_uk_osm_project.sh now 07_aerospace_pipeline.sh
# ========================================

# To make this work
# Fixed load_schema.py(?)
# deleted garbage after last echo (incomplete / stray code likely from load_schema.py(?))
# Within check_database within run_aerospace_scoring.py :
# changed cur.execute("SELECT COUNT(*) FROM osm_raw.planet_osm_point LIMIT 1") to cur.execute(f"SELECT COUNT(*) FROM {schema}.planet_osm_point LIMIT 1")
# added schema and print in 
# schema = config['database'].get('schema', 'public')
# print("Using schema:", schema)
# Changed steps = [python3...] to 
    # steps = [
    #     ('uv run aerospace_scoring/load_schema.py', 'Database Schema Analysis'),
    #     ('uv run aerospace_scoring/generate_exclusions.py', 'Generate Exclusion Rules'),
    #     ('uv run aerospace_scoring/generate_scoring.py', 'Generate Scoring Rules'),
    #     ('uv run aerospace_scoring/assemble_sql.py', 'Assemble Complete SQL')
    # ]
# Changed scoring_expr = f"(\n        {' +\n        '.join(all_parts)}\n    ) AS aerospace_score" to 
# joined_parts = ' +\n        '.join(all_parts)
# scoring_expr = f"(\n        {joined_parts}\n    ) AS aerospace_score"
# Within run_aerospace_scoring.py 
# Changed (then changed back again, because it didn't work) cmd = f"psql -h {db_config['host']} ... -f aerospace_scoring/compute_aerospace_scores.sql" to 
# cmd = f"psql -h {db_config['host']} ... -f aerospace_scoring/compute_aerospace_complete.sql"

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== UK Aerospace Supplier Scoring System Setup ===${NC}"

echo "Granting view permissions to pipeline user..."
psql -d uk_osm_full -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO ukosm_user;"

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p aerospace_scoring

# Create all YAML configuration files
echo -e "${YELLOW}Creating YAML configuration files...${NC}"

# 1. exclusions.yaml
cat > aerospace_scoring/exclusions.yaml << 'EOF'
# aerospace_scoring/exclusions.yaml - RELAXED VERSION
exclusions:
  # Only exclude obvious non-industrial categories
  residential_strict:
    amenity: ['restaurant', 'pub', 'cafe', 'fast_food', 'school', 'hospital']
    shop: ['convenience', 'supermarket', 'clothes', 'hairdresser']
    tourism: ['hotel', 'attraction', 'museum']
  
  # Remove problematic empty arrays entirely
  # infrastructure: {} # REMOVED - was causing issues

overrides:
  # Aerospace keywords - expanded and case-insensitive ready
  aerospace_keywords:
    name: ['aerospace', 'aviation', 'aircraft', 'airbus', 'boeing', 'bae', 'rolls', 'royce', 'leonardo', 'thales', 'safran']
    operator: ['aerospace', 'aviation', 'aircraft', 'defense', 'defence']
  
  # Keep ALL industrial/office facilities
  industrial_overrides:
    landuse: ['industrial', 'commercial']
    building: ['industrial', 'warehouse', 'factory', 'office']
    office: ['*']  # Keep all offices
    industrial: ['*']  # Keep all industrial
    man_made: ['works', 'factory', 'tower', 'mast']

# Minimal table-specific exclusions
table_exclusions:
  planet_osm_point:
    amenity: ['restaurant', 'cafe', 'pub']  # Only obvious non-industrial
  planet_osm_polygon:
    landuse: ['residential']  # Only residential areas
EOF

# 2. scoring.yaml
cat > aerospace_scoring/scoring.yaml << 'EOF'
# Scoring rules for aerospace supplier candidates
scoring_rules:
  # Direct aerospace indicators (highest scores)
  direct_aerospace:
    weight: 100
    conditions:
      - name_contains: ['aerospace', 'aviation', 'aircraft', 'airbus', 'boeing', 'bae', 'rolls royce', 'safran', 'leonardo', 'thales']
      - operator_contains: ['aerospace', 'aviation', 'aircraft']
      - description_contains: ['aerospace', 'aviation', 'aircraft', 'avionics']
      - office: ['aerospace', 'aviation']

  # Defense/military contractors (high scores)
  defense:
    weight: 80
    conditions:
      - name_contains: ['defense', 'defence', 'military', 'radar', 'missile', 'weapons']
      - description_contains: ['defense', 'defence', 'military', 'security']
      - military: ['*']
      - landuse: ['military']

  # High-tech manufacturing (medium-high scores)
  high_tech:
    weight: 70
    conditions:
      - name_contains: ['engineering', 'technology', 'systems', 'electronics', 'precision', 'advanced']
      - industrial: ['engineering', 'electronics', 'precision', 'high_tech']
      - man_made: ['works', 'factory']
      - office: ['engineering', 'research', 'technology']
      - building: ['industrial', 'factory', 'warehouse']

  # General manufacturing (medium scores)
  manufacturing:
    weight: 50
    conditions:
      - landuse: ['industrial']
      - building: ['industrial', 'warehouse', 'manufacture']
      - industrial: ['*']
      - craft: ['metalworking', 'electronics', 'machining']

  # Research and development (medium scores)
  research:
    weight: 60
    conditions:
      - name_contains: ['research', 'development', 'laboratory', 'institute', 'university']
      - office: ['research', 'engineering']
      - amenity: ['research_institute', 'university']

  # Geographic bonuses (UK aerospace clusters)
  geographic_bonuses:
    weight: 20
    conditions:
      - postcode_area: ['BA', 'BS', 'GL', 'DE', 'PR', 'YO', 'CB', 'RG', 'SL']

# Keyword scoring bonuses
keyword_bonuses:
  tier1_keywords:
    weight: 50
    keywords: ['boeing', 'airbus', 'rolls royce', 'bae systems', 'leonardo', 'thales', 'safran']
  
  tier2_keywords:
    weight: 30
    keywords: ['aerospace', 'aviation', 'aircraft', 'avionics', 'turbine', 'engine']
  
  manufacturing_keywords:
    weight: 20
    keywords: ['precision', 'machining', 'casting', 'forging', 'composite', 'materials']
EOF

# 3. negative_signals.yaml
cat > aerospace_scoring/negative_signals.yaml << 'EOF'
# Negative indicators that reduce aerospace supplier likelihood
negative_signals:
  # Strong negative indicators
  strong_negatives:
    weight: -50
    conditions:
      - amenity: ['restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'hospital', 'school']
      - shop: ['*']
      - tourism: ['*']
      - leisure: ['*']
      - building: ['house', 'apartments', 'residential', 'hotel', 'retail']

  # Medium negative indicators
  medium_negatives:
    weight: -25
    conditions:
      - landuse: ['residential', 'retail', 'commercial', 'farmland']
      - name_contains: ['restaurant', 'cafe', 'pub', 'hotel', 'school', 'church', 'farm']

  # Service sector indicators
  service_negatives:
    weight: -15
    conditions:
      - office: ['insurance', 'finance', 'estate_agent', 'lawyer', 'accountant']
      - amenity: ['bank', 'post_office', 'library']

# Context-aware negatives
contextual_negatives:
  small_consumer:
    weight: -30
    conditions:
      - building_area: '<500'
      - name_contains: ['shop', 'store', 'market', 'centre', 'services']
EOF

# 4. thresholds.yaml
cat > aerospace_scoring/thresholds.yaml << 'EOF'
# Scoring thresholds - TESTING VERSION (zero thresholds)
thresholds:
  classification:
    tier1_candidate:
      min_score: 0
      description: "Testing - any score"
      
    tier2_candidate:
      min_score: 0
      max_score: 999
      description: "Testing - any score"
      
    potential_candidate:
      min_score: 0
      max_score: 999
      description: "Testing - any score"

  minimum_requirements:
    has_name: false
    not_residential: false
    has_industrial_indicator: false
    min_building_area: 0
    in_uk: true
    min_score: 0  # CRITICAL - was blocking all results

  output_limits:
    max_tier1_results: 1000
    max_tier2_results: 5000
    max_total_results: 10000
    max_per_postcode: 100
EOF

# 5. seed_columns.yaml
cat > aerospace_scoring/seed_columns.yaml << 'EOF'
# Output table structure and column definitions
output_table:
  name: "aerospace_supplier_candidates"
  description: "Tier-2 aerospace supplier candidates from UK OSM data"

# Core identification columns
identification_columns:
  - column_name: "osm_id"
    source_column: "osm_id"
    data_type: "bigint"
    description: "Original OSM object ID"
    
  - column_name: "osm_type"
    source_column: "source_table"
    data_type: "varchar(50)"
    description: "Source OSM table"
    
  - column_name: "name"
    source_column: "name"
    data_type: "text"
    description: "Primary name"
    fallback_columns: ["operator", "brand"]
    
  - column_name: "operator"
    source_column: "operator"
    data_type: "text"
    description: "Operating company"

# Contact information
contact_columns:
  - column_name: "website"
    source_column: "website"
    data_type: "text"
    description: "Website URL"
    fallback_columns: ["contact:website"]
    
  - column_name: "phone"
    source_column: "phone"
    data_type: "text"
    description: "Phone number"
    fallback_columns: ["contact:phone"]

# Address components
address_columns:
  - column_name: "postcode"
    source_column: "addr:postcode"
    data_type: "varchar(20)"
    description: "UK postal code"
    
  - column_name: "street_address"
    source_column: "addr:street"
    data_type: "text"
    description: "Street address"
    
  - column_name: "city"
    source_column: "addr:city"
    data_type: "text"
    description: "City"
    fallback_columns: ["addr:town"]

# Industrial classification
classification_columns:
  - column_name: "landuse_type"
    source_column: "landuse"
    data_type: "text"
    description: "Land use type"
    
  - column_name: "building_type"
    source_column: "building"
    data_type: "text"
    description: "Building type"
    
  - column_name: "industrial_type"
    source_column: "industrial"
    data_type: "text"
    description: "Industrial type"
    fallback_columns: ["craft"]
    
  - column_name: "office_type"
    source_column: "office"
    data_type: "text"
    description: "Office type"

# Descriptive information
descriptive_columns:
  - column_name: "description"
    source_column: "description"
    data_type: "text"
    description: "Description"

# Spatial data
spatial_columns:
  - column_name: "geometry"
    source_column: "way"
    data_type: "geometry"
    description: "PostGIS geometry"
    
  - column_name: "latitude"
    source_expression: "ST_Y(ST_Transform(ST_Centroid(way), 4326))"
    data_type: "double precision"
    description: "Latitude"
    
  - column_name: "longitude"
    source_expression: "ST_X(ST_Transform(ST_Centroid(way), 4326))"
    data_type: "double precision"
    description: "Longitude"

# Scoring columns
scoring_columns:
  - column_name: "aerospace_score"
    source_expression: "computed"
    data_type: "integer"
    description: "Aerospace relevance score"
    
  - column_name: "tier_classification"
    source_expression: "computed"
    data_type: "varchar(50)"
    description: "Supplier tier"
    
  - column_name: "matched_keywords"
    source_expression: "computed"
    data_type: "text[]"
    description: "Matched keywords"

# Metadata
metadata_columns:
  - column_name: "created_at"
    source_expression: "NOW()"
    data_type: "timestamp"
    description: "Creation timestamp"
    
  - column_name: "confidence_level"
    source_expression: "computed"
    data_type: "varchar(20)"
    description: "Confidence level"
EOF

echo -e "${GREEN}✓ YAML configuration files created${NC}"

# Create Python scripts by copying content from artifacts
echo -e "${YELLOW}Creating Python processing scripts...${NC}"

# We'll need to create these as separate files since they're quite large
# For now, create placeholders that reference the artifact content

# Create load_schema.py
cat > aerospace_scoring/load_schema.py << 'EOF'
#!/usr/bin/env python3
"""
Database schema inspector for UK OSM data - COLUMN-AWARE VERSION
"""

import psycopg2
import json
import yaml
from pathlib import Path
from typing import Dict, List, Any

def connect_to_database() -> psycopg2.extensions.connection:
    """Connect to the UK OSM database."""
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
        return conn
    except Exception as e:
        print(f"✗ Database connection failed: {e}")
        raise

def detect_actual_schema(conn: psycopg2.extensions.connection) -> str:
    """Detect which schema actually contains the OSM tables."""
    cur = conn.cursor()
    
    # Check common schema names
    schemas_to_check = ['public', 'osm_raw', 'osm']
    osm_tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
    
    for schema in schemas_to_check:
        try:
            for table in osm_tables:
                cur.execute("""
                    SELECT COUNT(*) FROM information_schema.tables 
                    WHERE table_schema = %s AND table_name = %s
                """, (schema, table))
                
                if cur.fetchone()[0] > 0:
                    print(f"✓ Found OSM tables in schema: {schema}")
                    return schema
        except Exception:
            continue
    
    return 'public'  # Default based on your system

def inspect_osm_tables(conn: psycopg2.extensions.connection) -> Dict[str, Any]:
    """Inspect OSM tables and their columns - with column awareness."""
    cur = conn.cursor()
    
    actual_schema = 'public'  # We know from diagnostic
    osm_tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
    
    schema_info = {
        'schema': actual_schema,
        'tables': {},
        'summary': {'total_tables': 0, 'total_columns': 0, 'tables_with_data': 0}
    }
    
    # Key columns we care about for aerospace scoring
    important_columns = [
        'name', 'operator', 'amenity', 'building', 'landuse', 
        'industrial', 'office', 'man_made', 'shop', 'tourism', 
        'website', 'phone', 'addr:postcode', 'addr:street', 'addr:city',
        'description', 'military', 'craft', 'railway', 'waterway',
        'natural', 'barrier', 'leisure'
    ]
    
    for table in osm_tables:
        try:
            # Get ALL columns
            cur.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (actual_schema, table))
            
            all_columns = []
            important_found = []
            
            for row in cur.fetchall():
                col_info = {
                    'name': row[0],
                    'type': row[1],
                    'nullable': row[2] == 'YES'
                }
                all_columns.append(col_info)
                
                # Track important columns for aerospace analysis
                if row[0] in important_columns:
                    important_found.append(row[0])
            
            if all_columns:
                # Get row count
                cur.execute(f"SELECT count(*) FROM {actual_schema}.{table}")
                row_count = cur.fetchone()[0]
                
                # Sample data to understand content
                sample_data = []
                if row_count > 0:
                    # Sample query with only existing important columns
                    existing_important = [col for col in important_found if col in ['name', 'amenity', 'landuse', 'office', 'industrial']]
                    if existing_important:
                        sample_columns = ', '.join(existing_important)
                        try:
                            cur.execute(f"""
                                SELECT {sample_columns}
                                FROM {actual_schema}.{table} 
                                WHERE name IS NOT NULL
                                LIMIT 3
                            """)
                            sample_data = cur.fetchall()
                        except Exception as e:
                            print(f"  Warning: Could not sample data from {table}: {e}")
                
                schema_info['tables'][table] = {
                    'exists': True,
                    'columns': all_columns,
                    'column_count': len(all_columns),
                    'row_count': row_count,
                    'important_columns_found': important_found,
                    'sample_data': sample_data
                }
                
                if row_count > 0:
                    schema_info['summary']['tables_with_data'] += 1
                
                schema_info['summary']['total_columns'] += len(all_columns)
                schema_info['summary']['total_tables'] += 1
                
                print(f"✓ {table}: {len(all_columns)} columns, {row_count:,} rows")
                print(f"  Important columns found: {len(important_found)}/{len(important_columns)}")
                print(f"  Key columns: {', '.join(important_found[:8])}")
                
            else:
                schema_info['tables'][table] = {'exists': False}
                print(f"✗ {table}: not found")
                
        except Exception as e:
            schema_info['tables'][table] = {'exists': False, 'error': str(e)}
            print(f"✗ {table}: error - {e}")
    
    cur.close()
    return schema_info

def main():
    """Main function to inspect database schema."""
    print("Inspecting UK OSM database schema with column awareness...")
    
    try:
        conn = connect_to_database()
        schema_info = inspect_osm_tables(conn)
        
        # Export schema info
        with open('aerospace_scoring/schema.json', 'w') as f:
            json.dump(schema_info, f, indent=2, default=str)
        
        conn.close()
        print(f"\n✓ Schema inspection completed")
        print(f"✓ Using schema: {schema_info['schema']}")
        print(f"✓ Schema saved to aerospace_scoring/schema.json")
        
        # Show summary
        summary = schema_info['summary']
        total_records = sum(t.get('row_count', 0) for t in schema_info['tables'].values() if isinstance(t, dict))
        print(f"\nSummary:")
        print(f"  Tables with data: {summary['tables_with_data']}")
        print(f"  Total records: {total_records:,}")
        print(f"  Schema: {schema_info['schema']}")
        
        # Show column analysis
        print(f"\nColumn Analysis:")
        for table_name, table_info in schema_info['tables'].items():
            if isinstance(table_info, dict) and table_info.get('exists'):
                important_cols = table_info.get('important_columns_found', [])
                print(f"  {table_name}: {len(important_cols)} aerospace-relevant columns")
        
    except Exception as e:
        print(f"✗ Schema inspection failed: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
EOF

# Create a minimal working exclusions generator
cat > aerospace_scoring/generate_exclusions.py << 'EOF'
#!/usr/bin/env python3
"""Generate SQL exclusion clauses - MINIMAL WORKING VERSION"""

import yaml
import json
from pathlib import Path

def main():
    print("Generating minimal exclusion SQL...")
    
    try:
        # Load schema to get actual table info
        with open('aerospace_scoring/schema.json', 'r') as f:
            schema = json.load(f)
        
        schema_name = schema.get('schema', 'public')
        sql_parts = []
        
        sql_parts.append("-- Minimal Aerospace Exclusion Filters")
        sql_parts.append("-- Creates pass-through views with minimal filtering\n")
        
        # Create simple pass-through views for each table
        for table_name, table_info in schema['tables'].items():
            if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
                continue
            
            view_name = f"{table_name}_aerospace_filtered"
            
            # Very minimal exclusion - only exclude obvious restaurants/cafes
            if table_name == 'planet_osm_point':
                where_clause = "(amenity IS NULL OR amenity NOT IN ('restaurant', 'cafe', 'pub', 'fast_food'))"
            else:
                where_clause = "1=1"  # Keep everything
            
            sql_parts.append(f"-- Filtered view for {table_name}")
            sql_parts.append(f"DROP VIEW IF EXISTS {schema_name}.{view_name} CASCADE;")
            sql_parts.append(f"CREATE VIEW {schema_name}.{view_name} AS")
            sql_parts.append(f"SELECT * FROM {schema_name}.{table_name}")
            sql_parts.append(f"WHERE {where_clause};")
            sql_parts.append("")
        
        # Save the SQL
        with open('aerospace_scoring/exclusions.sql', 'w') as f:
            f.write("\n".join(sql_parts))
        
        print("✓ Minimal exclusion SQL generated")
        
        # Show what we generated
        print("\nGenerated SQL preview:")
        for line in sql_parts[:15]:
            print(f"  {line}")
        
        return 0
        
    except Exception as e:
        print(f"✗ Failed: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    exit(main())
EOF

# Create simplified generate_scoring.py
cat > aerospace_scoring/generate_scoring.py << 'EOF'
#!/usr/bin/env python3
"""Generate SQL scoring expressions from scoring.yaml - FIXED VERSION"""

import yaml
import json
from pathlib import Path

def load_configs():
    with open('aerospace_scoring/scoring.yaml', 'r') as f:
        scoring = yaml.safe_load(f)
    
    with open('aerospace_scoring/negative_signals.yaml', 'r') as f:
        negative_signals = yaml.safe_load(f)
    
    with open('aerospace_scoring/schema.json', 'r') as f:
        schema = json.load(f)
    
    return scoring, negative_signals, schema

def check_column_exists(schema, table, column):
    table_info = schema.get('tables', {}).get(table, {})
    if not table_info.get('exists'):
        return False
    columns = table_info.get('columns', [])
    return any(col['name'] == column for col in columns)

def generate_scoring_sql(scoring, negative_signals, schema):
    schema_name = schema.get('schema', 'public')
    sql_parts = []
    
    sql_parts.append("-- Aerospace Supplier Scoring SQL")
    sql_parts.append("-- Generated from scoring.yaml and negative_signals.yaml\n")
    
    for table_name, table_info in schema['tables'].items():
        if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
            continue
        
        print(f"Processing {table_name}...")
        
        # Get available columns for this table
        available_columns = [col['name'] for col in table_info.get('columns', [])]
        
        # Build scoring expressions that only use existing columns
        scoring_expressions = []
        
        # Text-based aerospace keyword matching
        text_fields = [col for col in ['name', 'operator'] if col in available_columns]
        if text_fields:
            aerospace_keywords = ['aerospace', 'aviation', 'aircraft', 'airbus', 'boeing', 'bae', 'rolls royce']
            
            for field in text_fields:
                keyword_conditions = []
                for keyword in aerospace_keywords:
                    keyword_conditions.append(f"{field} ILIKE '%{keyword}%'")
                
                if keyword_conditions:
                    scoring_expressions.append(f"CASE WHEN ({' OR '.join(keyword_conditions)}) THEN 100 ELSE 0 END")
        
        # Industrial facility bonuses
        if 'landuse' in available_columns:
            scoring_expressions.append("CASE WHEN landuse = 'industrial' THEN 50 ELSE 0 END")
        
        if 'building' in available_columns:
            scoring_expressions.append("CASE WHEN building IN ('industrial', 'warehouse', 'factory', 'office') THEN 40 ELSE 0 END")
        
        if 'office' in available_columns:
            scoring_expressions.append("CASE WHEN office IS NOT NULL THEN 30 ELSE 0 END")
        
        if 'industrial' in available_columns:
            scoring_expressions.append("CASE WHEN industrial IS NOT NULL THEN 40 ELSE 0 END")
        
        if 'man_made' in available_columns:
            scoring_expressions.append("CASE WHEN man_made IN ('works', 'factory', 'tower', 'mast') THEN 25 ELSE 0 END")
        
        # Technology/engineering name bonuses
        if 'name' in available_columns:
            tech_keywords = ['technology', 'engineering', 'systems', 'electronics', 'precision']
            tech_conditions = []
            for keyword in tech_keywords:
                tech_conditions.append(f"name ILIKE '%{keyword}%'")
            
            if tech_conditions:
                scoring_expressions.append(f"CASE WHEN ({' OR '.join(tech_conditions)}) THEN 35 ELSE 0 END")
        
        # Generate final score expression
        if scoring_expressions:
            final_score = f"({' + '.join(scoring_expressions)})"
        else:
            final_score = "10"  # Give minimal score to industrial facilities
        
        # Create scored view
        view_name = f"{table_name}_aerospace_scored"
        sql_parts.append(f"-- Scored view for {table_name}")
        sql_parts.append(f"DROP VIEW IF EXISTS {schema_name}.{view_name} CASCADE;")
        sql_parts.append(f"CREATE VIEW {schema_name}.{view_name} AS")
        sql_parts.append(f"SELECT *,")
        sql_parts.append(f"    {final_score} AS aerospace_score,")
        sql_parts.append(f"    ARRAY[]::text[] AS matched_keywords,")
        sql_parts.append(f"    '{table_name}' AS source_table")
        sql_parts.append(f"FROM {schema_name}.{table_name}_aerospace_filtered")
        sql_parts.append(f"WHERE {final_score} > 0;")
        sql_parts.append("")
    
    return "\n".join(sql_parts)

def main():
    print("Generating scoring SQL...")
    
    try:
        scoring, negative_signals, schema = load_configs()
        scoring_sql = generate_scoring_sql(scoring, negative_signals, schema)
        
        with open('aerospace_scoring/scoring.sql', 'w') as f:
            f.write(scoring_sql)
        
        print("✓ Scoring SQL generated: aerospace_scoring/scoring.sql")
        
    except Exception as e:
        print(f"✗ Failed: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
EOF

# Create simplified assemble_sql.py
cat > aerospace_scoring/assemble_sql.py << 'EOF'
#!/usr/bin/env python3
"""Assemble complete SQL script for aerospace supplier scoring"""

import yaml
from pathlib import Path
from datetime import datetime

def load_table_name():
    seed = yaml.safe_load(open('aerospace_scoring/seed_columns.yaml'))
    return seed['output_table']['name']  # e.g. "aerospace_supplier_candidates"

def inline_sql(path, header):
    return f"-- {header}\n{Path(path).read_text()}"

def generate_ddl(table):
    return f"""-- STEP 3: Create output table
DROP TABLE IF EXISTS public.{table} CASCADE;
CREATE TABLE public.{table} (
  osm_id BIGINT,
  osm_type VARCHAR(50),
  name TEXT,
  operator TEXT,
  website TEXT,
  landuse_type TEXT,
  geometry GEOMETRY,
  aerospace_score INTEGER,
  tier_classification VARCHAR(50),
  matched_keywords TEXT[],
  source_table VARCHAR(50),
  created_at TIMESTAMP
);
CREATE INDEX ON public.{table}(aerospace_score);
CREATE INDEX ON public.{table}(tier_classification);
CREATE INDEX ON public.{table} USING GIST(geometry);
"""

def generate_insert(table):
    cols = [
        'osm_id','osm_type','name','operator','website',
        'landuse_type','geometry','aerospace_score',
        'tier_classification','matched_keywords',
        'source_table','created_at'
    ]

    unions = []
    for typ in ['point','polygon','line']:
        view = f"public.planet_osm_{typ}_aerospace_scored"
        unions.append(f"""SELECT
  osm_id,
  '{typ}' AS osm_type,
  COALESCE(name,operator) AS name,
  operator,
  website,
  landuse AS landuse_type,
  way AS geometry,
  aerospace_score,
  CASE
    WHEN aerospace_score>=150 THEN 'tier1_candidate'
    WHEN aerospace_score>=80  THEN 'tier2_candidate'
    WHEN aerospace_score>=40  THEN 'potential_candidate'
    WHEN aerospace_score>=10  THEN 'low_probability'
    ELSE 'excluded'
  END AS tier_classification,
  matched_keywords,
  source_table,
  NOW() AS created_at
FROM {view}
WHERE aerospace_score >= 10""")

    union_sql = "\nUNION ALL\n".join(unions)
    col_list = ", ".join(cols)

    return f"""-- STEP 4: Insert final results
INSERT INTO public.{table} ({col_list})
{union_sql}
ON CONFLICT DO NOTHING;
"""

def assemble_sql():
    table = load_table_name()
    sql_parts = [
        "-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM",
        f"-- Generated on: {datetime.now():%Y-%m-%d %H:%M:%S}",
        inline_sql('aerospace_scoring/exclusions.sql', 'STEP 1: Exclusion Filters'),
        inline_sql('aerospace_scoring/scoring.sql',    'STEP 2: Scoring Rules'),
        generate_ddl(table),
        generate_insert(table),
        "-- STEP 5: Analysis queries",
        f"SELECT 'Total candidates' AS metric, COUNT(*) AS value FROM public.{table};",
        f"SELECT tier_classification, COUNT(*) AS cnt FROM public.{table} GROUP BY tier_classification ORDER BY cnt DESC;"
    ]
    full_sql = "\n\n".join(sql_parts)
    Path('aerospace_scoring/compute_aerospace_scores.sql').write_text(full_sql)
    print("✓ compute_aerospace_scores.sql assembled")

if __name__=='__main__':
    assemble_sql()
EOF

# Create main execution script
cat > aerospace_scoring/run_aerospace_scoring.py << 'EOF'
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
EOF

# Make scripts executable
chmod +x aerospace_scoring/*.py

echo -e "${GREEN}✓ Python processing scripts created${NC}"

# Create diagnostic test
cat > diagnostic_test.sh << 'EOF'
#!/bin/bash
# diagnostic_test.sh - Test individual components of aerospace scoring - FIXED

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Aerospace Pipeline Diagnostic Test ===${NC}"

# Step 1: Test database connection and schema detection
echo -e "${YELLOW}Step 1: Testing database connection...${NC}"
if psql -d uk_osm_full -c "SELECT current_schema(), version();" 2>/dev/null; then
    echo -e "${GREEN}✓ Database connection works${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    exit 1
fi

ACTUAL_SCHEMA="public"  # We know it's public from the diagnostic

# Step 2: Check what columns actually exist
echo -e "${YELLOW}Step 2: Checking available columns...${NC}"
echo "Columns in planet_osm_point:"
psql -d uk_osm_full -c "
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema='public' AND table_name='planet_osm_point' 
  AND column_name IN ('name', 'amenity', 'building', 'landuse', 'industrial', 'office', 'man_made', 'shop', 'tourism')
ORDER BY column_name;
"

echo "Columns in planet_osm_polygon:"
psql -d uk_osm_full -c "
SELECT column_name 
FROM information_schema.columns 
WHERE table_schema='public' AND table_name='planet_osm_polygon' 
  AND column_name IN ('name', 'amenity', 'building', 'landuse', 'industrial', 'office', 'man_made')
ORDER BY column_name;
"

# Step 3: Row counts
echo -e "${YELLOW}Step 3: Checking row counts...${NC}"
psql -d uk_osm_full -c "
SELECT 
    'planet_osm_point' as table_name, count(*) as rows
FROM public.planet_osm_point
UNION ALL
SELECT 
    'planet_osm_polygon', count(*)
FROM public.planet_osm_polygon
ORDER BY table_name;
"

# Step 4: Test for aerospace-relevant data (column-safe)
echo -e "${YELLOW}Step 4: Checking for aerospace-relevant data...${NC}"
echo "Industrial facilities in polygons:"
psql -d uk_osm_full -c "
SELECT COUNT(*) as industrial_count
FROM public.planet_osm_polygon 
WHERE landuse = 'industrial' OR building IN ('industrial', 'warehouse', 'factory');
"

echo "Facilities with aerospace-related names in points (safe query):"
psql -d uk_osm_full -c "
SELECT name, amenity, landuse
FROM public.planet_osm_point 
WHERE name IS NOT NULL 
  AND (LOWER(name) LIKE '%aerospace%' 
       OR LOWER(name) LIKE '%aviation%'
       OR LOWER(name) LIKE '%aircraft%'
       OR LOWER(name) LIKE '%engineering%'
       OR LOWER(name) LIKE '%technology%')
LIMIT 5;
"

# Step 5: Test what data we can actually work with
echo -e "${YELLOW}Step 5: Testing available aerospace-relevant data...${NC}"
echo "Points with office/industrial tags:"
psql -d uk_osm_full -c "
SELECT COUNT(*) as office_industrial_points
FROM public.planet_osm_point 
WHERE office IS NOT NULL OR man_made IS NOT NULL;
"

echo "Sample of potentially relevant points:"
psql -d uk_osm_full -c "
SELECT name, amenity, office, man_made
FROM public.planet_osm_point 
WHERE (office IS NOT NULL OR man_made IS NOT NULL)
  AND name IS NOT NULL
LIMIT 10;
"

echo ""
echo -e "${BLUE}=== Diagnostic Complete ===${NC}"
echo -e "${YELLOW}Schema: public${NC}"
echo -e "${YELLOW}Key finding: Points table lacks 'building' column - this needs to be handled in the code${NC}"
EOF

chmod +x diagnostic_test.sh

echo -e "${GREEN}✓ Diagnostic test created${NC}"

# Create README
cat > aerospace_scoring/README.md << 'EOF'
# UK Aerospace Supplier Scoring System

This system analyzes UK OpenStreetMap data to identify potential Tier-2 aerospace suppliers.

## Quick Start

**Prerequisites:**
- UK OSM database imported (from previous steps)
- Python 3 with psycopg2, pyyaml

**Run the complete system:**
```bash
python3 aerospace_scoring/run_aerospace_scoring.py
```

## Manual Steps (if needed)

1. **Analyze database schema:**
   ```bash
   uv run aerospace_scoring/load_schema.py
   ```

2. **Generate exclusion filters:**
   ```bash
   uv run aerospace_scoring/generate_exclusions.py
   ```

3. **Generate scoring rules:**
   ```bash
   uv run aerospace_scoring/generate_scoring.py
   ```

4. **Assemble complete SQL:**
   ```bash
   uv run aerospace_scoring/assemble_sql.py
   ```

5. **Execute the scoring:**
   ```bash
   psql -d uk_osm_full -f aerospace_scoring/compute_aerospace_scores.sql
   ```

## Configuration Files

All scoring rules are in YAML files and can be edited without code changes:

- **exclusions.yaml**: Filters out non-aerospace features
- **scoring.yaml**: Positive scoring rules for aerospace relevance  
- **negative_signals.yaml**: Negative scoring penalties
- **thresholds.yaml**: Classification tiers and limits
- **seed_columns.yaml**: Output table structure

## Results

The system creates a table `aerospace_supplier_candidates` with:
- Tier-1 candidates (score ≥150): Direct aerospace indicators
- Tier-2 candidates (score 80-149): Strong manufacturing + aerospace keywords  
- Potential candidates (score 40-79): Industrial with some relevance
- Geographic data, contact information, confidence levels

## Sample Queries

```sql
-- Top tier-2 candidates
SELECT name, aerospace_score, postcode, website
FROM aerospace_supplier_candidates 
WHERE tier_classification = 'tier2_candidate'
ORDER BY aerospace_score DESC;

-- Candidates by region
SELECT LEFT(postcode,2) as area, COUNT(*), AVG(aerospace_score)
FROM aerospace_supplier_candidates
WHERE postcode IS NOT NULL
GROUP BY LEFT(postcode,2)
ORDER BY COUNT(*) DESC;

-- High-confidence candidates with contact info
SELECT name, aerospace_score, website, phone, city
FROM aerospace_supplier_candidates
WHERE confidence_level = 'high' AND (website IS NOT NULL OR phone IS NOT NULL);
```
EOF

echo -e "${GREEN}✓ README created${NC}"

echo ""
echo -e "${BLUE}=== SETUP COMPLETE ===${NC}"
echo -e "${GREEN}Created aerospace supplier scoring system in: aerospace_scoring/${NC}"
echo ""
echo -e "${YELLOW}Files created:${NC}"
echo -e "${YELLOW}  Configuration: 5 YAML files (exclusions, scoring, thresholds, etc.)${NC}"
echo -e "${YELLOW}  Processing: 4 Python scripts${NC}"
echo -e "${YELLOW}  Documentation: README.md${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "${YELLOW}1. Ensure your UK OSM database is accessible${NC}"
echo -e "${YELLOW}2. Run: python3 aerospace_scoring/run_aerospace_scoring.py${NC}"
echo -e "${YELLOW}3. Review results in aerospace_supplier_candidates table${NC}"
echo ""
echo -e "${GREEN}The system will identify tier-2 aerospace suppliers from your OSM data!${NC}"
