#!/usr/bin/env bash
# Test script for duckdns_setup.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DUCKDNS_SCRIPT="${SCRIPT_DIR}/duckdns_setup.sh"
TEST_LOG="/tmp/duckdns_test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((passed++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((failed++))
}

# Test 1: Script is executable
log_test "Checking if duckdns_setup.sh is executable"
if [[ -x "$DUCKDNS_SCRIPT" ]]; then
    log_pass "Script is executable"
else
    log_fail "Script is not executable"
fi

# Test 2: Help command works
log_test "Testing help command"
if "$DUCKDNS_SCRIPT" help > "$TEST_LOG" 2>&1; then
    if grep -q "DuckDNS Setup and Update Script" "$TEST_LOG"; then
        log_pass "Help command displays usage information"
    else
        log_fail "Help command output is incorrect"
    fi
else
    log_fail "Help command failed"
fi

# Test 3: No command shows error
log_test "Testing error handling for no command"
if ! "$DUCKDNS_SCRIPT" > "$TEST_LOG" 2>&1; then
    if grep -q "No command specified" "$TEST_LOG"; then
        log_pass "Correctly detects missing command"
    else
        log_fail "Error message not shown for missing command"
    fi
else
    log_fail "Should fail when no command provided"
fi

# Test 4: Invalid command shows error
log_test "Testing error handling for invalid command"
if ! "$DUCKDNS_SCRIPT" invalid_command > "$TEST_LOG" 2>&1; then
    if grep -q "Unknown command" "$TEST_LOG"; then
        log_pass "Correctly detects invalid command"
    else
        log_fail "Error message not shown for invalid command"
    fi
else
    log_fail "Should fail for invalid command"
fi

# Test 5: Update without config shows error
log_test "Testing update command without configuration"
# Remove any existing config for this test
rm -f "${SCRIPT_DIR}/.duckdns.conf"
if ! "$DUCKDNS_SCRIPT" update > "$TEST_LOG" 2>&1; then
    if grep -q "DuckDNS not configured" "$TEST_LOG"; then
        log_pass "Correctly detects missing configuration"
    else
        log_fail "Error message not shown for missing config"
    fi
else
    log_fail "Should fail when config is missing"
fi

# Test 6: Status without config shows error
log_test "Testing status command without configuration"
if ! "$DUCKDNS_SCRIPT" status > "$TEST_LOG" 2>&1; then
    if grep -q "DuckDNS not configured" "$TEST_LOG"; then
        log_pass "Status correctly detects missing configuration"
    else
        log_fail "Status error message not shown for missing config"
    fi
else
    log_fail "Status should fail when config is missing"
fi

# Test 7: Example config file exists
log_test "Checking if example config file exists"
if [[ -f "${SCRIPT_DIR}/.duckdns.conf.example" ]]; then
    log_pass "Example config file exists"
else
    log_fail "Example config file is missing"
fi

# Test 8: Script has proper shebang
log_test "Checking script shebang"
if head -n 1 "$DUCKDNS_SCRIPT" | grep -q "#!/usr/bin/env bash"; then
    log_pass "Script has correct shebang"
else
    log_fail "Script shebang is incorrect"
fi

# Test 9: Script passes shellcheck (if available)
log_test "Running shellcheck (if available)"
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck "$DUCKDNS_SCRIPT" > "$TEST_LOG" 2>&1; then
        log_pass "Script passes shellcheck"
    else
        log_fail "Script has shellcheck issues"
        cat "$TEST_LOG"
    fi
else
    echo "  Skipping (shellcheck not installed)"
fi

# Test 10: Documentation files exist
log_test "Checking documentation files"
docs_ok=true
if [[ ! -f "${SCRIPT_DIR}/DUCKDNS_SETUP.md" ]]; then
    log_fail "DUCKDNS_SETUP.md is missing"
    docs_ok=false
fi
if [[ ! -f "${SCRIPT_DIR}/DUCKDNS_QUICKSTART.sh" ]]; then
    log_fail "DUCKDNS_QUICKSTART.sh is missing"
    docs_ok=false
fi
if [[ "$docs_ok" == "true" ]]; then
    log_pass "All documentation files exist"
fi

# Test 11: .gitignore includes sensitive files
log_test "Checking .gitignore for sensitive files"
if [[ -f "${SCRIPT_DIR}/.gitignore" ]]; then
    if grep -q ".duckdns.conf" "${SCRIPT_DIR}/.gitignore" && grep -q ".duckdns.log" "${SCRIPT_DIR}/.gitignore"; then
        log_pass ".gitignore protects sensitive files"
    else
        log_fail ".gitignore does not protect .duckdns.conf and .duckdns.log"
    fi
else
    log_fail ".gitignore file is missing"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Results:"
echo "  Passed: $passed"
echo "  Failed: $failed"
echo "=========================================="

if [[ $failed -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
