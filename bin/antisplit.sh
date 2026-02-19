#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
# AntiSplit - Merge split APK files and sign them
# Script by: @termuxvoid
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'

has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '[INFO] %s\n' "$*"; }
err(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }

echo -e "\tAPK Split Merger auto Signer"
echo -e "\t\t\t\t@termuxvoid"
echo

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <input.apks|apkm|xapk>"
    exit 1
fi

has apkeditor || err "apkeditor not found"
has apksigner || err "apksigner not found"

INPUT="$1"
INPUT_DIR=$(dirname "$INPUT")
BASE_NAME=$(basename "$INPUT" ".${INPUT##*.}")

OUTPUT="$INPUT_DIR/$BASE_NAME.apk"
SIGNED="$INPUT_DIR/${BASE_NAME}_signed.apk"

log "Input: $INPUT"
log "Output: $SIGNED"

[[ ! -f "$INPUT" ]] && err "File not found: $INPUT"

# Configuration - customizable via environment variables
KEYSTORE="${KEYSTORE:-key/antisplit.keystore}"
KS_PASS="${KS_PASS:-password}"
KS_ALIAS="${KS_ALIAS:-antisplit}"
KEY_PASS="${KEY_PASS:-password}"
[[ ! -f "$KEYSTORE" ]] && err "Keystore not found: $KEYSTORE"

log "Merging split files..."
if apkeditor m -i "$INPUT" -o "$OUTPUT"; then
    log "Merged successfully"
else
    err "Merge failed"
fi

log "Signing APK..."
if apksigner sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" \
    --ks-key-alias "$KS_ALIAS" --key-pass "pass:$KEY_PASS" \
    --out "$SIGNED" "$OUTPUT"; then
    log "Signed successfully: $SIGNED"
    rm -f "$OUTPUT" "$INPUT_DIR"/*.idsig 
else
    err "Signing failed"
fi

log "All done!"
