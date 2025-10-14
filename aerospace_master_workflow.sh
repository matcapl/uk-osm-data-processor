#!/bin/bash
# Master Automation Workflow
# One command to rule them all - complete pipeline execution with reporting

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

WORKFLOW_START=$(date +%s)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    UK AEROSPACE SUPPLIER INTELLIGENCE SYSTEM              ║${NC}"
echo -e "${CYAN}║    Master Workflow Automation                             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ==============================================================================
# Parse Arguments
# ==============================================================================

FULL_RUN=false
QUICK_RUN=false
REPORT_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --full)
      FULL_RUN=true
      shift
      ;;
    --quick)
      QUICK_RUN=true
      shift
      ;;
    --report-only)
      REPORT_ONLY=true
      shift
      ;;
    --help)
      echo "Usage: bash aerospace_master_workflow.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --full          Run complete pipeline (all geometries)"
      echo "  --quick         Quick run (polygon only, for testing)"
      echo "  --report-only   Skip pipeline, just generate reports"
      echo "  --help          Show this help message"
      echo ""
      echo "Examples:"
      echo "  bash aerospace_master_workflow.sh --full      # Complete run"
      echo "  bash aerospace_master_workflow.sh --quick     # Test run"
      echo "  bash aerospace_master_workflow.sh --report-only  # Just reports"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Default to full run if no args
if [ "$FULL_RUN" = false ] && [ "$QUICK_RUN" = false ] && [ "$REPORT_ONLY" = false ]; then
    FULL_RUN=true
fi

# ==============================================================================
# PHASE 1: Pipeline Execution
# ==============================================================================

if [ "$REPORT_ONLY" = false ]; then
    echo -e "${BLUE}[PHASE 1]${NC} Pipeline Execution"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ "$QUICK_RUN" = true ]; then
        echo "Running quick mode (polygon only)..."
        bash 07_pipeline_polygon.sh
    else
        echo "Running full pipeline (all geometries)..."
        
        echo -e "${YELLOW}→${NC} Processing polygons..."
        bash 07_pipeline_polygon.sh
        
        echo -e "${YELLOW}→${NC} Processing points..."
        bash 07_pipeline_point.sh
        
        echo -e "${YELLOW}→${NC} Processing lines..."
        bash 07_pipeline_line.sh
        
        echo -e "${YELLOW}→${NC} Processing roads..."
        bash 07_pipeline_roads.sh
    fi

    echo ""
    echo -e "${YELLOW}→${NC} Creating unified table..."
    psql -d uk_osm_full -f create_final_table.sql -q

    echo -e "${GREEN}✓${NC} Pipeline execution complete"
    echo ""
fi

# ==============================================================================
# PHASE 2: Validation & Quality Checks
# ==============================================================================

echo -e "${BLUE}[PHASE 2]${NC} Validation & Quality Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Quick metrics
echo -e "${YELLOW}→${NC} Running quality checks..."

TOTAL=$(psql -d uk_osm_full -t -A -c "SELECT COUNT(*) FROM aerospace_supplier_candidates;")
TIER1=$(psql -d uk_osm_full -t -A -c "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE tier_classification = 'tier1_candidate';")
TIER2=$(psql -d uk_osm_full -t -A -c "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE tier_classification = 'tier2_candidate';")
SUSPICIOUS=$(psql -d uk_osm_full -t -A -c "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE aerospace_score >= 80 AND (building_type IN ('house', 'apartments', 'residential') OR LOWER(name) ~* '(cafe|restaurant|hotel|pub)');")

echo ""
echo "Quick Metrics:"
echo "  Total Candidates: $TOTAL"
echo "  Tier 1: $TIER1"
echo "  Tier 2: $TIER2"
echo "  Suspicious Records: $SUSPICIOUS"
echo ""

if [ "$SUSPICIOUS" -gt 50 ]; then
    echo -e "${RED}⚠${NC}  High number of suspicious records detected!"
    echo "     Consider reviewing exclusion filters."
fi

if [ "$TOTAL" -eq 0 ]; then
    echo -e "${RED}✗${NC} ERROR: No candidates found!"
    echo "     Check diagnose_pipeline.sql for debugging."
    exit 1
fi

echo -e "${GREEN}✓${NC} Validation complete"
echo ""

# ==============================================================================
# PHASE 3: Coverage Analysis
# ==============================================================================

echo -e "${BLUE}[PHASE 3]${NC} Coverage Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${YELLOW}→${NC} Checking known supplier coverage..."
psql -d uk_osm_full -f known_suppliers_check.sql -q > /tmp/coverage_check.txt 2>&1

# Extract key coverage metric
COVERAGE=$(grep "Coverage %" /tmp/coverage_check.txt | awk -F'|' '{print $3}' | tr -d ' ')

echo "Known Supplier Coverage: ${COVERAGE}"
echo ""

if [ ! -z "$COVERAGE" ]; then
    COVERAGE_NUM=$(echo "$COVERAGE" | tr -d '%')
    if [ "$COVERAGE_NUM" -lt 50 ]; then
        echo -e "${YELLOW}⚠${NC}  Coverage below 50% - consider:"
        echo "     1. Checking if suppliers exist in OSM"
        echo "     2. Reviewing keyword patterns"
        echo "     3. Adjusting geographic filters"
        echo ""
    fi
fi

echo -e "${GREEN}✓${NC} Coverage analysis complete"
echo ""

# ==============================================================================
# PHASE 4: Export Results
# ==============================================================================

echo -e "${BLUE}[PHASE 4]${NC} Export Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${YELLOW}→${NC} Generating CSV exports..."
bash 08_export_results.sh -q 2>&1 | grep "✓"

echo ""
echo -e "${GREEN}✓${NC} Exports complete"
echo ""

# ==============================================================================
# PHASE 5: Intelligence Reports
# ==============================================================================

echo -e "${BLUE}[PHASE 5]${NC} Intelligence Reports"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${YELLOW}→${NC} Generating weekly intelligence report..."
bash generate_weekly_report.sh 2>&1 | grep "✓"

echo ""
echo -e "${YELLOW}→${NC} Running power user queries..."
psql -d uk_osm_full -f power_user_queries.sql > ./reports/power_analysis_${TIMESTAMP}.txt

echo ""
echo -e "${GREEN}✓${NC} Reports generated"
echo ""

# ==============================================================================
# PHASE 6: Iterative Improvement Analysis
# ==============================================================================

if [ "$REPORT_ONLY" = false ]; then
    echo -e "${BLUE}[PHASE 6]${NC} Improvement Analysis"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo -e "${YELLOW}→${NC} Running improvement analysis..."
    bash iterative_improvement.sh 2>&1 | tail -20

    echo ""
    echo -e "${GREEN}✓${NC} Improvement analysis complete"
    echo ""
fi

# ==============================================================================
# PHASE 7: Summary & Next Steps
# ==============================================================================

WORKFLOW_END=$(date +%s)
DURATION=$((WORKFLOW_END - WORKFLOW_START))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    WORKFLOW COMPLETE                                       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓${NC} Execution time: ${MINUTES}m ${SECONDS}s"
echo ""
echo "📊 Results Summary:"
echo "   • Total Candidates: $TOTAL"
echo "   • Tier 1 (High Confidence): $TIER1"
echo "   • Tier 2 (Target Segment): $TIER2"
echo "   • Ready for Outreach: $(psql -d uk_osm_full -t -A -c "SELECT COUNT(*) FROM aerospace_supplier_candidates WHERE aerospace_score >= 100 AND (website IS NOT NULL OR phone IS NOT NULL);")"
echo ""
echo "📁 Generated Files:"
echo "   • CSV Exports: ./exports/"
echo "   • Weekly Report: ./reports/weekly/"
echo "   • Power Analysis: ./reports/power_analysis_${TIMESTAMP}.txt"
if [ "$REPORT_ONLY" = false ]; then
    LATEST_ITERATION=$(ls -t iterations/ | head -1)
    echo "   • Improvement Analysis: ./iterations/${LATEST_ITERATION}/"
fi
echo ""
echo "🎯 Next Steps:"
echo ""
echo "   1. IMMEDIATE (Today):"
echo "      → Review: ./reports/weekly/aerospace_intel_$(date +%Y-%m-%d).md"
echo "      → Contact top 10 outreach targets"
echo ""
echo "   2. THIS WEEK:"
echo "      → Manually validate 30 random Tier 2 candidates"
echo "      → Research missing contact info (see weekly_research_needed CSV)"
echo "      → Review quality control alerts"
echo ""
echo "   3. ONGOING:"
echo "      → Run this workflow weekly: bash aerospace_master_workflow.sh --full"
echo "      → Track improvements in ./iterations/"
echo "      → Update scoring rules based on validation feedback"
echo ""
echo "📖 Documentation:"
echo "   • Complete Guide: COMPLETE_WORKFLOW_GUIDE.md"
echo "   • Scoring Strategy: WORLD_CLASS_SCORING_STRATEGY.md"
echo "   • Power Queries: power_user_queries.sql"
echo ""

# ==============================================================================
# Optional: Open Reports (macOS)
# ==============================================================================

if [[ "$OSTYPE" == "darwin"* ]]; then
    read -p "Open weekly report in browser? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        LATEST_REPORT=$(ls -t reports/weekly/*.html 2>/dev/null | head -1)
        if [ ! -z "$LATEST_REPORT" ]; then
            open "$LATEST_REPORT"
        else
            LATEST_MD=$(ls -t reports/weekly/*.md | head -1)
            if [ ! -z "$LATEST_MD" ]; then
                open "$LATEST_MD"
            fi
        fi
    fi
fi

echo ""
echo -e "${CYAN}Have a great day! 🚀${NC}"
echo ""