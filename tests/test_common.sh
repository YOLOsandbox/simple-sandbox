#!/bin/bash
# test_common.sh - Unified testing framework for YOLOsandbox
# Provides consistent output formatting and test tracking

# Color palette
export COLOR_RESET='\033[0m'
export COLOR_PASS='\033[0;32m'
export COLOR_FAIL='\033[0;31m'
export COLOR_WARN='\033[1;33m'
export COLOR_INFO='\033[0;36m'
export COLOR_HEADER='\033[0;35m'
export COLOR_BOLD='\033[1m'
export COLOR_DIM='\033[2m'

# Icons
export ICON_PASS="✓"
export ICON_FAIL="✗"
export ICON_WARN="⚠"
export ICON_INFO="ℹ"
export ICON_RUN="→"

# Test tracking
export TESTS_RUN=0
export TESTS_PASSED=0
export TESTS_FAILED=0
export FAILED_TESTS=""
export CURRENT_GROUP=""

# Print test suite header
print_header() {
    local title="$1"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${COLOR_HEADER}${COLOR_BOLD}YOLOSANDBOX TEST SUITE${COLOR_RESET}"
    echo -e "${COLOR_INFO}${title}${COLOR_RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Start a new test group
start_group() {
    CURRENT_GROUP="$1"
    echo ""
    echo -e "${COLOR_BOLD}[TEST GROUP: $1]${COLOR_RESET}"
}

# Run a test and track results
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected="$3"  # "pass" or "fail"
    
    ((TESTS_RUN++))
    
    # Run test silently
    eval "$test_cmd" >/dev/null 2>&1
    local result=$?
    
    # Determine pass/fail
    local passed=false
    if [[ "$expected" == "pass" && $result -eq 0 ]] || \
       [[ "$expected" == "fail" && $result -ne 0 ]]; then
        passed=true
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
        FAILED_TESTS="${FAILED_TESTS}\n  - ${CURRENT_GROUP}: ${test_name}"
    fi
    
    # Print result with consistent formatting
    if $passed; then
        printf "  ${COLOR_PASS}${ICON_PASS}${COLOR_RESET} %-50s ${COLOR_PASS}PASS${COLOR_RESET}\n" "$test_name"
    else
        printf "  ${COLOR_FAIL}${ICON_FAIL}${COLOR_RESET} %-50s ${COLOR_FAIL}FAIL${COLOR_RESET}\n" "$test_name"
    fi
}

# Print test summary
print_summary() {
    local percentage=0
    if [ $TESTS_RUN -gt 0 ]; then
        percentage=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    
    echo ""
    echo -e "${COLOR_BOLD}════════════════════════════════════════════════════════════════════${COLOR_RESET}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${COLOR_PASS}${COLOR_BOLD}✅ ALL TESTS PASSED${COLOR_RESET}"
    else
        echo -e "${COLOR_WARN}${COLOR_BOLD}⚠ SOME TESTS FAILED${COLOR_RESET}"
        if [ -n "$FAILED_TESTS" ]; then
            echo -e "${COLOR_FAIL}Failed tests:${FAILED_TESTS}${COLOR_RESET}"
        fi
    fi
    
    echo -e "Summary: ${COLOR_BOLD}${TESTS_PASSED}/${TESTS_RUN}${COLOR_RESET} tests passed (${percentage}%)"
    echo -e "${COLOR_BOLD}════════════════════════════════════════════════════════════════════${COLOR_RESET}"
}