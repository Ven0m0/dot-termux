#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t'; LC_ALL=C; LANG=C; DEBIAN_FRONTEND=noninteractive
# In-place optimization for JPG & PNG. Source or run.
# Usage: ./img-inplace.sh [dir]
log(){ printf '[INFO] %s\n' "$*"; }
fdjpg(){
  local d=${1:-.}
  log "Optimizing JPEGs in $d..."
  fd -tf -e jpg -e jpeg . "$d" -x jpegoptim -s --all-progressive -m85 --quiet || :
}
fdpng(){
  local d=${1:-.}
  log "Optimizing PNGs in $d..."
  fd -tf -e png . "$d" -x optipng -o5 -strip all -fix -clobber -quiet || :
}
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  TARGET=${1:-.}; log "Running in-place optimization on '$TARGET'..."
  fdjpg "$TARGET"; fdpng "$TARGET"; log "Done."
fi
