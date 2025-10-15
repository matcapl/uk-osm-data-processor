#!/usr/bin/env python3
"""
Enhanced LLM-powered Research Agent using Groq
Asks AI to search and extract information about companies from Companies House.

Key Improvements:
- Load GROQ_API_KEY from .env file using python-dotenv.
- Switch to official Companies House API where possible (free, no scraping needed for basic info).
- Fallback to web scraping only for details not in API (e.g., filings content).
- Optimize LLM calls: Batch questions into a single prompt to reduce API usage and latency.
- Handle filings: Detect and fetch latest accounts URLs, extract text from HTML/PDF if needed.
- Use pdfplumber for PDF extraction (added dependency).
- Better error handling and retries.
- Removed redundant examples; consolidated into modular functions.
- Added geospatial filtering stub for future Tier 2 supplier discovery (towards broader goal).
- Rate limiting with exponential backoff.
- Output to JSON/CSV with better structure.

Requirements:
    pip install groq requests beautifulsoup4 pandas python-dotenv pdfplumber

Setup:
    Create .env file with: GROQ_API_KEY=your_key_here
    Get free key from: https://console.groq.com/keys
    Companies House API key (free): https://developer.company-information.service.gov.uk/ (optional for advanced rate limits)
"""

import os
import json
import requests
from bs4 import BeautifulSoup
from groq import Groq
import pandas as pd
import time
import pdfplumber
from dotenv import load_dotenv
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import re

# Load environment variables
load_dotenv()

class EnhancedLLMAgent:
    """Enhanced agent that uses LLM to research companies with API-first approach"""
    
    def __init__(self, groq_api_key=None, ch_api_key=None):
        self.groq_api_key = groq_api_key or os.getenv('GROQ_API_KEY')
        if not self.groq_api_key:
            raise ValueError("GROQ_API_KEY not found in .env. Get one from https://console.groq.com/keys")
        
        self.ch_api_key = ch_api_key or os.getenv('CH_API_KEY')  # Optional
        
        self.client = Groq(api_key=self.groq_api_key)
        self.model = "llama-3.3-70b-versatile"  # Fast and smart
        
        # Session with retries
        self.session = requests.Session()
        retries = Retry(total=3, backoff_factor=1, status_forcelist=[502, 503, 504])
        self.session.mount('https://', HTTPAdapter(max_retries=retries))
    
    def fetch_ch_api(self, endpoint: str, params: dict = None) -> dict:
        """Fetch from Companies House API"""
        base_url = "https://api.company-information.service.gov.uk"
        url = f"{base_url}/{endpoint}"
        auth = (self.ch_api_key, '') if self.ch_api_key else None
        headers = {'Accept': 'application/json'}
        
        try:
            response = self.session.get(url, auth=auth, headers=headers, params=params, timeout=15)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"API Error: {e}")
            return {}
    
    def fetch_webpage(self, url: str) -> str:
        """Fetch and clean webpage content (fallback for non-API data)"""
        try:
            headers = {'User-Agent': 'Mozilla/5.0'}
            response = self.session.get(url, headers=headers, timeout=15)
            soup = BeautifulSoup(response.text, 'html.parser')
            for script in soup(["script", "style"]):
                script.decompose()
            text = ' '.join(chunk.strip() for line in soup.get_text().splitlines() for chunk in line.split("  ") if chunk.strip())
            return text[:30000]  # Increased limit for more context
        except Exception as e:
            return f"Error fetching {url}: {e}"
    
    def extract_pdf(self, url: str) -> str:
        """Download and extract text from PDF"""
        try:
            response = self.session.get(url, timeout=15)
            response.raise_for_status()
            with pdfplumber.open(io.BytesIO(response.content)) as pdf:
                text = ' '.join(page.extract_text() or '' for page in pdf.pages)
            return text[:30000]  # Limit for context
        except Exception as e:
            return f"Error extracting PDF {url}: {e}"
    
    def get_company_profile(self, ch_number: str) -> dict:
        """Get company profile via API"""
        return self.fetch_ch_api(f"company/{ch_number}")
    
    def get_filings(self, ch_number: str, category: str = "accounts") -> list:
        """Get list of filings via API"""
        params = {'category': category, 'items_per_page': 5}  # Latest 5 accounts
        return self.fetch_ch_api(f"company/{ch_number}/filing-history", params).get('items', [])
    
    def ask_llm_batch(self, questions: list, context: str = "") -> dict:
        """Ask multiple questions in one LLM call for efficiency"""
        prompt = f"""You are a precise research assistant. Answer each question accurately based on the provided context.
If information is not found, respond "Not found" for that question.

CONTEXT: {context}

QUESTIONS:
""" + "\n".join(f"{i+1}. {q}" for i, q in enumerate(questions))
        
        prompt += "\n\nOutput as JSON: {\"q1\": \"answer1\", \"q2\": \"answer2\", ...}"
        
        try:
            completion = self.client.chat.completions.create(
                messages=[{"role": "user", "content": prompt}],
                model=self.model,
                temperature=0.1,
                max_tokens=2048,
            )
            response = completion.choices[0].message.content.strip()
            # Parse JSON
            match = re.search(r'\{.*\}', response, re.DOTALL)
            if match:
                return json.loads(match.group(0))
            else:
                return {f"q{i+1}": "Parse error" for i in range(len(questions))}
        except Exception as e:
            return {f"q{i+1}": f"Error: {e}" for i in range(len(questions))}
    
    def research_company(self, company_name: str, ch_number: str, questions: list) -> dict:
        """Research a company using API first, then filings if needed"""
        print(f"\n{'='*70}")
        print(f"🔍 Researching: {company_name} ({ch_number})")
        print(f"{'='*70}")
        
        result = {
            'company_name': company_name,
            'companies_house_number': ch_number
        }
        
        # Step 1: Get profile via API
        profile = self.get_company_profile(ch_number)
        if not profile:
            result['error'] = "Failed to fetch profile"
            return result
        
        context = json.dumps(profile, indent=2)  # Use API data as primary context
        
        # Add basic info
        result['status'] = profile.get('company_status', 'Not found')
        result['sic_codes'] = profile.get('sic_codes', [])
        result['address'] = profile.get('registered_office_address', {})
        
        # Step 2: If questions involve employees or detailed accounts, fetch filings
        needs_filings = any(kw in q.lower() for q in questions for kw in ['employee', 'staff', 'headcount', '2023', '2024'])
        if needs_filings:
            print("\n📂 Fetching latest accounts...")
            filings = self.get_filings(ch_number)
            if filings:
                latest = filings[0]  # Assume first is latest
                doc_url = f"https://find-and-update.company-information.service.gov.uk{latest['pages'][0]['barcode'] if 'pages' in latest else ''}"
                # CH filing URLs are like /company/{num}/filing-history/{transaction_id}/document?format=pdf
                trans_id = latest['transaction_id']
                doc_url = f"https://find-and-update.company-information.service.gov.uk/company/{ch_number}/filing-history/{trans_id}/document?format=pdf&download=0"
                print(f"   {doc_url}")
                if doc_url.endswith('.pdf'):
                    filing_content = self.extract_pdf(doc_url)
                else:
                    filing_content = self.fetch_webpage(doc_url)
                context += f"\n\nLATEST ACCOUNTS: {filing_content}"
        
        # Step 3: Ask all questions in batch
        print("\n❓ Asking questions (batched)...")
        answers = self.ask_llm_batch(questions, context)
        
        for i, q in enumerate(questions, 1):
            key = f"q{i}_{q[:30].lower().replace(' ', '_').replace('?', '')}"
            result[key] = answers.get(f"q{i}", "Not found")
            print(f"   Q{i}: {q}")
            print(f"      A: {result[key]}")
        
        time.sleep(1)  # Base rate limit
        return result

def batch_process_spreadsheet(input_csv: str, output_csv: str, questions: list = None):
    """Process a spreadsheet of companies"""
    agent = EnhancedLLMAgent()
    
    if questions is None:
        questions = [
            "How many employees did this company have in 2024?",
            "How many employees did this company have in 2023?",
            "What is the main business activity?",
            "Does the description mention aerospace, aviation, or aircraft?",
            "Is this an active or dissolved company?"
        ]
    
    df = pd.read_csv(input_csv)
    print(f"\n🚀 Processing {len(df)} companies with {len(questions)} questions...")
    
    results = []
    for idx, row in df.iterrows():
        try:
            result = agent.research_company(row['company_name'], str(row['companies_house_number']), questions)
            results.append(result)
            pd.DataFrame(results).to_csv(output_csv, index=False)
            print(f"✅ {idx + 1}/{len(df)}")
            time.sleep(2)  # Increased for safety
        except Exception as e:
            print(f"❌ Error at {idx + 1}: {e}")
            results.append({'company_name': row['company_name'], 'error': str(e)})
    
    print(f"\n✅ Saved to {output_csv}")
    return results

def interactive_mode():
    """Interactive research mode"""
    agent = EnhancedLLMAgent()
    print("\n🤖 Enhanced LLM Research Agent - Interactive")
    company_name = input("Company name: ")
    ch_number = input("Companies House number: ")
    print("\nQuestions (one per line, empty to finish):")
    questions = []
    while (q := input(f"Q{len(questions)+1}: ")):
        questions.append(q)
    if questions:
        result = agent.research_company(company_name, ch_number, questions)
        print("\nRESULTS:")
        print(json.dumps(result, indent=2))

# Stub for broader goal: Tier 2 supplier discovery
def discover_nearby_suppliers(facility_address: str, radius_miles: int = 60, sic_filter: list = ['30300']):
    """Stub: Discover potential Tier 2 suppliers near a facility.
    Future: Use CH bulk data download, geocode with Nominatim/Postcodes.io, filter by SIC/distance.
    """
    print(f"\n🗺️ Discovering suppliers near {facility_address} within {radius_miles} miles...")
    # TODO: Implement with postcodes.io API for distance calc
    # Download CH data: http://download.companieshouse.gov.uk/en_output.html
    # Filter active companies with SIC in sic_filter, calc distance
    # Enrich with LLM verification
    return []  # Placeholder

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) == 1:
        print("\nUsage:")
        print("python agent.py batch input.csv output.csv")
        print("python agent.py interactive")
        print("python agent.py discover 'Derby, UK' 60")
    
    elif sys.argv[1] == "batch" and len(sys.argv) == 4:
        batch_process_spreadsheet(sys.argv[2], sys.argv[3])
    
    elif sys.argv[1] == "interactive":
        interactive_mode()
    
    elif sys.argv[1] == "discover" and len(sys.argv) >= 3:
        address = sys.argv[2]
        radius = int(sys.argv[3]) if len(sys.argv) > 3 else 60
        discover_nearby_suppliers(address, radius)
    
    else:
        print("Invalid args.")