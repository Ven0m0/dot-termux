#!/bin/bash
# tests/test_termux_change_repo.sh

set -euo pipefail

# Source the script under test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=bin/termux-change-repo
source "$SCRIPT_DIR/bin/termux-change-repo"

test_resolve_mirror_target() {
    local region="$1"
    local expected_path="$2"
    local expected_exit="$3"

    echo "Testing region: '$region'..."

    local output
    set +e
    output=$(resolve_mirror_target "$region")
    local exit_code=$?
    set -e

    if [[ "$output" != "$expected_path" ]]; then
        echo "FAIL: Expected path '$expected_path', got '$output'"
        return 1
    fi

    if [[ $exit_code -ne $expected_exit ]]; then
        echo "FAIL: Expected exit code $expected_exit, got $exit_code"
        return 1
    fi

    echo "PASS"
    return 0
}

# MIRROR_BASE is defined as readonly in the sourced script
failed=0

echo "=== Testing resolve_mirror_target ==="

# Happy paths
test_resolve_mirror_target "all" "$MIRROR_BASE/all" 0 || failed=1
test_resolve_mirror_target "asia" "$MIRROR_BASE/asia" 0 || failed=1
test_resolve_mirror_target "chinese_mainland" "$MIRROR_BASE/chinese_mainland" 0 || failed=1
test_resolve_mirror_target "europe" "$MIRROR_BASE/europe" 0 || failed=1
test_resolve_mirror_target "north_america" "$MIRROR_BASE/north_america" 0 || failed=1
test_resolve_mirror_target "oceania" "$MIRROR_BASE/oceania" 0 || failed=1
test_resolve_mirror_target "russia" "$MIRROR_BASE/russia" 0 || failed=1

# Fallback paths
test_resolve_mirror_target "antarctica" "$MIRROR_BASE/europe" 1 || failed=1
test_resolve_mirror_target "unknown" "$MIRROR_BASE/europe" 1 || failed=1
test_resolve_mirror_target "" "$MIRROR_BASE/europe" 1 || failed=1

if [[ $failed -eq 0 ]]; then
    echo "ALL resolve_mirror_target TESTS PASSED"
    exit 0
else
    echo "SOME TESTS FAILED"
    exit 1
fi
