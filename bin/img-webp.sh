#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
# WebP converter - converts JPG/PNG to WebP and deletes originals
# Usage: source img-webp.sh; fdwebp [dir] OR ./img-webp.sh [dir]
# Dependencies: cwebp; fd optional for speed
log(){ printf '[INFO] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
has(){ command -v -- "$1" &>/dev/null; }
webp_one(){
  local in=$1
  local out="${in%.*}.webp"
  [[ -e $out ]] && { log "Skip (exists): $out"; return 0; }
  cwebp -q 80 -m 6 -pass 10 -quiet -metadata none "$in" -o "$out"
  rm -- "$in"
}
fdwebp(){
  local d=${1:-.}
  has cwebp || die "cwebp (libwebp) required"
  if has fd; then
    fd -tf -e jpg -e jpeg -e png -E '*.webp' . "$d" \
      -x bash -c 'set -euo pipefail; '"$(declare -f webp_one)"'; webp_one "$1"' _ {}
  else
    local jobs; jobs=$(nproc 2>/dev/null || echo 4)
    log "fd not found, using find with $jobs parallel jobs..."
    find "$d" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) ! -name "*.webp" -print0 | \
      xargs -0 -P "$jobs" -I {} bash -c 'set -euo pipefail; '"$(declare -f webp_one)"'; webp_one "$1"' _ {}
  fi
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  target=${1:-.}
  log "Converting to WebP in '$target' (originals deleted)..."
  fdwebp "$target"
  log "Done."
fi
