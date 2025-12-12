#!/data/data/com.termux/files/usr/bin/env bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '[INFO] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit "${2:-1}"; }

img_opt(){
  local d=${1:-.} it=${2:-50} sz=${3:-1920}
  has image-optimizer || die "image-optimizer not found (cargo install image-optimizer)"
  log "Running image-optimizer in $d (zopfli-iterations=$it, max-size=$sz)..."
  image-optimizer --png-optimization-level max -r --zopfli-iterations "$it" --max-size "$sz" -i "$d" || :
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  img_opt "${1:-.}" "${2:-50}" "${3:-1920}"
  log "Done."
fi
