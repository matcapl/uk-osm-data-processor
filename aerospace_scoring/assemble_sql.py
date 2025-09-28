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
    schema_name = schema.get('schema', 'public')
    # Fallback for filter_minimum_score
    min_score = thresholds.get(
        'filter_minimum_score',
        thresholds.get('scores', {}).get('filter_minimum_score', 10)
    )
    max_cands = thresholds.get('max_candidates', 5000)

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

    insert_sql = f"""-- Insert enriched aerospace supplier candidates
INSERT INTO aerospace_supplier_candidates (
    osm_id, osm_type, name, operator, website, phone, postcode, street_address, city,
    landuse_type, building_type, industrial_type, office_type, description,
    geometry, latitude, longitude, aerospace_score, tier_classification,
    matched_keywords, confidence_level, created_at, source_table
)
SELECT
    osm_id,
    source_table::VARCHAR AS osm_type,
    COALESCE(name, operator) AS name,
    operator,
    COALESCE(website, tags->'contact:website') AS website,
    COALESCE(tags->'phone', tags->'contact:phone') AS phone,
    tags->'addr:postcode' AS postcode,
    tags->'addr:street'   AS street_address,
    COALESCE(tags->'addr:city', tags->'addr:town') AS city,
    landuse               AS landuse_type,
    building              AS building_type,
    industrial            AS industrial_type,
    office                AS office_type,
    tags->'description'   AS description,
    way                   AS geometry,
    ST_Y(ST_Transform(ST_Centroid(way), 4326)) AS latitude,
    ST_X(ST_Transform(ST_Centroid(way), 4326)) AS longitude,
    aerospace_score,
    {tier_case}          AS tier_classification,
    matched_keywords,
    {confidence_case}    AS confidence_level,
    NOW()                AS created_at,
    source_table
FROM (
    SELECT * FROM {schema_name}.planet_osm_point_aerospace_scored
    UNION ALL
    SELECT * FROM {schema_name}.planet_osm_polygon_aerospace_scored
    UNION ALL
    SELECT * FROM {schema_name}.planet_osm_line_aerospace_scored
) combined
WHERE aerospace_score >= {min_score}
ORDER BY aerospace_score DESC
LIMIT {max_cands};"""
    return insert_sql


def assemble_complete_sql(configs):
    schema = configs['schema']
    thresholds = configs['thresholds']
    seed_columns = configs['seed_columns']

    try:
        exclusions_sql = Path('aerospace_scoring/exclusions.sql').read_text()
    except FileNotFoundError:
        exclusions_sql = "-- Run generate_exclusions.py first"
    try:
        scoring_sql = Path('aerospace_scoring/scoring.sql').read_text()
    except FileNotFoundError:
        scoring_sql = "-- Run generate_scoring.py first"

    table_ddl = generate_output_table_ddl(seed_columns)
    insert_sql = generate_insert_sql(schema, thresholds)

    complete_sql = f"""-- UK AEROSPACE SUPPLIER IDENTIFICATION SYSTEM
-- Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- Schema: {schema.get('schema','public')}

-- STEP 1: Apply exclusion filters
{exclusions_sql}

-- STEP 2: Apply scoring rules
{scoring_sql}

-- STEP 3: Create output table
{table_ddl}

-- STEP 4: Insert final results
{insert_sql}

-- STEP 5: Analysis queries
SELECT 'Total candidates' AS metric, COUNT(*) AS value FROM aerospace_supplier_candidates
UNION ALL
SELECT 'With contact info', COUNT(*) FROM aerospace_supplier_candidates WHERE website IS NOT NULL OR phone IS NOT NULL
UNION ALL
SELECT 'High confidence', COUNT(*) FROM aerospace_supplier_candidates WHERE confidence_level = 'high';

-- Classification breakdown
SELECT tier_classification, COUNT(*) AS count, AVG(aerospace_score) AS avg_score
FROM aerospace_supplier_candidates
GROUP BY tier_classification
ORDER BY avg_score DESC;

-- Top candidates
SELECT name, tier_classification, aerospace_score, postcode
FROM aerospace_supplier_candidates
WHERE tier_classification IN ('tier1_candidate','tier2_candidate')
ORDER BY aerospace_score DESC
LIMIT 20;
"""
    return complete_sql


def main():
    print("Assembling complete SQL script...")
    try:
        configs = load_configs()
        complete_sql = assemble_complete_sql(configs)
        Path('aerospace_scoring/compute_aerospace_scores.sql').write_text(complete_sql)
        print("✓ Complete SQL script assembled: aerospace_scoring/compute_aerospace_scores.sql")
    except Exception as e:
        print(f"✗ Failed: {e}")
        return 1
    return 0


if __name__ == "__main__":
    exit(main())
