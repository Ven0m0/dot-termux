#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
# ADB utilities for Android optimization and management
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'

# Colors
readonly GRN=$'\e[32m' YLW=$'\e[33m' RED=$'\e[31m' DEF=$'\e[0m'

has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '%s[INFO]%s %s\n' "$GRN" "$DEF" "$*"; }
warn(){ printf '%s[WARN]%s %s\n' "$YLW" "$DEF" "$*" >&2; }
err(){ printf '%s[ERROR]%s %s\n' "$RED" "$DEF" "$*" >&2; exit 1; }

# Check ADB connection
check_adb(){
  has adb || err "ADB not installed"
  adb get-state &>/dev/null || err "No ADB connection. Connect device first."
}

# ADB optimization commands
optimize_device(){
  check_adb
  log "Optimizing device performance..."
  
  # Compile apps with speed profile
  adb shell pm compile -p PRIORITY_INTERACTIVE_FAST --force-merge-profile --full -a -r cmdline -m speed &>/dev/null || warn "Compile failed"
  
  # Optimize device
  adb shell am broadcast -a android.intent.action.ACTION_OPTIMIZE_DEVICE &>/dev/null || :
  
  # Background dexopt
  adb shell pm bg-dexopt-job &>/dev/null || warn "dexopt failed"
  
  log "Optimization complete"
}

# Clear system caches
clear_caches(){
  check_adb
  log "Clearing system caches..."
  
  # Clear memory
  adb shell am broadcast -a com.android.systemui.action.CLEAR_MEMORY &>/dev/null || :
  
  # Clear stats cache
  adb shell cmd stats clear-puller-cache &>/dev/null || :
  
  # Kill all apps
  adb shell am kill-all &>/dev/null || :
  
  log "Caches cleared"
}

# Disable verbose logging
disable_logging(){
  check_adb
  log "Disabling verbose logging..."
  
  adb shell cmd wifi set-verbose-logging disabled &>/dev/null || :
  adb shell cmd voiceinteraction set-debug-hotword-logging false &>/dev/null || :
  adb shell cmd looper_stats disable &>/dev/null || :
  adb shell cmd display ab-logging-disable &>/dev/null || :
  adb shell cmd display dwb-logging-disable &>/dev/null || :
  
  log "Verbose logging disabled"
}

# Run idle maintenance
idle_maintenance(){
  check_adb
  log "Running idle maintenance..."
  
  adb shell cmd activity idle-maintenance &>/dev/null || warn "idle-maintenance failed"
  adb shell sm idle-maint run &>/dev/null || warn "sm idle-maint failed"
  
  log "Idle maintenance complete"
}

# Setup ADB over WiFi
adb_wifi_setup(){
  check_adb
  local port="${1:-5555}"
  
  log "Setting up ADB over WiFi on port $port..."
  adb tcpip "$port" || err "Failed to enable TCP mode"
  
  local ip
  ip=$(adb shell ip route | awk '{print $9}' | head -1)
  [[ -z $ip ]] && err "Could not determine device IP"
  
  log "Device IP: $ip"
  log "Now disconnect USB and run:"
  echo "  adb connect $ip:$port"
}

# Connect to ADB over WiFi
adb_connect(){
  [[ -z ${1:-} ]] && { echo "Usage: $(basename "$0") connect <ip> [port]"; exit 1; }
  local ip="$1" port="${2:-5555}"
  
  log "Connecting to $ip:$port..."
  adb connect "$ip:$port"
}

# Usage
usage(){
  cat <<EOF
ADB utilities for Android optimization

USAGE:
  $(basename "$0") optimize       Optimize device performance
  $(basename "$0") clear-cache    Clear system caches
  $(basename "$0") disable-logs   Disable verbose logging
  $(basename "$0") idle-maint     Run idle maintenance
  $(basename "$0") wifi-setup     Setup ADB over WiFi
  $(basename "$0") connect <ip>   Connect to device over WiFi

EXAMPLES:
  $(basename "$0") optimize
  $(basename "$0") clear-cache
  $(basename "$0") wifi-setup
  $(basename "$0") connect 192.168.1.100
EOF
}

main(){
  case "${1:-}" in
    optimize) optimize_device ;;
    clear-cache) clear_caches ;;
    disable-logs) disable_logging ;;
    idle-maint) idle_maintenance ;;
    wifi-setup) shift; adb_wifi_setup "$@" ;;
    connect) shift; adb_connect "$@" ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
