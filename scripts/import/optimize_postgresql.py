#!/usr/bin/env python3
"""
PostgreSQL Configuration Optimizer for OSM Import
"""

import sys
import os
import subprocess
import platform
sys.path.append('scripts/utils')

from osm_utils import setup_logging, run_command
import logging

def get_system_info():
    """Get system information for optimization."""
    try:
        # Get total RAM
        if platform.system() == "Linux":
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if 'MemTotal:' in line:
                        total_ram_kb = int(line.split()[1])
                        total_ram_gb = total_ram_kb // (1024 * 1024)
                        break
        elif platform.system() == "Darwin":  # macOS
            result = run_command("sysctl -n hw.memsize")
            total_ram_gb = int(result.stdout.strip()) // (1024**3)
        else:
            total_ram_gb = 8  # Default assumption
        
        # Get CPU cores
        cpu_cores = os.cpu_count() or 4
        
        return total_ram_gb, cpu_cores
        
    except Exception as e:
        logging.warning(f"Could not detect system specs: {e}")
        return 8, 4  # Safe defaults

def generate_postgresql_conf(total_ram_gb, cpu_cores):
    """Generate optimized PostgreSQL configuration."""
    
    # Calculate optimal settings based on system resources
    shared_buffers_gb = max(1, min(total_ram_gb // 4, 8))  # 25% of RAM, max 8GB
    work_mem_mb = max(64, min(total_ram_gb * 1024 // 32, 512))  # Conservative work_mem
    maintenance_work_mem_gb = max(1, min(total_ram_gb // 2, 4))  # Up to 4GB
    effective_cache_size_gb = max(2, total_ram_gb * 3 // 4)  # 75% of RAM
    
    config = f"""
# PostgreSQL Configuration Optimized for OSM Import
# Generated automatically - backup your original postgresql.conf first

# Memory Settings
shared_buffers = {shared_buffers_gb}GB
work_mem = {work_mem_mb}MB
maintenance_work_mem = {maintenance_work_mem_gb}GB
effective_cache_size = {effective_cache_size_gb}GB

# Checkpoint and WAL Settings
checkpoint_completion_target = 0.9
checkpoint_timeout = 15min
max_wal_size = 4GB
min_wal_size = 1GB
wal_buffers = 16MB

# Connection Settings
max_connections = 100

# Query Planner Settings
random_page_cost = 1.1
effective_io_concurrency = {min(cpu_cores * 2, 200)}

# Logging (optional - for debugging)
log_min_duration_statement = 1000
log_checkpoints = on
log_lock_waits = on

# Background Writer
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0

# Vacuum and Analyze
autovacuum = on
autovacuum_max_workers = {max(2, cpu_cores // 2)}
autovacuum_naptime = 30s
"""
    
    return config

def find_postgresql_config():
    """Find PostgreSQL configuration file location."""
    try:
        # Try to find config through PostgreSQL (macOS approach)
        result = run_command("psql -c 'SHOW config_file;' -t postgres")
        config_path = result.stdout.strip()
        if os.path.exists(config_path):
            return config_path
    except:
        pass
    
    # Common macOS locations (prioritized for macOS)
    common_paths = [
        '/opt/homebrew/var/postgres/postgresql.conf',  # Apple Silicon Homebrew
        '/usr/local/var/postgres/postgresql.conf',     # Intel Homebrew
        '/opt/homebrew/var/postgresql@*/postgresql.conf',  # Specific versions
        '/usr/local/var/postgresql@*/postgresql.conf',
        '/etc/postgresql/*/main/postgresql.conf',      # Linux fallback
        '/var/lib/pgsql/data/postgresql.conf'          # Linux fallback
    ]
    
    import glob
    for pattern in common_paths:
        matches = glob.glob(pattern)
        if matches:
            return matches[0]
    
    return None

def main():
    setup_logging()
    
    total_ram_gb, cpu_cores = get_system_info()
    logging.info(f"System detected: {total_ram_gb}GB RAM, {cpu_cores} CPU cores")
    
    config_content = generate_postgresql_conf(total_ram_gb, cpu_cores)
    
    # Save optimized configuration
    config_path = "config/postgresql_optimized.conf"
    with open(config_path, 'w') as f:
        f.write(config_content)
    
    logging.info(f"Generated optimized configuration: {config_path}")
    
    # Try to find actual PostgreSQL config
    pg_config_path = find_postgresql_config()
    if pg_config_path:
        logging.info(f"PostgreSQL config found at: {pg_config_path}")
        print(f"""
To apply these optimizations:

1. Backup current config:
   sudo cp {pg_config_path} {pg_config_path}.backup

2. Apply optimizations (choose one):
   
   Option A - Append to existing config:
   sudo cat {config_path} >> {pg_config_path}
   
   Option B - Manual edit:
   sudo nano {pg_config_path}
   (Copy settings from {config_path})

3. Restart PostgreSQL:
   sudo systemctl restart postgresql

Note: These settings are optimized for import operations.
Consider reverting to more conservative settings after import.
        """)
    else:
        logging.warning("Could not locate PostgreSQL configuration file")
        print(f"Generated optimized settings in: {config_path}")
        print("Please manually apply these settings to your postgresql.conf file")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
