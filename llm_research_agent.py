#!/usr/bin/env python3
"""
Simple LLM-powered Research Agent using Groq
Asks AI to search and extract information about companies

Requirements:
    pip install groq requests beautifulsoup4 pandas

Setup:
    export GROQ_API_KEY="your_key_here"
    Get free key from: https://console.groq.com/keys
"""

import os
import json
import requests
from bs4 import BeautifulSoup
from groq import Groq
import pandas as pd
import time

class SimpleLLMAgent:
    """Simple agent that uses LLM to research companies"""
    
    def __init__(self, api_key=None):
        self.api_key = api_key or os.environ.get('GROQ_API_KEY')
        if not self.api_key:
            raise ValueError("GROQ_API_KEY not found. Get one from https://console.groq.com/keys")
        
        self.client = Groq(api_key=self.api_key)
        self.model = "llama-3.3-70b-versatile"  # Fast and smart
    
    def fetch_webpage(self, url: str) -> str:
        """Fetch webpage content"""
        try:
            headers = {'User-Agent': 'Mozilla/5.0'}
            response = requests.get(url, headers=headers, timeout=15)
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Remove script and style elements
            for script in soup(["script", "style"]):
                script.decompose()
            
            # Get text
            text = soup.get_text()
            lines = (line.strip() for line in text.splitlines())
            chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
            text = ' '.join(chunk for chunk in chunks if chunk)
            
            # Limit to 15000 chars to fit in context
            return text[:15000]
        except Exception as e:
            return f"Error fetching {url}: {e}"
    
    def ask_llm(self, question: str, context: str = "") -> str:
        """Ask the LLM a question with optional context"""
        
        prompt = f"""You are a helpful research assistant. Answer the question accurately based on the provided information.

{f"CONTEXT: {context}" if context else ""}

QUESTION: {question}

Provide a clear, concise answer. If the information is not in the context, say "Information not found"."""

        try:
            chat_completion = self.client.chat.completions.create(
                messages=[
                    {
                        "role": "user",
                        "content": prompt,
                    }
                ],
                model=self.model,
                temperature=0.1,  # More deterministic
                max_tokens=1024,
            )
            
            return chat_completion.choices[0].message.content.strip()
        
        except Exception as e:
            return f"Error: {e}"
    
    def research_company(self, company_name: str, ch_number: str, questions: list) -> dict:
        """Research a company and answer questions about it"""
        
        print(f"\n{'='*70}")
        print(f"🔍 Researching: {company_name}")
        print(f"{'='*70}")
        
        result = {
            'company_name': company_name,
            'companies_house_number': ch_number
        }
        
        # Step 1: Find Companies House page
        ch_url = f"https://find-and-update.company-information.service.gov.uk/company/{ch_number}"
        print(f"\n📄 Fetching Companies House page...")
        print(f"   {ch_url}")
        
        ch_content = self.fetch_webpage(ch_url)
        
        # Step 2: Ask each question
        for i, question in enumerate(questions, 1):
            print(f"\n❓ Question {i}: {question}")
            
            # Let the LLM figure out where to look
            answer = self.ask_llm(question, ch_content)
            print(f"   💡 Answer: {answer}")
            
            # Store answer with sanitized key
            key = f"q{i}_{question[:30].lower().replace(' ', '_').replace('?', '')}"
            result[key] = answer
            
            time.sleep(0.5)  # Rate limiting
        
        return result


def example_employee_count():
    """Example: Find employee count from Companies House"""
    
    agent = SimpleLLMAgent()
    
    # Example company
    company = "GKN AEROSPACE SERVICES LIMITED"
    ch_number = "00000000"  # Replace with real CH number
    
    questions = [
        "How many employees did this company have in 2024?",
        "How many employees did this company have in 2023?",
        "What is the company's main business activity or SIC code?",
        "Is this company still active or dissolved?"
    ]
    
    result = agent.research_company(company, ch_number, questions)
    
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    print(json.dumps(result, indent=2))
    
    return result


def example_aerospace_verification():
    """Example: Verify aerospace credentials"""
    
    agent = SimpleLLMAgent()
    
    company = "SENIOR AEROSPACE BIRD BELLOWS LIMITED"
    ch_number = "00378900"  # Real CH number for example
    
    questions = [
        "What does this company manufacture or do?",
        "Does the company description mention aerospace, aviation, or aircraft?",
        "What are the company's registered SIC codes?",
        "How many employees does the company have?",
        "What is the company's registered address postcode?"
    ]
    
    result = agent.research_company(company, ch_number, questions)
    return result


def batch_process_spreadsheet(input_csv: str, output_csv: str):
    """Process a spreadsheet of companies"""
    
    agent = SimpleLLMAgent()
    
    # Define your questions
    questions = [
        "How many employees did this company have in 2024?",
        "How many employees did this company have in 2023?",
        "What is the main business activity?",
        "Does the description mention aerospace, aviation, or aircraft?",
        "Is this an active or dissolved company?"
    ]
    
    # Read input
    df = pd.read_csv(input_csv)
    
    print(f"\n🚀 Processing {len(df)} companies...")
    print(f"📝 Questions to ask:")
    for i, q in enumerate(questions, 1):
        print(f"   {i}. {q}")
    print()
    
    results = []
    
    for idx, row in df.iterrows():
        company_name = row['company_name']
        ch_number = str(row['companies_house_number'])
        
        try:
            result = agent.research_company(company_name, ch_number, questions)
            results.append(result)
            
            # Save progress
            pd.DataFrame(results).to_csv(output_csv, index=False)
            
            print(f"\n✅ Progress: {idx + 1}/{len(df)}")
            
            time.sleep(1)  # Be nice to APIs
            
        except Exception as e:
            print(f"\n❌ Error: {e}")
            results.append({
                'company_name': company_name,
                'companies_house_number': ch_number,
                'error': str(e)
            })
    
    print(f"\n✅ Complete! Results saved to: {output_csv}")
    return results


def interactive_mode():
    """Interactive research mode"""
    
    agent = SimpleLLMAgent()
    
    print("\n🤖 LLM Research Agent - Interactive Mode")
    print("="*50)
    
    company_name = input("\nCompany name: ")
    ch_number = input("Companies House number: ")
    
    print("\nEnter your questions (one per line, empty line to finish):")
    questions = []
    while True:
        q = input(f"  Question {len(questions) + 1}: ")
        if not q:
            break
        questions.append(q)
    
    if not questions:
        print("No questions provided!")
        return
    
    result = agent.research_company(company_name, ch_number, questions)
    
    print("\n" + "="*50)
    print("RESULTS")
    print("="*50)
    print(json.dumps(result, indent=2))


# =============================================================================
# SIMPLE EXAMPLES
# =============================================================================

def simple_example():
    """Super simple one-off query"""
    
    # Initialize
    agent = SimpleLLMAgent()
    
    # Fetch webpage
    url = "https://find-and-update.company-information.service.gov.uk/company/00378900"
    content = agent.fetch_webpage(url)
    
    # Ask question
    answer = agent.ask_llm(
        "How many employees did this company have in 2023?",
        context=content
    )
    
    print(f"Answer: {answer}")


def simple_multi_question():
    """Ask multiple questions about one company"""
    
    agent = SimpleLLMAgent()
    
    # One company
    ch_number = "00378900"
    url = f"https://find-and-update.company-information.service.gov.uk/company/{ch_number}"
    content = agent.fetch_webpage(url)
    
    # Multiple questions
    questions = [
        "How many employees in 2024?",
        "How many employees in 2023?",
        "What is the SIC code?",
        "Is the company active?"
    ]
    
    for q in questions:
        answer = agent.ask_llm(q, context=content)
        print(f"Q: {q}")
        print(f"A: {answer}\n")


# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) == 1:
        # No args - show examples
        print("\nUsage Examples:")
        print("-" * 50)
        print("\n1. Simple one question:")
        print("   python llm_research_agent.py simple")
        print("\n2. Multiple questions:")
        print("   python llm_research_agent.py multi")
        print("\n3. Employee count example:")
        print("   python llm_research_agent.py employee")
        print("\n4. Aerospace verification:")
        print("   python llm_research_agent.py aerospace")
        print("\n5. Batch process CSV:")
        print("   python llm_research_agent.py batch input.csv output.csv")
        print("\n6. Interactive mode:")
        print("   python llm_research_agent.py interactive")
        print()
        
    elif sys.argv[1] == "simple":
        simple_example()
    
    elif sys.argv[1] == "multi":
        simple_multi_question()
    
    elif sys.argv[1] == "employee":
        example_employee_count()
    
    elif sys.argv[1] == "aerospace":
        example_aerospace_verification()
    
    elif sys.argv[1] == "batch" and len(sys.argv) == 4:
        batch_process_spreadsheet(sys.argv[2], sys.argv[3])
    
    elif sys.argv[1] == "interactive":
        interactive_mode()
    
    else:
        print("Invalid arguments. Run without args to see usage.")