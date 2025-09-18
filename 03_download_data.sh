#!/bin/bash
# ========================================
# UK OSM Import Automation - Phase 3: Download Data
# File: 03_download_data.sh
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== UK OSM Import Automation - Phase 3: Download OSM Data ===${NC}"

# Create Python script for downloading
cat > scripts/download/download_osm.py << 'EOF'
#!/usr/bin/env python3
"""
UK OSM Data Downloader
Downloads UK OSM data with verification and resume capability
"""

import sys
import os
sys.path.append('scripts/utils')

from osm_utils import setup_logging, load_config, check_disk_space, download_file, verify_checksum
import logging
from pathlib import Path

def main():
    setup_logging()
    config = load_config()
    
    # Check disk space
    if not check_disk_space('.', config.get('system', {}).get('min_free_space_gb', 100)):
        logging.error("Insufficient disk space for download and processing")
        return False
    
    # Create data directory
    data_dir = Path(config['download']['data_dir'])
    data_dir.mkdir(parents=True, exist_ok=True)
    
    # Download paths
    osm_url = config['download']['source_url']
    checksum_url = config['download']['checksum_url']
    
    osm_file = data_dir / 'great-britain-latest.osm.pbf'
    checksum_file = data_dir / 'great-britain-latest.osm.pbf.md5'
    
    logging.info(f"Starting UK OSM data download...")
    logging.info(f"Source: {osm_url}")
    logging.info(f"Destination: {osm_file}")
    
    # Download checksum file first
    logging.info("Downloading checksum file...")
    if not download_file(checksum_url, str(checksum_file)):
        logging.error("Failed to download checksum file")
        return False
    
    # Download main data file
    logging.info("Downloading OSM data file...")
    if not download_file(osm_url, str(osm_file)):
        logging.error("Failed to download OSM data file")
        return False
    
    # Verify checksum
    logging.info("Verifying file integrity...")
    if not verify_checksum(str(osm_file), str(checksum_file)):
        logging.error("File verification failed")
        return False
    
    # Get file info using osmium
    logging.info("Analyzing downloaded file...")
    try:
        import subprocess
        result = subprocess.run(['osmium', 'fileinfo', str(osm_file)], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            logging.info("File analysis:")
            for line in result.stdout.split('\n')[:20]:  # First 20 lines
                if line.strip():
                    logging.info(f"  {line}")
    except Exception as e:
        logging.warning(f"Could not analyze file with osmium: {e}")
    
    logging.info("Download phase completed successfully!")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOF

# Create data inspection script
cat > scripts/download/inspect_data.py << 'EOF'
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
EOF

# Make Python scripts executable
chmod +x scripts/download/download_osm.py
chmod +x scripts/download/inspect_data.py

# Create the OSM2PGSQL style file for maximum data retention
cat > config/uk_full_retention.style << 'EOF'
# OSM2PGSQL Style File for Complete UK Data Retention
# Ensures maximum data preservation during import

# Way tags - comprehensive coverage
way   access        text     linear
way   addr:city     text     linear
way   addr:country  text     linear
way   addr:housenumber text  linear
way   addr:postcode text     linear
way   addr:street   text     linear
way   addr:state    text     linear
way   addr:suburb   text     linear
way   admin_level   text     linear
way   aerialway     text     linear
way   aeroway       text     linear
way   amenity       text     linear
way   area          text     linear
way   barrier       text     linear
way   bicycle       text     linear
way   boundary      text     linear
way   brand         text     linear
way   bridge        text     linear
way   building      text     linear
way   building:levels text   linear
way   building:use  text     linear
way   bus           text     linear
way   construction  text     linear
way   covered       text     linear
way   cuisine       text     linear
way   cutting       text     linear
way   denomination  text     linear
way   disused       text     linear
way   embankment    text     linear
way   foot          text     linear
way   generator:source text  linear
way   harbour       text     linear
way   highway       text     linear
way   historic      text     linear
way   horse         text     linear
way   industrial    text     linear
way   junction      text     linear
way   landuse       text     linear
way   layer         text     linear
way   leisure       text     linear
way   lock          text     linear
way   man_made      text     linear
way   military      text     linear
way   motorcar      text     linear
way   name          text     linear
way   name:en       text     linear
way   natural       text     linear
way   office        text     linear
way   oneway        text     linear
way   operator      text     linear
way   place         text     linear
way   population    text     linear
way   power         text     linear
way   power_source  text     linear
way   public_transport text  linear
way   railway       text     linear
way   ref           text     linear
way   religion      text     linear
way   route         text     linear
way   service       text     linear
way   shop          text     linear
way   sport         text     linear
way   surface       text     linear
way   toll          text     linear
way   tourism       text     linear
way   tracktype     text     linear
way   tunnel        text     linear
way   water         text     linear
way   waterway      text     linear
way   website       text     linear
way   wetland       text     linear
way   wheelchair    text     linear
way   width         text     linear
way   wood          text     linear
way   z_order       int4     linear

# Point tags - for nodes (POIs)
node  addr:city     text     
node  addr:country  text     
node  addr:housenumber text  
node  addr:postcode text     
node  addr:street   text     
node  aerialway     text     
node  aeroway       text     
node  amenity       text     
node  barrier       text     
node  bicycle       text     
node  brand         text     
node  bus           text     
node  construction  text     
node  covered       text     
node  cuisine       text     
node  denomination  text     
node  disused       text     
node  ele           text     
node  emergency     text     
node  entrance      text     
node  foot          text     
node  generator:source text  
node  harbour       text     
node  highway       text     
node  historic      text     
node  horse         text     
node  information   text     
node  junction      text     
node  landuse       text     
node  leisure       text     
node  man_made      text     
node  military      text     
node  name          text     
node  name:en       text     
node  natural       text     
node  office        text     
node  operator      text     
node  place         text     
node  population    text     
node  power         text     
node  public_transport text  
node  railway       text     
node  ref           text     
node  religion      text     
node  shop          text     
node  sport         text     
node  surface       text     
node  tourism       text     
node  waterway      text     
node  website       text     
node  wheelchair    text     
EOF

# Run the download and inspection
echo -e "${YELLOW}Starting OSM data download...${NC}"

# Activate virtual environment and run download
if command -v uv &> /dev/null; then
    echo -e "${YELLOW}Using uv to run download script...${NC}"
    uv run scripts/download/download_osm.py
else
    echo -e "${YELLOW}Using system python to run download script...${NC}"
    python3 scripts/download/download_osm.py
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Download completed successfully${NC}"
    
    # Ask if user wants to run inspection
    read -p "Run data inspection? This creates sample extracts and analyzes structure (Y/n): " RUN_INSPECTION
    
    if [[ $RUN_INSPECTION != "n" && $RUN_INSPECTION != "N" ]]; then
        echo -e "${YELLOW}Running data inspection...${NC}"
        
        if command -v uv &> /dev/null; then
            uv run scripts/download/inspect_data.py
        else
            python3 scripts/download/inspect_data.py
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Data inspection completed${NC}"
            echo -e "${YELLOW}Check data/samples/ for extracted samples and analysis results${NC}"
        else
            echo -e "${YELLOW}⚠ Data inspection had some issues, but download is complete${NC}"
        fi
    fi
    
    # Show download summary
    echo -e "${BLUE}=== Download Summary ===${NC}"
    if [ -f "data/raw/great-britain-latest.osm.pbf" ]; then
        FILE_SIZE=$(ls -lh data/raw/great-britain-latest.osm.pbf | awk '{print $5}')
        echo -e "${GREEN}OSM File: data/raw/great-britain-latest.osm.pbf (${FILE_SIZE})${NC}"
    fi
    
    if [ -f "data/samples/file_info.txt" ]; then
        echo -e "${GREEN}File info: data/samples/file_info.txt${NC}"
    fi
    
    if [ -f "data/samples/tag_analysis_results.txt" ]; then
        echo -e "${GREEN}Tag analysis: data/samples/tag_analysis_results.txt${NC}"
    fi
    
    echo -e "${GREEN}=== Phase 3 Complete: Data Downloaded ===${NC}"
    echo -e "${YELLOW}Next step: Run ./04_setup_database.sh${NC}"
    
else
    echo -e "${RED}✗ Download failed${NC}"
    echo -e "${YELLOW}Check logs/osm_processor.log for details${NC}"
    exit 1
fi