#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
shopt -s nullglob globstar
IFS=$'\n\t'
export LC_ALL=C LANG=C

# ============================================================================
# COLORS AND HELPERS
# ============================================================================

R=$'\e[31m' G=$'\e[32m' Y=$'\e[33m' B=$'\e[34m' D=$'\e[0m'
has() { command -v "$1" &>/dev/null; }
log() { printf '%b\n' "${G}▸${D} $*"; }
warn() { printf '%b\n' "${Y}⚠${D} $*" >&2; }
err() { printf '%b\n' "${R}✗${D} $*" >&2; }
info() { printf '%b\n' "${B}ℹ${D} $*"; }
print_step() { printf '\n%b==>%b %s\n' "$B" "$D" "$*"; }

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

DRY_RUN=0
VERBOSE=0
ASSUME_YES=0
HAS_SHIZUKU=0
HAS_ROOT=0
HAS_ADB=0
LOG_FILE="${HOME}/clean.log"

# Option flags
OPT_QUICK=0
OPT_DEEP=0
OPT_WHATSAPP=0
OPT_TELEGRAM=0
OPT_ADB=0
OPT_SYSTEM_CACHE=0
OPT_PKG_CACHE=0

# ============================================================================
# HELP
# ============================================================================

show_help() {
  cat <<'EOF'
clean - Unified cleaning tool for Termux and Android

Usage: clean [options]

Options:
  -q, --quick         Quick clean (cache, logs, temp files)
  -d, --deep          Deep clean (includes media, downloads)
  -w, --whatsapp      Clean WhatsApp media (files older than 30 days)
  -t, --telegram      Clean Telegram media (files older than 30 days)
  -a, --adb           Use ADB for cleaning operations
  -s, --system-cache  Clean system cache (requires root/ADB/Shizuku)
  -p, --pkg-cache     Clean package manager cache
  
  -n, --dry-run       Show what would be done without doing it
  -y, --yes           Assume yes to all prompts
  -v, --verbose       Verbose output
  -h, --help          Show this help message

Examples:
  clean -q                    # Quick clean
  clean -d                    # Deep clean
  clean -w -t                 # Clean WhatsApp and Telegram
  clean -q -w -y              # Quick clean + WhatsApp (no prompts)
  clean -s -a                 # Clean system cache via ADB
  clean -n -d                 # Dry run of deep clean

Privilege modes:
  The tool will automatically detect available privilege modes:
  - Direct access (if running as system user)
  - Shizuku (rish command)
  - ADB (connected device)
  - Root (su command)
EOF
}

# ============================================================================
# PRIVILEGE DETECTION
# ============================================================================

detect_privileges() {
  # Check for Shizuku
  if has rish; then
    if rish id >/dev/null 2>&1; then
      HAS_SHIZUKU=1
      [[ $VERBOSE -eq 1 ]] && info "Shizuku access available"
    fi
  fi

  # Check for ADB
  if has adb; then
    if adb devices 2>/dev/null | grep -q 'device$'; then
      HAS_ADB=1
      [[ $VERBOSE -eq 1 ]] && info "ADB access available"
    fi
  fi

  # Check for root
  if has su; then
    if su -c id 2>/dev/null | grep -q uid=0; then
      HAS_ROOT=1
      [[ $VERBOSE -eq 1 ]] && info "Root access available"
    fi
  fi
}

# ============================================================================
# CLEANING FUNCTIONS
# ============================================================================

# Quick clean: cache, logs, temp files
clean_quick() {
  print_step "Quick cleaning"

  # Clean Termux package cache
  if has pkg; then
    [[ $DRY_RUN -eq 1 ]] && {
      log "Would clean package cache"
      return 0
    }
    log "Cleaning package cache"
    pkg clean >/dev/null 2>&1 || :
    pkg autoclean >/dev/null 2>&1 || :
  fi

  if has apt; then
    apt clean >/dev/null 2>&1 || :
    apt autoclean >/dev/null 2>&1 || :
    apt-get -y autoremove --purge >/dev/null 2>&1 || :
  fi

  # Clean shell cache
  log "Cleaning shell cache"
  [[ $DRY_RUN -eq 0 ]] && {
    rm -f "$HOME"/.zcompdump* >/dev/null 2>&1 || :
    rm -f "$HOME"/.bash_history.tmp >/dev/null 2>&1 || :
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}"/.zcompdump* >/dev/null 2>&1 || :
  }

  # Clean temp files
  log "Cleaning temp files"
  [[ $DRY_RUN -eq 0 ]] && {
    # Consolidate cache and temp cleaning (with existence checks)
    [[ -d ${HOME}/.cache ]] && find "${HOME}/.cache" -type f -delete 2>/dev/null || :
    [[ -d ${HOME}/tmp ]] && find "${HOME}/tmp" -type f -delete 2>/dev/null || :
    find "${TMPDIR:-/tmp}" -type f -user "$(id -u)" -delete 2>/dev/null || :
    # Termux-specific paths (with existence checks)
    [[ -d /data/data/com.termux/files/home/.cache ]] && \
      find /data/data/com.termux/files/home/.cache/ -type f -delete 2>/dev/null || :
    [[ -d /data/data/com.termux/cache ]] && \
      find /data/data/com.termux/cache -type f -delete 2>/dev/null || :
    [[ -d /data/data/com.termux/files/home/tmp ]] && \
      find /data/data/com.termux/files/home/tmp/ -type f -delete 2>/dev/null || :
    # Clean backup and log files in termux home (with existence check)
    [[ -d /data/data/com.termux/files/home ]] && \
      find /data/data/com.termux/files/home/ -type f \( -name "*.bak" -o -name "*.log" \) -delete 2>/dev/null || :
  }

  # Clean log files
  log "Cleaning log files"
  [[ $DRY_RUN -eq 0 ]] && {
    find "$HOME" -type f -name "*.log" -mtime +7 -delete >/dev/null 2>&1 || :
    find "$HOME" -type f -name "*.bak" -delete >/dev/null 2>&1 || :
  }

  # Clean empty directories
  log "Cleaning empty directories"
  [[ $DRY_RUN -eq 0 ]] && {
    find "$HOME" -type d -empty -delete >/dev/null 2>&1 || :
  }

  info "Quick clean complete"
}

# Deep clean: includes everything from quick plus more aggressive cleaning
clean_deep() {
  print_step "Deep cleaning"

  # Run quick clean first
  clean_quick

  echo "Cleaning up broken symlinks in: $PWD"
  find "$PWD" -xtype l -delete 2>/dev/null || :

  # Clean download directories
  log "Cleaning downloads"
  if [[ -d "$HOME/storage/shared/Download" ]]; then
    [[ $DRY_RUN -eq 0 ]] && {
      find "$HOME/storage/shared/Download" -type f -mtime +60 -delete >/dev/null 2>&1 || :
    }
  fi

  # Clean old files in home
  log "Cleaning old files in home"
  [[ $DRY_RUN -eq 0 ]] && {
    find "$HOME" -type f -name "*.tmp" -delete >/dev/null 2>&1 || :
    find "$HOME" -type f -name "*~" -delete >/dev/null 2>&1 || :
    find "$HOME" -type f -name "core" -delete >/dev/null 2>&1 || :
  }

  info "Deep clean complete"
}

# Clean WhatsApp media
clean_whatsapp() {
  print_step "Cleaning WhatsApp media"

  local storage_path="${HOME}/storage/shared"

  [[ ! -d $storage_path ]] && {
    warn "Storage not accessible. Run: termux-setup-storage"
    return 1
  }

  local -a whatsapp_paths=(
    "$storage_path/WhatsApp/Media/.Statuses"
    "$storage_path/WhatsApp/Media/WhatsApp Documents"
    "$storage_path/WhatsApp/Media/WhatsApp Images"
    "$storage_path/WhatsApp/Media/WhatsApp Video"
    "$storage_path/WhatsApp/Media/WhatsApp Audio"
  )

  for path in "${whatsapp_paths[@]}"; do
    [[ ! -d $path ]] && continue

    log "Cleaning: $path"

    if [[ $DRY_RUN -eq 1 ]]; then
      local count
      count=$(find "$path" -type f -mtime +30 2>/dev/null | wc -l)
      info "Would delete $count files from $path"
    else
      find "$path" -type f -mtime +30 -delete >/dev/null 2>&1 || :
    fi
  done

  info "WhatsApp cleaning complete"
}

# Clean Telegram media
clean_telegram() {
  print_step "Cleaning Telegram media"

  local storage_path="${HOME}/storage/shared"

  [[ ! -d $storage_path ]] && {
    warn "Storage not accessible. Run: termux-setup-storage"
    return 1
  }

  local -a telegram_paths=(
    "$storage_path/Telegram/Telegram Images"
    "$storage_path/Telegram/Telegram Video"
    "$storage_path/Telegram/Telegram Documents"
    "$storage_path/Telegram/Telegram Audio"
  )

  for path in "${telegram_paths[@]}"; do
    [[ ! -d $path ]] && continue

    log "Cleaning: $path"

    if [[ $DRY_RUN -eq 1 ]]; then
      local count
      count=$(find "$path" -type f -mtime +30 2>/dev/null | wc -l)
      info "Would delete $count files from $path"
    else
      find "$path" -type f -mtime +30 -delete >/dev/null 2>&1 || :
    fi
  done

  info "Telegram cleaning complete"
}

# Clean system cache (requires elevated privileges)
clean_system_cache() {
  print_step "Cleaning system cache"

  if [[ $HAS_SHIZUKU -eq 1 ]]; then
    log "Using Shizuku for system cache cleaning"
    [[ $DRY_RUN -eq 0 ]] && {
      rish pm trim-caches 128G >/dev/null 2>&1 || :
      rish sync >/dev/null 2>&1 || :
      rish cmd shortcut reset-all-throttling >/dev/null 2>&1 || :
      rish logcat -b all -c >/dev/null 2>&1 || :
      rish sm fstrim >/dev/null 2>&1 || :
    }
  elif [[ $HAS_ADB -eq 1 ]]; then
    log "Using ADB for system cache cleaning"
    [[ $DRY_RUN -eq 0 ]] && {
      adb shell pm trim-caches 128G >/dev/null 2>&1 || :
      adb shell sync >/dev/null 2>&1 || :
      adb shell cmd shortcut reset-all-throttling >/dev/null 2>&1 || :
      adb shell logcat -b all -c >/dev/null 2>&1 || :
      adb shell sm fstrim >/dev/null 2>&1 || :
    }
  elif [[ $HAS_ROOT -eq 1 ]]; then
    log "Using root for system cache cleaning"
    [[ $DRY_RUN -eq 0 ]] && {
      su -c "pm trim-caches 128G" >/dev/null 2>&1 || :
      su -c "sync" >/dev/null 2>&1 || :
      su -c "logcat -b all -c" >/dev/null 2>&1 || :
      su -c "sm fstrim" >/dev/null 2>&1 || :
    }
  else
    err "System cache cleaning requires root, ADB, or Shizuku"
    return 1
  fi

  info "System cache cleaning complete"
}

# Clean via ADB
clean_adb() {
  print_step "Cleaning via ADB"

  [[ $HAS_ADB -eq 0 ]] && {
    err "ADB not available or no device connected"
    return 1
  }

  # Clean logs
  log "Cleaning Android logs via ADB"
  [[ $DRY_RUN -eq 0 ]] && {
    adb shell logcat -c >/dev/null 2>&1 || :
    adb shell rm -rf /cache/log/* >/dev/null 2>&1 || :
    adb shell rm -rf /data/log/* >/dev/null 2>&1 || :
    adb shell rm -rf /data/tombstones/* >/dev/null 2>&1 || :
  }

  # Clean cache
  log "Cleaning app caches via ADB"
  [[ $DRY_RUN -eq 0 ]] && {
    adb shell pm trim-caches 999999999M >/dev/null 2>&1 || :
  }

  info "ADB cleaning complete"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -q | --quick)
      OPT_QUICK=1
      shift
      ;;
    -d | --deep)
      OPT_DEEP=1
      shift
      ;;
    -w | --whatsapp)
      OPT_WHATSAPP=1
      shift
      ;;
    -t | --telegram)
      OPT_TELEGRAM=1
      shift
      ;;
    -a | --adb)
      OPT_ADB=1
      shift
      ;;
    -s | --system-cache)
      OPT_SYSTEM_CACHE=1
      shift
      ;;
    -p | --pkg-cache)
      OPT_PKG_CACHE=1
      shift
      ;;
    -n | --dry-run)
      DRY_RUN=1
      shift
      ;;
    -y | --yes)
      ASSUME_YES=1
      shift
      ;;
    -v | --verbose)
      VERBOSE=1
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      show_help
      exit 1
      ;;
    esac
  done

  # If no options specified, default to quick clean
  if [[ $OPT_QUICK -eq 0 && $OPT_DEEP -eq 0 && $OPT_WHATSAPP -eq 0 &&
    $OPT_TELEGRAM -eq 0 && $OPT_ADB -eq 0 && $OPT_SYSTEM_CACHE -eq 0 &&
    $OPT_PKG_CACHE -eq 0 ]]; then
    OPT_QUICK=1
  fi

  # Detect available privileges
  detect_privileges

  # Start logging
  log "Starting clean operations"
  [[ $DRY_RUN -eq 1 ]] && warn "DRY RUN MODE - No files will be deleted"

  # Execute cleaning operations
  [[ $OPT_QUICK -eq 1 ]] && clean_quick
  [[ $OPT_DEEP -eq 1 ]] && clean_deep
  [[ $OPT_WHATSAPP -eq 1 ]] && clean_whatsapp
  [[ $OPT_TELEGRAM -eq 1 ]] && clean_telegram
  [[ $OPT_SYSTEM_CACHE -eq 1 ]] && clean_system_cache
  [[ $OPT_ADB -eq 1 ]] && clean_adb

  info "All cleaning operations complete"
  [[ $VERBOSE -eq 1 ]] && info "Log file: $LOG_FILE"
}

main "$@"
