#!/usr/bin/env python3
"""
Generate summary of the entire UK OSM import process
"""

import sys
import os
import json
from pathlib import Path
sys.path.append('scripts/utils')

from osm_utils import setup_logging, load_config

def main():
    setup_logging()
    
    print("\n" + "="*70)
    print("UK OSM DATA PROCESSOR - PROCESS COMPLETE")
    print("="*70)
    
    # Check what files exist
    project_files = {
        'Data file': 'data/raw/great-britain-latest.osm.pbf',
        'Sample data': 'data/samples/',
        'Verification report': 'reports/import_verification_report.txt',
        'JSON report': 'reports/import_verification.json',
        'Log files': 'logs/osm_processor.log'
    }
    
    print("\nFILES CREATED:")
    for desc, path in project_files.items():
        if Path(path).exists():
            if Path(path).is_file():
                size = Path(path).stat().st_size
                size_str = f"({size/1024/1024:.1f}MB)" if size > 1024*1024 else f"({size/1024:.1f}KB)"
                print(f"✓ {desc:20}: {path} {size_str}")
            else:
                files_count = len(list(Path(path).glob('*')))
                print(f"✓ {desc:20}: {path} ({files_count} files)")
        else:
            print(f"✗ {desc:20}: {path}")
    
    print("\nNEXT STEPS:")
    print("1. Review verification report: reports/import_verification_report.txt")
    print("2. Create indexes for performance: psql -d uk_osm_full")
    print("3. Start querying your data!")
    
    print("\nSAMPLE QUERIES TO TRY:")
    print("-- Find all pubs in Manchester")
    print("SELECT name, ST_AsText(ST_Transform(way, 4326)) as location")
    print("FROM osm_raw.planet_osm_point") 
    print("WHERE amenity = 'pub'")
    print("  AND way && ST_Transform(ST_GeomFromText(")
    print("    'POLYGON((-2.3 53.4, -2.1 53.4, -2.1 53.5, -2.3 53.5, -2.3 53.4))', 4326), 3857);")
    
    print("\n-- Count buildings by type")
    print("SELECT building, count(*) FROM osm_raw.planet_osm_polygon")
    print("WHERE building IS NOT NULL GROUP BY building ORDER BY count DESC LIMIT 20;")
    
    print("\nFor more complex queries, consider creating indexes:")
    print("CREATE INDEX idx_point_amenity ON osm_raw.planet_osm_point(amenity);")
    print("CREATE INDEX idx_polygon_building ON osm_raw.planet_osm_polygon(building);")
    print("CREATE INDEX idx_point_geom ON osm_raw.planet_osm_point USING GIST(way);")
    
    print("="*70)

if __name__ == "__main__":
    main()
