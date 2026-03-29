#!/usr/bin/env bash

# Test script for setup-shizu.sh refactoring

set -euo pipefail

# Mock environment
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cd "$TEST_DIR"
mkdir -p lucky-patcher ai-tools system mock_home/bin

# Mock HOME
export HOME="$TEST_DIR/mock_home"

# Create dummy scripts
touch lucky-patcher/lp1.sh lucky-patcher/lp2.sh lucky-patcher/not_a_script.txt
touch ai-tools/ai1 ai-tools/ai2.py
touch system/sys1.sh

# Function to be tested
create_symlinks() {
    local pattern="$1"
    # shellcheck disable=SC2086
    for script in $pattern; do
        if [ -f "$script" ]; then
            name=$(basename "$script")
            ln -sf "$PWD/$script" "$HOME/bin/$name"
        fi
    done
}

# Run the function with patterns
create_symlinks "lucky-patcher/*.sh"
create_symlinks "ai-tools/*"
create_symlinks "system/*.sh"

# Verification
echo "Checking Lucky Patcher symlinks..."
[[ -L "$HOME/bin/lp1.sh" ]] || (echo "FAILED: lp1.sh symlink missing"; exit 1)
[[ -L "$HOME/bin/lp2.sh" ]] || (echo "FAILED: lp2.sh symlink missing"; exit 1)
[[ ! -e "$HOME/bin/not_a_script.txt" ]] || (echo "FAILED: not_a_script.txt should not be linked"; exit 1)

echo "Checking AI tools symlinks..."
[[ -L "$HOME/bin/ai1" ]] || (echo "FAILED: ai1 symlink missing"; exit 1)
[[ -L "$HOME/bin/ai2.py" ]] || (echo "FAILED: ai2.py symlink missing"; exit 1)

echo "Checking System tools symlinks..."
[[ -L "$HOME/bin/sys1.sh" ]] || (echo "FAILED: sys1.sh symlink missing"; exit 1)

echo "All tests passed!"
