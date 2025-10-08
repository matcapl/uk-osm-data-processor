# World-Class Aerospace Supplier Scoring Strategy

## Philosophy: Multi-Layered Signal Detection

The best approach combines **multiple independent signals** that reinforce each other:

1. **Direct Evidence** (definitive)
2. **Strong Indicators** (high probability)
3. **Contextual Signals** (supporting evidence)
4. **Negative Filters** (exclusions)
5. **Geographic Intelligence** (location clustering)
6. **Network Analysis** (supplier ecosystem)

---

## Tier 1: Direct Evidence (Score: 150-300)

### Company Name Matching
**Most Reliable Signal** - Use authoritative lists

```sql
-- Tier-1 Prime Contractors (definitive +200)
CASE WHEN LOWER(name) ~ ANY(ARRAY[
  'airbus',
  'boeing',
  'rolls.royce|rolls royce',
  'bae systems|bae',
  'leonardo',
  'thales',
  'safran',
  'raytheon',
  'lockheed martin',
  'northrop grumman',
  'general electric aviation|ge aviation',
  'pratt.whitney|pratt & whitney',
  'honeywell aerospace',
  'collins aerospace',
  'spirit aerosystems'
]) THEN 200 ELSE 0 END

-- Known UK Tier-2 Suppliers (definitive +150)
CASE WHEN LOWER(name) ~ ANY(ARRAY[
  'gkn aerospace',
  'meggitt',
  'cobham',
  'senior aerospace',
  'gardner aerospace',
  'magellan aerospace',
  'triumph group',
  'moog aircraft',
  'parker hannifin',
  'woodward aerospace',
  'eaton aerospace'
]) THEN 150 ELSE 0 END
```

**Pro Tip:** Maintain this list from:
- UK Aerospace Growth Partnership supplier database
- ADS (Aerospace Defence Security) member list
- SC21 (aerospace supply chain program) participants

---

## Tier 2: Keyword-Based Detection (Score: 50-120)

### Multi-Level Keyword Strategy

**Level 1: Exact Aerospace Terms (+100)**
```sql
CASE WHEN LOWER(COALESCE(name, '') || ' ' || COALESCE(description, '')) ~ 
  '\\m(aerospace|aviation|aircraft|avionics|aeronautical)\\m'
THEN 100 ELSE 0 END
```

**Level 2: Manufacturing Capability (+80)**
```sql
CASE WHEN LOWER(name) ~ ANY(ARRAY[
  'precision.engineer',
  'precision.machin',
  'cnc.machin',
  'advanced.manufactur',
  'composite.manufactur',
  'metal.finishing',
  'surface.treatment',
  'heat.treatment',
  'forging',
  'casting',
  'additive.manufactur|3d.print'
]) THEN 80 ELSE 0 END
```

**Level 3: Technical Specializations (+70)**
```sql
CASE WHEN LOWER(COALESCE(name, '') || ' ' || COALESCE(tags::text, '')) ~ ANY(ARRAY[
  'turbine',
  'propulsion',
  'landing.gear',
  'hydraulic.systems',
  'actuator',
  'composite.material',
  'titanium.machin',
  'aerospace.fastener',
  'flight.control',
  'nacelle'
]) THEN 70 ELSE 0 END
```

---

## Tier 3: Contextual Signals (Score: 20-60)

### Industry Certifications (Hard to Fake)

```sql
-- Check for aerospace quality standards in tags/description
CASE WHEN LOWER(COALESCE(tags::text, '') || ' ' || COALESCE(description, '')) ~ ANY(ARRAY[
  'as9100',      -- Aerospace quality management
  'nadcap',      -- Aerospace special processes
  'easa',        -- European Aviation Safety
  'faa',         -- US FAA certification
  'military.standard|mil.std',
  'jisq.9100',   -- Japanese aerospace standard
  'en.9100'      -- European aerospace standard
]) THEN 60 ELSE 0 END
```

**Implementation:** Requires OSM tags or website scraping - but VERY high signal.

### Industrial Classification

```sql
-- SIC codes if available in tags
CASE WHEN tags ? 'sic_code' THEN
  CASE 
    WHEN tags->'sic_code' ~ '^(30300|32500|30400)' THEN 80  -- Aerospace manufacturing
    WHEN tags->'sic_code' ~ '^(2599|2562)' THEN 60          -- Precision machining
    ELSE 0
  END
ELSE 0 END
```

### Building Characteristics

```sql
-- Large industrial buildings in aerospace clusters
CASE WHEN 
  building IN ('industrial', 'warehouse', 'factory')
  AND ST_Area(way) > 5000  -- Large facilities
  AND LEFT(postcode, 2) IN ('BS', 'GL', 'DE', 'PR')  -- Bristol, Gloucester, Derby, Preston
THEN 40 ELSE 0 END
```

---

## Tier 4: Negative Filters (Critical!)

### The "Not Obviously Wrong" Filter

```sql
-- EXCLUDE with strong negative score
CASE WHEN (
  -- Consumer businesses
  shop IS NOT NULL
  OR tourism IS NOT NULL
  OR amenity IN ('restaurant', 'pub', 'cafe', 'school', 'hospital')
  
  -- Residential
  OR building IN ('house', 'apartments', 'residential')
  
  -- Obviously wrong keywords
  OR LOWER(name) ~ '\\m(cafe|restaurant|hotel|pub|retail|supermarket|gym|salon)\\m'
  
) AND NOT (
  -- UNLESS explicitly aerospace (override)
  LOWER(name) ~ '\\m(aerospace|aviation|aircraft)\\m'
) THEN -200 ELSE 0 END
```

---

## Tier 5: Geographic Intelligence (Score: 20-50)

### UK Aerospace Clusters (Known Hotspots)

```yaml
Primary Clusters: (+40 points)
  - Bristol/Filton: BS, GL (Airbus, Rolls-Royce, GKN)
  - Derby: DE (Rolls-Royce)
  - Preston: PR (BAE Systems)
  - Yeovil: BA (Leonardo Helicopters)
  - Farnborough: GU (aerospace hub)

Secondary Clusters: (+20 points)
  - Cambridge: CB (high-tech aerospace)
  - Southampton: SO (Solent aerospace)
  - Belfast: BT (Bombardier, Spirit)
  - East Midlands: LE, NG (aerospace suppliers)
```

```sql
CASE 
  WHEN LEFT(postcode, 2) IN ('BS', 'GL', 'DE', 'PR', 'BA', 'GU') THEN 40
  WHEN LEFT(postcode, 2) IN ('CB', 'SO', 'BT', 'LE', 'NG') THEN 20
  ELSE 0
END
```

### Proximity to Airports/Airfields

```sql
-- Bonus for facilities near airports (requires spatial query)
+ CASE WHEN EXISTS (
    SELECT 1 FROM planet_osm_point airports
    WHERE airports.aeroway = 'aerodrome'
    AND ST_DWithin(
      planet_osm_polygon.way,
      airports.way,
      10000  -- 10km radius
    )
  ) THEN 30 ELSE 0 END
```

---

## Tier 6: Network & Supply Chain Analysis

### Co-location with Known Suppliers

```sql
-- Same industrial estate as known aerospace companies
+ CASE WHEN EXISTS (
    SELECT 1 FROM aerospace_supplier_candidates known
    WHERE known.tier_classification = 'tier1_candidate'
    AND LEFT(planet_osm_polygon."addr:postcode", 4) = LEFT(known.postcode, 4)
    AND planet_osm_polygon.osm_id != known.osm_id
  ) THEN 25 ELSE 0 END
```

### Business Park / Industrial Estate Detection

```sql
-- Part of named aerospace/technology park
CASE WHEN tags->'industrial:estate' IS NOT NULL
  OR LOWER(COALESCE(name, '')) ~ '(technology.park|business.park|industrial.estate)'
THEN 15 ELSE 0 END
```

---

## Advanced: Machine Learning Signals

### Pattern-Based Scoring

**Company Name Patterns** (ML features):
```python
# Extract features for ML model
features = {
  'has_ltd': 'ltd' in name.lower(),
  'has_limited': 'limited' in name.lower(),
  'has_engineering': 'engineering' in name.lower(),
  'has_precision': 'precision' in name.lower(),
  'has_systems': 'systems' in name.lower(),
  'word_count': len(name.split()),
  'has_ampersand': '&' in name,
  'has_abbreviation': bool(re.match(r'^[A-Z]{2,5}\s', name))
}
```

Aerospace companies tend to:
- Have "Ltd" or "Limited"
- Use technical terms (Systems, Precision, Advanced)
- Be 2-4 words long
- Use abbreviations (BAE, GKN, UTC)

---

## Implementation: Progressive Enhancement

### Phase 1: Core Scoring (Current)
✅ You have this now
- Direct company matches
- Keyword detection
- Geographic clusters
- Basic exclusions

### Phase 2: Enhanced Filtering
**Add these to your YAML:**

```yaml
# enhanced_keywords.yaml
tier1_companies:
  exact_match:
    - "airbus"
    - "boeing"
    - "rolls royce"
    - "bae systems"
  # ... add 50+ known suppliers

capability_keywords:
  high_confidence:
    - "precision engineering"
    - "cnc machining"
    - "aerospace manufacturing"
    - "composite materials"
  medium_confidence:
    - "metal finishing"
    - "surface treatment"
    - "quality assurance"

certifications:
  aerospace_specific:
    - "as9100"
    - "nadcap"
    - "easa part 21"
    - "faa certified"
```

### Phase 3: Validation Layer
**Cross-check candidates:**

```sql
-- Validate candidates by checking for "deal-breakers"
UPDATE aerospace_supplier_candidates
SET confidence_level = 'suspect',
    validation_notes = 'Residential area / consumer business'
WHERE (
  building_type IN ('house', 'retail')
  OR landuse_type = 'residential'
  OR matched_keywords && ARRAY['cafe', 'shop', 'retail']
)
AND aerospace_score < 100;  -- Unless very strong signal
```

### Phase 4: External Data Enrichment
**Augment with:**
1. **Companies House data** (UK company registration)
2. **ADS member directory** (aerospace trade association)
3. **SC21 database** (supply chain program)
4. **LinkedIn company data** (industry classification)

---

## Scoring Weights: Best Practices

**Conservative Approach** (Minimize False Positives):
- Tier 1 threshold: 150 (very confident)
- Tier 2 threshold: 100 (confident)
- Review threshold: 60 (needs human review)

**Aggressive Approach** (Maximize Recall):
- Tier 1 threshold: 120
- Tier 2 threshold: 70
- Review threshold: 40

**Your Current Setup:** Middle ground ✓
- Tier 1: 150
- Tier 2: 80
- Potential: 40

---

## Quality Metrics to Track

**Precision (Accuracy):**
```sql
-- Sample 100 random Tier 2 candidates
-- Manually verify → Calculate accuracy
SELECT * FROM aerospace_supplier_candidates
WHERE tier_classification = 'tier2_candidate'
ORDER BY RANDOM()
LIMIT 100;
```

**Recall (Coverage):**
- Get list of known aerospace suppliers from ADS
- Check how many you captured
- Target: 80%+ of known suppliers

**F1 Score:**
- Balance precision vs recall
- Target: >0.70 for Tier 2

---

## Nodes and Ways: Use Cases

**Nodes (planet_osm_nodes):**
❌ **Skip** - Raw node data, not useful for your analysis
- Just coordinates
- Use `planet_osm_point` instead (processed POIs)

**Ways (planet_osm_ways):**
❌ **Skip** - Raw way data
- Use `planet_osm_line` and `planet_osm_polygon` instead

**Summary:** The processed tables (point/line/polygon/roads) are all you need.

---

## Incremental Improvement Strategy

### Week 1: Validate Current Results
1. Export top 100 Tier 1 candidates
2. Manually verify via Google/LinkedIn
3. Calculate precision

### Week 2: Refine Exclusions
1. Identify false positives
2. Add negative keywords
3. Re-run pipeline

### Week 3: Add Certifications
1. Scrape websites of known suppliers
2. Extract AS9100/NADCAP mentions
3. Add as high-value signal

### Week 4: Geographic Enhancement
1. Add proximity-to-airport bonus
2. Refine cluster definitions
3. Add industrial estate co-location

### Week 5: External Data
1. Import Companies House data
2. Match by postcode + name similarity
3. Add SIC code filtering

---

## SQL Example: Enhanced Scoring

```sql
-- World-class scoring formula
(
  -- TIER 1: Direct Evidence (150-200)
  CASE WHEN LOWER(name) ~ 'airbus|boeing|rolls.royce|bae' THEN 200 ELSE 0 END +
  
  -- TIER 2: Strong Keywords (80-100)
  CASE WHEN LOWER(name) ~ 'aerospace|aviation|aircraft' THEN 100 ELSE 0 END +
  CASE WHEN LOWER(name) ~ 'precision.engineer|cnc.machin' THEN 80 ELSE 0 END +
  
  -- TIER 3: Capabilities (50-70)
  CASE WHEN LOWER(name) ~ 'composite|turbine|actuat' THEN 70 ELSE 0 END +
  CASE WHEN industrial IN ('engineering', 'electronics') THEN 60 ELSE 0 END +
  
  -- TIER 4: Geographic (20-40)
  CASE WHEN LEFT(postcode, 2) IN ('BS', 'GL', 'DE') THEN 40 
       WHEN LEFT(postcode, 2) IN ('CB', 'SO', 'LE') THEN 20 
       ELSE 0 END +
  
  -- TIER 5: Contact/Legitimacy (10-30)
  CASE WHEN website IS NOT NULL AND website ~ 'aerospace|aviation' THEN 30 ELSE 0 END +
  CASE WHEN website IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN phone IS NOT NULL THEN 5 ELSE 0 END +
  
  -- TIER 6: Building Characteristics (10-20)
  CASE WHEN ST_Area(way) > 5000 AND building = 'industrial' THEN 20 ELSE 0 END +
  CASE WHEN landuse = 'industrial' THEN 15 ELSE 0 END +
  
  -- NEGATIVE SIGNALS (-200 to 0)
  CASE WHEN shop IS NOT NULL OR tourism IS NOT NULL THEN -200 ELSE 0 END +
  CASE WHEN amenity IN ('restaurant', 'cafe', 'pub') THEN -150 ELSE 0 END +
  CASE WHEN building IN ('house', 'apartments') THEN -100 ELSE 0 END
  
) AS aerospace_score
```

---

## Next Steps for You

**Immediate (This Week):**
1. ✅ Run point/line/roads pipelines
2. ✅ Create final unified table
3. ✅ Export and manually validate top 50

**Short-term (2-4 weeks):**
1. Build authoritative company list (ADS members)
2. Add certification keywords (AS9100, NADCAP)
3. Refine negative filters based on false positives
4. Add proximity-to-airport scoring

**Long-term (1-3 months):**
1. Integrate Companies House data
2. Build ML model for name classification
3. Add supplier network analysis
4. Create confidence scoring system

**Your pipeline is already good! These enhancements will make it world-class.**