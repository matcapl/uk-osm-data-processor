"""
UK OSM Data Processor - Utility Functions
"""

import os
import sys
import yaml
import logging
import subprocess
import requests
import hashlib
from pathlib import Path
from typing import Dict, Any, Optional

def setup_logging(log_level: str = "INFO") -> None:
    """Setup logging configuration."""
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_dir / 'osm_processor.log'),
            logging.StreamHandler(sys.stdout)
        ]
    )

def load_config(config_path: str = "config/config.yaml") -> Dict[str, Any]:
    """Load configuration from YAML file."""
    try:
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        logging.error(f"Configuration file not found: {config_path}")
        sys.exit(1)
    except yaml.YAMLError as e:
        logging.error(f"Error parsing configuration: {e}")
        sys.exit(1)

def check_disk_space(path: str, required_gb: int) -> bool:
    """Check if there's enough disk space."""
    stat = os.statvfs(path)
    free_gb = (stat.f_bavail * stat.f_frsize) / (1024**3)
    logging.info(f"Available disk space: {free_gb:.1f}GB (required: {required_gb}GB)")
    return free_gb >= required_gb

def run_command(cmd: str, check: bool = True, shell: bool = True) -> subprocess.CompletedProcess:
    """Run a system command with logging."""
    logging.info(f"Executing: {cmd}")
    try:
        result = subprocess.run(cmd, shell=shell, check=check, 
                              capture_output=True, text=True)
        if result.stdout:
            logging.debug(f"STDOUT: {result.stdout}")
        return result
    except subprocess.CalledProcessError as e:
        logging.error(f"Command failed: {cmd}")
        logging.error(f"Error: {e.stderr}")
        raise

def verify_checksum(file_path: str, checksum_path: str) -> bool:
    """Verify file checksum."""
    try:
        with open(checksum_path, 'r') as f:
            expected_hash = f.read().split()[0].strip()
        
        with open(file_path, 'rb') as f:
            file_hash = hashlib.md5(f.read()).hexdigest()
        
        match = file_hash == expected_hash
        logging.info(f"Checksum verification: {'PASSED' if match else 'FAILED'}")
        return match
    except Exception as e:
        logging.error(f"Checksum verification failed: {e}")
        return False

def download_file(url: str, dest_path: str, resume: bool = True) -> bool:
    """Download file with progress and resume capability."""
    dest_path = Path(dest_path)
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    
    headers = {}
    mode = 'wb'
    
    if resume and dest_path.exists():
        headers['Range'] = f'bytes={dest_path.stat().st_size}-'
        mode = 'ab'
        logging.info(f"Resuming download from {dest_path.stat().st_size} bytes")
    
    try:
        response = requests.get(url, headers=headers, stream=True)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        downloaded = dest_path.stat().st_size if mode == 'ab' else 0
        
        with open(dest_path, mode) as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    
                    # Simple progress indicator
                    if total_size > 0:
                        percent = (downloaded / total_size) * 100
                        if downloaded % (1024*1024*10) == 0:  # Every 10MB
                            logging.info(f"Downloaded: {percent:.1f}%")
        
        logging.info(f"Download completed: {dest_path}")
        return True
        
    except Exception as e:
        logging.error(f"Download failed: {e}")
        return False
