#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
# media-opt: Unified image optimization tool
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
# -- Config --
readonly VERSION="2.1.0"
JOBS=$(nproc)
QUALITY=80
DRY_RUN=0
# -- Helpers --
die(){ printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; exit 1; }
log(){ printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
has(){ command -v "$1" &>/dev/null; }
usage(){
  cat <<EOF
media-opt v$VERSION
Usage: media-opt <command> [target] [options]

Commands:
  jpg   Optimize JPEGs (jpegoptim)
  png   Optimize PNGs (oxipng)
  webp  Convert to WebP (cwebp)
  all   Run jpg + png

Options:
  -j N  Jobs (default: $JOBS)
  -q N  Quality (webp: 0-100)
  -n    Dry run
EOF
  exit 0
}
# -- Workloads --
opt_jpg(){
  has jpegoptim || die "Missing: jpegoptim"
  log "Optimizing JPEGs in $1..."
  local args=("-s" "--all-progressive" "-m85" "--quiet")
  [[ $DRY_RUN -eq 1 ]] && args+=("-n")
  if has fd; then
    fd -0 -t f -e jpg -e jpeg . "$1" -j "$JOBS" -x jpegoptim "${args[@]}"
  else
    find "$1" -type f \( -name '*.jpg' -o -name '*.jpeg' \) -print0 | \
      xargs -0 -r -P "$JOBS" -n 1 jpegoptim "${args[@]}"
  fi
}
opt_png(){
  log "Optimizing PNGs in $1..."
  if has oxipng; then
    local args=("-o4" "--strip" "safe" "--quiet")
    [[ $DRY_RUN -eq 1 ]] && args+=("--dry")
    if has fd; then
      fd -0 -t f -e png . "$1" -X oxipng "${args[@]}"
    else
      find "$1" -type f -name '*.png' -exec oxipng "${args[@]}" {} +
    fi
  elif has optipng; then
    log "Falling back to optipng..."
    find "$1" -type f -name '*.png' -exec optipng -o5 -strip all -quiet {} +
  else
    die "Missing: oxipng or optipng"
  fi
}
to_webp(){
  has cwebp || die "Missing: cwebp"
  log "Converting to WebP (q=$QUALITY) in $1..."
  local cmd
  if [[ $DRY_RUN -eq 1 ]]; then
    cmd='echo "Convert: $1 -> ${1%.*}.webp"'
  else
    cmd='cwebp -q '"$QUALITY"' -m 6 -pass 10 -quiet -mt -metadata none "$1" -o "${1%.*}.webp" && rm "$1"'
  fi
  if has fd; then
    fd -0 -t f -e jpg -e jpeg -e png -E '*.webp' . "$1" -j "$JOBS" -x bash -c "$cmd" _
  else
    find "$1" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) ! -name '*.webp' \
      -exec bash -c "$cmd" _ {} \;
  fi
}
# -- Main --
[[ $# -eq 0 ]] && usage
CMD=$1; shift
TARGET="${1:-.}"
[[ -d $TARGET ]] || TARGET="."
while getopts "j:q:n" opt; do
  case $opt in
    j) JOBS="$OPTARG" ;;
    q) QUALITY="$OPTARG" ;;
    n) DRY_RUN=1 ;;
    *) usage ;;
  esac
done
case "$CMD" in
  jpg)  opt_jpg "$TARGET" ;;
  png)  opt_png "$TARGET" ;;
  webp) to_webp "$TARGET" ;;
  all)  opt_jpg "$TARGET"; opt_png "$TARGET" ;;
  *)    usage ;;
esac

log "Done."
