#!/usr/bin/env python3
"""
Aerospace Supplier Verification Agent
Automatically researches and verifies aerospace suppliers from a spreadsheet

Requirements:
    pip install requests beautifulsoup4 pandas openpyxl selenium

Usage:
    python aerospace_verification_agent.py input.csv output.csv
"""

import requests
from bs4 import BeautifulSoup
import pandas as pd
import time
import re
import json
from urllib.parse import quote_plus, urljoin
import sys
from typing import Dict, List, Optional

class AerospaceVerificationAgent:
    """Simple agent to verify aerospace supplier credentials"""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        self.results = []
        
    def google_search(self, query: str, num_results: int = 5) -> List[str]:
        """Simple Google search scraper"""
        try:
            url = f"https://www.google.com/search?q={quote_plus(query)}"
            response = self.session.get(url, timeout=10)
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Extract URLs from search results
            links = []
            for div in soup.find_all('div', class_='g'):
                link = div.find('a')
                if link and link.get('href'):
                    href = link['href']
                    if href.startswith('http') and 'google.com' not in href:
                        links.append(href)
                        if len(links) >= num_results:
                            break
            
            return links
        except Exception as e:
            print(f"Google search error: {e}")
            return []
    
    def find_company_website(self, company_name: str, companies_house_number: str) -> Optional[str]:
        """Find company website via Google search"""
        print(f"  🔍 Finding website for {company_name}...")
        
        # Search with company name and CH number
        query = f"{company_name} {companies_house_number} site:.co.uk OR site:.com"
        results = self.google_search(query, num_results=3)
        
        if results:
            # First result is usually the company website
            print(f"     ✓ Found: {results[0]}")
            return results[0]
        
        # Fallback: just company name
        query = f"{company_name} UK official website"
        results = self.google_search(query, num_results=3)
        
        if results:
            print(f"     ✓ Found: {results[0]}")
            return results[0]
        
        print(f"     ✗ No website found")
        return None
    
    def find_linkedin(self, company_name: str) -> Optional[str]:
        """Find company LinkedIn profile"""
        print(f"  🔍 Finding LinkedIn for {company_name}...")
        
        query = f"{company_name} site:linkedin.com/company"
        results = self.google_search(query, num_results=3)
        
        for url in results:
            if 'linkedin.com/company' in url:
                print(f"     ✓ Found: {url}")
                return url
        
        print(f"     ✗ No LinkedIn found")
        return None
    
    def check_oasis_as9100(self, company_name: str) -> Dict[str, any]:
        """Check OASIS database for AS9100 certification"""
        print(f"  🔍 Checking OASIS for AS9100...")
        
        # OASIS search endpoint (simplified - actual API may vary)
        try:
            # Method 1: Direct search
            query = f"{company_name} AS9100 OASIS"
            results = self.google_search(query, num_results=5)
            
            oasis_found = False
            as9100_certified = False
            
            for url in results:
                if 'oasis-open.org' in url or 'eauditnet.com' in url:
                    oasis_found = True
                    
                    # Try to fetch and check content
                    try:
                        response = self.session.get(url, timeout=10)
                        content = response.text.lower()
                        
                        if 'as9100' in content or 'as 9100' in content:
                            as9100_certified = True
                            print(f"     ✓ AS9100 certified (found in OASIS)")
                            return {
                                'oasis_listed': True,
                                'as9100_certified': True,
                                'source_url': url
                            }
                    except:
                        pass
            
            if oasis_found:
                print(f"     ~ Found in OASIS (AS9100 status unclear)")
                return {'oasis_listed': True, 'as9100_certified': False}
            else:
                print(f"     ✗ Not found in OASIS")
                return {'oasis_listed': False, 'as9100_certified': False}
                
        except Exception as e:
            print(f"     ✗ OASIS check failed: {e}")
            return {'oasis_listed': False, 'as9100_certified': False}
    
    def check_nadcap(self, company_name: str) -> Dict[str, any]:
        """Check NADCAP accreditation"""
        print(f"  🔍 Checking NADCAP...")
        
        try:
            # Search for NADCAP accreditation
            query = f"{company_name} NADCAP accredited"
            results = self.google_search(query, num_results=5)
            
            for url in results:
                if 'eauditnet.com' in url or 'nadcap' in url.lower():
                    try:
                        response = self.session.get(url, timeout=10)
                        content = response.text.lower()
                        
                        if company_name.lower() in content and 'nadcap' in content:
                            print(f"     ✓ NADCAP accredited")
                            return {
                                'nadcap_accredited': True,
                                'source_url': url
                            }
                    except:
                        pass
            
            print(f"     ✗ No NADCAP accreditation found")
            return {'nadcap_accredited': False}
            
        except Exception as e:
            print(f"     ✗ NADCAP check failed: {e}")
            return {'nadcap_accredited': False}
    
    def find_key_customers(self, company_name: str, website: Optional[str] = None) -> List[str]:
        """Find key aerospace customers mentioned"""
        print(f"  🔍 Finding key customers...")
        
        customers = []
        aerospace_companies = [
            'Airbus', 'Boeing', 'Rolls-Royce', 'BAE Systems', 'Leonardo',
            'Thales', 'Safran', 'Spirit AeroSystems', 'GKN', 'Meggitt',
            'Bombardier', 'Embraer', 'Raytheon', 'Lockheed Martin',
            'Collins Aerospace', 'Honeywell', 'Parker Aerospace'
        ]
        
        # Check company website if available
        if website:
            try:
                response = self.session.get(website, timeout=10)
                soup = BeautifulSoup(response.text, 'html.parser')
                text = soup.get_text().lower()
                
                for company in aerospace_companies:
                    if company.lower() in text:
                        if company not in customers:
                            customers.append(company)
                            
            except Exception as e:
                print(f"     ⚠ Could not check website: {e}")
        
        # Google search for customer mentions
        query = f'"{company_name}" AND ("supplies" OR "supplier to" OR "approved by") AND (Airbus OR Boeing OR "Rolls-Royce" OR BAE)'
        results = self.google_search(query, num_results=5)
        
        for url in results:
            try:
                response = self.session.get(url, timeout=10)
                text = response.text.lower()
                
                for company in aerospace_companies:
                    if company.lower() in text:
                        if company not in customers:
                            customers.append(company)
            except:
                pass
        
        if customers:
            print(f"     ✓ Found customers: {', '.join(customers)}")
        else:
            print(f"     ✗ No key customers found")
        
        return customers
    
    def find_approvals(self, company_name: str, website: Optional[str] = None) -> List[str]:
        """Find aerospace approvals and certifications"""
        print(f"  🔍 Finding approvals & certifications...")
        
        approvals = []
        approval_keywords = [
            'AS9100', 'AS9110', 'AS9120', 'NADCAP', 'EASA Part 21',
            'FAA approved', 'ISO 9001', 'Rolls-Royce approved',
            'Airbus approved', 'Boeing approved', 'BAE approved'
        ]
        
        # Check company website
        if website:
            try:
                response = self.session.get(website, timeout=10)
                soup = BeautifulSoup(response.text, 'html.parser')
                text = soup.get_text()
                
                for keyword in approval_keywords:
                    if re.search(keyword, text, re.IGNORECASE):
                        if keyword not in approvals:
                            approvals.append(keyword)
                            
            except Exception as e:
                print(f"     ⚠ Could not check website: {e}")
        
        # Search for approvals
        query = f'"{company_name}" AND (AS9100 OR NADCAP OR "approved supplier" OR certification)'
        results = self.google_search(query, num_results=5)
        
        for url in results:
            try:
                response = self.session.get(url, timeout=10)
                text = response.text
                
                for keyword in approval_keywords:
                    if re.search(keyword, text, re.IGNORECASE):
                        if keyword not in approvals:
                            approvals.append(keyword)
            except:
                pass
        
        if approvals:
            print(f"     ✓ Found approvals: {', '.join(approvals)}")
        else:
            print(f"     ✗ No approvals found")
        
        return approvals
    
    def verify_supplier(self, company_name: str, companies_house_number: str) -> Dict:
        """Main verification workflow"""
        print(f"\n{'='*60}")
        print(f"Verifying: {company_name} ({companies_house_number})")
        print(f"{'='*60}")
        
        result = {
            'company_name': company_name,
            'companies_house_number': companies_house_number,
            'website': None,
            'linkedin': None,
            'oasis_listed': False,
            'as9100_certified': False,
            'nadcap_accredited': False,
            'key_customers': [],
            'approvals': [],
            'verification_score': 0
        }
        
        # Step 1: Find website
        website = self.find_company_website(company_name, companies_house_number)
        result['website'] = website
        if website:
            result['verification_score'] += 10
        
        time.sleep(1)  # Be polite to servers
        
        # Step 2: Find LinkedIn
        linkedin = self.find_linkedin(company_name)
        result['linkedin'] = linkedin
        if linkedin:
            result['verification_score'] += 5
        
        time.sleep(1)
        
        # Step 3: Check OASIS/AS9100
        oasis_data = self.check_oasis_as9100(company_name)
        result['oasis_listed'] = oasis_data.get('oasis_listed', False)
        result['as9100_certified'] = oasis_data.get('as9100_certified', False)
        if result['as9100_certified']:
            result['verification_score'] += 50
        elif result['oasis_listed']:
            result['verification_score'] += 20
        
        time.sleep(1)
        
        # Step 4: Check NADCAP
        nadcap_data = self.check_nadcap(company_name)
        result['nadcap_accredited'] = nadcap_data.get('nadcap_accredited', False)
        if result['nadcap_accredited']:
            result['verification_score'] += 40
        
        time.sleep(1)
        
        # Step 5: Find key customers
        customers = self.find_key_customers(company_name, website)
        result['key_customers'] = customers
        result['verification_score'] += len(customers) * 10
        
        time.sleep(1)
        
        # Step 6: Find approvals
        approvals = self.find_approvals(company_name, website)
        result['approvals'] = approvals
        result['verification_score'] += len(approvals) * 5
        
        # Summary
        print(f"\n{'─'*60}")
        print(f"VERIFICATION SUMMARY:")
        print(f"  Website: {'✓' if website else '✗'}")
        print(f"  LinkedIn: {'✓' if linkedin else '✗'}")
        print(f"  AS9100: {'✓' if result['as9100_certified'] else '✗'}")
        print(f"  NADCAP: {'✓' if result['nadcap_accredited'] else '✗'}")
        print(f"  Customers: {len(customers)}")
        print(f"  Approvals: {len(approvals)}")
        print(f"  Verification Score: {result['verification_score']}/100+")
        print(f"{'─'*60}\n")
        
        return result
    
    def process_spreadsheet(self, input_file: str, output_file: str):
        """Process entire spreadsheet"""
        print(f"\n🚀 Starting Aerospace Verification Agent")
        print(f"📄 Input: {input_file}")
        print(f"📊 Output: {output_file}")
        
        # Read input
        if input_file.endswith('.csv'):
            df = pd.read_csv(input_file)
        else:
            df = pd.read_excel(input_file)
        
        print(f"\n📋 Found {len(df)} companies to verify")
        
        # Required columns: company_name, companies_house_number
        if 'company_name' not in df.columns or 'companies_house_number' not in df.columns:
            # Try common alternatives
            if 'name' in df.columns:
                df['company_name'] = df['name']
            if 'ch_number' in df.columns:
                df['companies_house_number'] = df['ch_number']
            if 'company_number' in df.columns:
                df['companies_house_number'] = df['company_number']
        
        results = []
        
        for idx, row in df.iterrows():
            company_name = row['company_name']
            ch_number = str(row['companies_house_number'])
            
            try:
                result = self.verify_supplier(company_name, ch_number)
                results.append(result)
                
                # Save progress after each company
                results_df = pd.DataFrame(results)
                results_df.to_csv(output_file, index=False)
                
                print(f"✓ Progress: {idx + 1}/{len(df)} companies verified\n")
                
                # Rate limiting
                time.sleep(2)
                
            except Exception as e:
                print(f"✗ Error processing {company_name}: {e}")
                results.append({
                    'company_name': company_name,
                    'companies_house_number': ch_number,
                    'error': str(e)
                })
        
        # Final save
        results_df = pd.DataFrame(results)
        results_df['key_customers'] = results_df['key_customers'].apply(lambda x: ', '.join(x) if isinstance(x, list) else '')
        results_df['approvals'] = results_df['approvals'].apply(lambda x: ', '.join(x) if isinstance(x, list) else '')
        
        results_df.to_csv(output_file, index=False)
        
        print(f"\n✅ Complete! Results saved to: {output_file}")
        print(f"\n📊 Summary:")
        print(f"  Total verified: {len(results_df)}")
        print(f"  With websites: {results_df['website'].notna().sum()}")
        print(f"  AS9100 certified: {results_df['as9100_certified'].sum()}")
        print(f"  NADCAP accredited: {results_df['nadcap_accredited'].sum()}")
        print(f"  Average score: {results_df['verification_score'].mean():.1f}")


def main():
    """Main entry point"""
    if len(sys.argv) < 3:
        print("Usage: python aerospace_verification_agent.py input.csv output.csv")
        print("\nInput file should have columns: company_name, companies_house_number")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    agent = AerospaceVerificationAgent()
    agent.process_spreadsheet(input_file, output_file)


if __name__ == "__main__":
    main()