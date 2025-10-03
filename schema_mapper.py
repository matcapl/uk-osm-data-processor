#!/usr/bin/env python3
"""
comprehensive_schema_mapper.py - Maps all tables/views at each pipeline stage
Identifies column inconsistencies, overlaps, and transformation requirements
"""

import psycopg2
import yaml
import json
import sys
from collections import defaultdict
from pathlib import Path

def load_config():
    """Load database config"""
    try:
        with open('config/config.yaml', 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print("ERROR: config/config.yaml not found")
        sys.exit(1)

def get_table_schema(cursor, schema_name, table_name):
    """Get complete column information for a table/view"""
    query = """
        SELECT 
            column_name, 
            data_type, 
            udt_name,
            is_nullable,
            column_default,
            ordinal_position
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position
    """

    cursor.execute(query, [schema_name, table_name])
    columns = []
    for row in cursor.fetchall():
        col_name, data_type, udt_name, nullable, default, position = row
        columns.append({
            'name': col_name,
            'type': data_type,
            'udt': udt_name,
            'nullable': nullable == 'YES',
            'default': default,
            'position': position
        })
    return columns

def get_row_count(cursor, schema_name, table_name):
    """Get row count for table/view"""
    try:
        cursor.execute(f'SELECT COUNT(*) FROM "{schema_name}"."{table_name}"')
        return cursor.fetchone()[0]
    except Exception as e:
        return f"ERROR: {str(e)}"

def check_table_exists(cursor, schema_name, table_name):
    """Check if table/view exists"""
    cursor.execute("""
        SELECT table_type 
        FROM information_schema.tables 
        WHERE table_schema = %s AND table_name = %s
    """, [schema_name, table_name])
    result = cursor.fetchone()
    return result[0] if result else None

def analyze_pipeline_stages(cursor, schema_name):
    """Analyze all pipeline stages and their schemas"""

    # Define the pipeline stages and expected tables
    pipeline_stages = {
        'raw_osm': [
            'planet_osm_point',
            'planet_osm_line', 
            'planet_osm_polygon',
            'planet_osm_roads'
        ],
        'filtered_views': [
            'planet_osm_point_aerospace_filtered',
            'planet_osm_line_aerospace_filtered',
            'planet_osm_polygon_aerospace_filtered',
            'planet_osm_roads_aerospace_filtered'
        ],
        'scored_views': [
            'planet_osm_point_aerospace_scored',
            'planet_osm_line_aerospace_scored',
            'planet_osm_polygon_aerospace_scored',
            'planet_osm_roads_aerospace_scored'
        ],
        'final_output': [
            'aerospace_supplier_candidates'
        ]
    }

    analysis = {}

    for stage_name, tables in pipeline_stages.items():
        print(f"\n=== ANALYZING STAGE: {stage_name.upper()} ===")
        stage_analysis = {}

        for table_name in tables:
            print(f"  Checking {table_name}...")

            # Check existence
            table_type = check_table_exists(cursor, schema_name, table_name)
            if not table_type:
                stage_analysis[table_name] = {
                    'exists': False,
                    'error': 'Table/view does not exist'
                }
                continue

            # Get schema
            columns = get_table_schema(cursor, schema_name, table_name)
            row_count = get_row_count(cursor, schema_name, table_name)

            stage_analysis[table_name] = {
                'exists': True,
                'type': table_type,
                'row_count': row_count,
                'column_count': len(columns),
                'columns': {col['name']: col for col in columns}
            }

            print(f"    ✓ {table_type}: {len(columns)} columns, {row_count} rows")

        analysis[stage_name] = stage_analysis

    return analysis

def find_inconsistencies(analysis):
    """Find column inconsistencies across tables in the same stage"""
    print(f"\n=== INCONSISTENCY ANALYSIS ===")

    inconsistencies = {}

    # Categories of columns we care about
    key_categories = {
        'core_osm': ['osm_id', 'name', 'tags', 'way'],
        'address': ['postcode', 'city', 'street', 'addr:postcode', 'addr:city', 'addr:street'],
        'contact': ['phone', 'website', 'email', 'contact:phone', 'contact:website'],
        'business': ['operator', 'office', 'building', 'landuse', 'industrial'],
        'scoring': ['aerospace_score', 'source_table', 'tier_classification']
    }

    for stage_name, stage_data in analysis.items():
        if not stage_data:
            continue

        print(f"\n--- Stage: {stage_name} ---")
        stage_inconsistencies = {}

        # Get all columns across all tables in this stage
        all_stage_columns = set()
        table_columns = {}

        for table_name, table_data in stage_data.items():
            if table_data.get('exists', False):
                table_cols = set(table_data['columns'].keys())
                table_columns[table_name] = table_cols
                all_stage_columns.update(table_cols)

        # Check each category
        for category, expected_cols in key_categories.items():
            category_analysis = {}

            for col in expected_cols:
                col_presence = {}
                for table_name, table_cols in table_columns.items():
                    col_presence[table_name] = col in table_cols

                if len(set(col_presence.values())) > 1:  # Inconsistent presence
                    category_analysis[col] = {
                        'inconsistent': True,
                        'presence': col_presence
                    }

            if category_analysis:
                stage_inconsistencies[category] = category_analysis

        # Check for columns present in some tables but not others
        missing_columns = {}
        for table_name, table_cols in table_columns.items():
            missing_in_this_table = all_stage_columns - table_cols
            if missing_in_this_table:
                missing_columns[table_name] = list(missing_in_this_table)

        if missing_columns:
            stage_inconsistencies['missing_columns'] = missing_columns

        inconsistencies[stage_name] = stage_inconsistencies

        # Print summary
        if stage_inconsistencies:
            print(f"  ❌ Found inconsistencies in {len(stage_inconsistencies)} categories")
            for category, issues in stage_inconsistencies.items():
                if category != 'missing_columns':
                    print(f"    - {category}: {len(issues)} inconsistent columns")
                else:
                    print(f"    - missing_columns: affects {len(issues)} tables")
        else:
            print(f"  ✅ No inconsistencies found")

    return inconsistencies

def generate_transformation_recommendations(analysis, inconsistencies):
    """Generate specific transformation recommendations"""
    print(f"\n=== TRANSFORMATION RECOMMENDATIONS ===")

    recommendations = []

    # Check for missing address columns that should be extracted from tags
    address_columns = ['postcode', 'city', 'street']
    for stage_name, stage_data in analysis.items():
        if 'scored' in stage_name:  # Focus on scored views
            for table_name, table_data in stage_data.items():
                if not table_data.get('exists', False):
                    continue

                columns = table_data['columns']
                missing_address = []

                for addr_col in address_columns:
                    if addr_col not in columns:
                        # Check if we have tags column to extract from
                        if 'tags' in columns:
                            missing_address.append(addr_col)

                if missing_address:
                    recommendations.append({
                        'table': table_name,
                        'issue': f'Missing address columns: {missing_address}',
                        'solution': f'Add: ' + ', '.join([
                            f"tags->'addr:{col}' AS {col}" for col in missing_address
                        ])
                    })

    # Check for missing contact columns
    contact_columns = ['phone', 'website', 'email']
    for stage_name, stage_data in analysis.items():
        if 'scored' in stage_name:
            for table_name, table_data in stage_data.items():
                if not table_data.get('exists', False):
                    continue

                columns = table_data['columns']
                missing_contact = []

                for contact_col in contact_columns:
                    if contact_col not in columns and 'tags' in columns:
                        missing_contact.append(contact_col)

                if missing_contact:
                    recommendations.append({
                        'table': table_name,
                        'issue': f'Missing contact columns: {missing_contact}',
                        'solution': f'Add: ' + ', '.join([
                            f"tags->'{col}' AS {col}" for col in missing_contact
                        ])
                    })

    # Print recommendations
    if recommendations:
        print("\nRECOMMENDED TRANSFORMATIONS:")
        for i, rec in enumerate(recommendations, 1):
            print(f"\n{i}. Table: {rec['table']}")
            print(f"   Issue: {rec['issue']}")
            print(f"   Solution: {rec['solution']}")
    else:
        print("\n✅ No transformations needed")

    return recommendations

def save_analysis_report(analysis, inconsistencies, recommendations):
    """Save detailed analysis to JSON file"""
    report = {
        'timestamp': str(datetime.now()),
        'analysis': analysis,
        'inconsistencies': inconsistencies,
        'recommendations': recommendations
    }

    with open('aerospace_scoring/schema_analysis_report.json', 'w') as f:
        json.dump(report, f, indent=2, default=str)

    print(f"\n📄 Detailed report saved to: aerospace_scoring/schema_analysis_report.json")

def main():
    print("🔍 COMPREHENSIVE SCHEMA MAPPER")
    print("=" * 50)

    # Load config
    config = load_config()
    db_config = config['database']
    schema_name = db_config.get('schema', 'public')

    # Connect to database
    try:
        conn = psycopg2.connect(
            host=db_config.get('host', 'localhost'),
            port=db_config.get('port', 5432),
            dbname=db_config.get('database', 'uk_osm_full'),
            user=db_config.get('user'),
            password=db_config.get('password', '')
        )

        with conn.cursor() as cursor:
            # Analyze all pipeline stages
            analysis = analyze_pipeline_stages(cursor, schema_name)

            # Find inconsistencies
            inconsistencies = find_inconsistencies(analysis)

            # Generate recommendations
            recommendations = generate_transformation_recommendations(analysis, inconsistencies)

            # Save report
            from datetime import datetime
            save_analysis_report(analysis, inconsistencies, recommendations)

    except Exception as e:
        print(f"ERROR: Database connection failed: {e}")
        return 1
    finally:
        if 'conn' in locals():
            conn.close()

    print("\n✅ Schema mapping complete!")
    return 0

if __name__ == "__main__":
    sys.exit(main())