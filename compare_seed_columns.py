#!/usr/bin/env python3
"""
compare_seed_columns.py - Compare seed_columns.yaml against expected insert columns
"""
import yaml
import sys

def load_yaml(path):
    with open(path) as f:
        return yaml.safe_load(f)

# Expected columns based on per-view SELECT aliases
expected = [
    'osm_id','source_table','aerospace_score','name','operator',
    'postcode','city','street_address','phone','email','website',
    'created_at','tier_classification','confidence_level',
    'tags_raw','latitude','longitude','geometry'
]

def main():
    data = load_yaml('aerospace_scoring/seed_columns.yaml')
    cols = data.get('output_table', {}).get('columns', [])
    yaml_cols = [c['name'] for c in cols]
    missing = [col for col in expected if col not in yaml_cols]
    extra = [col for col in yaml_cols if col not in expected]
    print('Expected vs YAML column comparison:')
    print('--- Missing in YAML ---')
    for c in missing:
        print(c)
    print('--- Extra in YAML ---')
    for c in extra:
        print(c)
    if not missing and not extra:
        print('✅ seed_columns.yaml matches expected columns exactly')
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()