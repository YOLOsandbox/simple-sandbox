#!/bin/bash
# test_persistence.sh - Validates data persistence features

# Test metadata
TEST_NAME="Persistence"
TEST_DESCRIPTION="Data Persistence"
TEST_CATEGORY="persistence"

source ./test_common.sh

print_header "$TEST_DESCRIPTION"

# FEATURE: Claude Data Volume
start_group "Claude Data Directory"
CLAUDE_DIR="/home/developer/.claude"
run_test "Claude directory exists" "test -d $CLAUDE_DIR" "pass"
run_test "Claude directory writable" "touch $CLAUDE_DIR/.test_$$ && rm $CLAUDE_DIR/.test_$$" "pass"
run_test "Correct ownership" "[ \$(stat -c '%U:%G' $CLAUDE_DIR) = 'developer:developer' ]" "pass"

start_group "Persistence Verification"
MARKER="$CLAUDE_DIR/.persistence-marker"
if [ -f "$MARKER" ]; then
    run_test "Persistence marker found" "test -f $MARKER" "pass"
    echo -e "  ${COLOR_INFO}Previous run: $(cat $MARKER)${COLOR_RESET}"
else
    run_test "Creating persistence marker" "date > $MARKER" "pass"
fi

print_summary
exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)