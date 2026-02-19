#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
# clean: Unified system and cache cleaner
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
# -- Config --
VERSION="2.1.0"
DRY_RUN=0
VERBOSE=0
# -- Helpers --
has() { command -v "$1" &>/dev/null; }
log() { printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[WARN]\e[0m %s\n' "$*"; }
die() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; exit 1; }
# Unified file removal with fd/find translation
rm_files() {
  local path="$1"; shift
  [[ -d "$path" ]] || return 0
  local fd_opts=()
  local find_opts=()
  local patterns=()
  local regexs=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e)
        patterns+=("-name" "*.$2")
        regexs+=("\.$2$")
        shift 2 ;;
      --changed-before)
        fd_opts+=("--changed-before" "$2")
        find_opts+=("-mtime" "+${2%d}")
        shift 2 ;;
      -g)
        patterns+=("-name" "$2")
        local re="$2"
        re="${re//./\\.}"
        re="${re//\*/.*}"
        regexs+=("^$re$")
        shift 2 ;;
      -d|--max-depth)
        fd_opts+=("--max-depth" "$2")
        find_opts+=("-maxdepth" "$2")
        shift 2 ;;
      *) shift ;;
    esac
  done

  local find_cmd=("find" "$path" "${find_opts[@]}" "-type" "f")
  if [[ ${#patterns[@]} -gt 0 ]]; then
    find_cmd+=("(")
    for ((i=0; i<${#patterns[@]}; i+=2)); do
      [[ $i -gt 0 ]] && find_cmd+=("-o")
      find_cmd+=("${patterns[i]}" "${patterns[i+1]}")
    done
    find_cmd+=(")")
  fi

  local fd_cmd=("fd" "-tf" "${fd_opts[@]}")
  if [[ ${#regexs[@]} -gt 0 ]]; then
    local joined_re
joined_re=$(printf '%s|' "${regexs[@]}")
fd_cmd+=("(${joined_re%|})" "$path")
  else
    fd_cmd+=("." "$path")
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    if has fd; then
      "${fd_cmd[@]}"
    else
      "${find_cmd[@]}" -print
    fi
    return
  fi

  if has fd; then
    "${fd_cmd[@]}" -X rm -f 2>/dev/null || :
  else
    "${find_cmd[@]}" -delete 2>/dev/null || :
  fi
}
# -- Tasks --
clean_pkg() {
  log "Cleaning package cache..."
  [[ $DRY_RUN -eq 1 ]] && return
  if has pkg; then
    pkg clean &>/dev/null || :
    pkg autoclean &>/dev/null || :
  elif has apt-get; then
    sudo apt-get clean &>/dev/null || :
    sudo apt-get autoclean &>/dev/null || :
  fi
}
clean_quick() {
  log "Running quick clean..."
  [[ $DRY_RUN -eq 0 ]] && {
    rm -f "$HOME/.zcompdump"* &>/dev/null || :
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump"* &>/dev/null || :
  }
  local tmp_dirs=("${XDG_CACHE_HOME:-$HOME/.cache}" "$HOME/tmp" "/data/data/com.termux/files/usr/tmp")
  for dir in "${tmp_dirs[@]}"; do
    rm_files "$dir"
  done
  rm_files "$HOME" -d 1 -e "log" -e "bak" -g "*~"
  if [[ $DRY_RUN -eq 0 ]]; then
    if has fd; then
      fd -td --max-depth 5 -H . "$HOME" -x rmdir 2>/dev/null || :
    else
      find "$HOME" -maxdepth 5 -type d -empty -delete 2>/dev/null || :
    fi
  fi
}
clean_deep() {
  clean_quick
  log "Running deep clean..."
  local dl="$HOME/storage/shared/Download"
  rm_files "$dl" --changed-before 60d
  rm_files "$HOME" -g "Thumbs.db" -g ".DS_Store"
}
clean_app_media() {
  local app="$1" days="${2:-30d}"
  local base="$HOME/storage/shared"
  [[ -d "$base" ]] || return
  log "Cleaning $app media (> $days)..."
  local paths=()
  if [[ "$app" == "WhatsApp" ]]; then
    paths=("$base/WhatsApp/Media/WhatsApp "{Images,Video,Audio,Documents})
  elif [[ "$app" == "Telegram" ]]; then
    paths=("$base/Telegram/Telegram "{Images,Video,Audio,Documents})
  fi
  for p in "${paths[@]}"; do
    rm_files "$p" --changed-before "$days"
  done
}
clean_system() {
  log "Cleaning system cache (requires privs)..."
  [[ $DRY_RUN -eq 1 ]] && return
  local cmd=""
  if has rish && rish -c id &>/dev/null; then cmd="rish";
  elif has adb && adb get-state &>/dev/null; then cmd="adb shell";
  elif [[ $EUID -eq 0 ]]; then cmd="eval";
  else warn "No root/adb/shizuku detected."; return 1;
  fi
  $cmd pm trim-caches 128G &>/dev/null || :
  $cmd logcat -c &>/dev/null || :
}
# -- CLI --
usage() {
  echo "Usage: clean [-q|-d] [-w|-t] [-s] [-n]"
  echo "  -q  Quick clean (cache, tmp, logs)"
  echo "  -d  Deep clean (includes downloads, junk)"
  echo "  -w  Clean WhatsApp (>30d)"
  echo "  -t  Clean Telegram (>30d)"
  echo "  -s  System cache (Trim caches)"
  echo "  -n  Dry run"
  exit 0
}
[[ $# -eq 0 ]] && usage
while getopts "qdwtsnvh" opt; do
  case $opt in
    q) clean_pkg; clean_quick ;;
    d) clean_pkg; clean_deep ;;
    w) clean_app_media "WhatsApp" ;;
    t) clean_app_media "Telegram" ;;
    s) clean_system ;;
    n) DRY_RUN=1 ;;
    v) VERBOSE=1 ;;
    *) usage ;;
  esac
done
