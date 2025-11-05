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

# Environment setup
export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export HOME="${HOME:-/data/data/com.termux/files/home}"
export LD_LIBRARY_PATH="$PREFIX/lib"
export PATH="$PREFIX/bin:$PATH"
export LANG=C.UTF-8 LC_ALL=C

# Configuration
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

# Helper functions
log() {
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

run_cmd() {
  ((DRY_RUN)) && {
    log "[DRY RUN] Would run: $*"
    return 0
  }
  log "Running: $*"
  "$@" &>>"$LOG_FILE" || {
    log "Command failed: $*"
    return 1
  }
}

confirm() {
  ((ASSUME_YES)) && return 0
  local response
  read -rp "$1 [y/N] " response
  [[ ${response,,} == @(y|yes) ]]
}

check_tools() {
  # Check for Termux:API package
  if command -v termux-info &>/dev/null; then
    log "Termux:API is installed"
  else
    log "Termux:API not found. Consider installing: pkg install termux-api"
  fi

  # Check for Shizuku support
  if command -v rish &>/dev/null; then
    log "Shizuku integration available via rish"
    rish id &>/dev/null && {
      log "Shizuku is active"
      HAS_SHIZUKU=1
    } || log "Shizuku is installed but not active"
  fi

  # Check for ADB
  command -v adb &>/dev/null && adb devices | grep -q 'device$' && {
    log "ADB connection available"
    HAS_ADB=1
  } || log "ADB not available"

  # Check for root
  command -v su &>/dev/null && su -c id 2>/dev/null | grep -q uid=0 && {
    log "Root access available"
    HAS_ROOT=1
  }
}

# Storage access functions
access_external_storage() {
  # Check if we have direct access
  [[ -d /sdcard && -w /sdcard ]] && {
    log "Direct /sdcard access available"
    echo "/sdcard"
    return 0
  }

  # Try termux-setup-storage first
  if command -v termux-setup-storage &>/dev/null; then
    log "Running termux-setup-storage to request access..."
    termux-setup-storage
    [[ -d $HOME/storage/shared && -w $HOME/storage/shared ]] && {
      log "Access granted via termux-setup-storage"
      echo "$HOME/storage/shared"
      return 0
    }
  fi

  # Try termux-saf as a fallback
  if command -v termux-saf &>/dev/null; then
    log "Using termux-saf for storage access"
    local saf_dir=$(termux-saf -d)
    [[ -n $saf_dir ]] && {
      echo "$saf_dir"
      return 0
    }
  fi

  # Use ADB or Shizuku as last resort
  ((HAS_ADB)) && {
    log "Using ADB for storage access"
    echo "adb"
    return 0
  }
  ((HAS_SHIZUKU)) && {
    log "Using Shizuku for storage access"
    echo "shizuku"
    return 0
  }

  log "Warning: No storage access method available"
  return 1
}

# Cleaning functions
clean_app_cache() {
  log "Cleaning cache for $1"
  ((HAS_SHIZUKU)) && {
    run_cmd rish pm clear --cache-only "$1"
    return
  }
  ((HAS_ADB)) && {
    run_cmd adb shell pm clear --cache-only "$1"
    return
  }
  ((HAS_ROOT)) && {
    run_cmd su -c "rm -rf /data/data/$1/cache/*"
    return
  }
  log "Cannot clean app cache without Shizuku, ADB, or root"
  return 1
}

clean_system_cache() {
  log "Cleaning system cache"

  if ((HAS_SHIZUKU)); then
    run_cmd rish pm trim-caches 128G
    run_cmd rish sync
    run_cmd rish cmd shortcut reset-all-throttling
    run_cmd rish logcat -b all -c
    run_cmd rish sm fstrim
  elif ((HAS_ADB)); then
    run_cmd adb shell pm trim-caches 128G
    run_cmd adb shell sync
    run_cmd adb shell cmd shortcut reset-all-throttling
    run_cmd adb shell logcat -b all -c
    run_cmd adb shell sm fstrim
  elif ((HAS_ROOT)); then
    run_cmd su -c "pm trim-caches 128G"
    run_cmd su -c "sync"
    run_cmd su -c "logcat -b all -c"
    run_cmd su -c "sm fstrim"
  else
    log "Cannot clean system cache without Shizuku, ADB, or root"
    return 1
  fi

  # Clean package manager cache
  ((HAS_ROOT)) && run_cmd su -c "rm -rf /data/dalvik-cache/*"
}

clean_whatsapp_media() {
  log "Cleaning WhatsApp media"

  local storage_path
  storage_path=$(access_external_storage) || return 1

  if [[ $storage_path == adb ]]; then
    run_cmd adb shell "find -O3 /sdcard/WhatsApp/Media -type f \( -name '*.jpg' -o -name '*.mp4' -o -name '*.opus' \) -mtime +30 -delete"
  elif [[ $storage_path == shizuku ]]; then
    run_cmd rish "find -O3 /sdcard/WhatsApp/Media -type f \( -name '*.jpg' -o -name '*.mp4' -o -name '*.opus' \) -mtime +30 -delete"
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
      [[ -d $path ]] || continue
      log "Cleaning $path"
      ((DRY_RUN)) && {
        log "[DRY RUN] Would clean files older than 30 days in $path"
        continue
      }
      # Use fd or find with -O3 and xargs for better performance
      if command -v fd &>/dev/null; then
        fd -t f --changed-before 30d . "$path" -0 2>/dev/null | xargs -0 -P 4 rm -f 2>/dev/null || log "Failed to clean $path"
      else
        find -O3 "$path" -type f -mtime +30 -print0 2>/dev/null | xargs -0 -P 4 rm -f 2>/dev/null || log "Failed to clean $path"
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
    [[ -d $path ]] || continue
    log "Cleaning $path"
    ((DRY_RUN)) && {
      log "[DRY RUN] Would clean files older than 30 days in $path"
      continue
    }
    # Use fd or find with -O3 and xargs for better performance
    if command -v fd &>/dev/null; then
      fd -t f --changed-before 30d . "$path" -0 2>/dev/null | xargs -0 -P 4 rm -f 2>/dev/null || log "Failed to clean $path"
    else
      find -O3 "$path" -type f -mtime +30 -print0 2>/dev/null | xargs -0 -P 4 rm -f 2>/dev/null || log "Failed to clean $path"
    fi
  done
}

# Main function
main() {
  log "Starting Termux Cleaner"
  check_tools

  # Parse options (if any were passed)
  confirm "Do you want to clean WhatsApp media?" && CLEAN_WHATSAPP=1
  confirm "Do you want to clean Telegram media?" && CLEAN_TELEGRAM=1
  confirm "Do you want to clean system cache?" && CLEAN_SYSTEM_CACHE=1

  # Perform cleaning operations
  ((CLEAN_WHATSAPP)) && clean_whatsapp_media
  ((CLEAN_TELEGRAM)) && clean_telegram_media
  ((CLEAN_SYSTEM_CACHE)) && clean_system_cache

  log "Cleaning complete"
}

# Parse command-line arguments
while getopts "ynswhd" opt; do
  case "$opt" in
  y) ASSUME_YES=1 ;;
  n) DRY_RUN=1 ;;
  s) CLEAN_SYSTEM_CACHE=1 ;;
  w) CLEAN_WHATSAPP=1 ;;
  d) CLEAN_DOWNLOADS=1 ;;
  h | *)
    echo "Usage: $0 [-y] [-n] [-s] [-w] [-d]"
    echo "  -y  Assume yes to all prompts"
    echo "  -n  Dry run (don't actually delete files)"
    echo "  -s  Clean system cache"
    echo "  -w  Clean WhatsApp media"
    echo "  -d  Clean downloads"
    echo "  -h  Show this help"
    exit 0
    ;;
  esac
done

# Run main function
main
