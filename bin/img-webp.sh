#!/usr/bin/env bash
# Wrapper for image optimization.
# Usage: source img-opt.sh; fdwebp [dir] OR ./img-opt.sh [dir]
set -euo pipefail
export LC_ALL=C
# Dependencies: pkg install fd libwebp

# TODO: 
# fdjpg(){ fd . "${1:-.}" -e jpg -e jpeg -x jpegoptim -s --all-progressive -m85; }
# fdpng(){ fd . "${1:-.}" -e png -x optipng -o2 -strip all -fix -clobber; }

# WebP: Convert JPG/PNG to WebP (q80) and DELETE original
fdwebp(){
  # bash -c allows chaining '&& rm'; ${1%.*} strips ext
  fd . "${1:-.}" -e jpg -e jpeg -e png \
    -x bash -c 'cwebp -q 80 -m 6 -pass 10 -progress -metadata none -mt \
    "$1" -o "${1%.*}.webp" && rm "$1"' _ "{}"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TARGET="${1:-.}"
  echo "🚀 Converting to WebP in '$TARGET'..."
  fdwebp "$TARGET"
  echo "✅ Done."
fi
