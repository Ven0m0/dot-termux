#!/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t'; LC_ALL=C; LANG=C
# --- Config & Global Variables ---
# Export variables immediately so subshells inherit them
export V_FILT="scale=-2:'min(1080,ih)'"
export A_OPTS="-c:a libopus -b:a 128k"
readonly EXTS="mp4|mkv|avi|mov|webm|flv"
has(){ command -v "$1" &>/dev/null; }
log(){ printf '\e[32m[OK]\e[0m %s\n' "$*"; }
# --- Encoder Function ---
convert(){
  local in="$1" mode="${2:-av1}" crf="${3:-}"
  local enc opts out tool="ffmpeg"
  # Config based on mode
  case "$mode" in
    vp9) enc="libvpx-vp9"; crf="${crf:-32}"; opts="-b:v 0 -cpu-used 3 -row-mt 1";;
    *) enc="libsvtav1";  crf="${crf:-32}"; opts="-preset 8"; mode="av1";;
  esac
  # Auto-use ffzap if available
  has ffzap && tool="ffzap"
  out="${in%.*}.${mode}.mkv"
  [[ -f "$out" ]] && return
  printf "⚡ %s (%s, crf=%s): %s\n" "$tool" "$mode" "$crf" "$in"
  # Use environment variables V_FILT and A_OPTS
  if [[ "$tool" == "ffzap" ]]; then
    # ffzap wrapper syntax
    ffzap -o "$out" "$in" -- -c:v "$enc" -crf "$crf" $opts -vf "$V_FILT" $A_OPTS &>/dev/null
  else
    # Standard ffmpeg syntax
    ffmpeg -hide_banner -loglevel error -stats -i "$in" \
      -c:v "$enc" -crf "$crf" $opts -vf "$V_FILT" $A_OPTS -y "$out"
  fi
  log "$out"
}
# --- Runner ---
run_batch(){
  local mode="$1" target="$2" crf="${3:-}"
  if has fd; then
    # Sequential (-j1) to prevent OOM
    # Note: convert/has/log are exported functions; V_FILT/A_OPTS are exported vars
    fd -t f -e mp4 -e mkv -e avi -e mov -e webm -j1 . "$target" \
      -x bash -c 'convert "$1" "$2" "$3"' _ {} "$mode" "$crf"
  else
    find "$target" -type f -regextype posix-extended -iregex ".*\.($EXTS)$" | \
    while read -r f; do convert "$f" "$mode" "$crf"; done
  fi
}
main(){
  # Only export functions here
  export -f convert has log
  # Heuristic argument parsing
  local mode="av1" target="" crf=""
  if [[ $# -eq 0 ]]; then printf "Usage: %s [av1|vp9] <file|dir> [crf]\n" "$0"; exit 1; fi
  # Detect if $1 is a mode keyword
  if [[ "$1" =~ ^(av1|vp9)$ ]]; then
    mode="$1"; shift
  fi
  target="${1:-}"; crf="${2:-}"
  [[ -z "$target" ]] && { printf "Error: No input specified.\n" >&2; exit 1; }
  if [[ -f "$target" ]]; then
    convert "$target" "$mode" "$crf"
  elif [[ -d "$target" ]]; then
    run_batch "$mode" "$target" "$crf"
  else
    printf "Error: Invalid input '%s'\n" "$target" >&2; exit 1
  fi
}
main "$@"
