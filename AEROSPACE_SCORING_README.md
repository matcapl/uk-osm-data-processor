# UK Aerospace Supplier Intelligence System

**World-class scoring and identification of Tier-2 aerospace suppliers from OpenStreetMap data**

## 🎯 What This Does

Automatically identifies and scores UK aerospace suppliers by analyzing 41M OpenStreetMap records, producing a curated list of high-confidence candidates ready for business outreach.

**Current Performance:**
- ✅ 1,500+ candidates identified
- ✅ 130+ Tier 1 (high confidence) suppliers
- ✅ 250+ Tier 2 (target segment) suppliers
- ✅ Geographic coverage across all major UK aerospace clusters

---

## 🚀 Quick Start (5 Minutes)

### Option 1: One-Command Full Run
```bash
# Complete pipeline with all reports
bash aerospace_master_workflow.sh --full
```

### Option 2: Step-by-Step
```bash
# 1. Run scoring pipelines
bash 07_pipeline_polygon.sh   # Buildings/facilities (most important)
bash 07_pipeline_point.sh     # Single locations
bash 07_pipeline_line.sh      # Linear features
bash 07_pipeline_roads.sh     # Named roads/estates

# 2. Create unified table
psql -d uk_osm_full -f create_final_table.sql

# 3. Export & analyze
bash 08_export_results.sh
bash generate_weekly_report.sh
```

### Option 3: Quick Test (Polygons Only)
```bash
bash aerospace_master_workflow.sh --quick
```

---

## 📊 Understanding the Outputs

### Main Database Table
```sql
-- Query your results
psql -d uk_osm_full

SELECT * FROM aerospace_supplier_candidates
WHERE tier_classification = 'tier2_candidate'
ORDER BY aerospace_score DESC
LIMIT 20;
```

### CSV Exports (./exports/)
- `all_candidates_*.csv` - Complete list
- `tier1_candidates_*.csv` - High confidence (≥150 points)
- `tier2_candidates_*.csv` - Main targets (80-149 points)
- `candidates_with_contact_*.csv` - Ready for outreach

### Reports (./reports/)
- `weekly/aerospace_intel_*.md` - Executive summary
- `power_analysis_*.txt` - Detailed analytics
- `import_verification.json` - Data quality metrics

---

## 🎓 How Scoring Works

### Tier Classification

| Tier | Score Range | Confidence | Typical Characteristics |
|------|-------------|------------|------------------------|
| **Tier 1** | 150-300 | Very High | Known aerospace companies, direct keywords, strong signals |
| **Tier 2** | 80-149 | High | Precision manufacturing, aerospace clusters, multiple indicators |
| **Potential** | 40-79 | Medium | Industrial + some aerospace signals, needs validation |

### Signal Sources (Additive Scoring)

**Direct Evidence (+100-200 points):**
- Known aerospace company names (Airbus, Rolls-Royce, BAE, etc.)
- "Aerospace", "aviation", "aircraft" in name/description
- Defense/military facilities

**Strong Indicators (+60-80 points):**
- Precision engineering, CNC machining
- Composite manufacturing, metal finishing
- Industrial classification with aerospace context

**Supporting Evidence (+20-50 points):**
- Geographic clusters (Bristol, Derby, Preston, etc.)
- Large industrial buildings
- Contact information present
- Proximity to airports/aerospace hubs

**Negative Filters (-50 to -200 points):**
- Consumer businesses (cafes, shops, hotels)
- Residential properties
- Clearly non-industrial uses

---

## 🔧 Customization

### Update Scoring Rules

Edit `enhanced_scoring_v2.yaml`:

```yaml
# Add your verified suppliers
known_tier2:
  weight: 150
  patterns:
    - 'your_verified_company'
    
# Strengthen negative filters
strong_negatives:
  consumer_businesses:
    weight: -200
    conditions:
      - name_contains: ['pattern_you_found']
```

Then re-run:
```bash
bash aerospace_master_workflow.sh --full
```

### Adjust Thresholds

In pipeline scripts, modify:
```sql
CASE 
  WHEN aerospace_score >= 150 THEN 'tier1_candidate'  -- Adjust this
  WHEN aerospace_score >= 80 THEN 'tier2_candidate'   -- And this
  ...
```

---

## 📈 Weekly Workflow

### Monday: Run Pipeline
```bash
bash aerospace_master_workflow.sh --full
```

### Tuesday-Wednesday: Validate
1. Open `validation_sample_*.csv`
2. For 30 random candidates:
   - Google the company
   - Visit website
   - Mark YES/NO in spreadsheet
3. Calculate precision: `YES / Total`

### Thursday: Refine
1. Review `iterations/[latest]/recommendations.md`
2. Add verified companies to scoring YAML
3. Update negative filters for false positives
4. Re-run pipeline

### Friday: Report
1. Review `aerospace_intel_*.md`
2. Contact top outreach targets
3. Research missing contact info
4. Plan next week's improvements

---

## 🎯 Quality Targets

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Tier 1 Precision** | >90% | Manually validate 50 random Tier 1 |
| **Tier 2 Precision** | >70% | Manually validate 100 random Tier 2 |
| **Known Supplier Recall** | >75% | Run `known_suppliers_check.sql` |
| **Data Completeness** | >30% with contact | Check reports |

Track weekly in `iterations/` folder.

---

## 🛠️ Troubleshooting

### Problem: Getting 0 candidates
```bash
psql -d uk_osm_full -f diagnose_pipeline.sql
```

**Common causes:**
- Views created but INSERT failed → Run `create_final_table.sql`
- Threshold too high → Lower minimum score in pipelines
- Exclusions too strict → Review filtered view counts

### Problem: Too many false positives
**Solutions:**
1. Strengthen negative keywords
2. Require industrial classification
3. Increase score thresholds
4. Add company name pattern filters

### Problem: Missing known suppliers
**Check:**
1. Are they actually in OSM? (Many aren't!)
2. Do they use different naming?
3. Were they filtered out? Check filtered views
4. Score too low? Review their characteristics

---

## 📚 Documentation

### Core Files
- **COMPLETE_WORKFLOW_GUIDE.md** - Comprehensive usage guide
- **WORLD_CLASS_SCORING_STRATEGY.md** - Scoring methodology & best practices
- **power_user_queries.sql** - Advanced analysis queries
- **diagnose_pipeline.sql** - Debugging toolkit

### Pipeline Scripts
- `07_pipeline_[geometry].sh` - Individual geometry processors
- `07_run_all_pipelines.sh` - Master pipeline runner
- `aerospace_master_workflow.sh` - Complete automation

### Analysis Tools
- `validation_and_refinement_workflow.sh` - Quality validation
- `iterative_improvement.sh` - Improvement tracking
- `known_suppliers_check.sql` - Coverage analysis
- `generate_weekly_report.sh` - Intelligence reports

---

## 💡 Pro Tips

### 1. Start Conservative
- Begin with high thresholds (Tier 2 ≥ 100)
- Validate thoroughly
- Gradually lower to capture more

### 2. Build a Known List
Maintain `known_suppliers.txt` with verified aerospace companies:
```
Airbus UK, Bristol, BS34
GKN Aerospace, Redditch, B98
Meggitt PLC, Coventry, CV3
```

Update `known_suppliers_check.sql` regularly.

### 3. Geographic Intelligence
Focus on proven clusters:
- **Bristol/Filton (BS/GL)** - Airbus, Rolls-Royce
- **Derby (DE)** - Rolls-Royce
- **Preston (PR)** - BAE Systems
- **Yeovil (BA)** - Leonardo
- **Cambridge (CB)** - High-tech aerospace

### 4. Certification Keywords
If you can scrape websites, look for:
- AS9100 (aerospace quality standard)
- NADCAP (aerospace processes)
- EASA Part 21 (design/production)

These are VERY high-signal indicators.

### 5. Supply Chain Clustering
Companies in same industrial estate = high probability both aerospace:
```sql
SELECT * FROM aerospace_supplier_candidates
WHERE LEFT(postcode, 4) IN (
  SELECT LEFT(postcode, 4)
  FROM aerospace_supplier_candidates
  WHERE tier_classification = 'tier1_candidate'
  GROUP BY LEFT(postcode, 4)
  HAVING COUNT(*) >= 2
);
```

---

## 🔬 Advanced Features

### Machine Learning Integration
```python
# Export training data
import pandas as pd
df = pd.read_csv('validated_candidates.csv')

# Features
features = ['has_aerospace_kw', 'precision_kw', 'building_area', 
            'in_cluster', 'has_website']

# Train classifier
from sklearn.ensemble import RandomForestClassifier
model = RandomForestClassifier()
model.fit(df[features], df['is_aerospace'])

# Enhance scoring with ML confidence
```

### External Data Integration
1. **Companies House** - SIC codes 30300, 25620
2. **ADS Members** - UK aerospace trade association
3. **SC21 Database** - Supply chain program participants
4. **LinkedIn** - Company industry classification

### Network Analysis
```sql
-- Find supplier networks
WITH company_clusters AS (
  SELECT 
    LEFT(postcode, 4) as area,
    array_agg(name) as companies
  FROM aerospace_supplier_candidates
  WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
  GROUP BY LEFT(postcode, 4)
  HAVING COUNT(*) >= 3
)
SELECT * FROM company_clusters;
```

---

## 📊 Sample Queries

### Top Targets by Region
```sql
SELECT 
  LEFT(postcode, 2) as region,
  COUNT(*) as candidates,
  string_agg(name, '; ' ORDER BY aerospace_score DESC) as top_companies
FROM aerospace_supplier_candidates
WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
GROUP BY region
ORDER BY COUNT(*) DESC;
```

### High Scores Missing Contact
```sql
SELECT name, aerospace_score, postcode, city
FROM aerospace_supplier_candidates
WHERE aerospace_score >= 100
  AND website IS NULL
  AND phone IS NULL
ORDER BY aerospace_score DESC;
```

### Geographic Density
```sql
SELECT 
  LEFT(postcode, 4) as area,
  COUNT(*) as density,
  MAX(aerospace_score) as max_score
FROM aerospace_supplier_candidates
GROUP BY LEFT(postcode, 4)
HAVING COUNT(*) >= 5
ORDER BY COUNT(*) DESC;
```

---

## 🚀 Roadmap to World-Class

### Week 1-2: Baseline & Validation ✅
- [x] Run complete pipeline
- [x] Export results
- [ ] Manually validate 100 candidates
- [ ] Calculate precision metrics

### Week 3-4: Refinement
- [ ] Add verified company names
- [ ] Strengthen negative filters
- [ ] Adjust geographic bonuses
- [ ] Re-run and compare

### Week 5-6: Enhancement
- [ ] Add certification keywords
- [ ] Integrate Companies House data
- [ ] Implement proximity scoring
- [ ] Add supply chain clustering

### Week 7-8: External Data
- [ ] Cross-reference with ADS members
- [ ] LinkedIn company matching
- [ ] Website scraping for certifications
- [ ] SC21 database integration

### Target: 75%+ Precision on Tier 2 🎯

---

## 🤝 Contributing

### Validated a Supplier?
Add to `known_suppliers_check.sql`:
```sql
('Company Name', 'City', 'XX', expected_score),
```

### Found a False Positive Pattern?
Update `enhanced_scoring_v2.yaml`:
```yaml
strong_negatives:
  your_pattern:
    weight: -200
```

### Improved a Query?
Share via pull request or issue on GitHub.

---

## 📞 Support

**Questions?**
- Check `COMPLETE_WORKFLOW_GUIDE.md` first
- Run diagnostics: `psql -d uk_osm_full -f diagnose_pipeline.sql`
- Review latest iteration: `./iterations/[latest]/recommendations.md`

**Issues?**
- Zero candidates → Run `diagnose_pipeline.sql`
- High false positives → Strengthen negatives
- Missing suppliers → Check OSM coverage first

---

## 📄 License

MIT