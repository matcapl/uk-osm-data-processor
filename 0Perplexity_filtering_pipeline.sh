#!/usr/bin/env bash
set -euo pipefail

# 07_run_aerospace_pipeline.sh
# Full end-to-end aerospace scoring pipeline

# Move into the aerospace_scoring directory
cd aerospace_scoring

# Step 1: Generate schema.json
echo "1. Inspecting schema..."
uv run load_schema.py

# Step 2: Generate exclusions.sql
echo "2. Generating exclusions..."
uv run generate_exclusions.py

# Step 3: Generate scoring.sql
echo "3. Generating scoring..."
uv run generate_scoring.py

# Step 4: Assemble complete SQL
echo "4. Assembling complete SQL..."
uv run assemble_sql.py

# Back to repo root
cd ..

# Step 5: Execute SQL against database
echo "5. Executing complete SQL..."
psql -d uk_osm_full -c "SET search_path = public;"
psql -d uk_osm_full -f aerospace_scoring/compute_aerospace_complete.sql

echo "✅ Aerospace scoring pipeline complete."
