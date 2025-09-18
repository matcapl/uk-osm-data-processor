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
