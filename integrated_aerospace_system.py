#!/usr/bin/env python3
"""
INTEGRATED AEROSPACE INTELLIGENCE SYSTEM
Ties together: Database → Filtering → LLM Verification → Feedback Loop

Shows impact of different criteria on results in real-time
"""

import os
import psycopg2
import pandas as pd
from groq import Groq
import requests
from bs4 import BeautifulSoup
from typing import Dict, List
import time
from datetime import datetime

# ============================================================================
# CONFIGURATION - CHANGE THESE TO SEE IMPACT!
# ============================================================================

# Database connection
DB_CONFIG = {
    'dbname': 'uk_osm_full',
    'user': 'a',
    'password': '',
    'host': 'localhost',
    'port': 5432
}

# Groq API
GROQ_API_KEY = os.environ.get('GROQ_API_KEY')

# ============================================================================
# FILTERING CRITERIA - ADJUST THESE TO SEE IMPACT
# ============================================================================

CRITERIA = {
    # Score thresholds
    'min_aerospace_score': 80,        # Try: 40, 60, 80, 100, 120
    'max_aerospace_score': 300,
    
    # Geographic filters
    'required_postcode_areas': [],    # Try: ['BS', 'GL', 'DE'] or []
    'exclude_postcode_areas': [],     # Try: ['LE', 'HD'] or []
    
    # Classification filters
    'tier_classifications': ['tier1_candidate', 'tier2_candidate'],  
    # Try: ['tier1_candidate'] or ['tier2_candidate'] or both
    
    # Required fields
    'require_name': True,              # Try: True or False
    'require_postcode': False,         # Try: True or False
    'require_website': False,          # Try: True or False
    
    # Industrial indicators
    'require_industrial_landuse': False,  # Try: True or False
    'require_industrial_building': False, # Try: True or False
    
    # Keyword filters
    'required_keywords': [],           # Try: ['aerospace', 'precision'] or []
    'exclude_keywords': ['cafe', 'restaurant', 'hotel', 'retail'],
    
    # Source tables
    'source_tables': ['planet_osm_polygon', 'planet_osm_point'],
    # Try: ['planet_osm_polygon'] or all four
    
    # Limits
    'max_results': 50,                 # Try: 10, 50, 100
}

# ============================================================================
# KNOWN AEROSPACE SUPPLIERS (Ground Truth)
# ============================================================================

KNOWN_SUPPLIERS = [
    {'name': 'Airbus', 'location': 'Bristol', 'postcode': 'BS34'},
    {'name': 'Rolls-Royce', 'location': 'Derby', 'postcode': 'DE24'},
    {'name': 'BAE Systems', 'location': 'Preston', 'postcode': 'PR'},
    {'name': 'Leonardo', 'location': 'Yeovil', 'postcode': 'BA20'},
    {'name': 'GKN Aerospace', 'location': 'Redditch', 'postcode': 'B98'},
    {'name': 'Senior Aerospace', 'location': 'Various', 'postcode': None},
    {'name': 'Meggitt', 'location': 'Coventry', 'postcode': 'CV'},
    {'name': 'Spirit AeroSystems', 'location': 'Belfast', 'postcode': 'BT'},
]

# ============================================================================
# SYSTEM CLASS
# ============================================================================

class IntegratedAerospaceSystem:
    """Complete system: Database → Filter → Verify → Analyze"""
    
    def __init__(self, db_config, groq_api_key, criteria):
        self.db_config = db_config
        self.groq_client = Groq(api_key=groq_api_key) if groq_api_key else None
        self.criteria = criteria
        self.conn = None
        
    def connect_db(self):
        """Connect to PostgreSQL"""
        try:
            self.conn = psycopg2.connect(**self.db_config)
            print("✅ Connected to database")
            return True
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def build_query(self) -> str:
        """Build SQL query based on criteria"""
        
        # Base SELECT
        query = """
        SELECT 
            osm_id,
            source_table,
            name,
            aerospace_score,
            tier_classification,
            postcode,
            city,
            website,
            phone,
            landuse_type,
            building_type,
            industrial_type,
            matched_keywords,
            latitude,
            longitude
        FROM aerospace_supplier_candidates
        WHERE 1=1
        """
        
        # Score filters
        query += f"\n  AND aerospace_score >= {self.criteria['min_aerospace_score']}"
        query += f"\n  AND aerospace_score <= {self.criteria['max_aerospace_score']}"
        
        # Tier classification
        if self.criteria['tier_classifications']:
            tiers = "', '".join(self.criteria['tier_classifications'])
            query += f"\n  AND tier_classification IN ('{tiers}')"
        
        # Required fields
        if self.criteria['require_name']:
            query += "\n  AND name IS NOT NULL AND name != ''"
        
        if self.criteria['require_postcode']:
            query += "\n  AND postcode IS NOT NULL"
        
        if self.criteria['require_website']:
            query += "\n  AND website IS NOT NULL"
        
        # Industrial indicators
        if self.criteria['require_industrial_landuse']:
            query += "\n  AND landuse_type = 'industrial'"
        
        if self.criteria['require_industrial_building']:
            query += "\n  AND building_type IN ('industrial', 'warehouse', 'factory')"
        
        # Geographic filters
        if self.criteria['required_postcode_areas']:
            areas = "', '".join(self.criteria['required_postcode_areas'])
            query += f"\n  AND LEFT(postcode, 2) IN ('{areas}')"
        
        if self.criteria['exclude_postcode_areas']:
            areas = "', '".join(self.criteria['exclude_postcode_areas'])
            query += f"\n  AND (postcode IS NULL OR LEFT(postcode, 2) NOT IN ('{areas}'))"
        
        # Keyword filters
        if self.criteria['exclude_keywords']:
            for keyword in self.criteria['exclude_keywords']:
                query += f"\n  AND LOWER(name) NOT LIKE '%{keyword}%'"
        
        if self.criteria['required_keywords']:
            keyword_conditions = " OR ".join([
                f"LOWER(name) LIKE '%{kw}%'" for kw in self.criteria['required_keywords']
            ])
            query += f"\n  AND ({keyword_conditions})"
        
        # Source tables
        if self.criteria['source_tables']:
            tables = "', '".join(self.criteria['source_tables'])
            query += f"\n  AND source_table IN ('{tables}')"
        
        # Order and limit
        query += "\nORDER BY aerospace_score DESC"
        query += f"\nLIMIT {self.criteria['max_results']}"
        
        return query
    
    def fetch_candidates(self) -> pd.DataFrame:
        """Fetch candidates from database based on criteria"""
        
        query = self.build_query()
        
        print("\n" + "="*70)
        print("📊 SQL QUERY GENERATED:")
        print("="*70)
        print(query)
        print("="*70 + "\n")
        
        try:
            df = pd.read_sql_query(query, self.conn)
            return df
        except Exception as e:
            print(f"❌ Query failed: {e}")
            return pd.DataFrame()
    
    def analyze_coverage(self, candidates_df: pd.DataFrame) -> Dict:
        """Check how many known suppliers we captured"""
        
        print("\n" + "="*70)
        print("🎯 COVERAGE ANALYSIS - Known Suppliers")
        print("="*70)
        
        found_suppliers = []
        missing_suppliers = []
        
        for supplier in KNOWN_SUPPLIERS:
            # Check if any candidate matches this known supplier
            matches = candidates_df[
                candidates_df['name'].str.contains(supplier['name'], case=False, na=False)
            ]
            
            if len(matches) > 0:
                found_suppliers.append(supplier)
                print(f"  ✅ FOUND: {supplier['name']} (Score: {matches.iloc[0]['aerospace_score']})")
            else:
                missing_suppliers.append(supplier)
                print(f"  ❌ MISSING: {supplier['name']} in {supplier['location']}")
        
        coverage = len(found_suppliers) / len(KNOWN_SUPPLIERS) * 100
        
        print(f"\n  Coverage: {len(found_suppliers)}/{len(KNOWN_SUPPLIERS)} ({coverage:.1f}%)")
        print("="*70 + "\n")
        
        return {
            'found': found_suppliers,
            'missing': missing_suppliers,
            'coverage_pct': coverage
        }
    
    def analyze_distribution(self, candidates_df: pd.DataFrame):
        """Analyze the distribution of results"""
        
        print("\n" + "="*70)
        print("📊 RESULT DISTRIBUTION")
        print("="*70)
        
        if len(candidates_df) == 0:
            print("  ⚠️  No candidates found with current criteria!")
            return
        
        # By tier
        print("\n1. BY TIER:")
        tier_counts = candidates_df['tier_classification'].value_counts()
        for tier, count in tier_counts.items():
            print(f"   {tier}: {count}")
        
        # By score range
        print("\n2. BY SCORE RANGE:")
        score_bins = [0, 60, 80, 100, 120, 150, 200, 300]
        score_labels = ['<60', '60-79', '80-99', '100-119', '120-149', '150-199', '200+']
        candidates_df['score_range'] = pd.cut(
            candidates_df['aerospace_score'], 
            bins=score_bins, 
            labels=score_labels
        )
        for score_range, count in candidates_df['score_range'].value_counts().sort_index().items():
            print(f"   {score_range}: {count}")
        
        # By region
        print("\n3. BY REGION (Top 10):")
        candidates_df['region'] = candidates_df['postcode'].str[:2]
        region_counts = candidates_df['region'].value_counts().head(10)
        for region, count in region_counts.items():
            print(f"   {region}: {count}")
        
        # By source
        print("\n4. BY SOURCE TABLE:")
        source_counts = candidates_df['source_table'].value_counts()
        for source, count in source_counts.items():
            source_short = source.replace('planet_osm_', '')
            print(f"   {source_short}: {count}")
        
        # Data completeness
        print("\n5. DATA COMPLETENESS:")
        print(f"   With website: {candidates_df['website'].notna().sum()} ({candidates_df['website'].notna().sum()/len(candidates_df)*100:.1f}%)")
        print(f"   With phone: {candidates_df['phone'].notna().sum()} ({candidates_df['phone'].notna().sum()/len(candidates_df)*100:.1f}%)")
        print(f"   With postcode: {candidates_df['postcode'].notna().sum()} ({candidates_df['postcode'].notna().sum()/len(candidates_df)*100:.1f}%)")
        
        print("\n" + "="*70 + "\n")
    
    def llm_verify_sample(self, candidates_df: pd.DataFrame, sample_size: int = 5):
        """Use LLM to verify a sample of candidates"""
        
        if not self.groq_client:
            print("⚠️  Groq API key not set - skipping LLM verification")
            return
        
        if len(candidates_df) == 0:
            print("⚠️  No candidates to verify")
            return
        
        print("\n" + "="*70)
        print(f"🤖 LLM VERIFICATION - Sample of {min(sample_size, len(candidates_df))} candidates")
        print("="*70 + "\n")
        
        # Take a sample
        sample = candidates_df.head(sample_size)
        
        verified_count = 0
        
        for idx, row in sample.iterrows():
            print(f"📋 {row['name']}")
            print(f"   Score: {row['aerospace_score']} | Tier: {row['tier_classification']}")
            
            # Quick verification question
            prompt = f"""Is "{row['name']}" likely to be an aerospace supplier?
            
Consider:
- Name: {row['name']}
- Location: {row.get('city', 'Unknown')} ({row.get('postcode', 'No postcode')})
- Landuse: {row.get('landuse_type', 'Unknown')}
- Building: {row.get('building_type', 'Unknown')}

Answer YES, NO, or MAYBE with a brief reason."""
            
            try:
                response = self.groq_client.chat.completions.create(
                    model="llama-3.3-70b-versatile",
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.1,
                    max_tokens=150
                )
                
                answer = response.choices[0].message.content.strip()
                print(f"   🤖 LLM: {answer}")
                
                if answer.upper().startswith('YES'):
                    verified_count += 1
                
            except Exception as e:
                print(f"   ❌ Error: {e}")
            
            print()
            time.sleep(1)  # Rate limiting
        
        precision = verified_count / min(sample_size, len(candidates_df)) * 100
        print(f"✅ LLM Verification: {verified_count}/{min(sample_size, len(candidates_df))} confirmed ({precision:.1f}%)")
        print("="*70 + "\n")
    
    def compare_scenarios(self, scenarios: List[Dict]):
        """Compare multiple criteria scenarios side-by-side"""
        
        print("\n" + "="*70)
        print("🔬 SCENARIO COMPARISON")
        print("="*70 + "\n")
        
        results = []
        
        for i, scenario in enumerate(scenarios, 1):
            print(f"Running Scenario {i}: {scenario['name']}")
            
            # Temporarily update criteria
            old_criteria = self.criteria.copy()
            self.criteria.update(scenario['criteria'])
            
            # Fetch candidates
            candidates = self.fetch_candidates()
            
            # Analyze
            coverage = self.analyze_coverage(candidates)
            
            # Store results
            results.append({
                'scenario': scenario['name'],
                'total_candidates': len(candidates),
                'coverage_pct': coverage['coverage_pct'],
                'tier1_count': len(candidates[candidates['tier_classification'] == 'tier1_candidate']),
                'tier2_count': len(candidates[candidates['tier_classification'] == 'tier2_candidate']),
                'with_website': candidates['website'].notna().sum(),
            })
            
            # Restore criteria
            self.criteria = old_criteria
            
            print()
        
        # Summary table
        print("\n" + "="*70)
        print("📊 COMPARISON SUMMARY")
        print("="*70)
        
        comparison_df = pd.DataFrame(results)
        print(comparison_df.to_string(index=False))
        print("\n" + "="*70 + "\n")
        
        return comparison_df
    
    def run_full_analysis(self):
        """Run complete analysis with current criteria"""
        
        print("\n" + "🚀 "*35)
        print("    INTEGRATED AEROSPACE INTELLIGENCE SYSTEM")
        print("🚀 "*35 + "\n")
        
        print(f"⏰ Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        
        # Show current criteria
        print("="*70)
        print("⚙️  CURRENT CRITERIA:")
        print("="*70)
        for key, value in self.criteria.items():
            print(f"  {key}: {value}")
        print("="*70)
        
        # Connect to DB
        if not self.connect_db():
            return
        
        # Fetch candidates
        print("\n🔍 Fetching candidates from database...")
        candidates = self.fetch_candidates()
        
        print(f"\n✅ Retrieved {len(candidates)} candidates")
        
        if len(candidates) == 0:
            print("\n⚠️  NO CANDIDATES FOUND!")
            print("\n💡 Try adjusting criteria:")
            print("   - Lower min_aerospace_score")
            print("   - Remove required_postcode_areas")
            print("   - Set require_website = False")
            return
        
        # Analyze coverage
        coverage = self.analyze_coverage(candidates)
        
        # Analyze distribution
        self.analyze_distribution(candidates)
        
        # LLM verification (sample)
        if self.groq_client:
            self.llm_verify_sample(candidates, sample_size=3)
        
        # Save results
        output_file = f"analysis_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        candidates.to_csv(output_file, index=False)
        print(f"💾 Results saved to: {output_file}")
        
        # Final summary
        print("\n" + "="*70)
        print("📈 FINAL SUMMARY")
        print("="*70)
        print(f"  Total Candidates: {len(candidates)}")
        print(f"  Known Supplier Coverage: {coverage['coverage_pct']:.1f}%")
        print(f"  Tier 1: {len(candidates[candidates['tier_classification'] == 'tier1_candidate'])}")
        print(f"  Tier 2: {len(candidates[candidates['tier_classification'] == 'tier2_candidate'])}")
        print(f"  With Contact Info: {candidates['website'].notna().sum()}")
        print("="*70 + "\n")
        
        return candidates


# ============================================================================
# USAGE EXAMPLES
# ============================================================================

def example_single_run():
    """Example: Single run with current criteria"""
    
    system = IntegratedAerospaceSystem(DB_CONFIG, GROQ_API_KEY, CRITERIA)
    candidates = system.run_full_analysis()


def example_compare_scenarios():
    """Example: Compare different filtering strategies"""
    
    scenarios = [
        {
            'name': 'Conservative (High Precision)',
            'criteria': {
                'min_aerospace_score': 100,
                'tier_classifications': ['tier1_candidate'],
                'require_website': True,
                'required_postcode_areas': ['BS', 'GL', 'DE', 'PR'],
            }
        },
        {
            'name': 'Balanced',
            'criteria': {
                'min_aerospace_score': 80,
                'tier_classifications': ['tier1_candidate', 'tier2_candidate'],
                'require_website': False,
            }
        },
        {
            'name': 'Aggressive (High Recall)',
            'criteria': {
                'min_aerospace_score': 60,
                'tier_classifications': ['tier1_candidate', 'tier2_candidate', 'potential_candidate'],
                'require_postcode': False,
            }
        },
    ]
    
    system = IntegratedAerospaceSystem(DB_CONFIG, GROQ_API_KEY, CRITERIA)
    
    if system.connect_db():
        comparison = system.compare_scenarios(scenarios)
        print("\n💡 INSIGHTS:")
        print("  - Conservative finds fewer but higher quality")
        print("  - Balanced gives good precision/recall tradeoff")
        print("  - Aggressive captures more known suppliers")


def example_test_single_criterion():
    """Example: Test impact of ONE criterion"""
    
    print("\n🧪 TESTING: Impact of 'require_industrial_landuse'")
    print("="*70 + "\n")
    
    scenarios = [
        {
            'name': 'WITHOUT industrial landuse requirement',
            'criteria': {'require_industrial_landuse': False}
        },
        {
            'name': 'WITH industrial landuse requirement',
            'criteria': {'require_industrial_landuse': True}
        },
    ]
    
    system = IntegratedAerospaceSystem(DB_CONFIG, GROQ_API_KEY, CRITERIA)
    
    if system.connect_db():
        system.compare_scenarios(scenarios)


# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) == 1:
        print("\nUsage:")
        print("  python integrated_aerospace_system.py run      # Single run")
        print("  python integrated_aerospace_system.py compare  # Compare scenarios")
        print("  python integrated_aerospace_system.py test     # Test single criterion")
        print()
        
    elif sys.argv[1] == 'run':
        example_single_run()
    
    elif sys.argv[1] == 'compare':
        example_compare_scenarios()
    
    elif sys.argv[1] == 'test':
        example_test_single_criterion()
    
    else:
        print("Unknown command. Use: run, compare, or test")