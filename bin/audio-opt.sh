#!/data/data/com.termux/files/usr/bin/env bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '[INFO] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
# audio-opt: Convert audio to Opus 96k Stereo (deletes originals)
# Usage: ./audio-opt.sh [dir]
# Dependencies: ffmpeg; fd optional for parallelism
readonly A_OPTS=("-c:a" "libopus" "-b:a" "96k" "-ac" "2" "-rematrix_maxval" "1.0" "-vn")
encode_one(){
  local in=$1 out="${in%.*}.opus"
  [[ -e $out ]] && { log "Skip (exists): $out"; return 0; }
  ffmpeg -nostdin -hide_banner -loglevel error -i "$in" "${A_OPTS[@]}" -y "$out"
  rm -- "$in"
}
fdaudio(){
  local d=${1:-.} jobs=1
  has nproc && jobs=$(nproc)
  if has fd; then
    fd -tf -e mp3 -e m4a -e flac -e wav -e ogg -e aac -e wma -E '*.opus' . "$d" \
      -j "$jobs" -x bash -c 'set -euo pipefail; '"$(declare -f encode_one)"'; encode_one "$1"' _ {}
  else
    log "fd not found, using find..."
    find "$d" -type f \( -name "*.mp3" -o -name "*.m4a" -o -name "*.flac" -o -name "*.wav" -o -name "*.ogg" -o -name "*.aac" -o -name "*.wma" \) \
      -exec bash -c 'set -euo pipefail; '"$(declare -f encode_one)"'; encode_one "$1"' _ {} \;
  fi
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  has ffmpeg || die "ffmpeg is required"
  target=${1:-.}
  log "Optimizing audio to Opus 96k in '$target' (originals deleted)..."
  fdaudio "$target"
  log "Done."
fi
