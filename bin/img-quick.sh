#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t'; LC_ALL=C; LANG=C; DEBIAN_FRONTEND=noninteractive
# Quick image optimization - comprehensive toolset
# Usage: img-quick.sh COMMAND [DIR] [ARGS]
has(){ command -v "$1" &>/dev/null; }
die(){ printf '%b[ERROR]%b %s\n' '\e[1;31m' '\e[0m' "$*" >&2; exit "${2:-1}"; }
log(){ printf '[INFO] %s\n' "$*"; }
jpg_opt(){
  local d=${1:-.}; has jpegoptim || die "jpegoptim not found"
  log "Optimizing JPEGs in $d..."
  if has fd; then
    fd -tf -e jpg -e jpeg . "$d" -x jpegoptim -s --all-progressive -m85 --quiet
  else
    find "$d" -type f \( -name '*.jpg' -o -name '*.jpeg' \) \
      -exec jpegoptim -s --all-progressive -m85 --quiet {} +
  fi
}
png_opt(){
  local d=${1:-.}
  log "Optimizing PNGs in $d..."
  if has oxipng; then
    log "Using oxipng..."
    if has fd; then
      fd -tf -e png . "$d" -x oxipng -o4 --strip safe -i0 -q
    else
      find "$d" -type f -name '*.png' -exec oxipng -o4 --strip safe -i0 -q {} +
    fi
  elif has optipng; then
    log "Using optipng..."
    if has fd; then
      fd -tf -e png . "$d" -x optipng -o5 -strip all -fix -clobber -quiet
    else
      find "$d" -type f -name '*.png' -exec optipng -o5 -strip all -fix -clobber -quiet {} +
    fi
  else
    die "oxipng or optipng required"
  fi
}
webp_conv(){
  local d=${1:-.} q=${2:-80}; has cwebp || die "cwebp not found"
  log "Converting to WebP (q=$q, deletes originals) in $d..."
  if has fd; then
    fd -tf -e jpg -e jpeg -e png -E '*.webp' . "$d" \
      -x bash -c 'cwebp -q '"$q"' -m6 -pass 10 -quiet -metadata none "$1" -o "${1%.*}.webp" && rm "$1"' _ {}
  else
    find "$d" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) ! -name '*.webp' \
      -exec bash -c 'f="$1"; cwebp -q '"$q"' -m6 -pass 10 -quiet -metadata none "$f" -o "${f%.*}.webp" && rm "$f"' _ {} \;
  fi
}
img_full(){
  local d=${1:-.} it=${2:-50}; has image-optimizer || die "image-optimizer not found"
  log "Full optimization (zopfli iterations=$it) in $d..."
  image-optimizer --png-optimization-level max -r --zopfli-iterations "$it" --max-size 1920 -i "$d" || :
}
usage(){
  cat <<'EOF'
img-quick.sh - Quick image optimization
USAGE: img-quick.sh COMMAND [DIR] [ARGS]
COMMANDS:
  jpg [dir]         Optimize JPEGs in-place (jpegoptim)
  png [dir]         Optimize PNGs in-place (oxipng/optipng)
  webp [dir] [q]    Convert to WebP + delete originals (default q=80)
  full [dir] [iter] Full optimization with image-optimizer (default iter=50)
  all [dir]         Run jpg + png optimization
EXAMPLES:
  img-quick.sh jpg ~/Pictures
  img-quick.sh png .
  img-quick.sh webp photos/ 85
  img-quick.sh full images/ 100
  img-quick.sh all ~/Downloads
NOTES:
  - jpg: requires jpegoptim
  - png: requires oxipng or optipng
  - webp: requires cwebp, DELETES originals!
  - full: requires image-optimizer (cargo install image-optimizer)
EOF
}
main(){
  [[ $# -eq 0 || $1 == -h || $1 == --help ]] && { usage; exit 0; }
  local cmd=$1; shift
  case $cmd in
    jpg) jpg_opt "${1:-.}";;
    png) png_opt "${1:-.}";;
    webp) webp_conv "${1:-.}" "${2:-80}";;
    full) img_full "${1:-.}" "${2:-50}";;
    all) jpg_opt "${1:-.}"; png_opt "${1:-.}";;
    *) die "Unknown command: $cmd (use --help)";;
  esac
  log "Done."
}
main "$@"
