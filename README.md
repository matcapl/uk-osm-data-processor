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
