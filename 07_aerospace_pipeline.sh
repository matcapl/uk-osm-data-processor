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

# Create directory structure
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p aerospace_scoring

# Create all YAML configuration files
echo -e "${YELLOW}Creating YAML configuration files...${NC}"

# 1. exclusions.yaml
cat > aerospace_scoring/exclusions.yaml << 'EOF'
# Exclusion rules to filter out non-industrial/non-aerospace relevant features
exclusions:
  residential:
    - key: landuse
      values: ['residential', 'retail', 'commercial']
    - key: building
      values: ['house', 'apartments', 'residential', 'hotel', 'retail', 'supermarket']
    - key: amenity
      values: ['restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'school', 'hospital', 'bank', 'pharmacy']
    - key: shop
      values: ['*']
    - key: tourism
      values: ['*']
    - key: leisure
      values: ['park', 'playground', 'sports_centre', 'swimming_pool', 'golf_course']

  infrastructure:
    - key: railway
      values: ['station', 'halt', 'platform']
    - key: waterway
      values: ['*']
    - key: natural
      values: ['*']
    - key: barrier
      values: ['*']

  primary_sectors:
    - key: landuse
      values: ['farmland', 'forest', 'meadow', 'orchard', 'vineyard', 'quarry', 'landfill']
    - key: man_made
      values: ['water_tower', 'water_works', 'sewage_plant']

# Positive inclusion overrides
overrides:
  aerospace_keywords:
    - key: name
      values: ['aerospace', 'aviation', 'aircraft', 'airbus', 'boeing', 'rolls royce', 'bae systems']
    - key: operator
      values: ['aerospace', 'aviation', 'aircraft']
    - key: description
      values: ['aerospace', 'aviation', 'aircraft', 'defense', 'defence']

  industrial_overrides:
    - key: landuse
      values: ['industrial']
    - key: building
      values: ['industrial', 'warehouse', 'factory', 'manufacture']
    - key: man_made
      values: ['works', 'factory']
    - key: industrial
      values: ['*']
    - key: office
      values: ['company', 'research', 'engineering']

# Table-specific exclusion rules
table_exclusions:
  planet_osm_point:
    - key: amenity
      values: ['restaurant', 'pub', 'cafe', 'bar', 'fast_food', 'fuel', 'parking']
    - key: shop
      values: ['*']
    - key: tourism
      values: ['*']
  
  planet_osm_polygon:
    - key: building
      values: ['house', 'apartments', 'residential']
    - key: landuse
      values: ['residential', 'farmland', 'forest']
  
  planet_osm_line:
    - key: highway
      values: ['footway', 'cycleway', 'path', 'steps']
    - key: railway
      values: ['abandoned', 'disused']
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
# Scoring thresholds and classification rules
thresholds:
  # Score ranges for classification
  classification:
    tier1_candidate:
      min_score: 150
      description: "Highly likely aerospace supplier"
      
    tier2_candidate:
      min_score: 80
      max_score: 149
      description: "Strong aerospace supplier candidate"
      
    potential_candidate:
      min_score: 40
      max_score: 79
      description: "Possible supplier"
      
    low_probability:
      min_score: 10
      max_score: 39
      description: "Low probability"
      
    excluded:
      max_score: 9
      description: "Not aerospace relevant"

  # Minimum requirements
  minimum_requirements:
    has_name: true
    not_residential: true
    has_industrial_indicator: true
    min_building_area: 50
    in_uk: true
    min_score: 10

  # Quality filters
  quality_filters:
    contact_bonus: 10
    description_bonus: 5
    specific_type_bonus: 15
    generic_name_penalty: -10

  # Output limits
  output_limits:
    max_tier1_results: 500
    max_tier2_results: 2000
    max_total_results: 5000
    max_per_postcode: 50
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
Database schema inspector for UK OSM data
Run this first to analyze your database structure
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

def inspect_osm_tables(conn: psycopg2.extensions.connection) -> Dict[str, Any]:
    """Inspect OSM tables and their columns."""
    cur = conn.cursor()
    
    # OSM tables to inspect
    osm_tables = ['planet_osm_point', 'planet_osm_line', 'planet_osm_polygon', 'planet_osm_roads']
    
    schema_info = {
        'schema': 'osm_raw',
        'tables': {},
        'summary': {'total_tables': 0, 'total_columns': 0, 'tables_with_data': 0}
    }
    
    try:
        with open('config/config.yaml', 'r') as f:
            config = yaml.safe_load(f)
        schema_info['schema'] = config['database'].get('schema', 'osm_raw')
    except:
        pass
    
    for table in osm_tables:
        try:
            # Get column information
            cur.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
            """, (schema_info['schema'], table))
            
            columns = []
            for row in cur.fetchall():
                columns.append({
                    'name': row[0],
                    'type': row[1],
                    'nullable': row[2] == 'YES'
                })
            
            if columns:
                # Get row count
                cur.execute(f"SELECT count(*) FROM {schema_info['schema']}.{table}")
                row_count = cur.fetchone()[0]
                
                schema_info['tables'][table] = {
                    'exists': True,
                    'columns': columns,
                    'column_count': len(columns),
                    'row_count': row_count
                }
                
                if row_count > 0:
                    schema_info['summary']['tables_with_data'] += 1
                
                schema_info['summary']['total_columns'] += len(columns)
                schema_info['summary']['total_tables'] += 1
                
                print(f"✓ {table}: {len(columns)} columns, {row_count:,} rows")
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
    print("Inspecting UK OSM database schema...")
    
    try:
        conn = connect_to_database()
        schema_info = inspect_osm_tables(conn)
        
        # Export schema info
        with open('aerospace_scoring/schema.json', 'w') as f:
            json.dump(schema_info, f, indent=2, default=str)
        
        conn.close()
        print("\n✓ Schema inspection completed")
        print("✓ Schema saved to aerospace_scoring/schema.json")
        
    except Exception as e:
        print(f"✗ Schema inspection failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
EOF

# Create simplified generate_exclusions.py
cat > aerospace_scoring/generate_exclusions.py << 'EOF'
#!/usr/bin/env python3
"""Generate SQL exclusion clauses from exclusions.yaml"""

import yaml
import json
from pathlib import Path

def load_configs():
    with open('aerospace_scoring/exclusions.yaml', 'r') as f:
        exclusions = yaml.safe_load(f)
    
    with open('aerospace_scoring/schema.json', 'r') as f:
        schema = json.load(f)
    
    return exclusions, schema

def check_column_exists(schema, table, column):
    table_info = schema.get('tables', {}).get(table, {})
    if not table_info.get('exists'):
        return False
    columns = table_info.get('columns', [])
    return any(col['name'] == column for col in columns)

def generate_exclusion_sql(exclusions, schema):
    schema_name = schema.get('schema', 'osm_raw')
    sql_parts = []
    
    sql_parts.append("-- Aerospace Supplier Exclusion Filters")
    sql_parts.append("-- Generated from exclusions.yaml\n")
    
    for table_name, table_info in schema['tables'].items():
        if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
            continue
        
        conditions = []
        
        # Apply general exclusions
        for category, rules in exclusions['exclusions'].items():
            for rule in rules:
                for column, values in rule.items():
                    if check_column_exists(schema, table_name, column):
                        if '*' in values:
                            conditions.append(f"{column} IS NULL")
                        else:
                            quoted_values = "', '".join(values)
                            conditions.append(f"{column} NOT IN ('{quoted_values}')")
        
        # Create filtered view
        if conditions:
            view_name = f"{table_name}_aerospace_filtered"
            where_clause = ' AND '.join(conditions)
            
            sql_parts.append(f"-- Filtered view for {table_name}")
            sql_parts.append(f"CREATE OR REPLACE VIEW {schema_name}.{view_name} AS")
            sql_parts.append(f"SELECT * FROM {schema_name}.{table_name}")
            sql_parts.append(f"WHERE {where_clause};\n")
    
    return "\n".join(sql_parts)

def main():
    print("Generating exclusion SQL...")
    
    try:
        exclusions, schema = load_configs()
        exclusion_sql = generate_exclusion_sql(exclusions, schema)
        
        with open('aerospace_scoring/exclusions.sql', 'w') as f:
            f.write(exclusion_sql)
        
        print("✓ Exclusion SQL generated: aerospace_scoring/exclusions.sql")
        
    except Exception as e:
        print(f"✗ Failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
EOF

# Create simplified generate_scoring.py
cat > aerospace_scoring/generate_scoring.py << 'EOF'
#!/usr/bin/env python3
"""Generate SQL scoring expressions from scoring.yaml"""

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

def generate_text_search(column, keywords):
    conditions = []
    for keyword in keywords:
        conditions.append(f"LOWER({column}) LIKE LOWER('%{keyword}%')")
    return f"({' OR '.join(conditions)})"

def generate_scoring_sql(scoring, negative_signals, schema):
    schema_name = schema.get('schema', 'osm_raw')
    sql_parts = []
    
    sql_parts.append("-- Aerospace Supplier Scoring SQL")
    sql_parts.append("-- Generated from scoring.yaml and negative_signals.yaml\n")
    
    for table_name, table_info in schema['tables'].items():
        if not table_info.get('exists') or table_info.get('row_count', 0) == 0:
            continue
        
        # Build scoring CASE statement
        case_parts = []
        
        # Positive scoring rules
        for rule_name, rule_config in scoring['scoring_rules'].items():
            weight = rule_config.get('weight', 0)
            conditions = rule_config.get('conditions', [])
            
            rule_conditions = []
            for condition in conditions:
                for field, values in condition.items():
                    if field.endswith('_contains'):
                        base_field = field.replace('_contains', '')
                        if check_column_exists(schema, table_name, base_field):
                            text_condition = generate_text_search(base_field, values)
                            rule_conditions.append(text_condition)
                    elif check_column_exists(schema, table_name, field):
                        if '*' in values:
                            rule_conditions.append(f"{field} IS NOT NULL")
                        else:
                            quoted_values = "', '".join(values)
                            rule_conditions.append(f"{field} IN ('{quoted_values}')")
            
            if rule_conditions:
                combined = ' OR '.join(rule_conditions)
                case_parts.append(f"WHEN ({combined}) THEN {weight}")
        
        # Build keyword bonuses
        bonus_expressions = []
        for bonus_name, bonus_config in scoring['keyword_bonuses'].items():
            weight = bonus_config.get('weight', 0)
            keywords = bonus_config.get('keywords', [])
            
            text_fields = []
            for field in ['name', 'operator', 'description']:
                if check_column_exists(schema, table_name, field):
                    text_fields.append(field)
            
            if text_fields and keywords:
                field_conditions = []
                for field in text_fields:
                    keyword_condition = generate_text_search(field, keywords)
                    field_conditions.append(keyword_condition)
                
                combined_condition = ' OR '.join(field_conditions)
                bonus_expressions.append(f"CASE WHEN ({combined_condition}) THEN {weight} ELSE 0 END")
        
        # Build negative scoring
        negative_expressions = []
        for signal_name, signal_config in negative_signals['negative_signals'].items():
            weight = signal_config.get('weight', 0)
            conditions = signal_config.get('conditions', [])
            
            signal_conditions = []
            for condition in conditions:
                for field, values in condition.items():
                    if check_column_exists(schema, table_name, field):
                        if '*' in values:
                            signal_conditions.append(f"{field} IS NOT NULL")
                        else:
                            quoted_values = "', '".join(values)
                            signal_conditions.append(f"{field} IN ('{quoted_values}')")
            
            if signal_conditions:
                combined = ' OR '.join(signal_conditions)
                negative_expressions.append(f"CASE WHEN ({combined}) THEN {weight} ELSE 0 END")
        
        # Combine all scoring components
        all_parts = []
        
        if case_parts:
            base_case = "CASE\n        " + "\n        ".join(case_parts) + "\n        ELSE 0\n    END"
            all_parts.append(base_case)
        
        all_parts.extend(bonus_expressions)
        all_parts.extend(negative_expressions)
        
        if all_parts:
            joined_parts = ' +\n        '.join(all_parts)
            scoring_expr = f"(\n        {joined_parts}\n    ) AS aerospace_score"

        else:
            scoring_expr = "0 AS aerospace_score"
        
        # Create scored view
        view_name = f"{table_name}_aerospace_scored"
        sql_parts.append(f"-- Scored view for {table_name}")
        sql_parts.append(f"CREATE OR REPLACE VIEW {schema_name}.{view_name} AS")
        sql_parts.append(f"SELECT *,")
        sql_parts.append(f"    {scoring_expr},")
        sql_parts.append(f"    ARRAY[]::text[] AS matched_keywords,")
        sql_parts.append(f"    '{table_name}' AS source_table")
        sql_parts.append(f"FROM {schema_name}.{table_name}_aerospace_filtered")
        sql_parts.append(f"WHERE (")
        sql_parts.append(f"    {scoring_expr.replace(' AS aerospace_score', '')}")
        sql_parts.append(f") > 0;\n")
    
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
import json
from pathlib import Path
from datetime import datetime

def load_configs():
    configs = {}
    for name in ['thresholds', 'seed_columns']:
        with open(f'aerospace_scoring/{name}.yaml', 'r') as f:
            configs[name] = yaml.safe_load(f)
    
    with open('aerospace_scoring/schema.json', 'r') as f:
        configs['schema'] = json.load(f)
    
    return configs

def generate_output_table_ddl(seed_columns):
    table_name = seed_columns['output_table']['name']
    
    ddl = f"""-- Create aerospace supplier candidates table
DROP TABLE IF EXISTS {table_name} CASCADE;
CREATE TABLE {table_name} (
    osm_id BIGINT,
    osm_type VARCHAR(50),
    name TEXT,
    operator TEXT,
    website TEXT,
    phone TEXT,
    postcode VARCHAR(20),
    street_address TEXT,
    city TEXT,
    landuse_type TEXT,
    building_type TEXT,
    industrial_type TEXT,
    office_type TEXT,
    description TEXT,
    geometry GEOMETRY,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    aerospace_score INTEGER,
    tier_classification VARCHAR(50),
    matched_keywords TEXT[],
    confidence_level VARCHAR(20),
    created_at TIMESTAMP,
    source_table VARCHAR(50)
);

-- Create indexes
CREATE INDEX idx_aerospace_score ON {table_name}(aerospace_score);
CREATE INDEX idx_tier ON {table_name}(tier_classification);
CREATE INDEX idx_postcode ON {table_name}(postcode);
CREATE INDEX idx_geom ON {table_name} USING GIST(geometry);"""
    
    return ddl

def generate_insert_sql(schema, thresholds):
    schema_name = schema.get('schema', 'osm_raw')
    
    tier_case = """CASE
        WHEN aerospace_score >= 150 THEN 'tier1_candidate'
        WHEN aerospace_score >= 80 THEN 'tier2_candidate'
        WHEN aerospace_score >= 40 THEN 'potential_candidate'
        WHEN aerospace_score >= 10 THEN 'low_probability'
        ELSE 'excluded'
    END"""
    
    confidence_case = """CASE
        WHEN aerospace_score >= 150 AND (website IS NOT NULL OR phone IS NOT NULL) THEN 'high'
        WHEN aerospace_score >= 80 THEN 'medium'
        WHEN aerospace_score >= 40 THEN 'low'
        ELSE 'very_low'
    END"""
    
    insert_sql = f"""-- Insert aerospace supplier candidates
INSERT INTO aerospace_supplier_candidates (
    osm_id, osm_type, name, operator, website, phone, postcode, street_address, city,
    landuse_type, building_type, industrial_type, office_type, description,
    geometry, latitude, longitude, aerospace_score, tier_classification,
    matched_keywords, confidence_level, created_at, source_table
)
SELECT 
    osm_id,
    source_table AS osm_type,
    COALESCE(name, operator) AS name,
    operator,
    COALESCE(website, "contact:website") AS website,
    COALESCE(phone, "contact:phone") AS phone,
    "addr:postcode" AS postcode,
    "addr:street" AS street_address,
    COALESCE("addr:city", "addr:town") AS city,
    landuse AS landuse_type,
    building AS building_type,
    industrial AS industrial_type,
    office AS office_type,
    description,
    way AS geometry,
    ST_Y(ST_Transform(ST_Centroid(way), 4326)) AS latitude,
    ST_X(ST_Transform(ST_Centroid(way), 4326)) AS longitude,
    aerospace_score,
    {tier_case} AS tier_classification,
    matched_keywords,
    {confidence_case} AS confidence_level,
    NOW() AS created_at,
    source_table
FROM (
    SELECT * FROM {schema_name}.planet_osm_point_aerospace_scored
    UNION ALL
    SELECT * FROM {schema_name}.planet_osm_polygon_aerospace_scored
    UNION ALL
    SELECT * FROM {schema_name}.planet_osm_line_aerospace_scored
) combined
WHERE aerospace_score >= 10
ORDER BY aerospace_score DESC
LIMIT 5000;"""
    
    return insert_sql

def assemble_complete_sql(configs):
    schema = configs['schema']
    thresholds = configs['thresholds']
    seed_columns = configs['seed_columns']
    
    # Load component SQL files
    try:
        with open('aerospace_scoring/exclusions.sql', 'r') as f:
            exclusions_sql = f.read()
    except FileNotFoundError:
        exclusions_sql = "-- Run generate_exclusions.py first"
    
    try:
        with open('aerospace_scoring/scoring.sql', 'r') as f:
            scoring_sql = f.read()
    except FileNotFoundError:
        scoring_sql = "-- Run generate_scoring.py first"
    
    # Generate components
    table_ddl = generate_output_table_ddl(seed_columns)
    insert_sql = generate_insert_sql(schema, thresholds)
    
    # Assemble final script
    complete_sql = f"""-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM
-- Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- Database: {schema.get('schema', 'osm_raw')}

-- STEP 1: Apply exclusion filters
{exclusions_sql}

-- STEP 2: Apply scoring rules
{scoring_sql}

-- STEP 3: Create output table
{table_ddl}

-- STEP 4: Insert final results
{insert_sql}

-- STEP 5: Analysis queries
SELECT 'Total candidates' as metric, COUNT(*) as value FROM aerospace_supplier_candidates
UNION ALL
SELECT 'With contact info', COUNT(*) FROM aerospace_supplier_candidates WHERE website IS NOT NULL OR phone IS NOT NULL
UNION ALL
SELECT 'High confidence', COUNT(*) FROM aerospace_supplier_candidates WHERE confidence_level = 'high';

-- Classification breakdown
SELECT tier_classification, COUNT(*), AVG(aerospace_score) as avg_score
FROM aerospace_supplier_candidates
GROUP BY tier_classification
ORDER BY avg_score DESC;

-- Top candidates
SELECT name, tier_classification, aerospace_score, postcode
FROM aerospace_supplier_candidates
WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
ORDER BY aerospace_score DESC
LIMIT 20;
"""
    
    return complete_sql

def main():
    print("Assembling complete SQL script...")
    
    try:
        configs = load_configs()
        complete_sql = assemble_complete_sql(configs)
        
        with open('aerospace_scoring/compute_aerospace_scores.sql', 'w') as f:
            f.write(complete_sql)
        
        print("✓ Complete SQL script assembled: aerospace_scoring/compute_aerospace_scores.sql")
        
    except Exception as e:
        print(f"✗ Failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
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
EOF

# Make scripts executable
chmod +x aerospace_scoring/*.py

echo -e "${GREEN}✓ Python processing scripts created${NC}"

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
   python3 aerospace_scoring/load_schema.py
   ```

2. **Generate exclusion filters:**
   ```bash
   python3 aerospace_scoring/generate_exclusions.py
   ```

3. **Generate scoring rules:**
   ```bash
   python3 aerospace_scoring/generate_scoring.py
   ```

4. **Assemble complete SQL:**
   ```bash
   python3 aerospace_scoring/assemble_sql.py
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
