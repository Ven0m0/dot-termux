#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"

# vid-min: Video minimizer (AV1/VP9) using ffmpeg/ffzap
# Usage: vid-min [options] [dir|file]
# Options:
#   -m mode   Encoder mode: av1 (default) or vp9
#   -c crf    CRF quality (default: 30)
#   -r        Replace original files (delete source after success)
#   -n        Dry run
VERSION="2.1.0"
MODE="av1"
CRF="30"
REPLACE=0
DRY_RUN=0

# Video: Scale to max 1920 (landscape/portrait) > Deband
readonly V_FILT="scale='if(gt(iw,ih),min(1920,iw),-2)':'if(gt(iw,ih),-2,min(1920,ih))',deband"
# Audio: Opus 96k Stereo
readonly A_OPTS=(-c:a libopus -b:a 96k -ac 2 -rematrix_maxval 1.0)
# AV1: 10-bit, Preset 6 (Balanced), Tune 0
readonly AV1_OPTS=(-preset 6 -g 300 -pix_fmt yuv420p10le -svtav1-params film-grain=8:keyint=300:enable-qm=1:qm-min=0)
# VP9: 8-bit, CPU-used 3
readonly VP9_OPTS=(-b:v 0 -cpu-used 3 -row-mt 1)

has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
warn(){ printf '\e[33m[WARN]\e[0m %s\n' "$*"; }
die(){ printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; exit 1; }
usage(){
  cat <<EOF
vid-min v$VERSION
Usage: vid-min [-m av1|vp9] [-c crf] [-r] [-n] [target]
EOF
  exit 0
}
collect_inputs(){
  local t=$1
  if [[ -f $t ]]; then
    printf '%s\0' "$t"
    return
  fi
  if has fd; then
    fd -0 -t f -e mp4 -e mkv -e avi -e mov -e webm . "$t"
  else
    find "$t" -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" -o -name "*.webm" \) -print0
  fi
}
process_one(){
  local in=$1 out="${in%.*}.$MODE.mkv"
  [[ $in == *".$MODE".mkv ]] && return 0
  [[ -e $out ]] && { log "Skip (exists): $out"; return 0; }
  local enc opts tool="ffmpeg"
  if [[ $MODE == "vp9" ]]; then
    enc="libvpx-vp9"; opts=("${VP9_OPTS[@]}")
  else
    enc="libsvtav1"; opts=("${AV1_OPTS[@]}")
  fi
  command -v ffzap &>/dev/null && tool="ffzap"
  log "⚡ $tool [$MODE CRF $CRF]: ${in##*/}"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf 'DRY: %s -> %s\n' "$in" "$out"
    return 0
  fi
  if [[ $tool == "ffzap" ]]; then
    ffzap -o "$out" "$in" -- \
      -c:v "$enc" -crf "$CRF" "${opts[@]}" \
      -vf "$V_FILT" "${A_OPTS[@]}" \
      -map_metadata 0 -movflags +faststart \
      </dev/null &>/dev/null
  else
    ffmpeg -nostdin -hide_banner -loglevel error -stats -i "$in" \
      -c:v "$enc" -crf "$CRF" "${opts[@]}" \
      -vf "$V_FILT" "${A_OPTS[@]}" \
      -map_metadata 0 -movflags +faststart \
      -y "$out"
  fi
  local res=$?
  if [[ $res -eq 0 ]]; then
    echo "[DONE] $out"
    if [[ $REPLACE -eq 1 ]]; then
      log "Deleting original: $in"
      rm -- "$in"
    fi
  else
    echo "[FAIL] $in"
    rm -f -- "$out"
    return $res
  fi
}
process_video(){
  local target=${1:-.}
  log "Starting $MODE (CRF $CRF) in '$target'..."
  [[ $REPLACE -eq 1 ]] && warn "REPLACE MODE ACTIVE: Originals will be deleted!"
  while IFS= read -r -d '' path; do
    process_one "$path"
  done < <(collect_inputs "$target")
}
TARGET="."
while getopts "m:c:rnh" opt; do
  case $opt in
    m) MODE="$OPTARG" ;;
    c) CRF="$OPTARG" ;;
    r) REPLACE=1 ;;
    n) DRY_RUN=1 ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND -1))
TARGET="${1:-.}"
[[ ! -e "$TARGET" ]] && die "Target '$TARGET' not found."
has ffmpeg || die "ffmpeg not found."
process_video "$TARGET"
log "Done."
