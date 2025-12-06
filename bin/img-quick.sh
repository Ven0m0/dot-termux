#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t' LC_ALL=C LANG=C

has(){ command -v "$1" &>/dev/null; }
die(){ printf 'ERR: %s\n' "$*" >&2; exit 1; }

jpg_opt(){ local d=${1:-.}; has jpegoptim||die "need jpegoptim"; printf 'Optimizing JPEGs in %s...\n' "$d"; has fd&&fd -tf -e jpg -e jpeg . "$d" -x jpegoptim -s --all-progressive -m85 --quiet||find "$d" -type f \( -name '*.jpg' -o -name '*.jpeg' \) -exec jpegoptim -s --all-progressive -m85 --quiet {} +; }
png_opt(){ local d=${1:-.}; has oxipng&&{ printf 'Optimizing PNGs with oxipng in %s...\n' "$d"; has fd&&fd -tf -e png . "$d" -x oxipng -o4 --strip safe -i0 -q||find "$d" -type f -name '*.png' -exec oxipng -o4 --strip safe -i0 -q {} +; }||{ has optipng||die "need optipng/oxipng"; printf 'Optimizing PNGs with optipng in %s...\n' "$d"; has fd&&fd -tf -e png . "$d" -x optipng -o5 -strip all -fix -clobber -quiet||find "$d" -type f -name '*.png' -exec optipng -o5 -strip all -fix -clobber -quiet {} +; }; }

webp_conv(){
  local d=${1:-.} q=${2:-80}; has cwebp||die "need cwebp"
  printf 'Converting to WebP (q=%s, deletes originals) in %s...\n' "$q" "$d"
  has fd&&fd -tf -e jpg -e jpeg -e png -E '*.webp' . "$d" -x bash -c 'cwebp -q '"$q"' -m6 -pass 10 -quiet -metadata none "$1" -o "${1%.*}.webp"&&rm "$1"' _ {}||find "$d" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) ! -name '*.webp' -exec bash -c 'f="$1"; cwebp -q '"$q"' -m6 -pass 10 -quiet -metadata none "$f" -o "${f%.*}.webp"&&rm "$f"' _ {} \;
}
img_full(){
  local d=${1:-.} it=${2:-50}; has image-optimizer||die "need image-optimizer"
  printf 'Full optimization (zopfli iterations=%s) in %s...\n' "$it" "$d"
  image-optimizer --png-optimization-level max -r --zopfli-iterations "$it" --max-size 1920 -i "$d"||:
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
  [[ $# -eq 0 || $1 == -h || $1 == --help ]]&&{ usage; exit 0; }
  local cmd=$1; shift
  case $cmd in
    jpg)jpg_opt "${1:-.}";;
    png)png_opt "${1:-.}";;
    webp)webp_conv "${1:-.}" "${2:-80}";;
    full)img_full "${1:-.}" "${2:-50}";;
    all)jpg_opt "${1:-.}"; png_opt "${1:-.}";;
    *)die "Unknown: $cmd (use --help)";;
  esac
  printf 'Done.\n'
}
main "$@"
