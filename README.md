### Needs to be updated for 07_aerospace_pipeline.sh

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

--

# UK Aerospace Supplier Scoring System

This system analyzes UK OpenStreetMap data to identify potential Tier-2 aerospace suppliers.

## Quick Start

**Prerequisites:**
- UK OSM database imported (from previous steps)
- Python 3 with psycopg2, pyyaml

**Run the complete system:**
```bash
python3 aerospace_scoring/run_aerospace_scoring.py
```

## Manual Steps (if needed)

1. **Analyze database schema:**
   ```bash
   python3 aerospace_scoring/load_schema.py
   ```

2. **Generate exclusion filters:**
   ```bash
   python3 aerospace_scoring/generate_exclusions.py
   ```

3. **Generate scoring rules:**
   ```bash
   python3 aerospace_scoring/generate_scoring.py
   ```

4. **Assemble complete SQL:**
   ```bash
   python3 aerospace_scoring/assemble_sql.py
   ```

5. **Execute the scoring:**
   ```bash
   psql -d uk_osm_full -f aerospace_scoring/compute_aerospace_scores.sql
   ```

## Configuration Files

All scoring rules are in YAML files and can be edited without code changes:

- **exclusions.yaml**: Filters out non-aerospace features
- **scoring.yaml**: Positive scoring rules for aerospace relevance  
- **negative_signals.yaml**: Negative scoring penalties
- **thresholds.yaml**: Classification tiers and limits
- **seed_columns.yaml**: Output table structure

## Results

The system creates a table `aerospace_supplier_candidates` with:
- Tier-1 candidates (score ≥150): Direct aerospace indicators
- Tier-2 candidates (score 80-149): Strong manufacturing + aerospace keywords  
- Potential candidates (score 40-79): Industrial with some relevance
- Geographic data, contact information, confidence levels

## Sample Queries

```sql
-- Top tier-2 candidates
SELECT name, aerospace_score, postcode, website
FROM aerospace_supplier_candidates 
WHERE tier_classification = 'tier2_candidate'
ORDER BY aerospace_score DESC;

-- Candidates by region
SELECT LEFT(postcode,2) as area, COUNT(*), AVG(aerospace_score)
FROM aerospace_supplier_candidates
WHERE postcode IS NOT NULL
GROUP BY LEFT(postcode,2)
ORDER BY COUNT(*) DESC;

-- High-confidence candidates with contact info
SELECT name, aerospace_score, website, phone, city
FROM aerospace_supplier_candidates
WHERE confidence_level = 'high' AND (website IS NOT NULL OR phone IS NOT NULL);
```

# Repository Flow: 07_ Pipeline & Aerospace Scoring

## 1. 07_aerospace_pipeline.sh  
This shell script bootstraps the end-to-end data pipeline against your UK OSM database. Its main stages:  
1. **Environment Setup**  
   - Loads environment variables, PostgreSQL connection parameters, and `uv` task runner.  
2. **Exclusions & Filtering**  
   - Invokes SQL scripts or inline psql commands to create *filtered* views (`planet_osm_*_aerospace_filtered`) that drop unwanted amenities, landuses, shops, highways, etc.  
3. **Scoring Views**  
   - Runs psql scripts to generate *scored* views (`planet_osm_*_aerospace_scored`), computing `aerospace_score` via additive keyword and tag weights.  
4. **Assemble & Execute Final SQL**  
   - Concatenates the exclusion and scoring definitions into a single SQL file (`compute_aerospace_scores.sql`).  
   - Creates the final table `aerospace_supplier_candidates`, defines indexes, and inserts candidates.  
5. **Verification Queries**  
   - Executes row-count and tier breakdown queries to log pipeline success and metrics.  

You kick it off with:  
```bash
bash 07_aerospace_pipeline.sh
```
which runs through all the above steps in sequence.

## 2. aerospace_scoring/run_aerospace_scoring.py  
This Python script refactors the same process into modular steps with better logging and error handling:  
1. **Database Connection Check**  
   - Reads `config/config.yaml`, verifies connectivity by querying a small OSM table.  
2. **Schema Analysis, Exclusions, Scoring Generation**  
   - Runs via `uv run` the individual modules:  
     - `load_schema.py` (inspects OSM tables)  
     - `generate_exclusions.py` (builds `exclusions.sql`)  
     - `generate_scoring.py` (builds `scoring.sql`)  
     - `assemble_sql.py`   (writes `compute_aerospace_scores.sql`)  
3. **Debug Dump**  
   - Prints out counts from filtered and scored views to confirm intermediate states.  
4. **SQL Execution**  
   - Executes the assembled SQL file via psql, populating `aerospace_supplier_candidates`.  
5. **Final Verification**  
   - Queries total candidate count and tier breakdown, logging results and exiting with success/failure.

You invoke it as:
```bash
uv run aerospace_scoring/run_aerospace_scoring.py
```

***

**In essence**, `07_aerospace_pipeline.sh` is a monolithic shell orchestrator, while `run_aerospace_scoring.py` decomposes the same logic into Python-driven, `uv`-managed modules with improved observability. Both paths execute the same core steps: filter, score, assemble, insert, and verify.