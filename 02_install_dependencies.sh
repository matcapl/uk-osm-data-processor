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
