#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

# Source common library
readonly SCRIPT_DIR="$(builtin cd -P -- "$(dirname -- "${BASH_SOURCE[0]:-}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR%/*}/lib"
if [[ -f "${LIB_DIR}/common.sh" ]]; then
  # shellcheck source=../lib/common.sh
  source "${LIB_DIR}/common.sh"
else
  echo "ERROR: common.sh library not found at ${LIB_DIR}/common.sh" >&2
  exit 1
fi

# Display message
timeout 4 echo "
	#---Please approve logcat access for SuperShell---#
	#--- to extract the 'adb connect' IP & port values---#
	"

# Make sure our ADB environment is clean
adb kill-server
adb usb

# Detect grep command (prefer rg)
GREP_CMD='grep'
has rg && GREP_CMD='rg'

# Get the port number from logcat
timeout 3 logcat | "$GREP_CMD" -E "adbwifi|adb wifi" >~/adbport.txt || :
ADB_PORT=$(tail -n 1 ~/adbport.txt 2>/dev/null | awk '{print substr($NF, length($NF)-4)}')
[[ -z $ADB_PORT ]] && {
  echo "Failed to get ADB port"
  exit 1
}
export ADB_PORT

# Get IP addresses using modern approach (ip command instead of deprecated ifconfig)
if has ip; then
  ip addr show | "$GREP_CMD" -oP '192\.168\.\d+\.\d+(?=/)' | "$GREP_CMD" -v '255' >~/adbip.txt
else
  # Fallback to ifconfig if ip is not available
  ifconfig 2>/dev/null | "$GREP_CMD" -oE '\b192\.168\.[0-9]+\.[0-9]+\b' | "$GREP_CMD" -v '255' >~/adbip.txt || :
fi
chmod 600 ~/adbip.txt

# Try connecting to each IP
declare -a adb_addresses
while IFS= read -r ip; do
  [[ -n $ip ]] && adb_addresses+=("${ip}:${ADB_PORT}")
done <~/adbip.txt

for adb_address in "${adb_addresses[@]}"; do
  adb_ip=${adb_address%%:*}
  echo "$adb_address"
  echo "$adb_ip"
  # Try to connect
  if timeout 5 adb connect "$adb_address" 2>&1 | "$GREP_CMD" -q 'connected'; then
    echo "Connected to $adb_address"
    export adb_address adb_ip
    break
  fi
done

# Execute emulator commands
[[ -n ${adb_address:-} ]] || {
  echo "No valid ADB connection established"
  exit 1
}

adb reverse "localabstract:${ADB_PORT}" tcp:5555 2>/dev/null || :
adb connect "$adb_address" 2>/dev/null || :
adb reverse "localabstract:${ADB_PORT}" tcp:5555 2>/dev/null || :
adb tcpip 5555 2>/dev/null || :
adb devices
adb connect "${adb_ip}:5555" 2>/dev/null || :

if adb devices 2>/dev/null | "$GREP_CMD" -q 'emulator\|device'; then
  echo "
    #---- Mobile ADB Shell Enabled ----#
 "
fi

# Cleanup temporary files
rm -f ~/adbip.txt ~/adbport.txt

# Launch ADB shell
adb shell
