#!/usr/bin/env bash
set -euo pipefail
# -- Config --
# Filters: Scale to 1080p width, keep aspect ratio
readonly V_FILT="scale=-2:'min(1080,ih)'"
readonly A_OPTS="-c:a libopus -b:a 128k"

# -- Helpers --
has(){ command -v "$1" &>/dev/null; }
log(){ printf '\e[32m[OK]\e[0m %s\n' "$*"; }

convert_file(){
  local in="$1" mode="$2" crf="$3"
  local enc opts out tool="ffmpeg"
  # Detect tool
  has ffzap && tool="ffzap"
  # Settings
  case "$mode" in
    vp9) enc="libvpx-vp9"; crf="${crf:-32}"; opts="-b:v 0 -cpu-used 3 -row-mt 1" ;;
    *)   enc="libsvtav1";  crf="${crf:-32}"; opts="-preset 8 -g 240" ;;
  esac
  # Output filename: input.av1.mkv
  out="${in%.*}.${mode}.mkv"
  [[ -f "$out" ]] && return
  printf "⚡ %s [%s CRF %s]: %s\n" "$tool" "$mode" "$crf" "${in##*/}"
  if [[ "$tool" == "ffzap" ]]; then
    # ffzap wrapper (redirect stdin to prevent loop breaking)
    ffzap -o "$out" "$in" -- -c:v "$enc" -crf "$crf" $opts -vf "$V_FILT" $A_OPTS < /dev/null >/dev/null 2>&1
  else
    # standard ffmpeg (add -nostdin)
    ffmpeg -nostdin -hide_banner -loglevel error -stats -i "$in" \
      -c:v "$enc" -crf "$crf" $opts -vf "$V_FILT" $A_OPTS -y "$out"
  fi
  log "$out"
}
export -f convert_file has log
usage() {
  echo "Usage: vid-min [av1|vp9] [crf] [target_dir/file]"
  echo "Example: vid-min av1 30 ."
  exit 1
}
# -- Main --
MODE="av1"
CRF="32"
TARGET=""
# Heuristic arg parsing
for arg in "$@"; do
  if [[ "$arg" =~ ^(av1|vp9)$ ]]; then 
    MODE="$arg"
  elif [[ "$arg" =~ ^[0-9]+$ ]] && [[ ! -e "$arg" ]]; then 
    # Only treat as CRF if it's a number AND not an existing filename
    CRF="$arg"
  else 
    TARGET="$arg"
  fi
done
[[ -z "$TARGET" ]] && TARGET="."
# Export config variables so subshells (fd/xargs) can see them
export V_FILT A_OPTS
if [[ -f "$TARGET" ]]; then
  convert_file "$TARGET" "$MODE" "$CRF"
elif [[ -d "$TARGET" ]]; then
  # 1. Try using fd (Fastest)
  if has fd; then
    # -j1 is critical for video encoding on mobile to prevent overheating/OOM
    fd -t f -e mp4 -e mkv -e avi -e mov -e webm . "$TARGET" -j 1 \
       -x bash -c 'convert_file "$1" "$2" "$3"' _ {} "$MODE" "$CRF"
  # 2. Fallback to find (Compatible)
  else
    # Standard -name usage is safer than -regextype on limited systems
    find "$TARGET" -type f \( \
      -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" -o -name "*.webm" -o -name "*.flv" \
    \) -exec bash -c 'convert_file "$1" "$2" "$3"' _ {} "$MODE" "$CRF" \;
  fi
else
  echo "Input not found: $TARGET"
  exit 1
fi
