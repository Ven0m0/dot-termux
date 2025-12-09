#!/usr/bin/env bash
# media-opt: Unified image optimization tool
# Replaces: img-quick.sh, img-webp.sh, img-opt.sh
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t'
export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive
# -- Config --
readonly VERSION="2.0.0"
JOBS=$(nproc)
# -- Helpers --
die() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; exit 1; }
log() { printf '\e[32m[INFO]\e[0m %s\n' "$*"; }
has() { command -v "$1" &>/dev/null; }
usage() {
  cat <<EOF
media-opt v$VERSION
Usage: media-opt <command> [target_dir] [options]

Commands:
  jpg   Optimize JPEGs (lossy/lossless)
  png   Optimize PNGs (lossless)
  webp  Convert to WebP (deletes originals)
  full  Full optimization (slow, requires image-optimizer)
  all   Run jpg + png

Options:
  -j N  Parallel jobs (default: $JOBS)
  -q N  Quality (webp: 0-100, default: 80)
  -r    Recursive (implied if using fd)
EOF
  exit 0
}
# -- Workloads --
opt_jpg() {
  has jpegoptim || die "Missing: jpegoptim"
  log "Optimizing JPEGs..."
  # -s: strip all, -m85: max quality 85, --all-progressive
  if has fd; then
    fd -0 -t f -e jpg -e jpeg . "$1" -j "$JOBS" -x jpegoptim -s --all-progressive -m85 --quiet
  else
    find "$1" -type f \( -name '*.jpg' -o -name '*.jpeg' \) -exec jpegoptim -s --all-progressive -m85 --quiet {} +
  fi
}
opt_png() {
  log "Optimizing PNGs..."
  if has oxipng; then
    # oxipng is Rust-based and parallel by default, but we control it via fd for file discovery
    if has fd; then
      fd -0 -t f -e png . "$1" -j "$JOBS" -x oxipng -o4 --strip safe -i0 -q
    else
      find "$1" -type f -name '*.png' -exec oxipng -o4 --strip safe -i0 -q {} +
    fi
  elif has optipng; then
    log "Falling back to optipng..."
    find "$1" -type f -name '*.png' -exec optipng -o5 -strip all -fix -clobber -quiet {} +
  else
    die "Missing: oxipng or optipng"
  fi
}
to_webp() {
  local q="${2:-80}"
  has cwebp || die "Missing: cwebp"
  log "Converting to WebP (q=$q)..."
  # Conversion logic wrapped for export
  local cmd='cwebp -q '"$q"' -m 6 -pass 10 -quiet -metadata none "$1" -o "${1%.*}.webp" && rm "$1"'
  if has fd; then
    fd -0 -t f -e jpg -e jpeg -e png -E '*.webp' . "$1" -j "$JOBS" -x bash -c "$cmd" _
  else
    find "$1" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) ! -name '*.webp' \
      -exec bash -c "f='{}'; $cmd" _ {} \;
  fi
}
opt_full() {
  has image-optimizer || die "Missing: image-optimizer (cargo install image-optimizer)"
  log "Running full optimization (this may take a while)..."
  # image-optimizer handles its own recursion and concurrency
  image-optimizer --png-optimization-level max -r --zopfli-iterations 50 --max-size 1920 -i "$1"
}
# -- Main --
[[ $# -eq 0 ]] && usage
CMD=$1; shift
TARGET="${1:-.}"
[[ -d $TARGET ]] || TARGET="."
# Parse remaining args for flags
while getopts "j:q:" opt; do
  case $opt in
    j) JOBS="$OPTARG" ;;
    q) QUALITY="$OPTARG" ;;
    *) usage ;;
  esac
done
case "$CMD" in
  jpg) opt_jpg "$TARGET" ;;
  png) opt_png "$TARGET" ;;
  webp) to_webp "$TARGET" "${QUALITY:-80}" ;;
  full) opt_full "$TARGET" ;;
  all) opt_jpg "$TARGET"; opt_png "$TARGET" ;;
  *) usage ;;
esac
log "Done."
