#!/usr/bin/env python3
"""
OSM Data Inspector
Analyzes OSM data structure and creates sample extracts

Sampling strategy (best-practice):
  1) Try Python streaming sampler (scripts/utils/xml_stream_sampler.py) — memory-safe.
  2) If missing/fails, try xmlstarlet (fast for small streams).
  3) If both fail, create a filtered PBF as a fallback.
"""

import sys
import os
import shutil
sys.path.append('scripts/utils')

from osm_utils import setup_logging, load_config, run_command
import logging
from pathlib import Path

def xmlstarlet_available() -> bool:
    return shutil.which('xmlstarlet') is not None

def sampler_available(sampler_path: Path) -> bool:
    return sampler_path.exists() and sampler_path.is_file()

def try_sampler(osm_file: Path, filter_expr: str, count: int, output_file: Path, sampler_path: Path) -> bool:
    """
    Use Python streaming sampler: osmium ... -f xml -o - | python3 sampler N > output_file
    """
    try:
        cmd = (
            f'osmium tags-filter "{osm_file}" {filter_expr} -f xml -o - | '
            f'python3 "{sampler_path}" {count} > "{output_file}"'
        )
        logging.info(f'Executing sampler command: {cmd}')
        run_command(cmd)
        logging.info(f"Sample saved: {output_file} (first {count} matching objects)")
        return True
    except Exception as e:
        logging.warning(f"Python streaming sampler failed for {output_file}: {e}")
        return False

def try_xmlstarlet(osm_file: Path, filter_expr: str, count: int, output_file: Path) -> bool:
    """
    Use xmlstarlet to select the first `count` elements from osmium XML stream.
    Writes to a temporary file then moves into place atomically.
    """
    tmp = output_file.with_suffix('.tmp.xml')
    try:
        cmd = (
            f'osmium tags-filter "{osm_file}" {filter_expr} -f xml -o - | '
            f"xmlstarlet sel -t -c '(/osm/*)[position() <= {count}]' >> \"{tmp}\""
        )
        logging.info(f'Executing xmlstarlet command: {cmd}')
        run_command(cmd)
        # Wrap tmp with header/footer if xmlstarlet returned fragments — but xmlstarlet selection usually returns elements only
        # Add header/footer to ensure valid OSM XML
        with open(tmp, 'r', encoding='utf-8') as ftmp:
            body = ftmp.read()
        with open(output_file, 'w', encoding='utf-8') as fout:
            fout.write('<?xml version="1.0" encoding="utf-8"?>\n<osm version="0.6" generator="xmlstarlet-sample">\n')
            fout.write(body)
            fout.write('\n</osm>\n')
        tmp.unlink(missing_ok=True)
        logging.info(f"Sample saved: {output_file} (first {count} matching objects via xmlstarlet)")
        return True
    except Exception as e:
        logging.warning(f"xmlstarlet sampling failed for {output_file}: {e}")
        try:
            if tmp.exists():
                tmp.unlink()
        except Exception:
            pass
        return False

def try_filtered_pbf(osm_file: Path, filter_expr: str, fallback_file: Path) -> bool:
    """
    Fallback: create filtered PBF containing all matches (compact binary).
    """
    try:
        cmd = f'osmium tags-filter "{osm_file}" {filter_expr} -f pbf -o "{fallback_file}"'
        logging.info(f'Executing fallback PBF command: {cmd}')
        run_command(cmd)
        logging.info(f"Filtered PBF saved: {fallback_file} (all matches for {filter_expr})")
        return True
    except Exception as e:
        logging.error(f"Fallback PBF creation failed for {fallback_file}: {e}")
        return False

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

    sampler_path = Path('scripts/utils/xml_stream_sampler.py')
    have_sampler = sampler_available(sampler_path)
    have_xmlstar = xmlstarlet_available()

    if have_sampler:
        logging.info("Python streaming sampler detected: using scripts/utils/xml_stream_sampler.py as primary sampler.")
    else:
        logging.info("Python streaming sampler not found.")
    if have_xmlstar:
        logging.info("xmlstarlet detected: available as secondary sampler.")
    else:
        logging.info("xmlstarlet not detected: it will not be used as a fallback unless installed.")

    for name, filter_expr, count in sample_extracts:
        output_file = samples_dir / f'{name}_sample.xml'
        fallback_pbf = samples_dir / f'{name}_filtered.osm.pbf'
        logging.info(f"Extracting {name} sample (filter: {filter_expr})...")

        # 1) Try streaming sampler
        collected = False
        if have_sampler:
            collected = try_sampler(osm_file, filter_expr, count, output_file, sampler_path)

        # 2) If sampler failed or missing, try xmlstarlet
        if not collected and have_xmlstar:
            logging.info("Attempting xmlstarlet sampling as fallback.")
            collected = try_xmlstarlet(osm_file, filter_expr, count, output_file)

        # 3) If still not collected, fallback to creating filtered PBF
        if not collected:
            logging.warning(f"Both XML sampling methods failed (or were not available) for {name}. Falling back to filtered PBF.")
            ok = try_filtered_pbf(osm_file, filter_expr, fallback_pbf)
            if not ok:
                logging.error(f"Failed to extract {name} in any form.")

    # Create tag analysis script (unchanged)
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

    # Run tag analysis (only if any XML samples exist)
    logging.info("Running tag analysis...")
    try:
        os.chdir(samples_dir)
        any_xml = any(Path('.').glob('*_sample.xml'))
        if any_xml:
            run_command('python3 analyze_tags.py > tag_analysis_results.txt')
            logging.info("Tag analysis saved to data/samples/tag_analysis_results.txt")
        else:
            logging.warning("No XML sample files found to analyze (likely used PBF fallback).")
        os.chdir('../..')
    except Exception as e:
        try:
            os.chdir('../..')
        except Exception:
            pass
        logging.warning(f"Could not run tag analysis: {e}")

    logging.info("Data inspection completed successfully!")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
