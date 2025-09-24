#!/bin/bash
# test_environment.sh - Validates development environment features

# Test metadata
TEST_NAME="Environment"
TEST_DESCRIPTION="Development Environment"
TEST_CATEGORY="environment"

source ./test_common.sh

# Source NVM for Node.js tools
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

print_header "$TEST_DESCRIPTION"

# FEATURE: Python Development Stack
start_group "Python Stack"
run_test "UV package manager installed" "which uv >/dev/null 2>&1" "pass"
run_test "Python 3.11 available" "uv python list 2>/dev/null | grep -q '3\.11'" "pass"
run_test "UV pip functional" "uv pip list >/dev/null 2>&1" "pass"

# FEATURE: Node.js Development Stack  
start_group "Node.js Stack"
run_test "Node.js v22+ installed" "node -v 2>/dev/null | grep -qE 'v2[2-9]|v[3-9]'" "pass"
run_test "NPM available" "which npm >/dev/null 2>&1" "pass"
run_test "NVM directory exists" "test -d \$HOME/.nvm" "pass"

# FEATURE: AI CLI Tools
start_group "AI CLI Tools"
run_test "Claude Code installed" "claude --version >/dev/null 2>&1" "pass"
run_test "Gemini CLI installed" "gemini --version >/dev/null 2>&1" "pass"

# FEATURE: Workspace Access
start_group "Workspace Access"
run_test "Workspace mounted" "test -d /workspace" "pass"
run_test "Workspace writable" "touch /workspace/.test_\$\$ && rm /workspace/.test_\$\$" "pass"
run_test "Can create directories" "mkdir -p /workspace/test_\$\$ && rmdir /workspace/test_\$\$" "pass"

# FEATURE: Network Connectivity
start_group "Network Connectivity"
run_test "DNS resolution works" "nslookup google.com >/dev/null 2>&1" "pass"
run_test "HTTP connectivity" "curl -s -o /dev/null -w '%{http_code}' http://example.com | grep -q 200" "pass"
run_test "HTTPS connectivity" "curl -s -o /dev/null -w '%{http_code}' https://example.com | grep -q 200" "pass"

# FEATURE: Package Management
start_group "Package Management"
run_test "APT update works" "timeout 30 sudo apt-get update >/dev/null 2>&1" "pass"
run_test "Python packages work" "uv pip list >/dev/null 2>&1" "pass"
run_test "NPM global packages" "npm list -g --depth=0 >/dev/null 2>&1" "pass"

print_summary
exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)