#!/usr/bin/env python3
"""
SUPER SIMPLE LLM AGENT - Copy/Paste Ready
Just change the company details and questions!

Setup:
    pip install groq requests beautifulsoup4
    export GROQ_API_KEY="your_key_here"
"""

import os
import requests
from bs4 import BeautifulSoup
from groq import Groq

# ============================================================================
# CONFIGURATION - CHANGE THESE!
# ============================================================================

GROQ_API_KEY = os.environ.get('GROQ_API_KEY')  # Or paste your key here: "gsk_..."

COMPANY_NAME = "Senior Aerospace Bird Bellows"
COMPANIES_HOUSE_NUMBER = "00378900"

QUESTIONS = [
    "How many employees did this company have in 2024?",
    "How many employees did this company have in 2023?",
    "What is the company's main business activity?",
    "Does the company mention aerospace, aviation or aircraft?",
]

# ============================================================================
# THE MAGIC HAPPENS HERE (Don't need to change below)
# ============================================================================

def fetch_page(url):
    """Get webpage content"""
    response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'})
    soup = BeautifulSoup(response.text, 'html.parser')
    for script in soup(["script", "style"]):
        script.decompose()
    text = soup.get_text()
    return ' '.join(text.split())[:15000]  # First 15k characters


def ask_llm(question, context):
    """Ask Groq LLM a question"""
    client = Groq(api_key=GROQ_API_KEY)
    
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{
            "role": "user",
            "content": f"Based on this information: {context}\n\nAnswer this question: {question}\n\nBe specific and concise."
        }],
        temperature=0.1,
        max_tokens=500
    )
    
    return response.choices[0].message.content


# ============================================================================
# RUN IT!
# ============================================================================

if __name__ == "__main__":
    print(f"\n{'='*70}")
    print(f"🔍 Researching: {COMPANY_NAME}")
    print(f"{'='*70}\n")
    
    # Get Companies House page
    url = f"https://find-and-update.company-information.service.gov.uk/company/{COMPANIES_HOUSE_NUMBER}"
    print(f"📄 Fetching: {url}\n")
    
    page_content = fetch_page(url)
    print(f"✅ Got {len(page_content)} characters of content\n")
    
    # Ask each question
    for i, question in enumerate(QUESTIONS, 1):
        print(f"❓ Question {i}: {question}")
        answer = ask_llm(question, page_content)
        print(f"💡 Answer: {answer}\n")
    
    print("="*70)
    print("✅ Done!")