#!/usr/bin/env python3
"""
insert_column_mapper.py - Focused analysis of INSERT column mismatches
Builds on existing diagnostic tools to solve the specific INSERT problem
"""

import psycopg2
import yaml
import json
from collections import defaultdict

def load_config():
    """Load database config"""
    with open('config/config.yaml', 'r') as f:
        return yaml.safe_load(f)

def get_scored_view_columns(cursor, schema_name):
    """Get columns from each scored view that we're trying to UNION"""
    scored_views = [
        'planet_osm_point_aerospace_scored',
        'planet_osm_line_aerospace_scored', 
        'planet_osm_polygon_aerospace_scored',
        'planet_osm_roads_aerospace_scored'
    ]

    view_columns = {}

    for view in scored_views:
        # Check if view exists
        cursor.execute("""
            SELECT column_name, data_type 
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position
        """, [schema_name, view])

        columns = cursor.fetchall()
        if columns:
            view_columns[view] = {
                'columns': [col[0] for col in columns],
                'column_types': {col[0]: col[1] for col in columns},
                'exists': True,
                'count': len(columns)
            }
        else:
            view_columns[view] = {'exists': False}

    return view_columns

def get_target_table_columns(cursor, schema_name):
    """Get columns from target aerospace_supplier_candidates table"""
    cursor.execute("""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = 'aerospace_supplier_candidates'
        ORDER BY ordinal_position
    """, [schema_name])

    columns = cursor.fetchall()
    if not columns:
        return None

    return {
        'columns': [col[0] for col in columns],
        'column_info': {
            col[0]: {
                'type': col[1], 
                'nullable': col[2] == 'YES',
                'default': col[3]
            } for col in columns
        }
    }

def analyze_union_compatibility(view_columns):
    """Analyze if views can be UNIONed (same column count and types)"""
    print("\n=== UNION COMPATIBILITY ANALYSIS ===")

    existing_views = {k: v for k, v in view_columns.items() if v.get('exists')}

    if not existing_views:
        print("❌ No scored views exist!")
        return False

    # Check column counts
    column_counts = [info['count'] for info in existing_views.values()]
    if len(set(column_counts)) > 1:
        print("❌ UNION INCOMPATIBLE: Different column counts")
        for view, info in existing_views.items():
            print(f"  {view}: {info['count']} columns")
        return False

    # Check column names match
    all_columns = [info['columns'] for info in existing_views.values()]
    if not all(cols == all_columns[0] for cols in all_columns[1:]):
        print("❌ UNION INCOMPATIBLE: Different column names/order")

        # Show differences
        reference = set(all_columns[0])
        for view, info in existing_views.items():
            view_cols = set(info['columns'])
            missing = reference - view_cols
            extra = view_cols - reference
            if missing or extra:
                print(f"  {view}:")
                if missing: print(f"    Missing: {missing}")
                if extra: print(f"    Extra: {extra}")
        return False

    print("✅ UNION COMPATIBLE: All views have matching schemas")
    return True

def identify_missing_target_columns(view_columns, target_columns):
    """Identify which target table columns are missing from source views"""
    print("\n=== MISSING COLUMN ANALYSIS ===")

    if not target_columns:
        print("❌ Target table doesn't exist")
        return {}

    existing_views = {k: v for k, v in view_columns.items() if v.get('exists')}
    if not existing_views:
        print("❌ No source views exist")
        return {}

    # Use first view as reference (they should all be the same after UNION check)
    reference_view = list(existing_views.values())[0]
    source_columns = set(reference_view['columns'])
    target_required = set(target_columns['columns'])

    missing_in_source = target_required - source_columns
    extra_in_source = source_columns - target_required

    results = {
        'missing_in_source': missing_in_source,
        'extra_in_source': extra_in_source,
        'compatible': len(missing_in_source) == 0
    }

    if missing_in_source:
        print("❌ COLUMNS MISSING IN SOURCE VIEWS:")
        for col in sorted(missing_in_source):
            target_info = target_columns['column_info'][col]
            nullable = "NULL allowed" if target_info['nullable'] else "NOT NULL"
            default = f"default: {target_info['default']}" if target_info['default'] else "no default"
            print(f"  - {col} ({target_info['type']}, {nullable}, {default})")

    if extra_in_source:
        print(f"ℹ️  EXTRA COLUMNS IN SOURCE: {len(extra_in_source)}")
        print(f"  (These will be ignored in INSERT: {sorted(list(extra_in_source)[:5])}{'...' if len(extra_in_source) > 5 else ''})")

    if results['compatible']:
        print("✅ All target columns are available in source views")

    return results

def generate_insert_fix_recommendations(missing_analysis, view_columns, target_columns):
    """Generate specific recommendations to fix INSERT issues"""
    print("\n=== INSERT FIX RECOMMENDATIONS ===")

    if not missing_analysis.get('missing_in_source'):
        print("✅ No column mapping issues found")
        return []

    recommendations = []
    missing_cols = missing_analysis['missing_in_source']

    # Common OSM tag mappings
    tag_mappings = {
        'postcode': "tags->'addr:postcode'",
        'city': "tags->'addr:city'", 
        'street': "tags->'addr:street'",
        'phone': "tags->'phone'",
        'website': "tags->'website'",
        'email': "tags->'email'"
    }

    for col in missing_cols:
        target_info = target_columns['column_info'][col]

        if col in tag_mappings:
            # Can be extracted from tags
            recommendations.append({
                'column': col,
                'issue': f'Missing {col} column in scored views',
                'solution': f'Add to each scored view: {tag_mappings[col]} AS {col}',
                'sql_example': f'SELECT *, {tag_mappings[col]} AS {col} FROM ...'
            })
        elif col in ['created_at', 'updated_at']:
            # Timestamp columns
            recommendations.append({
                'column': col,
                'issue': f'Missing {col} column',
                'solution': f'Add to each scored view: NOW() AS {col}',
                'sql_example': f'SELECT *, NOW() AS {col} FROM ...'
            })
        elif col == 'tier_classification':
            # Computed column
            tier_case = """CASE 
    WHEN aerospace_score >= 150 THEN 'tier1_candidate'
    WHEN aerospace_score >= 80 THEN 'tier2_candidate'
    WHEN aerospace_score >= 40 THEN 'potential_candidate'
    ELSE 'low_probability'
END AS tier_classification"""
            recommendations.append({
                'column': col,
                'issue': f'Missing {col} column',
                'solution': 'Add CASE statement for tier classification',
                'sql_example': tier_case
            })
        else:
            # Unknown column
            recommendations.append({
                'column': col,
                'issue': f'Missing {col} column - unknown mapping',
                'solution': f'Need to determine source or use NULL/default',
                'sql_example': f'NULL AS {col}  -- or appropriate default'
            })

    # Print recommendations
    for i, rec in enumerate(recommendations, 1):
        print(f"\n{i}. Column: {rec['column']}")
        print(f"   Issue: {rec['issue']}")
        print(f"   Solution: {rec['solution']}")
        print(f"   SQL: {rec['sql_example']}")

    return recommendations

def main():
    print("🔧 INSERT COLUMN MAPPER")
    print("Analyzing column mismatches causing INSERT failures")
    print("=" * 55)

    # Load config and connect
    config = load_config()
    db_config = config['database']
    schema_name = db_config.get('schema', 'public')

    try:
        conn = psycopg2.connect(
            host=db_config.get('host', 'localhost'),
            port=db_config.get('port', 5432),
            dbname=db_config.get('database', 'uk_osm_full'),
            user=db_config.get('user'),
            password=db_config.get('password', '')
        )

        with conn.cursor() as cursor:
            # Get schemas for all scored views
            view_columns = get_scored_view_columns(cursor, schema_name)

            # Get target table schema
            target_columns = get_target_table_columns(cursor, schema_name)

            # Check UNION compatibility
            union_compatible = analyze_union_compatibility(view_columns)

            # Identify missing columns
            missing_analysis = identify_missing_target_columns(view_columns, target_columns)

            # Generate fix recommendations
            recommendations = generate_insert_fix_recommendations(
                missing_analysis, view_columns, target_columns
            )

            # Save results
            results = {
                'view_columns': view_columns,
                'target_columns': target_columns,
                'union_compatible': union_compatible,
                'missing_analysis': missing_analysis,
                'recommendations': recommendations
            }

            with open('aerospace_scoring/insert_analysis.json', 'w') as f:
                json.dump(results, f, indent=2, default=str)

            print(f"\n📄 Analysis saved to: aerospace_scoring/insert_analysis.json")

    except Exception as e:
        print(f"ERROR: {e}")
        return 1
    finally:
        if 'conn' in locals():
            conn.close()

    print("\n✅ Column mapping analysis complete!")
    return 0

if __name__ == "__main__":
    exit(main())