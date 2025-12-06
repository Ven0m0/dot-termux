#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t' LC_ALL=C LANG=C

has(){ command -v -- "$1" &>/dev/null; }
die(){ printf 'ERR: %s\n' "$*" >&2; exit 1; }
log(){ printf '[%(%H:%M:%S)T] %s\n' -1 "$*"; }
for c in ffmpeg fd; do has "$c" || die "missing: $c"; done
enc_vp9(){
  local d=${1:-.} crf=${2:-32}
  log "Encoding VP9 (crf=$crf, sequential) in $d..."
  fd -tf -e mp4 -e mov -e mkv -e avi -e webm -j1 . "$d" -x bash -c \
    'f="$1"; o="${f%.*}_vp9.mkv"; ffmpeg -hide_banner -loglevel error -y -i "$f" -c:v libvpx-vp9 -b:v 0 -crf '"$crf"' -cpu-used 3 -row-mt 1 -c:a libopus -b:a 96k "$o"&&printf "OK: %s\n" "$o"' _ {}
}
enc_av1(){
  local d=${1:-.} crf=${2:-35}
  log "Encoding AV1 (crf=$crf, sequential) in $d..."
  fd -tf -e mp4 -e mov -e mkv -e avi -e webm -j1 . "$d" -x bash -c \
    'f="$1"; o="${f%.*}_av1.mkv"; ffmpeg -hide_banner -loglevel error -y -i "$f" -c:v libsvtav1 -crf '"$crf"' -preset 10 -c:a libopus -b:a 96k "$o"&&printf "OK: %s\n" "$o"' _ {}
}
enc_ffzap(){
  local d=${1:-.} codec=${2:-vp9} crf=${3:-32} vc vcrf
  has ffzap||{ log "ffzap not found (cargo install ffzap), using fallback"; [[ $codec == av1 ]]&&enc_av1 "$d" "$crf"||enc_vp9 "$d" "$crf"; return; }
  log "Encoding with ffzap ($codec, crf=$crf) in $d..."
  if [[ $codec == av1 ]]; then vc=libsvtav1; vcrf=${crf:-35}; else vc=libvpx-vp9; vcrf=${crf:-32}; fi
  fd -tf -e mp4 -e mov -e mkv -e avi -e webm -j1 . "$d" -x bash -c \
    'f="$1"; o="${f%.*}_min.mkv"; ffzap -o "$o" "$f" -- -c:v '"$vc"' -crf '"$vcrf"' '"$([[ $vc == libsvtav1 ]]&&printf -- '-preset 10'||printf -- '-b:v 0 -cpu-used 3 -row-mt 1')"' -c:a libopus -b:a 96k&&printf "OK: %s\n" "$o"' _ {}
}
usage(){
  cat <<'EOF'
vid-min.sh - Video minification with VP9/AV1
USAGE: vid-min.sh COMMAND [DIR] [CRF]

COMMANDS:
  vp9 [dir] [crf]    Encode to VP9 (default crf=32)
  av1 [dir] [crf]    Encode to AV1 (default crf=35)
  zap [dir] [codec] [crf]  Use ffzap wrapper (codec=vp9|av1, default vp9/32)

EXAMPLES:
  vid-min.sh vp9 ~/Videos 28
  vid-min.sh av1 . 33
  vid-min.sh zap ~/Movies vp9 30
  vid-min.sh zap . av1 35

NOTES:
  - Sequential processing (-j1) to conserve battery/RAM
  - VP9: Good quality/size, faster encoding
  - AV1: Best compression, slower encoding
  - ffzap: Rust wrapper, requires 'cargo install ffzap'
EOF
}
main(){
  [[ $# -eq 0 || $1 == -h || $1 == --help ]]&&{ usage; exit 0; }
  local cmd=$1; shift
  case $cmd in
    vp9) enc_vp9 "${1:-.}" "${2:-32}";;
    av1) enc_av1 "${1:-.}" "${2:-35}";;
    zap) enc_ffzap "${1:-.}" "${2:-vp9}" "${3:-32}";;
    *) die "Unknown: $cmd (use --help)";;
  esac
  log "Done."
}
main "$@"
