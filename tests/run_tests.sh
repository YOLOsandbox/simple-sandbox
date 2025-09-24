#!/bin/bash
# run_tests.sh - Master test runner for YOLOsandbox

# Change to test directory
cd "$(dirname "$0")" || exit 1

# Track suite results
SUITE_PASSED=0
SUITE_FAILED=0
declare -A TEST_RESULTS

# Color definitions for main runner
COLOR_BOLD='\033[1m'
COLOR_RESET='\033[0m'

# Visual header
echo ""
echo -e "${COLOR_BOLD}YOLOSANDBOX TEST SUITE ${COLOR_RESET}"
echo -e "Security & Environment Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Test execution started: $(date)"

# Discover and run test files
for test_file in test_*.sh; do
    [[ "$test_file" == "test_common.sh" ]] && continue
    
    if [[ -f "$test_file" ]]; then
        # Source just the metadata (first 20 lines should contain it)
        TEST_NAME=""
        TEST_DESCRIPTION=""
        TEST_CATEGORY=""
        eval "$(head -20 "$test_file" | grep -E '^TEST_')"
        
        if [[ -n "$TEST_NAME" ]]; then
            echo ""
            echo "Running ${TEST_NAME} Tests..."
            
            if ./"$test_file"; then
                ((SUITE_PASSED++))
                TEST_RESULTS["${TEST_CATEGORY}"]="✅ PASS"
            else
                ((SUITE_FAILED++))
                TEST_RESULTS["${TEST_CATEGORY}"]="❌ FAIL"
            fi
        fi
    fi
done

# Feature Coverage Report
echo ""
echo ""
echo -e "${COLOR_BOLD}FEATURE COVERAGE REPORT${COLOR_RESET}"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Security Features:"
echo "  • Capability Restrictions ................. ${TEST_RESULTS[security]}"
echo "  • Filesystem Isolation .................... ${TEST_RESULTS[security]}"
echo "  • Sudo Restrictions ....................... ${TEST_RESULTS[security]}"
echo "  • Container Isolation ..................... ${TEST_RESULTS[security]}"
echo "  • Resource Limits ......................... ${TEST_RESULTS[security]}"
echo ""
echo "Development Environment:"
echo "  • Python/UV Stack ......................... ${TEST_RESULTS[environment]}"
echo "  • Node.js/NPM Stack ....................... ${TEST_RESULTS[environment]}"
echo "  • Workspace Access ........................ ${TEST_RESULTS[environment]}"
echo "  • Network Connectivity .................... ${TEST_RESULTS[environment]}"
echo "  • Package Management ...................... ${TEST_RESULTS[environment]}"
echo ""
echo "Data Persistence:"
echo "  • Claude Data Volume ...................... ${TEST_RESULTS[persistence]}"
echo ""
echo "═══════════════════════════════════════════════════════════════════"

# Final result
if [ $SUITE_FAILED -eq 0 ]; then
    echo "  ✅ ALL FEATURES VALIDATED - All systems operational"
    exit 0
else
    echo "  ⚠️  VALIDATION FAILED - $SUITE_FAILED suite(s) with failures"
    exit 1
fi