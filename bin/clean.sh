#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t'; export LC_ALL=C LANG=C

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

# ============================================================================
# GLOBAL FLAGS
# ============================================================================
DRY_RUN=0
VERBOSE=0
HAS_SHIZUKU=0
HAS_ADB=0
# Options
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
  -p, --pkg-cache     Clean package manager cache only

  -n, --dry-run       Show what would be done without doing it
  -v, --verbose       Verbose output
  -h, --help          Show this help message

Examples:
  clean -q
  clean -d
  clean -w -t
  clean -s -a
  clean -n -d
EOF
}

# ============================================================================
# PRIVILEGE DETECTION
# ============================================================================
PRIVILEGES_CHECKED=0
detect_privileges() {
  [[ $PRIVILEGES_CHECKED -eq 1 ]] && return
  PRIVILEGES_CHECKED=1
  if has rish; then
    if rish id &>/dev/null; then
      HAS_SHIZUKU=1
      [[ $VERBOSE -eq 1 ]] && info "Shizuku access available"
    fi
  fi
  if has adb; then
    if adb devices 2>/dev/null | (has rg && rg -q 'device$' || grep -q 'device$'); then
      HAS_ADB=1
      [[ $VERBOSE -eq 1 ]] && info "ADB access available"
    fi
  fi
}

# ============================================================================
# CLEANING FUNCTIONS
# ============================================================================
clean_pkg_cache() {
  print_step "Cleaning package cache"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "Would clean package caches"
    return 0
  fi
  if has pkg; then
    pkg clean &>/dev/null || :
    pkg autoclean &>/dev/null || :
  fi
  if has apt-get; then
    apt-get clean &>/dev/null || :
    apt-get autoclean &>/dev/null || :
    apt-get -y autoremove --purge &>/dev/null || :
  fi
  if has apt; then
    apt clean &>/dev/null || :
    apt autoclean &>/dev/null || :
  fi
  info "Package cache cleaning complete"
}

# Quick clean: cache, logs, temp files
clean_quick() {
  print_step "Quick cleaning"
  if has pkg || has apt || has apt-get; then
    [[ $DRY_RUN -eq 1 ]] && {
      log "Would clean package cache"
      :
    } || clean_pkg_cache
  fi

  log "Cleaning shell cache"
  [[ $DRY_RUN -eq 0 ]] && {
    rm -f "$HOME"/.zcompdump* &>/dev/null || :
    rm -f "$HOME"/.bash_history.tmp &>/dev/null || :
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}"/.zcompdump* &>/dev/null || :
  }

  log "Cleaning temp files"
  [[ $DRY_RUN -eq 0 ]] && {
    if has fd; then
      [[ -d ${HOME}/.cache ]] && fd -tf . "${HOME}/.cache" -X rm -f &>/dev/null || :
      [[ -d ${HOME}/tmp ]] && fd -tf . "${HOME}/tmp" -X rm -f &>/dev/null || :
      fd -tf --owner "$(id -u)" . "${TMPDIR:-/tmp}" -X rm -f &>/dev/null || :
      [[ -d /data/data/com.termux/files/home/.cache ]] && fd -tf . /data/data/com.termux/files/home/.cache/ -X rm -f &>/dev/null || :
      [[ -d /data/data/com.termux/cache ]] && fd -tf . /data/data/com.termux/cache -X rm -f &>/dev/null || :
      [[ -d /data/data/com.termux/files/home/tmp ]] && fd -tf . /data/data/com.termux/files/home/tmp/ -X rm -f &>/dev/null || :
      [[ -d /data/data/com.termux/files/home ]] && fd -tf -e bak -e log . /data/data/com.termux/files/home/ -X rm -f &>/dev/null || :
    else
      [[ -d ${HOME}/.cache ]] && find "${HOME}/.cache" -type f -delete &>/dev/null || :
      [[ -d ${HOME}/tmp ]] && find "${HOME}/tmp" -type f -delete &>/dev/null || :
      find "${TMPDIR:-/tmp}" -type f -user "$(id -u)" -delete &>/dev/null || :
      [[ -d /data/data/com.termux/files/home/.cache ]] && find /data/data/com.termux/files/home/.cache/ -type f -delete &>/dev/null || :
      [[ -d /data/data/com.termux/cache ]] && find /data/data/com.termux/cache -type f -delete &>/dev/null || :
      [[ -d /data/data/com.termux/files/home/tmp ]] && find /data/data/com.termux/files/home/tmp/ -type f -delete &>/dev/null || :
      [[ -d /data/data/com.termux/files/home ]] && find /data/data/com.termux/files/home/ -type f \( -name "*.bak" -o -name "*.log" \) -delete &>/dev/null || :
    fi
  }

  log "Cleaning log files"
  [[ $DRY_RUN -eq 0 ]] && {
    if has fd; then
      fd -tf -e log --changed-before 7d . "$HOME" -X rm -f &>/dev/null || :
      fd -tf -e bak . "$HOME" -X rm -f &>/dev/null || :
    else
      find -O2 "$HOME" -type f -name "*.log" -mtime +7 -delete &>/dev/null || :
      find -O2 "$HOME" -type f -name "*.bak" -delete &>/dev/null || :
    fi
  }

  log "Cleaning empty directories"
  [[ $DRY_RUN -eq 0 ]] && {
    if has fd; then
      fd -td --max-depth 10 . "$HOME" -x rmdir {} &>/dev/null || :
    else
      find -O2 "$HOME" -type d -empty -delete &>/dev/null || :
    fi
  }

  info "Quick clean complete"
}

# Deep clean: includes quick + more
clean_deep() {
  print_step "Deep cleaning"
  clean_quick
  log "Cleaning broken symlinks in: $PWD"
  if has fd; then
    fd -tl . "$PWD" -X sh -c '[ ! -e "$1" ] && rm -f "$1" || :' _ {} \; &>/dev/null || :
  else
    find "$PWD" -xtype l -delete &>/dev/null || :
  fi
  log "Cleaning downloads"
  if [[ -d "$HOME/storage/shared/Download" ]]; then
    [[ $DRY_RUN -eq 0 ]] && {
      if has fd; then
        fd -tf --changed-before 60d . "$HOME/storage/shared/Download" -X rm -f &>/dev/null || :
      else
        find "$HOME/storage/shared/Download" -type f -mtime +60 -delete &>/dev/null || :
      fi
    }
  fi
  log "Cleaning old files in home"
  [[ $DRY_RUN -eq 0 ]] && {
    if has fd; then
      fd -tf -e tmp . "$HOME" -X rm -f &>/dev/null || :
      fd -tf -g '*~' . "$HOME" -X rm -f &>/dev/null || :
      fd -tf -g 'core' . "$HOME" -X rm -f &>/dev/null || :
    else
      find "$HOME" -type f -name "*.tmp" -delete &>/dev/null || :
      find "$HOME" -type f -name "*~" -delete &>/dev/null || :
      find "$HOME" -type f -name "core" -delete &>/dev/null || :
    fi
  }
  info "Deep clean complete"
}

clean_whatsapp() {
  print_step "Cleaning WhatsApp media"
  local storage_path="${HOME}/storage/shared"
  [[ ! -d $storage_path ]] && {
    warn "Storage not accessible. Run: termux-setup-storage"
    return 1
  }
  local -a paths=(
    "$storage_path/WhatsApp/Media/.Statuses"
    "$storage_path/WhatsApp/Media/WhatsApp Documents"
    "$storage_path/WhatsApp/Media/WhatsApp Images"
    "$storage_path/WhatsApp/Media/WhatsApp Video"
    "$storage_path/WhatsApp/Media/WhatsApp Audio"
  )

  local path count
  for path in "${paths[@]}"; do
    [[ ! -d $path ]] && continue
    log "Cleaning: $path"
    if [[ $DRY_RUN -eq 1 ]]; then
      if has fd; then
        count=$(fd -tf --changed-before 30d . "$path" 2>/dev/null | wc -l)
      else count=$(find "$path" -type f -mtime +30 2>/dev/null | wc -l); fi
      info "Would delete $count files from $path"
    else
      if has fd; then
        fd -tf --changed-before 30d . "$path" -X rm -f &>/dev/null || :
      else find "$path" -type f -mtime +30 -delete &>/dev/null || :; fi
    fi
  done
  info "WhatsApp cleaning complete"
}

clean_telegram() {
  print_step "Cleaning Telegram media"
  local storage_path="${HOME}/storage/shared"
  [[ ! -d $storage_path ]] && {
    warn "Storage not accessible. Run: termux-setup-storage"
    return 1
  }
  local -a paths=(
    "$storage_path/Telegram/Telegram Images"
    "$storage_path/Telegram/Telegram Video"
    "$storage_path/Telegram/Telegram Documents"
    "$storage_path/Telegram/Telegram Audio"
  )

  local path count
  for path in "${paths[@]}"; do
    [[ ! -d $path ]] && continue
    log "Cleaning: $path"
    if [[ $DRY_RUN -eq 1 ]]; then
      if has fd; then
        count=$(fd -tf --changed-before 30d . "$path" 2>/dev/null | wc -l)
      else count=$(find "$path" -type f -mtime +30 2>/dev/null | wc -l); fi
      info "Would delete $count files from $path"
    else
      if has fd; then
        fd -tf --changed-before 30d . "$path" -X rm -f &>/dev/null || :
      else find "$path" -type f -mtime +30 -delete &>/dev/null || :; fi
    fi
  done
  info "Telegram cleaning complete"
}

clean_system_cache() {
  print_step "Cleaning system cache"
  if [[ $HAS_SHIZUKU -eq 1 ]]; then
    log "Using Shizuku"
    [[ $DRY_RUN -eq 0 ]] && {
      rish pm trim-caches 128G &>/dev/null || :
      rish sync &>/dev/null || :
      rish cmd shortcut reset-all-throttling &>/dev/null || :
      rish logcat -b all -c &>/dev/null || :
      rish sm fstrim &>/dev/null || :
    }
  elif [[ $HAS_ADB -eq 1 ]]; then
    log "Using ADB"
    [[ $DRY_RUN -eq 0 ]] && {
      adb shell pm trim-caches 128G &>/dev/null || :
      adb shell sync &>/dev/null || :
      adb shell cmd shortcut reset-all-throttling &>/dev/null || :
      adb shell logcat -b all -c &>/dev/null || :
      adb shell sm fstrim &>/dev/null || :
    }
  elif [[ $HAS_ROOT -eq 1 ]]; then
    log "Using root"
    [[ $DRY_RUN -eq 0 ]] && {
      su -c "pm trim-caches 128G" &>/dev/null || :
      su -c "sync" &>/dev/null || :
      su -c "logcat -b all -c" &>/dev/null || :
      su -c "sm fstrim" &>/dev/null || :
    }
  else
    err "System cache cleaning requires root, ADB, or Shizuku"
    return 1
  fi
  info "System cache cleaning complete"
}

clean_adb() {
  print_step "Cleaning via ADB"
  [[ $HAS_ADB -eq 0 ]] && {
    err "ADB not available or no device connected"
    return 1
  }
  log "Cleaning Android logs via ADB"
  [[ $DRY_RUN -eq 0 ]] && {
    adb shell logcat -c &>/dev/null || :
    adb shell rm -rf /cache/log/* &>/dev/null || :
    adb shell rm -rf /data/log/* &>/dev/null || :
    adb shell rm -rf /data/tombstones/* &>/dev/null || :
  }
  log "Cleaning app caches via ADB"
  [[ $DRY_RUN -eq 0 ]] && { adb shell pm trim-caches 999999999M &>/dev/null || :; }
  info "ADB cleaning complete"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
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
  if [[ $OPT_QUICK -eq 0 && $OPT_DEEP -eq 0 && $OPT_WHATSAPP -eq 0 && $OPT_TELEGRAM -eq 0 && $OPT_ADB -eq 0 && $OPT_SYSTEM_CACHE -eq 0 && $OPT_PKG_CACHE -eq 0 ]]; then
    OPT_QUICK=1
  fi
  detect_privileges
  log "Starting clean operations"
  [[ $DRY_RUN -eq 1 ]] && warn "DRY RUN MODE - No files will be deleted"

  [[ $OPT_PKG_CACHE -eq 1 ]] && clean_pkg_cache
  [[ $OPT_QUICK -eq 1 ]] && clean_quick
  [[ $OPT_DEEP -eq 1 ]] && clean_deep
  [[ $OPT_WHATSAPP -eq 1 ]] && clean_whatsapp
  [[ $OPT_TELEGRAM -eq 1 ]] && clean_telegram
  [[ $OPT_SYSTEM_CACHE -eq 1 ]] && clean_system_cache
  [[ $OPT_ADB -eq 1 ]] && clean_adb

  info "All cleaning operations complete"
}

main "$@"
