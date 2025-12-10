#!/data/data/com.termux/files/usr/bin/env bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t' LC_ALL=C
# audio-opt: Convert audio to Opus 96k Stereo (deletes originals)
# Usage: ./audio-opt.sh [dir]
# Dependencies: fd (optional), ffmpeg
# -- Config --
# Opus 96k Stereo, prevent clipping during downmixing
readonly A_OPTS="-c:a libopus -b:a 96k -ac 2 -rematrix_maxval 1.0 -vn"
has(){ command -v "$1" &>/dev/null; }
log(){ printf '[INFO] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
fdaudio(){
  local d=${1:-.}
  local cmd='ffmpeg -nostdin -hide_banner -loglevel error -i "$1" '"$A_OPTS"' -y "${1%.*}.opus" && rm "$1"'
  if has fd; then
    # Process in parallel with fd
    fd -tf -e mp3 -e m4a -e flac -e wav -e ogg -e aac -e wma -E '*.opus' . "$d" \
      -j "$(nproc)" -x bash -c "$cmd" _ {}
  else
    # Fallback to find
    log "fd not found, using find..."
    find "$d" -type f \( -name "*.mp3" -o -name "*.m4a" -o -name "*.flac" -o -name "*.wav" -o -name "*.ogg" -o -name "*.aac" \) \
      -exec bash -c "$cmd" _ {} \;
  fi
}
# -- Main --
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  has ffmpeg || die "ffmpeg is required"
  TARGET=${1:-.}
  log "Optimizing audio to Opus 96k in '$TARGET'..."
  fdaudio "$TARGET"
  log "Done."
fi
