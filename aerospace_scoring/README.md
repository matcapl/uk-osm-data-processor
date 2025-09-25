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
   uv run aerospace_scoring/load_schema.py
   ```

2. **Generate exclusion filters:**
   ```bash
   uv run aerospace_scoring/generate_exclusions.py
   ```

3. **Generate scoring rules:**
   ```bash
   uv run aerospace_scoring/generate_scoring.py
   ```

4. **Assemble complete SQL:**
   ```bash
   uv run aerospace_scoring/assemble_sql.py
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
