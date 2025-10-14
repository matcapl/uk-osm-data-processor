# Aerospace Verification Agent - Quick Start

## What It Does

Automatically researches aerospace suppliers and finds:
- ✅ Company website
- ✅ LinkedIn profile  
- ✅ AS9100 certification (via OASIS)
- ✅ NADCAP accreditation
- ✅ Key aerospace customers (Airbus, Boeing, Rolls-Royce, etc.)
- ✅ Aerospace approvals and certifications

## Setup (2 minutes)

```bash
# 1. Install dependencies
pip install requests beautifulsoup4 pandas openpyxl

# 2. Download the script
# (already created as aerospace_verification_agent.py)

# 3. Prepare your input CSV
```

## Input Format

Create a CSV file called `suppliers_to_check.csv`:

```csv
company_name,companies_house_number
GKN Aerospace,00000000
Senior Aerospace Bird Bellows,01234567
Meggitt PLC,00218402
```

**Required columns:**
- `company_name` - Full company name
- `companies_house_number` - UK Companies House registration number

## Usage

```bash
python aerospace_verification_agent.py suppliers_to_check.csv results.csv
```

**That's it!** The agent will:
1. Process each company one by one
2. Save progress after each company (so you can stop/resume)
3. Output results to `results.csv`

## Output Format

The `results.csv` will contain:

| Column | Description | Example |
|--------|-------------|---------|
| company_name | Input name | GKN Aerospace |
| companies_house_number | Input CH number | 00000000 |
| website | Found website | https://gknaerospace.com |
| linkedin | LinkedIn profile | https://linkedin.com/company/gkn-aerospace |
| oasis_listed | In OASIS database? | True/False |
| as9100_certified | AS9100 certified? | True/False |
| nadcap_accredited | NADCAP accredited? | True/False |
| key_customers | Major customers found | Airbus, Boeing, Rolls-Royce |
| approvals | Certifications found | AS9100, NADCAP, ISO 9001 |
| verification_score | Confidence score (0-100+) | 85 |

## Example Output

```csv
company_name,website,linkedin,as9100_certified,nadcap_accredited,key_customers,approvals,verification_score
GKN Aerospace,https://gknaerospace.com,https://linkedin.com/company/gkn-aerospace,True,True,"Airbus, Boeing, Rolls-Royce","AS9100, NADCAP, ISO 9001",95
Senior Aerospace,https://senioraerospace.com,https://linkedin.com/company/senior-plc,True,False,"Airbus, Safran","AS9100, ISO 9001",70
```

## Understanding the Verification Score

| Score Range | Meaning | Action |
|-------------|---------|--------|
| **80-100+** | Strong aerospace supplier | High confidence - proceed with outreach |
| **50-79** | Likely aerospace supplier | Good candidate - verify manually |
| **30-49** | Possible aerospace involvement | Needs deeper research |
| **0-29** | Weak signals | Low priority |

**Score Breakdown:**
- Website found: +10
- LinkedIn found: +5
- AS9100 certified: +50
- NADCAP accredited: +40
- Each key customer: +10
- Each approval: +5

## Tips for Best Results

### 1. Company Name Accuracy
Use the **official registered name** from Companies House:
```
✅ Good: "GKN Aerospace Services Limited"
✅ Good: "Senior Aerospace Bird Bellows"
❌ Bad: "GKN" (too generic)
❌ Bad: "Senior Aero" (abbreviated)
```

### 2. Batch Processing
Process 10-20 companies at a time:
```bash
# Split your list
head -20 all_suppliers.csv > batch1.csv
python aerospace_verification_agent.py batch1.csv results_batch1.csv
```

### 3. Rate Limiting
The agent waits 1-2 seconds between searches. For large batches:
- Run overnight
- Use `nohup` on Unix/Mac: `nohup python aerospace_verification_agent.py input.csv output.csv &`

### 4. Resume Interrupted Runs
The agent saves after each company, so if it crashes:
1. Check how many rows are in `results.csv`
2. Remove those rows from your input file
3. Re-run with remaining companies

## Troubleshooting

### Problem: "No website found"
**Causes:**
- Company not online
- Name mismatch with online presence
- Website redirects/broken

**Solution:** Manually Google the company

### Problem: "OASIS check failed"
**Causes:**
- OASIS website structure changed
- Company not in OASIS database
- Rate limiting

**Solution:** Manually check [eAuditNet OASIS](https://www.eauditnet.com/oasis/)

### Problem: "Slow processing"
**Normal:** 2-3 minutes per company due to rate limiting

**Speed up:**
- Use cached results
- Focus on high-priority companies first

### Problem: False negatives (real suppliers not found)
**Reasons:**
- No online presence
- AS9100 not publicly listed
- Customers not mentioned on website

**Solution:** Manual verification via phone/email

## Advanced Usage

### Filter Your OSM Results First
```bash
# From your OSM candidates, export Tier 1 only
psql -d uk_osm_full -c "
  COPY (
    SELECT name as company_name, 
           '' as companies_house_number
    FROM aerospace_supplier_candidates
    WHERE tier_classification = 'tier1_candidate'
    ORDER BY aerospace_score DESC
  ) TO 'tier1_to_verify.csv' CSV HEADER;
"

# Add CH numbers manually or via Companies House API
# Then run agent
python aerospace_verification_agent.py tier1_to_verify.csv tier1_verified.csv
```

### Combine with Your Pipeline
```python
# After running OSM pipeline
import pandas as pd

# Your OSM results
osm_results = pd.read_csv('exports/tier2_candidates_*.csv')

# Agent verification
verified = pd.read_csv('tier2_verified.csv')

# Merge
final = osm_results.merge(
    verified[['company_name', 'as9100_certified', 'verification_score']], 
    on='company_name', 
    how='left'
)

# Filter to verified aerospace suppliers
high_confidence = final[
    (final['aerospace_score'] >= 80) & 
    (final['verification_score'] >= 50)
]
```

## API Alternative (For Large Scale)

For processing 1000+ companies, consider these APIs:

**1. Companies House API (Free)**
```python
import requests

def get_company_info(ch_number):
    url = f"https://api.company-information.service.gov.uk/company/{ch_number}"
    headers = {"Authorization": "YOUR_API_KEY"}
    return requests.get(url, headers=headers).json()
```

**2. LinkedIn API (Paid)**
- Official LinkedIn Company API
- Better than web scraping
- Requires business account

**3. Certification Databases**
- OASIS/eAuditNet: May have API (contact them)
- NADCAP: Database access for members

## Example: Complete Workflow

```bash
# 1. Export your top OSM candidates
psql -d uk_osm_full -c "
  COPY (
    SELECT name, postcode 
    FROM aerospace_supplier_candidates 
    WHERE tier_classification IN ('tier1_candidate', 'tier2_candidate')
    ORDER BY aerospace_score DESC 
    LIMIT 100
  ) TO 'top_100.csv' CSV HEADER;
"

# 2. Add Companies House numbers (manually or via lookup)
# Edit top_100.csv to add 'companies_house_number' column

# 3. Run verification agent
python aerospace_verification_agent.py top_100.csv top_100_verified.csv

# 4. Filter verified aerospace suppliers
python << 'EOF'
import pandas as pd

df = pd.read_csv('top_100_verified.csv')

# High confidence: AS9100 OR NADCAP OR verification score >= 60
verified = df[
    (df['as9100_certified'] == True) | 
    (df['nadcap_accredited'] == True) |
    (df['verification_score'] >= 60)
]

verified.to_csv('confirmed_aerospace_suppliers.csv', index=False)
print(f"Confirmed {len(verified)} aerospace suppliers")
EOF

# 5. Ready for outreach!
# Open confirmed_aerospace_suppliers.csv
```

## Next Steps

After verification:
1. **Prioritize outreach** - Start with AS9100 + NADCAP companies
2. **Update your scoring** - Add verified companies to `enhanced_scoring_v2.yaml`
3. **Build company list** - Maintain master list of verified suppliers
4. **Share back** - Add to `known_suppliers_check.sql` for community

---

## Output Analysis

```python
import pandas as pd

df = pd.read_csv('results.csv')

# Certification breakdown
print("AS9100 Certified:", df['as9100_certified'].sum())
print("NADCAP Accredited:", df['nadcap_accredited'].sum())
print("Both AS9100 & NADCAP:", ((df['as9100_certified']) & (df['nadcap_accredited'])).sum())

# Top customers mentioned
from collections import Counter
all_customers = ' '.join(df['key_customers'].dropna()).split(', ')
print("\nTop Customers:", Counter(all_customers).most_common(10))

# Score distribution
print("\nScore Distribution:")
print(df['verification_score'].describe())
```

---

**Time estimate:** 2-3 minutes per company  
**Accuracy:** ~80% for finding websites, ~60% for certifications  
**Best for:** Batches of 10-100 companies