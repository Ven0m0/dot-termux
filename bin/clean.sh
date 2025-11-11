#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob globstar
IFS=$'\n\t'
export LC_ALL=C LANG=C

# ============================================================================
# EMBEDDED UTILITIES (self-contained, no external dependencies)
# ============================================================================

# Color codes
readonly R=$'\e[31m' G=$'\e[32m' Y=$'\e[33m' B=$'\e[34m'
readonly D=$'\e[0m'

# Check if command exists
has() { command -v -- "$1" &>/dev/null; }

# Logging functions
log() { printf '[%(%H:%M:%S)T] %s\n' -1 "$*"; }
info() { printf '%b[*]%b %s\n' "$G" "$D" "$*"; }
warn() { printf '%b[!]%b %s\n' "$Y" "$D" "$*" >&2; }
err() { printf '%b[x]%b %s\n' "$R" "$D" "$*" >&2; }

# Print step header
print_step() { printf '\n%b==>%b %s\n' "$B" "$D" "$*"; }

# ============================================================================
# GLOBALS
# ============================================================================

declare -g DRY_RUN=0 VERBOSE=0 HAS_SHIZUKU=0 HAS_ADB=0 PRIVILEGES_CHECKED=0
declare -g OPT_QUICK=0 OPT_DEEP=0 OPT_WHATSAPP=0 OPT_TELEGRAM=0 OPT_ADB=0 OPT_SYSTEM_CACHE=0 OPT_PKG_CACHE=0

# ============================================================================
# HELP & CORE FUNCTIONS
# ============================================================================

show_help() {
  cat <<EOF
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
EOF
}

# Utility Functions
detect_privileges() {
  [[ $PRIVILEGES_CHECKED -eq 1 ]] && return
  PRIVILEGES_CHECKED=1
  if has rish && rish id &>/dev/null; then
    HAS_SHIZUKU=1
    [[ $VERBOSE -eq 1 ]] && info "Shizuku access available"
  fi
  if has adb && adb devices 2>/dev/null | grep -q 'device$'; then
    HAS_ADB=1
    [[ $VERBOSE -eq 1 ]] && info "ADB access available"
  fi
}

clean_pkg_cache() {
  print_step "Cleaning package cache"
  if ((DRY_RUN)); then
    log "Would clean package caches"
    return
  fi
  if has apt || has apt-get; then
    apt-get clean && apt-get autoclean && apt-get autoremove -y --purge || :
  fi
  info "Package cache cleaning complete"
}

clean_temp_files() {
  log "Cleaning temporary files"
  if ((DRY_RUN)); then
    log "Would clean temporary files"
  else
    [[ -d "${HOME}/.cache" ]] && find "${HOME}/.cache" -type f -delete 2>/dev/null || :
    [[ -d "${TMPDIR:-/tmp}" ]] && find "${TMPDIR:-/tmp}" -type f -delete 2>/dev/null || :
  fi
}

quick_clean() {
  print_step "Quick cleaning"
  clean_pkg_cache
  clean_temp_files
}

deep_clean() {
  print_step "Deep cleaning"
  quick_clean
  log "Cleaning downloads older than 60 days"
  [[ -d "${HOME}/storage/shared/Download" ]] && find "${HOME}/storage/shared/Download" -type f -mtime +60 -delete || :
}

clean_system_cache() {
  print_step "Cleaning system cache"
  [[ $HAS_SHIZUKU -eq 1 ]] && rish pm trim-caches 128G || :
  [[ $HAS_ADB -eq 1 ]] && adb shell pm trim-caches 128G || :
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -q|--quick) OPT_QUICK=1; shift ;;
      -d|--deep) OPT_DEEP=1; shift ;;
      -s|--system-cache) OPT_SYSTEM_CACHE=1; shift ;;
      -p|--pkg-cache) OPT_PKG_CACHE=1; shift ;;
      -n|--dry-run) DRY_RUN=1; shift ;;
      -v|--verbose) VERBOSE=1; shift ;;
      -h|--help) show_help; exit 0 ;;
      *) err "Unknown option: $1" ;;
    esac
  done
  detect_privileges
  ((OPT_PKG_CACHE)) && clean_pkg_cache
  ((OPT_QUICK)) && quick_clean
  ((OPT_DEEP)) && deep_clean
  ((OPT_SYSTEM_CACHE)) && clean_system_cache
  info "All cleaning operations complete"
}

main "$@"
