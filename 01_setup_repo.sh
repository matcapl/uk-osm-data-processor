#!/bin/bash
# ========================================
# UK OSM Import Automation - Phase 1: Setup
# File: 01_setup_repo.sh
# ========================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== UK OSM Import Automation - Phase 1: Repository Setup ===${NC}"

# Check if we're in the right environment
if ! command -v uv &> /dev/null; then
    echo -e "${RED}Error: uv is not installed. Please install uv first.${NC}"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed. Please install gh first.${NC}"
    exit 1
fi

# Create project directory
PROJECT_NAME="uk-osm-data-processor"
echo -e "${YELLOW}Creating project directory: $PROJECT_NAME${NC}"

if [ -d "$PROJECT_NAME" ]; then
    echo -e "${YELLOW}Directory $PROJECT_NAME already exists. Continuing...${NC}"
    cd "$PROJECT_NAME"
else
    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"
fi

# Initialize git repository
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}Initializing git repository...${NC}"
    git init
else
    echo -e "${YELLOW}Git repository already exists. Continuing...${NC}"
fi

# Create Python project with uv
echo -e "${YELLOW}Setting up Python project with uv...${NC}"
if [ ! -f "pyproject.toml" ]; then
    uv init --name uk-osm-processor --python 3.11
fi

# Add required dependencies
echo -e "${YELLOW}Adding Python dependencies...${NC}"
uv add psycopg2-binary sqlalchemy geoalchemy2 osmium requests beautifulsoup4 pandas geopandas

# Create project structure
echo -e "${YELLOW}Creating project structure...${NC}"
mkdir -p {data,scripts,sql,logs,config,docs}
mkdir -p data/{raw,processed,samples}
mkdir -p scripts/{download,import,verify,utils}

# Create main configuration file
cat > config/config.yaml << 'EOF'
# UK OSM Data Processor Configuration

database:
  name: uk_osm_full
  user: ukosm_user
  password: ""  # Leave empty for peer authentication
  host: localhost
  port: 5432
  schema: osm_raw

download:
  source_url: https://download.geofabrik.de/europe/great-britain-latest.osm.pbf
  checksum_url: https://download.geofabrik.de/europe/great-britain-latest.osm.pbf.md5
  data_dir: ./data/raw
  
import:
  cache_size_mb: 2048
  num_processes: 4
  style_file: ./config/uk_full_retention.style
  
system:
  min_free_space_gb: 100
  temp_dir: ./tmp
  log_level: INFO
EOF

# Create requirements file for non-uv systems
cat > requirements.txt << 'EOF'
psycopg2-binary==2.9.7
sqlalchemy==2.0.23
geoalchemy2==0.14.2
osmium==3.6.0
requests==2.31.0
beautifulsoup4==4.12.2
pandas==2.1.3
geopandas==0.14.1
pyyaml==6.0.1
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
# Data files
data/raw/*.pbf
data/raw/*.osm
data/raw/*.xml
data/processed/
*.sqlite
*.db

# Logs
logs/*.log
*.log

# Temporary files
tmp/
temp/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
*.so

# Virtual environments
venv/
env/
.env
.venv

# OS files
.DS_Store
Thumbs.db

# IDE files
.vscode/settings.json
.idea/

# Backup files
*.bak
*~

# PostgreSQL
*.sql.backup
EOF

# Create README
cat > README.md << 'EOF'
# UK OSM Data Processor

Automated pipeline for downloading, processing, and importing complete UK OpenStreetMap data into PostgreSQL/PostGIS.

## Features

- Complete UK OSM data download and validation
- Full data retention (no data loss during import)
- PostgreSQL/PostGIS database setup and optimization
- Automated verification and quality checks
- Modular, scriptable approach for reproducibility

## Quick Start

1. **Setup Repository and Environment**
   ```bash
   ./01_setup_repo.sh
   ```

2. **Install System Dependencies**
   ```bash
   ./02_install_dependencies.sh
   ```

3. **Download OSM Data**
   ```bash
   ./03_download_data.sh
   ```

4. **Setup Database**
   ```bash
   ./04_setup_database.sh
   ```

5. **Import Data**
   ```bash
   ./05_import_data.sh
   ```

6. **Verify Import**
   ```bash
   ./06_verify_import.sh
   ```

## System Requirements

- **Storage**: 100GB+ free space
- **RAM**: 8GB minimum (16GB+ recommended)
- **OS**: Linux, macOS, or Windows WSL2
- **PostgreSQL**: 12+ with PostGIS extension

## Data Coverage

- Complete UK OpenStreetMap data
- All amenities, buildings, landuse, transport infrastructure
- Business sites, industrial areas, commercial locations
- Points of interest, administrative boundaries
- Full tag preservation using hstore

## License

This project is licensed under the MIT License. OSM data is licensed under ODbL.
EOF

# Create main Python utility module
cat > scripts/utils/osm_utils.py << 'EOF'
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
EOF

# Create GitHub repository
echo -e "${YELLOW}Creating GitHub repository...${NC}"
read -p "Enter your GitHub username: " GITHUB_USER
read -p "Create public repository? (y/N): " CREATE_PUBLIC

if [[ $CREATE_PUBLIC == "y" || $CREATE_PUBLIC == "Y" ]]; then
    VISIBILITY="--public"
else
    VISIBILITY="--private"
fi

# Check if repository already exists
if gh repo view "$GITHUB_USER/$PROJECT_NAME" &> /dev/null; then
    echo -e "${YELLOW}Repository already exists on GitHub. Continuing...${NC}"
else
    gh repo create "$PROJECT_NAME" $VISIBILITY --description "UK OSM Data Processor - Automated pipeline for OpenStreetMap data"
fi

# Create initial commit
echo -e "${YELLOW}Creating initial commit...${NC}"
git add .
git commit -m "Initial project setup with automation scripts" || echo "Nothing to commit"

# Set up remote
if ! git remote get-url origin &> /dev/null; then
    git remote add origin "https://github.com/$GITHUB_USER/$PROJECT_NAME.git"
fi

git branch -M main
git push -u origin main

# Create the next phase script
cat > 02_install_dependencies.sh << 'EOF'
#!/bin/bash
# ========================================
# UK OSM Import Automation - Phase 2: Dependencies
# File: 02_install_dependencies.sh
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== UK OSM Import Automation - Phase 2: System Dependencies ===${NC}"

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &> /dev/null; then
        OS="ubuntu"
    elif command -v yum &> /dev/null; then
        OS="redhat"
    else
        echo -e "${RED}Unsupported Linux distribution${NC}"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo -e "${RED}Unsupported operating system: $OSTYPE${NC}"
    exit 1
fi

echo -e "${YELLOW}Detected OS: $OS${NC}"

# Function to install packages based on OS
install_dependencies() {
    case $OS in
        "ubuntu")
            echo -e "${YELLOW}Installing Ubuntu/Debian dependencies...${NC}"
            sudo apt-get update
            sudo apt-get install -y \
                postgresql postgresql-contrib \
                postgis postgresql-postgis \
                osm2pgsql osmium-tool \
                wget curl git \
                python3 python3-pip \
                build-essential \
                libpq-dev
            ;;
        "macos")
            echo -e "${YELLOW}Installing macOS dependencies...${NC}"
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}Homebrew is required. Installing...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew update
            brew install postgresql postgis osm2pgsql osmium-tool wget
            brew services start postgresql
            ;;
        "redhat")
            echo -e "${YELLOW}Installing RedHat/CentOS dependencies...${NC}"
            sudo yum update -y
            sudo yum install -y \
                postgresql postgresql-server postgresql-contrib \
                postgis \
                wget curl git \
                python3 python3-pip \
                gcc gcc-c++ make \
                postgresql-devel
            
            # Install osm2pgsql and osmium from EPEL or compile
            sudo yum install -y epel-release
            sudo yum install -y osm2pgsql
            ;;
    esac
}

# Check system requirements
echo -e "${YELLOW}Checking system requirements...${NC}"

# Check available disk space
AVAILABLE_SPACE_GB=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
if [[ $AVAILABLE_SPACE_GB -lt 100 ]]; then
    echo -e "${RED}Warning: Less than 100GB available space. Current: ${AVAILABLE_SPACE_GB}GB${NC}"
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ $CONTINUE != "y" && $CONTINUE != "Y" ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}Disk space check: ${AVAILABLE_SPACE_GB}GB available${NC}"
fi

# Check RAM
TOTAL_RAM_GB=$(free -g | grep '^Mem:' | awk '{print $2}' 2>/dev/null || sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024/1024)}' || echo "unknown")
if [[ $TOTAL_RAM_GB != "unknown" && $TOTAL_RAM_GB -lt 8 ]]; then
    echo -e "${YELLOW}Warning: Less than 8GB RAM detected. Current: ${TOTAL_RAM_GB}GB${NC}"
    echo -e "${YELLOW}Import process may be slower and require reduced cache settings.${NC}"
fi

# Install dependencies
read -p "Install system dependencies? This requires sudo privileges. (Y/n): " INSTALL_DEPS
if [[ $INSTALL_DEPS != "n" && $INSTALL_DEPS != "N" ]]; then
    install_dependencies
else
    echo -e "${YELLOW}Skipping system dependency installation.${NC}"
fi

# Setup Python environment
echo -e "${YELLOW}Setting up Python environment with uv...${NC}"
uv sync

# Verify installations
echo -e "${YELLOW}Verifying installations...${NC}"

REQUIRED_COMMANDS=("psql" "osm2pgsql" "osmium" "wget" "curl")
MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_COMMANDS+=($cmd)
    else
        echo -e "${GREEN}✓ $cmd found${NC}"
    fi
done

if [[ ${#MISSING_COMMANDS[@]} -gt 0 ]]; then
    echo -e "${RED}Missing required commands: ${MISSING_COMMANDS[*]}${NC}"
    echo -e "${RED}Please install missing dependencies manually.${NC}"
    exit 1
fi

# PostgreSQL setup
echo -e "${YELLOW}Setting up PostgreSQL...${NC}"

case $OS in
    "ubuntu")
        sudo systemctl enable postgresql
        sudo systemctl start postgresql
        ;;
    "macos")
        brew services start postgresql || true
        ;;
    "redhat")
        sudo postgresql-setup initdb || true
        sudo systemctl enable postgresql
        sudo systemctl start postgresql
        ;;
esac

# Wait for PostgreSQL to start
sleep 3

# Test PostgreSQL connection
if sudo -u postgres psql -c "SELECT version();" &> /dev/null; then
    echo -e "${GREEN}✓ PostgreSQL is running${NC}"
else
    echo -e "${RED}✗ PostgreSQL connection failed${NC}"
    echo -e "${YELLOW}Please check PostgreSQL installation and start the service manually.${NC}"
fi

echo -e "${GREEN}=== Phase 2 Complete: Dependencies Installed ===${NC}"
echo -e "${YELLOW}Next step: Run ./03_download_data.sh${NC}"
EOF

chmod +x 02_install_dependencies.sh

echo -e "${GREEN}=== Phase 1 Complete: Repository Setup ===${NC}"
echo -e "${YELLOW}Repository created at: $(pwd)${NC}"
echo -e "${YELLOW}Next step: Run ./02_install_dependencies.sh${NC}"

# Create a summary of what was created
cat > SETUP_SUMMARY.md << 'EOF'
# Setup Summary

## Files Created:
- `01_setup_repo.sh` - Initial repository setup (completed)
- `02_install_dependencies.sh` - System dependencies installation
- `config/config.yaml` - Main configuration
- `scripts/utils/osm_utils.py` - Python utilities
- `README.md` - Project documentation
- `.gitignore` - Git ignore rules
- `pyproject.toml` - Python project configuration

## Directory Structure:
```
uk-osm-data-processor/
├── config/
├── data/raw/
├── data/processed/
├── data/samples/
├── scripts/
│   ├── download/
│   ├── import/
│   ├── verify/
│   └── utils/
├── sql/
├── logs/
└── docs/
```

## Next Steps:
1. Run `./02_install_dependencies.sh` to install system dependencies
2. Additional scripts will be created in the next phases

## GitHub Repository:
- Repository created and initial code pushed
- Ready for collaborative development
EOF

echo -e "${GREEN}Setup complete! Check SETUP_SUMMARY.md for details.${NC}"