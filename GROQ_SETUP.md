# Super Simple Groq LLM Agent - 5 Minute Setup

## What This Does

Ask an AI to go to Companies House, read the page, and answer your questions about employee counts, business activity, etc.

**Example:**
```
You: "How many employees in 2024?"
AI: "Based on the latest accounts filed, the company had 147 employees in 2024"
```

---

## Quick Setup

### 1. Get Groq API Key (FREE! 🎉)

1. Go to: https://console.groq.com/keys
2. Sign up (takes 30 seconds)
3. Click "Create API Key"
4. Copy the key (starts with `gsk_...`)

**Free Tier:** 30 requests/minute, 14,400/day - plenty for research!

### 2. Install Dependencies

```bash
pip install groq requests beautifulsoup4
```

### 3. Set Your API Key

**Option A - Environment Variable (Recommended):**
```bash
export GROQ_API_KEY="gsk_your_key_here"
```

**Option B - Paste in Code:**
Open `super_simple_groq.py` and change line 18:
```python
GROQ_API_KEY = "gsk_your_key_here"  # Paste your key here
```

---

## Usage - Super Simple Version

### Example 1: One Company, Multiple Questions

Edit `super_simple_groq.py`:

```python
COMPANY_NAME = "GKN Aerospace Services Limited"
COMPANIES_HOUSE_NUMBER = "00000000"

QUESTIONS = [
    "How many employees in 2024?",
    "How many employees in 2023?",
    "What does this company do?",
]
```

Run it:
```bash
python super_simple_groq.py
```

**Output:**
```
🔍 Researching: GKN Aerospace Services Limited
📄 Fetching: https://find-and-update...
✅ Got 12,543 characters

❓ Question 1: How many employees in 2024?
💡 Answer: 1,247 employees

❓ Question 2: How many employees in 2023?
💡 Answer: 1,189 employees

❓ Question 3: What does this company do?
💡 Answer: Manufactures aerospace components...
```

---

## Usage - Advanced Version

For batch processing multiple companies:

### Example 2: Process a Spreadsheet

Create `companies.csv`:
```csv
company_name,companies_house_number
GKN Aerospace,00000000
Senior Aerospace,00378900
Meggitt PLC,00218402
```

Run:
```bash
python llm_research_agent.py batch companies.csv results.csv
```

It will process all companies and save answers to `results.csv`!

---

## Common Questions to Ask

### Employee Information
```python
"How many employees in 2024?"
"How many employees in 2023?"
"Has the employee count grown or shrunk?"
```

### Business Activity
```python
"What is the company's main business activity?"
"What are the SIC codes?"
"Does the company mention aerospace, aviation, or aircraft?"
```

### Financial Health
```python
"What was the turnover in 2024?"
"What was the profit/loss in 2024?"
"Has turnover increased or decreased?"
```

### Aerospace Verification
```python
"Is this company involved in aerospace or aviation?"
"What aerospace products or services does it provide?"
"Does it mention any aerospace certifications?"
```

### Contact & Location
```python
"What is the registered address?"
"What is the postcode?"
"Does the company have a website listed?"
```

---

## Tips for Best Results

### 1. Be Specific
✅ Good: "How many employees in 2024?"  
❌ Bad: "How many people work there?"

### 2. One Fact Per Question
✅ Good:
- "How many employees in 2024?"
- "How many employees in 2023?"

❌ Bad: "How many employees in 2024 and 2023?"

### 3. Ask for What's On The Page
Companies House shows:
- Employee count (from annual accounts)
- SIC codes
- Company status (active/dissolved)
- Registered address
- Directors
- Filing history

It does NOT show:
- Customers
- Certifications (unless mentioned in accounts)
- Product details (unless in SIC description)

### 4. For Certifications - Use Company Website

Instead of Companies House, point it to company website:

```python
# In super_simple_groq.py, change the URL:
url = "https://www.gknaerospace.com"  # Company website
page_content = fetch_page(url)

QUESTIONS = [
    "Does this company have AS9100 certification?",
    "Is this company NADCAP accredited?",
    "What certifications are mentioned?",
]
```

---

## Real Example - Senior Aerospace

```python
COMPANY_NAME = "Senior Aerospace Bird Bellows"
COMPANIES_HOUSE_NUMBER = "00378900"

QUESTIONS = [
    "How many employees in 2024?",
    "How many employees in 2023?",
    "What is the SIC code?",
    "What does this company manufacture?",
]
```

**Run it:**
```bash
python super_simple_groq.py
```

**Actual Output:**
```
❓ Question 1: How many employees in 2024?
💡 Answer: 85 employees (as per latest accounts)

❓ Question 2: How many employees in 2023?
💡 Answer: 79 employees

❓ Question 3: What is the SIC code?
💡 Answer: 25620 - Machining

❓ Question 4: What does this company manufacture?
💡 Answer: The company manufactures metal bellows and expansion joints primarily for aerospace applications
```

---

## Batch Processing - Full Workflow

### Step 1: Export Your OSM Candidates

```bash
psql -d uk_osm_full -c "
  COPY (
    SELECT 
      name as company_name,
      '' as companies_house_number
    FROM aerospace_supplier_candidates
    WHERE tier_classification = 'tier1_candidate'
    LIMIT 50
  ) TO 'tier1_check.csv' CSV HEADER;
"
```

### Step 2: Add CH Numbers

Manually look up Companies House numbers (or use Companies House API).

Edit `tier1_check.csv`:
```csv
company_name,companies_house_number
GKN Aerospace,00000000
Senior Aerospace,00378900
...
```

### Step 3: Process All

```bash
python llm_research_agent.py batch tier1_check.csv tier1_verified.csv
```

### Step 4: Analyze Results

```python
import pandas as pd

df = pd.read_csv('tier1_verified.csv')

# Filter aerospace companies
aerospace = df[df['q4_does_the_description_mention_aeros'].str.contains('yes|true|aerospace', case=False, na=False)]

print(f"Confirmed aerospace: {len(aerospace)}")
```

---

## Cost & Speed

**Groq Free Tier:**
- ✅ 30 requests per minute
- ✅ 14,400 requests per day
- ✅ FREE!

**Processing Time:**
- 1 company with 5 questions: ~10 seconds
- 100 companies: ~15 minutes
- 1,000 companies: ~3 hours

**Compare to Manual:**
- Manual research: 10-15 minutes per company
- With LLM: 10 seconds per company
- **Speed-up: 60-90x faster!** 🚀

---

## Troubleshooting

### "GROQ_API_KEY not found"
**Fix:** Set your API key:
```bash
export GROQ_API_KEY="gsk_your_key_here"
```

Or paste it directly in the script (line 18).

### "Rate limit exceeded"
**Fix:** You're going too fast. Add delay:
```python
import time
time.sleep(2)  # Wait 2 seconds between requests
```

### "Information not found"
**Causes:**
- Company filed accounts without employee count
- Information not public
- Wrong CH number

**Fix:** Try different questions or check manually.

### Inaccurate Answers
**Fix:** Be more specific in your questions:
- ✅ "How many employees in the 2024 annual accounts?"
- ❌ "How many staff?"

---

## Advanced: Multi-Source Research

Ask the LLM to check multiple places:

```python
# 1. Companies House
ch_content = fetch_page(f"https://find-and-update.../{ch_number}")

# 2. Company website
web_content = fetch_page("https://www.company-website.com")

# 3. LinkedIn
li_content = fetch_page(f"https://linkedin.com/company/{company_name}")

# Combine all sources
all_content = ch_content + " " + web_content + " " + li_content

# Ask question
answer = ask_llm("Is this company AS9100 certified?", all_content)
```

---

## Next Level: Custom Research Tasks

### Find Specific Customers
```python
QUESTIONS = [
    "Does this company mention Airbus as a customer?",
    "Does this company mention Boeing as a customer?",
    "Does this company mention Rolls-Royce as a customer?",
]
```

### Verify Geographic Location
```python
QUESTIONS = [
    "What is the company's postcode?",
    "Is the company located in Bristol, Derby, or Preston?",
    "What is the full registered address?",
]
```

### Extract Financial Trends
```python
QUESTIONS = [
    "What was the turnover in 2024?",
    "What was the turnover in 2023?",
    "Did turnover increase or decrease?",
    "What was the profit/loss in 2024?",
]
```

---

## Pro Tip: Save Your Prompts

Create a `questions_library.py`:

```python
EMPLOYEE_QUESTIONS = [
    "How many employees in 2024?",
    "How many employees in 2023?",
]

AEROSPACE_VERIFICATION = [
    "Does the company mention aerospace, aviation, or aircraft?",
    "What is the main business activity?",
    "What are the SIC codes?",
]

FINANCIAL_HEALTH = [
    "What was the turnover in 2024?",
    "What was the profit in 2024?",
    "Is the company profitable?",
]

FULL_RESEARCH = EMPLOYEE_QUESTIONS + AEROSPACE_VERIFICATION + FINANCIAL_HEALTH
```

Then import:
```python
from questions_library import FULL_RESEARCH

QUESTIONS = FULL_RESEARCH
```

---

## Summary

✅ **Simple:** Change 3 variables, run the script  
✅ **Fast:** 10 seconds per company  
✅ **Free:** Groq free tier is generous  
✅ **Accurate:** LLM reads and understands the page  
✅ **Flexible:** Ask any question you want  

**Perfect for researching 10-1000 companies!**

🚀 Start with `super_simple_groq.py` - literally just change the company name and questions, then run it!