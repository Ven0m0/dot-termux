#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t'; LC_ALL=C; LANG=C; DEBIAN_FRONTEND=noninteractive
# Full image optimization using image-optimizer (Rust tool)
# Usage: ./img-opt.sh [dir] [zopfli-iterations] [max-size]
has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '[INFO] %s\n' "$*"; }
die(){ printf '%b[ERROR]%b %s\n' '\e[1;31m' '\e[0m' "$*" >&2; exit "${2:-1}"; }
img-opt(){
  local d=${1:-.} it=${2:-50} sz=${3:-1920}
  has image-optimizer || die "image-optimizer not found (cargo install image-optimizer)"
  log "Running image-optimizer in $d (zopfli-iterations=$it, max-size=$sz)..."
  image-optimizer --png-optimization-level max -r --zopfli-iterations "$it" --max-size "$sz" -i "$d" || :
}
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  img-opt "${1:-.}" "${2:-50}" "${3:-1920}"; log "Done."
fi
