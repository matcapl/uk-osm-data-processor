#!/usr/bin/env python3
"""
OSM Data Inspector
Analyzes OSM data structure and creates sample extracts
"""

import sys
import os
sys.path.append('scripts/utils')

from osm_utils import setup_logging, load_config, run_command
import logging
from pathlib import Path

def main():
    setup_logging()
    config = load_config()
    
    data_dir = Path(config['download']['data_dir'])
    osm_file = data_dir / 'great-britain-latest.osm.pbf'
    samples_dir = Path('data/samples')
    samples_dir.mkdir(parents=True, exist_ok=True)
    
    if not osm_file.exists():
        logging.error(f"OSM file not found: {osm_file}")
        return False
    
    logging.info("Inspecting OSM data structure...")
    
    # Get detailed file info
    logging.info("Getting file information...")
    try:
        result = run_command(f'osmium fileinfo -e "{osm_file}"')
        with open(samples_dir / 'file_info.txt', 'w') as f:
            f.write(result.stdout)
        logging.info("File info saved to data/samples/file_info.txt")
    except Exception as e:
        logging.warning(f"Could not get detailed file info: {e}")
    
    # Extract sample data for different categories
    sample_extracts = [
        ('amenities', 'w/amenity', 500),
        ('buildings', 'w/building', 500), 
        ('shops', 'n/shop', 300),
        ('landuse', 'w/landuse', 300),
        ('tourism', 'nwr/tourism', 200),
        ('industrial', 'w/landuse=industrial', 100)
    ]
    
    for name, filter_expr, count in sample_extracts:
        output_file = samples_dir / f'{name}_sample.xml'
        logging.info(f"Extracting {name} sample...")
        
        try:
            cmd = f'osmium tags-filter "{osm_file}" {filter_expr} -o "{output_file}" -f xml --max-items={count}'
            run_command(cmd)
            logging.info(f"Sample saved: {output_file}")
        except Exception as e:
            logging.warning(f"Could not extract {name} sample: {e}")
    
    # Create tag analysis script
    tag_analysis_script = samples_dir / 'analyze_tags.py'
    with open(tag_analysis_script, 'w') as f:
        f.write("""#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import collections
import sys
from pathlib import Path

def analyze_tags(xml_file):
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
        
        all_tags = collections.defaultdict(set)
        object_counts = collections.defaultdict(int)
        
        for elem in root:
            if elem.tag in ['node', 'way', 'relation']:
                object_counts[elem.tag] += 1
                for tag in elem.findall('tag'):
                    key = tag.get('k')
                    value = tag.get('v')
                    all_tags[key].add(value)
        
        print(f"\\n=== Analysis of {xml_file} ===")
        print(f"Object counts: {dict(object_counts)}")
        print(f"Total unique keys: {len(all_tags)}")
        print(f"\\nTop 15 most common keys:")
        
        key_counts = {k: len(v) for k, v in all_tags.items()}
        sorted_keys = sorted(key_counts.items(), key=lambda x: x[1], reverse=True)
        
        for key, count in sorted_keys[:15]:
            print(f"  {key}: {count} unique values")
            sample_values = list(all_tags[key])[:3]
            print(f"    Sample values: {sample_values}")
        
        return all_tags, object_counts
        
    except Exception as e:
        print(f"Error analyzing {xml_file}: {e}")
        return {}, {}

if __name__ == "__main__":
    samples_dir = Path('.')
    all_keys = set()
    
    for xml_file in samples_dir.glob('*_sample.xml'):
        tags, counts = analyze_tags(xml_file)
        all_keys.update(tags.keys())
    
    print(f"\\n=== SUMMARY ===")
    print(f"Total unique keys across all samples: {len(all_keys)}")
    print(f"\\nAll keys found: {sorted(list(all_keys))}")
""")
    
    # Run tag analysis
    logging.info("Running tag analysis...")
    try:
        os.chdir(samples_dir)
        run_command('python3 analyze_tags.py > tag_analysis_results.txt')
        os.chdir('../..')
        logging.info("Tag analysis saved to data/samples/tag_analysis_results.txt")
    except Exception as e:
        logging.warning(f"Could not run tag analysis: {e}")
    
    logging.info("Data inspection completed successfully!")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
