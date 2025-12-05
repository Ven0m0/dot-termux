#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t' LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive
# In-place optimization for JPG & PNG. Source or run.
# Usage: ./img-inplace.sh [dir]

# 1. JPEG: Strip metadata, progressive, quality 85
fdjpg(){
  echo "📷 Optimizing JPEGs..."
  fd -tf -e jpg -e jpeg . "${1:-.}" -x jpegoptim -s --all-progressive -m85 --quiet || :
}
# 2. PNG: Opt level 2, strip metadata, fix errors, clobber
fdpng(){
  echo "🎨 Optimizing PNGs..."
  fd -tf -e png . "${1:-.}" -x optipng -o5 -strip all -fix -clobber -quiet || :
}

# Execution block
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TARGET="${1:-.}"
  echo "🚀 Running in-place optimization on '$TARGET'..."
  fdjpg "$TARGET"
  fdpng "$TARGET"
  echo "✅ Done."
fi
