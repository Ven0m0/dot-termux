#!/data/data/com.termux/files/usr/bin/env bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t' LC_ALL=C
# -- Configuration --
# Video: Scale to max 1920 (landscape/portrait) > Deband
readonly V_FILT="scale='if(gt(iw,ih),min(1920,iw),-2)':'if(gt(iw,ih),-2,min(1920,ih))',deband"
# Audio: Opus 96k Stereo
readonly A_OPTS="-c:a libopus -b:a 96k -ac 2 -rematrix_maxval 1.0"
# AV1: 10-bit, Preset 4 (Quality > Speed), Tune 0
readonly AV1_OPTS="-preset 6 -g 240 -pix_fmt yuv420p10le -svtav1-params tune=0:enable-qm=1"
# -- Helpers --
has(){ command -v "$1" &>/dev/null; }
log(){ printf '\e[32m[OK]\e[0m %s\n' "$*"; }
convert_file(){
  local in="$1" mode="$2" crf="$3"
  local enc opts out tool="ffmpeg"
  # Skip if file looks like a result (prevent loops)
  if [[ "$in" == *."$mode".mkv ]]; then return; fi
  out="${in%.*}.${mode}.mkv"
  [[ -f "$out" ]] && return
  # Select Encoder
  case "$mode" in
    vp9) enc="libvpx-vp9"; opts="-b:v 0 -cpu-used 3 -row-mt 1" ;;
    *) enc="libsvtav1";  opts="$AV1_OPTS" ;;
  esac
  # Detect ffzap (Background killer protection for Termux)
  if has ffzap; then tool="ffzap"; fi
  printf "⚡ %s [%s CRF %s]: %s\n" "$tool" "$mode" "$crf" "${in##*/}"
  if [[ "$tool" == "ffzap" ]]; then
    # ffzap handles the process, we pass flags after --
    ffzap -o "$out" "$in" -- \
      -c:v "$enc" -crf "$crf" $opts \
      -vf "$V_FILT" $A_OPTS \
      -map_metadata 0 -movflags +faststart \
      </dev/null &>/dev/null
  else
    # Native ffmpeg
    ffmpeg -nostdin -hide_banner -loglevel error -stats -i "$in" \
      -c:v "$enc" -crf "$crf" $opts \
      -vf "$V_FILT" $A_OPTS \
      -map_metadata 0 -movflags +faststart \
      -y "$out"
  fi
  log "$out"
}
export -f convert_file has log
export V_FILT A_OPTS AV1_OPTS
# -- CLI --
usage(){ echo "Usage: ${0##*/} [av1|vp9] [crf] [path]" >&2; exit 1; }
MODE="av1"
CRF="30" # Updated default based on your previous opt check
TARGET="."
# Flexible Arg Parsing
for arg in "$@"; do
  if [[ "$arg" =~ ^(av1|vp9)$ ]]; then MODE="$arg"
  elif [[ "$arg" =~ ^[0-9]+$ ]] && [[ ! -e "$arg" ]]; then CRF="$arg"
  else TARGET="$arg"
  fi
done

if [[ ! -e "$TARGET" ]]; then
  echo "Error: Target '$TARGET' not found."
  exit 1
fi

# -- Execution --
# Note: -j1 is mandatory for AV1 preset 4 on mobile to prevent thermal throttling
if [[ -d "$TARGET" ]]; then
  if has fd; then
    fd -t f -e mp4 -e mkv -e avi -e mov -e webm . "$TARGET" -j 1 \
      -x bash -c 'convert_file "$1" "$2" "$3"' _ {} "$MODE" "$CRF"
  else
    find "$TARGET" -type f \( \
      -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" -o -name "*.webm" \
    \) -exec bash -c 'convert_file "$1" "$2" "$3"' _ {} "$MODE" "$CRF" \;
  fi
elif [[ -f "$TARGET" ]]; then
  convert_file "$TARGET" "$MODE" "$CRF"
fi
