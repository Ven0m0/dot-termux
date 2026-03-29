#!/bin/bash
# Mock helpers for the source-able script
log() { echo "MOCKED_LOG: $*"; }
err() { echo "MOCKED_ERR: $*" >&2; return 1; }
download() { echo "MOCKED_DOWNLOAD $*"; }
has() { return 0; }
export -f log err download has

# Source only the function definitions, skipping the execution block
# We do this by extracting everything EXCEPT the last line
sed '$d' bin/termux-install-tools.sh > temp_installer.sh
source temp_installer.sh
rm temp_installer.sh

test_tool() {
  local tool="$1"
  local func="install_${tool//-/_}"

  # Redefine the function to log its call
  eval "${func}() { echo \"CALLED_${func}\"; }"

  # Call main with the tool and check if it routed correctly
  output=$(main "$tool" 2>&1)
  if echo "$output" | grep -q "CALLED_${func}"; then
    echo "PASS: $tool -> $func"
    return 0
  else
    echo "FAIL: $tool did not call $func. Output: $output"
    return 1
  fi
}

TOOLS=("termuxvoid" "termuxvoid-theme" "enhancify" "xcmd" "lure" "soar" "cargo-binstall" "csb" "shizuku-tools" "revancify-xisr" "revancify" "rvx-builder" "simplify" "copilot" "claude" "coding-agent")

failed=0
for tool in "${TOOLS[@]}"; do
  if ! test_tool "$tool"; then
    failed=1
  fi
done

if [ "$failed" -eq 0 ]; then
  echo "ALL ROUTING TESTS PASSED"
else
  echo "SOME TESTS FAILED"
  exit 1
fi
