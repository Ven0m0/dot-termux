#!/data/data/com.termux/files/usr/bin/bash
# termux-cleaner.sh - Comprehensive Android cleaner for Termux
#
# Features:
# - App and system cache cleaning
# - Media cleaning (WhatsApp, Telegram, etc.)
# - Temp file removal
# - System optimization
# - ADB and Shizuku integration for privileged operations
set -euo pipefail
IFS=$'\n\t'
shopt -s nullglob globstar

# ----------------------------------------------------------------------
# Environment setup
# ----------------------------------------------------------------------
export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export HOME="${HOME:-/data/data/com.termux/files/home}"
export LD_LIBRARY_PATH="$PREFIX/lib"
export PATH="$PREFIX/bin:$PATH"
export LANG=C.UTF-8 LC_ALL=C

# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------
LOG_FILE="${HOME}/termux-cleaner.log"
TEMP_DIR=$(mktemp -d -p "$PREFIX/tmp")
HAS_SHIZUKU=0
HAS_ROOT=0
HAS_ADB=0
CLEAN_WHATSAPP=0
CLEAN_TELEGRAM=0
CLEAN_DOWNLOADS=0
CLEAN_PICTURES=0
CLEAN_SYSTEM_CACHE=0
DRY_RUN=0
ASSUME_YES=0

# ----------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------
log() {
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

run_cmd() {
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY RUN] Would run: $*"
    return 0
  fi
  
  log "Running: $*"
  if ! "$@" >> "$LOG_FILE" 2>&1; then
    log "Command failed: $*"
    return 1
  fi
  return 0
}

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  
  local prompt="$1"
  local response
  
  echo -n "$prompt [y/N] "
  read -r response
  
  [[ "${response,,}" == "y" || "${response,,}" == "yes" ]]
}

check_tools() {
  # Check for Termux:API package
  if command -v termux-info >/dev/null 2>&1; then
    log "Termux:API is installed"
  else
    log "Termux:API not found. Consider installing for more features:"
    log "pkg install termux-api"
  fi
  
  # Check for Shizuku support
  if command -v rish >/dev/null 2>&1; then
    log "Shizuku integration available via rish"
    if rish id >/dev/null 2>&1; then
      log "Shizuku is active"
      HAS_SHIZUKU=1
    else
      log "Shizuku is installed but not active"
    fi
  fi
  
  # Check for ADB
  if command -v adb >/dev/null 2>&1; then
    if adb devices | grep -q 'device$'; then
      log "ADB connection available"
      HAS_ADB=1
    else
      log "ADB installed but no device connected"
    fi
  fi
  
  # Check for root
  if command -v su >/dev/null 2>&1; then
    if su -c id 2>/dev/null | grep -q uid=0; then
      log "Root access available"
      HAS_ROOT=1
    fi
  fi
}

# ----------------------------------------------------------------------
# Storage access functions
# ----------------------------------------------------------------------
access_external_storage() {
  # Check if we have direct access
  if [[ -d /sdcard && -w /sdcard ]]; then
    log "Direct /sdcard access available"
    echo "/sdcard"
    return 0
  fi
  
  # Try termux-setup-storage first
  if command -v termux-setup-storage >/dev/null 2>&1; then
    log "Running termux-setup-storage to request access..."
    termux-setup-storage
    if [[ -d "$HOME/storage/shared" && -w "$HOME/storage/shared" ]]; then
      log "Access granted via termux-setup-storage"
      echo "$HOME/storage/shared"
      return 0
    fi
  fi
  
  # Try termux-saf as a fallback
  if command -v termux-saf >/dev/null 2>&1; then
    log "Using termux-saf for storage access"
    local saf_dir
    saf_dir=$(termux-saf -d)
    if [[ -n "$saf_dir" ]]; then
      echo "$saf_dir"
      return 0
    fi
  fi
  
  # Use ADB or Shizuku as last resort
  if [[ $HAS_ADB -eq 1 ]]; then
    log "Using ADB for storage access"
    echo "adb"
    return 0
  elif [[ $HAS_SHIZUKU -eq 1 ]]; then
    log "Using Shizuku for storage access"
    echo "shizuku"
    return 0
  fi
  
  log "Warning: No storage access method available"
  return 1
}

# ----------------------------------------------------------------------
# Cleaning functions
# ----------------------------------------------------------------------
clean_app_cache() {
  local app="$1"
  
  log "Cleaning cache for $app"
  
  if [[ $HAS_SHIZUKU -eq 1 ]]; then
    run_cmd rish pm clear --cache-only "$app"
    return $?
  elif [[ $HAS_ADB -eq 1 ]]; then
    run_cmd adb shell pm clear --cache-only "$app"
    return $?
  elif [[ $HAS_ROOT -eq 1 ]]; then
    run_cmd su -c "rm -rf /data/data/$app/cache/*"
    return $?
  else
    log "Cannot clean app cache without Shizuku, ADB, or root"
    return 1
  fi
}

clean_system_cache() {
  log "Cleaning system cache"
  
  if [[ $HAS_SHIZUKU -eq 1 ]]; then
    run_cmd rish pm trim-caches 128G
    run_cmd rish sync
    run_cmd rish cmd shortcut reset-all-throttling
    run_cmd rish logcat -b all -c
    run_cmd rish sm fstrim
  elif [[ $HAS_ADB -eq 1 ]]; then
    run_cmd adb shell pm trim-caches 128G
    run_cmd adb shell sync
    run_cmd adb shell cmd shortcut reset-all-throttling
    run_cmd adb shell logcat -b all -c
    run_cmd adb shell sm fstrim
  elif [[ $HAS_ROOT -eq 1 ]]; then
    run_cmd su -c "pm trim-caches 128G"
    run_cmd su -c "sync"
    run_cmd su -c "logcat -b all -c"
    run_cmd su -c "sm fstrim"
  else
    log "Cannot clean system cache without Shizuku, ADB, or root"
    return 1
  fi
  
  # Clean package manager cache
  if [[ $HAS_ROOT -eq 1 ]]; then
    run_cmd su -c "rm -rf /data/dalvik-cache/*"
  fi
  
  return 0
}

clean_whatsapp_media() {
  log "Cleaning WhatsApp media"
  
  local storage_path
  storage_path=$(access_external_storage) || return 1
  
  if [[ "$storage_path" == "adb" ]]; then
    run_cmd adb shell "find /sdcard/WhatsApp/Media -type f \( -name '*.jpg' -o -name '*.mp4' -o -name '*.opus' \) -mtime +30 -delete"
  elif [[ "$storage_path" == "shizuku" ]]; then
    run_cmd rish "find /sdcard/WhatsApp/Media -type f \( -name '*.jpg' -o -name '*.mp4' -o -name '*.opus' \) -mtime +30 -delete"
  else
    # Check WhatsApp media paths
    local whatsapp_paths=(
      "$storage_path/WhatsApp/Media/.Statuses"
      "$storage_path/WhatsApp/Media/WhatsApp Documents"
      "$storage_path/WhatsApp/Media/WhatsApp Images"
      "$storage_path/WhatsApp/Media/WhatsApp Video"
      "$storage_path/WhatsApp/Media/WhatsApp Audio"
    )
    
    for path in "${whatsapp_paths[@]}"; do
      if [[ -d "$path" ]]; then
        log "Cleaning $path"
        if [[ $DRY_RUN -eq 1 ]]; then
          log "[DRY RUN] Would clean files older than 30 days in $path"
        else
          # Use find to delete files older than 30 days
          find "$path" -type f -mtime +30 -delete 2>/dev/null || log "Failed to clean $path"
        fi
      fi
    done
  fi
}

clean_telegram_media() {
  log "Cleaning Telegram media"
  
  local storage_path
  storage_path=$(access_external_storage) || return 1
  
  local telegram_paths=(
    "$storage_path/Telegram/Telegram Images"
    "$storage_path/Telegram/Telegram Video"
    "$storage_path/Telegram/Telegram Documents"
    "$storage_path/Telegram/Telegram Audio"
  )
  
  for path in "${telegram_paths[@]}"; do
    if [[ -d "$path" ]]; then
      log "Cleaning $path"
      if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY RUN] Would clean files older than 30 days in $path"
      else
        # Use find to delete files older than 30 days
        find "$path" -type f -mtime +30 -delete 2>/dev/null || log "Failed to clean $path"
      
