#!/bin/bash
set -euo pipefail

# Setup mocks
export MOCK_DIR=$(mktemp -d)
export PATH="$MOCK_DIR:$PATH"

# Mock apkeditor
cat << "MOCK" > "$MOCK_DIR/apkeditor"
#!/bin/bash
exit 0
MOCK
chmod +x "$MOCK_DIR/apkeditor"

# Mock apksigner
cat << "MOCK" > "$MOCK_DIR/apksigner"
#!/bin/bash
echo "$@" > "$MOCK_DIR/apksigner.args"
shift
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--out" ]]; then
    touch "$2"
  fi
  shift
done
exit 0
MOCK
chmod +x "$MOCK_DIR/apksigner"

TEST_DIR=$(mktemp -d)
INPUT_APK="$TEST_DIR/app.apks"
touch "$INPUT_APK"
KEY_DIR="$TEST_DIR/key"
mkdir -p "$KEY_DIR"
KEYSTORE="$KEY_DIR/antisplit.keystore"
touch "$KEYSTORE"

# Use absolute path for bin/antisplit.sh
SCRIPT_PATH="$(pwd)/bin/antisplit.sh"

echo "=== Test 1: Defaults ==="
# Unset variables just in case
unset KEYSTORE KS_PASS KS_ALIAS KEY_PASS

# Run in subshell to isolate env
(
    cd "$TEST_DIR"
    bash "$SCRIPT_PATH" "app.apks" >/dev/null 2>&1
)

ARGS=$(cat "$MOCK_DIR/apksigner.args")
echo "ARGS: $ARGS"

if [[ "$ARGS" == *"--ks key/antisplit.keystore"* ]]; then
    echo "PASS: Default keystore used"
else
    echo "FAIL: Expected default keystore, got: $ARGS"
    exit 1
fi
if [[ "$ARGS" == *"--ks-pass pass:password"* ]]; then
    echo "PASS: Default password used"
else
    echo "FAIL: Expected default password, got: $ARGS"
    exit 1
fi

echo "=== Test 2: Custom Env ==="
CUSTOM_KEYSTORE="$TEST_DIR/custom.keystore"
touch "$CUSTOM_KEYSTORE"

(
    export KEYSTORE="$CUSTOM_KEYSTORE"
    export KS_PASS="mysecret"
    export KS_ALIAS="myalias"
    export KEY_PASS="mykeysecret"
    cd "$TEST_DIR"
    bash "$SCRIPT_PATH" "app.apks" >/dev/null 2>&1
)

ARGS=$(cat "$MOCK_DIR/apksigner.args")
echo "ARGS: $ARGS"

if [[ "$ARGS" == *"--ks $CUSTOM_KEYSTORE"* ]]; then
    echo "PASS: Custom keystore used"
else
    echo "FAIL: Expected custom keystore, got: $ARGS"
    exit 1
fi
if [[ "$ARGS" == *"--ks-pass pass:mysecret"* ]]; then
    echo "PASS: Custom password used"
else
    echo "FAIL: Expected custom password, got: $ARGS"
    exit 1
fi
if [[ "$ARGS" == *"--ks-key-alias myalias"* ]]; then
    echo "PASS: Custom alias used"
else
    echo "FAIL: Expected custom alias, got: $ARGS"
    exit 1
fi
if [[ "$ARGS" == *"--key-pass pass:mykeysecret"* ]]; then
    echo "PASS: Custom key password used"
else
    echo "FAIL: Expected custom key password, got: $ARGS"
    exit 1
fi

echo "ALL TESTS PASSED"
rm -rf "$MOCK_DIR" "$TEST_DIR"
