#!/usr/bin/env python3
"""
Test all user/schema combinations for aerospace pipeline
Diagnose why 0 candidates were found
"""

import psycopg2
import yaml
from pathlib import Path

def test_user_schema_combo(user, schema, dbname='uk_osm_full'):
    """Test a specific user/schema combination."""
    print(f"\n{'='*60}")
    print(f"Testing: USER={user}, SCHEMA={schema}")
    print('='*60)
    
    try:
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            user=user,
            database=dbname
        )
        cur = conn.cursor()
        
        results = {
            'user': user,
            'schema': schema,
            'connected': True,
            'tests': {}
        }
        
        # Test 1: Can read base tables?
        try:
            cur.execute(f"SELECT COUNT(*) FROM {schema}.planet_osm_polygon")
            count = cur.fetchone()[0]
            results['tests']['read_base_table'] = {'success': True, 'count': count}
            print(f"✓ Can read {schema}.planet_osm_polygon: {count:,} rows")
        except Exception as e:
            results['tests']['read_base_table'] = {'success': False, 'error': str(e)}
            print(f"✗ Cannot read {schema}.planet_osm_polygon: {e}")
        
        # Test 2: Can read filtered views?
        try:
            cur.execute(f"SELECT COUNT(*) FROM {schema}.planet_osm_polygon_aerospace_filtered")
            count = cur.fetchone()[0]
            results['tests']['read_filtered_view'] = {'success': True, 'count': count}
            print(f"✓ Can read filtered view: {count:,} rows")
        except Exception as e:
            results['tests']['read_filtered_view'] = {'success': False, 'error': str(e)}
            print(f"✗ Cannot read filtered view: {e}")
        
        # Test 3: Can read scored views?
        try:
            cur.execute(f"SELECT COUNT(*) FROM {schema}.planet_osm_polygon_aerospace_scored")
            count = cur.fetchone()[0]
            results['tests']['read_scored_view'] = {'success': True, 'count': count}
            print(f"✓ Can read scored view: {count:,} rows")
        except Exception as e:
            results['tests']['read_scored_view'] = {'success': False, 'error': str(e)}
            print(f"✗ Cannot read scored view: {e}")
        
        # Test 4: Industrial data exists?
        try:
            cur.execute(f"""
                SELECT COUNT(*) FROM {schema}.planet_osm_polygon
                WHERE landuse = 'industrial' 
                   OR building IN ('industrial', 'warehouse', 'factory')
                   OR office IS NOT NULL
            """)
            count = cur.fetchone()[0]
            results['tests']['industrial_data'] = {'success': True, 'count': count}
            print(f"✓ Industrial/office data available: {count:,} rows")
        except Exception as e:
            results['tests']['industrial_data'] = {'success': False, 'error': str(e)}
            print(f"✗ Cannot query industrial data: {e}")
        
        # Test 5: Can write to aerospace_supplier_candidates?
        try:
            cur.execute(f"""
                SELECT COUNT(*) FROM {schema}.aerospace_supplier_candidates
            """)
            count = cur.fetchone()[0]
            results['tests']['read_candidates_table'] = {'success': True, 'count': count}
            print(f"✓ Can read candidates table: {count:,} rows")
            
            # Try to insert a test row
            try:
                cur.execute(f"""
                    INSERT INTO {schema}.aerospace_supplier_candidates 
                    (osm_id, name, aerospace_score, created_at)
                    VALUES (-999999, 'TEST_ROW', 100, NOW())
                """)
                conn.commit()
                
                # Delete test row
                cur.execute(f"""
                    DELETE FROM {schema}.aerospace_supplier_candidates 
                    WHERE osm_id = -999999
                """)
                conn.commit()
                
                results['tests']['write_candidates_table'] = {'success': True}
                print(f"✓ Can write to candidates table")
            except Exception as e:
                conn.rollback()
                results['tests']['write_candidates_table'] = {'success': False, 'error': str(e)}
                print(f"✗ Cannot write to candidates table: {e}")
                
        except Exception as e:
            results['tests']['read_candidates_table'] = {'success': False, 'error': str(e)}
            print(f"✗ Cannot read candidates table: {e}")
        
        # Test 6: Sample data that should score
        try:
            cur.execute(f"""
                SELECT osm_id, name, landuse, building, office
                FROM {schema}.planet_osm_polygon
                WHERE landuse = 'industrial' 
                   OR building IN ('industrial', 'warehouse', 'factory')
                   OR office IS NOT NULL
                LIMIT 5
            """)
            samples = cur.fetchall()
            results['tests']['sample_data'] = {'success': True, 'samples': samples}
            print(f"✓ Sample industrial data:")
            for row in samples:
                print(f"   osm_id={row[0]}, name={row[1]}, landuse={row[2]}, building={row[3]}, office={row[4]}")
        except Exception as e:
            results['tests']['sample_data'] = {'success': False, 'error': str(e)}
            print(f"✗ Cannot get sample data: {e}")
        
        conn.close()
        return results
        
    except Exception as e:
        print(f"✗ Connection failed: {e}")
        return {
            'user': user,
            'schema': schema,
            'connected': False,
            'error': str(e)
        }

def test_view_definitions(schema='public'):
    """Check the actual SQL definitions of views."""
    print(f"\n{'='*60}")
    print("CHECKING VIEW DEFINITIONS")
    print('='*60)
    
    try:
        conn = psycopg2.connect(
            host='localhost',
            port=5432,
            user='a',
            database='uk_osm_full'
        )
        cur = conn.cursor()
        
        views_to_check = [
            'planet_osm_polygon_aerospace_filtered',
            'planet_osm_polygon_aerospace_scored'
        ]
        
        for view_name in views_to_check:
            print(f"\nView: {view_name}")
            cur.execute("""
                SELECT definition 
                FROM pg_views 
                WHERE schemaname = %s AND viewname = %s
            """, (schema, view_name))
            
            result = cur.fetchone()
            if result:
                definition = result[0]
                print(f"Definition length: {len(definition)} chars")
                print(f"First 200 chars: {definition[:200]}...")
            else:
                print(f"✗ View not found!")
        
        conn.close()
        
    except Exception as e:
        print(f"✗ Error checking views: {e}")

def main():
    print("="*60)
    print("AEROSPACE PIPELINE DIAGNOSTIC")
    print("Testing all user/schema combinations")
    print("="*60)
    
    # Users to test
    users = ['a', 'ukosm_user']
    
    # Schemas to test
    schemas = ['public', 'osm_raw']
    
    all_results = []
    
    # Test all combinations
    for user in users:
        for schema in schemas:
            result = test_user_schema_combo(user, schema)
            all_results.append(result)
    
    # Check view definitions
    test_view_definitions('public')
    
    # Summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    print('='*60)
    
    for result in all_results:
        if result['connected']:
            user = result['user']
            schema = result['schema']
            print(f"\n{user}@{schema}:")
            
            if result['tests'].get('industrial_data', {}).get('success'):
                ind_count = result['tests']['industrial_data']['count']
                print(f"  Industrial data: {ind_count:,} records")
            
            if result['tests'].get('read_filtered_view', {}).get('success'):
                filt_count = result['tests']['read_filtered_view']['count']
                print(f"  Filtered view: {filt_count:,} records")
            
            if result['tests'].get('read_scored_view', {}).get('success'):
                score_count = result['tests']['read_scored_view']['count']
                print(f"  Scored view: {score_count:,} records")
            
            if result['tests'].get('read_candidates_table', {}).get('success'):
                cand_count = result['tests']['read_candidates_table']['count']
                print(f"  Candidates table: {cand_count:,} records")
                
                if cand_count == 0 and score_count > 0:
                    print(f"  ⚠️  WARNING: Scored view has data but candidates table is empty!")
                    print(f"     This suggests the INSERT query failed or has wrong conditions")
    
    print("\n" + "="*60)
    print("RECOMMENDATIONS")
    print("="*60)
    
    # Find the working combination
    working = [r for r in all_results if r.get('connected') and 
               r.get('tests', {}).get('industrial_data', {}).get('success')]
    
    if working:
        best = working[0]
        print(f"\n✓ Working combination found: {best['user']}@{best['schema']}")
        
        ind_count = best['tests'].get('industrial_data', {}).get('count', 0)
        filt_count = best['tests'].get('read_filtered_view', {}).get('count', 0)
        score_count = best['tests'].get('read_scored_view', {}).get('count', 0)
        cand_count = best['tests'].get('read_candidates_table', {}).get('count', 0)
        
        print(f"\nData pipeline:")
        print(f"  Source industrial data: {ind_count:,}")
        print(f"  After filters: {filt_count:,}")
        print(f"  After scoring: {score_count:,}")
        print(f"  Final candidates: {cand_count:,}")
        
        if ind_count > 0 and filt_count == 0:
            print(f"\n⚠️  ISSUE: Filters are too restrictive!")
            print(f"   All {ind_count:,} industrial records were filtered out")
            print(f"   Check: aerospace_scoring/exclusions.sql")
        
        if filt_count > 0 and score_count == 0:
            print(f"\n⚠️  ISSUE: Scoring is not working!")
            print(f"   {filt_count:,} records pass filters but get score of 0")
            print(f"   Check: aerospace_scoring/scoring.sql")
        
        if score_count > 0 and cand_count == 0:
            print(f"\n⚠️  ISSUE: INSERT query is not working!")
            print(f"   {score_count:,} records have scores but aren't being inserted")
            print(f"   Check: aerospace_scoring/compute_aerospace_scores.sql")
            print(f"   Look for the INSERT INTO statement")
    else:
        print("\n✗ No working combination found!")
        print("   Cannot access industrial data in any schema")

if __name__ == "__main__":
    main()