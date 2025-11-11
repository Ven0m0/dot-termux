#!/data/data/com.termux/files/usr/bin/env bash
# common.sh - Shared utilities and constants for all scripts
# Source this file: source "${BASH_SOURCE[0]%/*}/lib/common.sh"

# Prevent multiple sourcing
[[ -n ${_COMMON_SH_LOADED:-} ]] && return 0
readonly _COMMON_SH_LOADED=1

# ============================================================================
# CONSTANTS
# ============================================================================

# Termux paths
readonly PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
readonly TERMUX_HOME="/data/data/com.termux/files/home"

# Color codes
readonly BLK=$'\e[30m' RED=$'\e[31m' GRN=$'\e[32m' YLW=$'\e[33m'
readonly BLU=$'\e[34m' MGN=$'\e[35m' CYN=$'\e[36m' WHT=$'\e[37m'
readonly LBLU=$'\e[38;5;117m' PNK=$'\e[38;5;218m' BWHT=$'\e[97m'
readonly DEF=$'\e[0m' BLD=$'\e[1m' UND=$'\e[4m'

# Short aliases
readonly R=$'\e[31m' G=$'\e[32m' Y=$'\e[33m' B=$'\e[34m'
readonly C=$'\e[36m' W=$'\e[37m' D=$'\e[0m' BD=$'\e[1m'

# ============================================================================
# CORE HELPER FUNCTIONS
# ============================================================================

# Check if command exists
has() { command -v -- "$1" &>/dev/null; }

# Logging functions
log() { printf '[%(%H:%M:%S)T] %s\n' -1 "$*"; }
info() { printf '%b[*]%b %s\n' "$G" "$D" "$*"; }
warn() { printf '%b[!]%b %s\n' "$Y" "$D" "$*" >&2; }
err() { printf '%b[x]%b %s\n' "$R" "$D" "$*" >&2; }

# Die with error message
die() {
  err "$1"
  exit "${2:-1}"
}

# Print step header
print_step() { printf '\n%b==>%b %s\n' "$B" "$D" "$*"; }

# ============================================================================
# FILE SYSTEM UTILITIES
# ============================================================================

# Ensure directory exists
ensure_dir() {
  local dir
  for dir in "$@"; do
    [[ -d $dir ]] || mkdir -p -- "$dir"
  done
}

# Get file size
get_size() {
  if stat -c%s "$1" 2>/dev/null; then
    stat -c%s "$1" 2>/dev/null || echo 0
  elif stat -f%z "$1" 2>/dev/null; then
    stat -f%z "$1" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# Format bytes to human-readable
format_bytes() {
  local bytes=$1
  if has numfmt; then
    numfmt --to=iec-i --suffix=B --format="%.2f" "$bytes"
  elif ((bytes < 1024)); then
    printf '%dB' "$bytes"
  elif ((bytes < 1048576)); then
    local kb=$((bytes * 10 / 1024))
    printf '%d.%dKB' $((kb / 10)) $((kb % 10))
  else
    local mb=$((bytes * 100 / 1048576))
    printf '%d.%02dMB' $((mb / 100)) $((mb % 100))
  fi
}

# Get absolute path
abs_path() {
  local target=$1
  [[ $target == /* ]] || target="${PWD}/$target"
  if has realpath; then
    realpath "$target"
  elif has readlink; then
    readlink -f "$target"
  else
    (builtin cd -P -- "$(dirname -- "$target")" && printf '%s/%s\n' "$PWD" "$(basename -- "$target")")
  fi
}

# Basename implementation
bname() {
  local t=${1%"${1##*[!/]}"}
  t=${t##*/}
  [[ -n $2 && $t == *"$2" ]] && t=${t%"$2"}
  printf '%s\n' "${t:-/}"
}

# Dirname implementation
dname() {
  local p=${1:-.}
  [[ $p != *[!/]* ]] && { printf '/\n'; return; }
  p=${p%"${p##*[!/]}"}
  [[ $p != */* ]] && { printf '.\n'; return; }
  p=${p%/*}
  p=${p%"${p##*[!/]}"}
  printf '%s\n' "${p:-/}"
}

# ============================================================================
# COMMAND WRAPPERS
# ============================================================================

# Universal find wrapper: fd with fallback to find
# Usage: run_find [fd_args...] path
# Just passes through to fd if available, otherwise translates to find
run_find() {
  # Use fd/fdfind if available - just pass through
  if has fd; then
    fd "$@" 2>/dev/null || :
    return
  elif has fdfind; then
    fdfind "$@" 2>/dev/null || :
    return
  fi
  
  # Fallback to find - parse common fd patterns
  local find_type="" find_path="." find_depth=""
  local -a find_names=() find_exec=() extra_args=()
  local null_sep=0
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -tf) find_type="-type f"; shift;;
      -td) find_type="-type d"; shift;;
      -tl) find_type="-type l"; shift;;
      -e)
        shift
        find_names+=(-o -name "*.$1")
        shift
        ;;
      -g)
        shift
        find_names+=(-o -name "$1")
        shift
        ;;
      -d|--max-depth)
        shift
        find_depth="-maxdepth $1"
        shift
        ;;
      --changed-before)
        shift
        # Convert "Nd" to -mtime +N
        local val="${1%d}"
        extra_args+=(-mtime "+$val")
        shift
        ;;
      --owner)
        shift
        extra_args+=(-user "$1")
        shift
        ;;
      -0) null_sep=1; shift;;
      -X|-x)
        shift
        find_exec=(-exec "$1" {} \;)
        shift
        ;;
      -u|-E)
        # fd-specific, ignore
        shift
        [[ "${1:-}" != -* ]] && shift || :
        ;;
      .)
        # Current dir marker
        shift
        ;;
      *)
        # Treat non-flag as path
        if [[ "$1" != -* ]]; then
          find_path="$1"
          shift
        else
          shift
        fi
        ;;
    esac
  done
  
  # Build find command
  local -a cmd=("$find_path")
  [[ -n $find_depth ]] && cmd+=($find_depth)
  [[ -n $find_type ]] && cmd+=($find_type)
  
  if [[ ${#find_names[@]} -gt 0 ]]; then
    # Remove first -o
    find_names=("${find_names[@]:1}")
    [[ ${#find_names[@]} -eq 1 ]] && cmd+=("${find_names[@]}") || cmd+=(\( "${find_names[@]}" \))
  fi
  
  [[ ${#extra_args[@]} -gt 0 ]] && cmd+=("${extra_args[@]}")
  [[ ${#find_exec[@]} -gt 0 ]] && cmd+=("${find_exec[@]}")
  [[ $null_sep -eq 1 ]] && cmd+=(-print0)
  
  find "${cmd[@]}" 2>/dev/null || :
}

# Git -> Gix wrapper (gitoxide)
git() {
  local subcmd="${1:-}"
  if has gix; then
    case "$subcmd" in
      clone|fetch|pull|init|status|diff|log|rev-parse|rev-list|commit-graph|\
      verify-pack|index-from-pack|pack-explode|remote|config|exclude|free|\
      mailmap|odb|commitgraph|pack)
        gix "$@"
        ;;
      *)
        command git "$@"
        ;;
    esac
  else
    command git "$@"
  fi
}

# Curl -> Aria2 wrapper
curl() {
  if ! has aria2c; then
    command curl "$@"
    return
  fi

  local -a args=()
  local out_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--output)
        out_file="$2"
        shift 2
        ;;
      -L|--location|-s|--silent|-S|--show-error|-f|--fail|--compressed)
        shift
        ;;
      http*|ftp*)
        args+=("$1")
        shift
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#args[@]} -gt 0 ]]; then
    local -a aria_flags=(-x16 -s16 -k1M -j16 --file-allocation=none --summary-interval=0)
    if [[ -n $out_file ]]; then
      aria2c "${aria_flags[@]}" -d "$(dirname "$out_file")" -o "$(basename "$out_file")" "${args[@]}"
    else
      aria2c "${aria_flags[@]}" "${args[@]}"
    fi
  else
    command curl "$@"
  fi
}

# Pip -> UV wrapper
pip() {
  if has uv; then
    case "${1:-}" in
      install|uninstall|list|show|freeze|check)
        uv pip "$@"
        ;;
      *)
        command pip "$@"
        ;;
    esac
  else
    command pip "$@"
  fi
}

# ============================================================================
# TERMUX-SPECIFIC UTILITIES
# ============================================================================

# Update Termux packages
updt() {
  export LC_ALL=C DEBIAN_FRONTEND=noninteractive
  local p=${PREFIX}
  pkg up -y
  apt-get -y --fix-broken install
  dpkg --configure -a
  pkg clean -y
  pkg autoclean -y
  apt -y autoclean
  apt-get -y autoremove --purge
  rm -rf "${p}/var/lib/apt/lists/"* "${p}/var/cache/apt/archives/partial/"* &>/dev/null
}

# Sweep home directory
sweep_home() {
  local base=${1:-$HOME}
  local p=${PREFIX}
  export LC_ALL=C

  run_find -tf -e bak -e log -e old -e tmp -u -E .git "$base" -x rm -f
  # Find and remove empty files
  find "$base" -type f -empty -not -path '*/.git/*' -delete 2>/dev/null || :
  # Find and remove empty directories
  find "$base" -type d -empty -not -path '*/.git/*' -delete 2>/dev/null || :
  run_find -tf "${p}/share/doc" "${p}/var/cache" "${p}/share/man" -x rm -f

  rm -rf "${p}/share/groff/"* "${p}/share/info/"* "${p}/share/lintian/"* "${p}/share/linda/"*
}

# ============================================================================
# CACHE SYSTEM
# ============================================================================

# Tool availability cache
declare -gA _TOOL_CACHE=()

cache_tool() {
  local tool=$1
  if [[ -z ${_TOOL_CACHE[$tool]:-} ]]; then
    if has "$tool"; then
      _TOOL_CACHE[$tool]=1
    else
      _TOOL_CACHE[$tool]=0
    fi
  fi
  return $((1 - _TOOL_CACHE[$tool]))
}

# Detect number of processors
get_nproc() {
  nproc 2>/dev/null || echo 4
}

# ============================================================================
# EXPORT FUNCTIONS FOR SUBSHELLS
# ============================================================================

# Export all functions for use in subshells (e.g., with parallel/xargs)
export_common_functions() {
  export -f has log info warn err die
  export -f ensure_dir get_size format_bytes abs_path bname dname
  export -f run_find git curl pip
  export -f cache_tool get_nproc
}
