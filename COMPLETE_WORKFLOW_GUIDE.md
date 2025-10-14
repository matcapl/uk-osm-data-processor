# Complete Aerospace Scoring Workflow Guide

## 🎯 Your Mission
Identify Tier-2 aerospace suppliers in the UK using OpenStreetMap data with world-class accuracy.

---

## 📊 Current Status (As of Your Last Run)

✅ **Working:**
- Pipeline infrastructure complete
- Polygon scoring: **1,569 candidates** (133 Tier 1, 254 Tier 2)
- Full UK dataset: **41M records** in 47GB database
- Scoring system functional

🔧 **Next Steps:**
- Run point/line/roads pipelines
- Validate results
- Iterate to improve accuracy

---

## 🚀 Quick Start (Today)

### 1. Complete the Pipeline (15 mins)
```bash
# Run remaining geometry types
bash 07_pipeline_point.sh      # ~5 mins, expect 500-2000 candidates
bash 07_pipeline_line.sh       # ~3 mins, expect 100-500 candidates
bash 07_pipeline_roads.sh      # ~2 mins, expect 50-200 candidates

# Create unified table
psql -d uk_osm_full -f create_final_table.sql

# Export results
bash 08_export_results.sh
```

**Expected outcome:** ~2,500-4,500 total candidates across all geometries.

### 2. Quick Validation (30 mins)
```bash
# Generate validation sample
bash validation_and_refinement_workflow.sh

# Open the CSV file it creates
open exports/validation_sample_*.csv
```

**Manual task:** For 30 random candidates, check:
- Google the company name
- Visit website if available
- LinkedIn search
- Mark: YES (aerospace) / NO (not aerospace) / MAYBE (unclear)

**Calculate precision:**
```
Precision = YES_count / Total_validated
Target: >70% for Tier 2, >90% for Tier 1
```

---

## 📈 Weekly Improvement Cycle

### Week 1: Baseline + Validation
**Day 1-2: Run & Export**
```bash
bash 07_run_all_pipelines.sh
bash 08_export_results.sh
```

**Day 3-4: Validate**
- Manually verify 50 Tier 1 candidates
- Manually verify 50 Tier 2 candidates
- Document false positives/negatives

**Day 5: Analyze**
```bash
bash iterative_improvement.sh
# Review: iterations/[DATE]/recommendations.md
```

### Week 2: Refine Keywords
**Update `enhanced_scoring_v2.yaml`:**

1. **Add True Positives** (companies you verified):
```yaml
known_tier2:
  weight: 150
  patterns:
    - 'verified_company_name_1'
    - 'verified_company_name_2'
```

2. **Add Negative Filters** (false positives):
```yaml
strong_negatives:
  consumer_businesses:
    weight: -200
    conditions:
      - name_contains: ['word_that_appeared_in_false_positives']
```

3. **Re-run pipeline:**
```bash
bash 07_run_all_pipelines.sh
bash iterative_improvement.sh  # Compare to previous
```

### Week 3: Geographic Refinement
**Review regional performance:**
```sql
-- Run this in psql
SELECT 
  LEFT(postcode, 2) as region,
  COUNT(*) as candidates,
  ROUND(AVG(aerospace_score)) as avg_score,
  COUNT(*) FILTER (WHERE website IS NOT NULL) as with_website
FROM aerospace_supplier_candidates
WHERE postcode IS NOT NULL
GROUP BY region
ORDER BY candidates DESC;
```

**Adjust bonuses:**
- High-scoring regions with few candidates → **Increase bonus**
- Low-scoring regions with many candidates → **Review if appropriate**

### Week 4: External Data Integration
**Add Companies House data:**
1. Download UK company data (free from Companies House)
2. Filter for SIC codes: 30300 (aircraft manufacturing), 25620 (machining)
3. Cross-reference with your candidates by postcode
4. Boost scores for matches

---

## 🎯 Precision Targets by Tier

| Tier | Precision Target | Recall Target | Notes |
|------|------------------|---------------|-------|
| **Tier 1** (≥150) | **90%+** | 70%+ | High confidence - ready for outreach |
| **Tier 2** (80-149) | **70%+** | 80%+ | Main target - balance precision/recall |
| **Potential** (40-79) | **40%+** | 90%+ | Needs further research |

**How to measure:**
```bash
# Export sample for validation
psql -d uk_osm_full -c "
  SELECT * FROM aerospace_supplier_candidates
  WHERE tier_classification = 'tier2_candidate'
  ORDER BY RANDOM()
  LIMIT 100;
" -o tier2_sample.txt

# Manually validate → Calculate precision
```

---

## 🔬 Advanced Techniques

### 1. Certification Detection (High Signal!)
**Add to scoring if you can scrape websites:**
```yaml
quality_standards:
  aerospace_certifications:  # +70 points
    weight: 70
    patterns:
      - 'as9100'
      - 'nadcap'
      - 'easa part 21'
```

**How to get this data:**
1. Export candidates with websites
2. Use web scraping (BeautifulSoup/Scrapy)
3. Search for certifications on their pages
4. Add as tags back into database

### 2. Proximity Scoring
**Facilities near aerospace hubs score higher:**
```sql
-- Add this to your scoring query
+ CASE WHEN EXISTS (
    SELECT 1 FROM planet_osm_point airports
    WHERE airports.aeroway = 'aerodrome'
    AND ST_DWithin(way, airports.way, 10000)  -- 10km
  ) THEN 30 ELSE 0 END
```

### 3. Supply Chain Network
**Co-location bonus:**
```sql
-- Facilities in same industrial estate as known Tier 1
+ CASE WHEN EXISTS (
    SELECT 1 FROM aerospace_supplier_candidates known
    WHERE known.tier_classification = 'tier1_candidate'
    AND LEFT(postcode, 4) = LEFT(known.postcode, 4)
  ) THEN 25 ELSE 0 END
```

### 4. Machine Learning (Advanced)
**If you have training data:**

```python
import pandas as pd
from sklearn.ensemble import RandomForestClassifier

# Load validated data
df = pd.read_csv('validated_candidates.csv')

# Features
features = [
    'has_aerospace_keyword',
    'has_precision_keyword',
    'building_area',
    'in_aerospace_cluster',
    'has_website',
    'name_word_count'
]

# Train
X = df[features]
y = df['is_aerospace_supplier']  # Manual validation results
model = RandomForestClassifier()
model.fit(X, y)

# Predict
predictions = model.predict_proba(new_candidates)
```

---

## 📝 Quality Checklist

Before declaring success, verify:

- [ ] **Coverage:** Found >70% of known major suppliers (run `known_suppliers_check.sql`)
- [ ] **Precision:** Tier 1 >90%, Tier 2 >70% (manual validation)
- [ ] **Geographic:** All major aerospace regions represented (BS, GL, DE, PR, etc.)
- [ ] **False Positives:** <5% obvious non-aerospace (cafes, shops, etc.)
- [ ] **Completeness:** Contact info for >30% of Tier 2 candidates
- [ ] **Documentation:** All scoring rules documented and justified

---

## 🗂️ File Organization

```
uk-osm-data-processor/
├── 07_pipeline_polygon.sh          # Geometry-specific pipelines
├── 07_pipeline_point.sh
├── 07_pipeline_line.sh
├── 07_pipeline_roads.sh
├── 07_run_all_pipelines.sh         # Master runner
├── 08_export_results.sh            # Export to CSV
├── create_final_table.sql          # Union all geometries
├── validation_and_refinement_workflow.sh  # Validation tools
├── iterative_improvement.sh        # Improvement loop
├── known_suppliers_check.sql       # Coverage analysis
├── diagnose_pipeline.sql           # Debugging
├── enhanced_scoring_v2.yaml        # Enhanced config
│
├── exports/                         # CSV exports
│   ├── all_candidates_*.csv
│   ├── tier1_candidates_*.csv
│   ├── tier2_candidates_*.csv
│   └── validation_sample_*.csv
│
├── iterations/                      # Improvement tracking
│   ├── 20250108_120000/
│   │   ├── baseline_metrics.txt
│   │   ├── recommendations.md
│   │   └── full_results.csv
│   └── 20250115_120000/
│       └── ...
│
└── reports/                         # Analysis reports
    └── import_verification.json
```

---

## 🚨 Common Issues & Fixes

### Issue: Getting 0 candidates
**Diagnosis:**
```bash
psql -d uk_osm_full -f diagnose_pipeline.sql
```

**Common causes:**
1. Views created but INSERT failed → Run `create_final_table.sql`
2. Scoring too strict → Check `aerospace_score` column in views
3. Exclusions too aggressive → Review filtered views

### Issue: Too many false positives
**Fix:**
1. Strengthen negative filters
2. Add required fields (must have industrial classification)
3. Increase minimum thresholds

### Issue: Missing known suppliers
**Fix:**
1. Check if they're in OSM (may not be!)
2. Review their typical naming patterns
3. Add company-specific patterns to scoring
4. Check if filtered out by exclusions

### Issue: Scores too low/high across board
**Fix:**
```sql
-- Analyze score distribution
SELECT 
  MIN(aerospace_score),
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY aerospace_score),
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY aerospace_score),
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY aerospace_score),
  MAX(aerospace_score)
FROM aerospace_supplier_candidates;
```

Adjust weights in `enhanced_scoring_v2.yaml` accordingly.

---

## 💡 Pro Tips

### 1. Start Conservative, Expand Gradually
- Begin with strict thresholds (high precision)
- Validate thoroughly
- Gradually lower thresholds to capture more (increase recall)

### 2. Domain Expert Review
- Share top 100 with someone in aerospace industry
- Get feedback on false positives/negatives
- Use their insights to refine keywords

### 3. Keyword Research
Visit websites of known Tier-2 suppliers and note:
- How they describe themselves
- Technical terms they use
- Certifications they mention
- Industries they serve

### 4. Postcode Clustering
```sql
-- Find aerospace "hotspots"
SELECT 
  LEFT(postcode, 4) as area,
  COUNT(*) as density,
  string_agg(DISTINCT name, '; ') as companies
FROM aerospace_supplier_candidates
WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
  AND postcode IS NOT NULL
GROUP BY area
HAVING COUNT(*) >= 3
ORDER BY density DESC;
```

Use these hotspots to boost nearby facilities.

### 5. Historical Comparison
Keep exports from each iteration:
```bash
cp exports/all_candidates_*.csv "archives/candidates_$(date +%Y%m%d).csv"
```

Track improvement over time:
- Candidate count changes
- Score distributions
- Geographic spread

---

## 🎓 Learning Resources

### UK Aerospace Industry
- **ADS Group**: UK aerospace trade association ([adsgroup.org.uk](https://www.adsgroup.org.uk))
- **SC21**: Supply chain program ([sc21.org.uk](https://www.sc21.org.uk))
- **Aerospace Growth Partnership**: Industry strategy

### OpenStreetMap
- **Taginfo**: See how tags are used ([taginfo.openstreetmap.org](https://taginfo.openstreetmap.org))
- **OSM Wiki**: Tag documentation ([wiki.openstreetmap.org](https://wiki.openstreetmap.org))

### Scoring Techniques
- **Information Retrieval**: TF-IDF, BM25 for text scoring
- **Named Entity Recognition**: Identify company types
- **Graph Analysis**: Supply chain networks

---

## 📊 Success Metrics Dashboard

Track these KPIs weekly:

```sql
-- Save as dashboard.sql
\echo '=== WEEKLY DASHBOARD ==='
\echo ''

SELECT 'Total Candidates' as metric, COUNT(*)::text as value
FROM aerospace_supplier_candidates
UNION ALL
SELECT 'Tier 1', COUNT(*)::text
FROM aerospace_supplier_candidates WHERE tier_classification = 'tier1_candidate'
UNION ALL
SELECT 'Tier 2', COUNT(*)::text
FROM aerospace_supplier_candidates WHERE tier_classification = 'tier2_candidate'
UNION ALL
SELECT 'With Contact', COUNT(*)::text
FROM aerospace_supplier_candidates WHERE website IS NOT NULL OR phone IS NOT NULL
UNION ALL
SELECT 'Avg Score', ROUND(AVG(aerospace_score))::text
FROM aerospace_supplier_candidates
UNION ALL
SELECT 'Regions Covered', COUNT(DISTINCT LEFT(postcode, 2))::text
FROM aerospace_supplier_candidates WHERE postcode IS NOT NULL;
```

---

## 🎯 Endgame: World-Class System

You'll know you've achieved world-class when:

1. **Precision >80%** for Tier 2 (validated manually)
2. **Recall >75%** of known suppliers (from ADS list)
3. **Coverage** across all major UK aerospace regions
4. **Reproducible** - documented, automated, version controlled
5. **Maintained** - regular updates as OSM data changes
6. **Actionable** - results directly usable for business outreach

**Your current system is already ~70% there!** With the validation loop and iterative refinement, you'll hit world-class in 4-6 weeks.

---

## 🚀 Final Checklist

Today:
- [ ] Run all four pipelines
- [ ] Create final unified table
- [ ] Export results
- [ ] Validate 20-30 samples manually

This Week:
- [ ] Run validation workflow
- [ ] Analyze false positives
- [ ] Update scoring YAML
- [ ] Re-run and compare

This Month:
- [ ] Build authoritative known-supplier list
- [ ] Integrate Companies House data
- [ ] Add certification detection
- [ ] Achieve 75%+ precision on Tier 2

**You're on track for an excellent system. Keep iterating!** 🎯