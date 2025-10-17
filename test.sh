#!/usr/bin/env bash
# Basic validation tests for dot-termux scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
EXIT_CODE=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start(){
  TESTS_RUN=$((TESTS_RUN + 1))
  printf "Testing: %s ... " "$1"
}

test_pass(){
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf "${GREEN}✓${NC}\n"
}

test_fail(){
  TESTS_FAILED=$((TESTS_FAILED + 1))
  EXIT_CODE=1
  printf "${RED}✗${NC}\n"
  printf "  ${RED}Error: %s${NC}\n" "$1"
}

# ============================================================================
# SYNTAX VALIDATION TESTS
# ============================================================================

printf "\n${YELLOW}=== Syntax Validation ===${NC}\n"

test_start "common.sh syntax"
if bash -n "$REPO_ROOT/.config/bash/common.sh" 2>/dev/null; then
  test_pass
else
  test_fail "Syntax error in common.sh"
fi

test_start "setup.sh syntax"
if bash -n "$REPO_ROOT/setup.sh" 2>/dev/null; then
  test_pass
else
  test_fail "Syntax error in setup.sh"
fi

test_start ".bashrc syntax"
if bash -n "$REPO_ROOT/.bashrc" 2>/dev/null; then
  test_pass
else
  test_fail "Syntax error in .bashrc"
fi

test_start "bin/optimize syntax"
if bash -n "$REPO_ROOT/bin/optimize" 2>/dev/null; then
  test_pass
else
  test_fail "Syntax error in bin/optimize"
fi

test_start "bin/clean syntax"
if bash -n "$REPO_ROOT/bin/clean" 2>/dev/null; then
  test_pass
else
  test_fail "Syntax error in bin/clean"
fi

# ============================================================================
# COMMON LIBRARY TESTS
# ============================================================================

printf "\n${YELLOW}=== Common Library Tests ===${NC}\n"

# Source the common library for testing
# shellcheck source=.config/bash/common.sh
source "$REPO_ROOT/.config/bash/common.sh"

test_start "has() function"
if has bash; then
  test_pass
else
  test_fail "has() function not working"
fi

test_start "ensure_dir() function"
TEST_DIR="${TMPDIR:-/tmp}/dot-termux-test-$$"
if ensure_dir "$TEST_DIR" && [[ -d "$TEST_DIR" ]]; then
  test_pass
else
  test_fail "ensure_dir() function not working"
fi
# Cleanup test directory
rm -rf "$TEST_DIR" >/dev/null 2>&1 || :

test_start "check_deps() function"
if check_deps bash grep sed; then
  test_pass
else
  test_fail "check_deps() function not working"
fi

test_start "get_find_tool() function"
get_find_tool find_cmd
if [[ -n $find_cmd ]]; then
  test_pass
else
  test_fail "get_find_tool() function not working"
fi

test_start "get_replace_tool() function"
get_replace_tool replace_cmd
if [[ -n $replace_cmd ]]; then
  test_pass
else
  test_fail "get_replace_tool() function not working"
fi

# ============================================================================
# SCRIPT EXECUTION TESTS
# ============================================================================

printf "\n${YELLOW}=== Script Execution Tests ===${NC}\n"

test_start "optimize help"
if "$REPO_ROOT/bin/optimize" help >/dev/null 2>&1; then
  test_pass
else
  test_fail "optimize help command failed"
fi

test_start "optimize image help"
if "$REPO_ROOT/bin/optimize" image --help >/dev/null 2>&1; then
  test_pass
else
  test_fail "optimize image help failed"
fi

test_start "clean help"
if "$REPO_ROOT/bin/clean" --help >/dev/null 2>&1; then
  test_pass
else
  test_fail "clean help command failed"
fi

# ============================================================================
# FILE PERMISSION TESTS
# ============================================================================

printf "\n${YELLOW}=== File Permission Tests ===${NC}\n"

test_start "bin/optimize is executable"
if [[ -x "$REPO_ROOT/bin/optimize" ]]; then
  test_pass
else
  test_fail "bin/optimize is not executable"
fi

test_start "bin/clean is executable"
if [[ -x "$REPO_ROOT/bin/clean" ]]; then
  test_pass
else
  test_fail "bin/clean is not executable"
fi

test_start "setup.sh is executable"
if [[ -x "$REPO_ROOT/setup.sh" ]]; then
  test_pass
else
  test_fail "setup.sh is not executable"
fi

# ============================================================================
# SUMMARY
# ============================================================================

printf "\n${YELLOW}=== Test Summary ===${NC}\n"
printf "Tests run:    %d\n" "$TESTS_RUN"
printf "Tests passed: ${GREEN}%d${NC}\n" "$TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
  printf "Tests failed: ${RED}%d${NC}\n" "$TESTS_FAILED"
else
  printf "Tests failed: %d\n" "$TESTS_FAILED"
fi

if [[ $EXIT_CODE -eq 0 ]]; then
  printf "\n${GREEN}All tests passed!${NC}\n"
else
  printf "\n${RED}Some tests failed!${NC}\n"
fi

exit $EXIT_CODE
