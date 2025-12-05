#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t'; export LC_ALL=C LANG=C
# Wrapper for image optimization.
# Usage: source img-opt.sh; fdwebp [dir] OR ./img-opt.sh [dir]
# Dependencies: pkg install fd libwebp

# WebP: Convert JPG/PNG to WebP (q80) and DELETE original
fdwebp(){
  # bash -c allows chaining '&& rm'; ${1%.*} strips ext
  fd . "${1:-.}" -e jpg -e jpeg -e png \
    -x bash -c 'cwebp -q 80 -m 6 -pass 10 -progress -metadata none \
    "$1" -o "${1%.*}.webp" && rm "$1"' _ "{}"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TARGET="${1:-.}"
  echo "🚀 Converting to WebP in '$TARGET'..."
  fdwebp "$TARGET"
  echo "✅ Done."
fi
