#!/data/data/com.termux/files/usr/bin/env bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t' LC_ALL=C
# WebP converter - converts JPG/PNG to WebP and deletes originals
# Usage: source img-webp.sh; fdwebp [dir] OR ./img-webp.sh [dir]
# Dependencies: fd, libwebp
log(){ printf '[INFO] %s\n' "$*"; }
fdwebp(){
  local d=${1:-.}
  fd -tf -e jpg -e jpeg -e png -E '*.webp' . "$d" \
    -x bash -c 'cwebp -q 80 -m 6 -pass 10 -quiet -metadata none "$1" -o "${1%.*}.webp" && rm "$1"' _ {} || :
}
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  TARGET=${1:-.}; log "Converting to WebP in '$TARGET' (deletes originals)..."
  fdwebp "$TARGET"; log "Done."
fi
