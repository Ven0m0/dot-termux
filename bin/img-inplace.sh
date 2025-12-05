#!/usr/bin/env bash
# In-place optimization for JPG & PNG. Source or run.
# Usage: ./img-inplace.sh [dir]
set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C

# 1. JPEG: Strip metadata, progressive, quality 85
fdjpg(){
  echo "📷 Optimizing JPEGs..."
  fd . "${1:-.}" -e jpg -e jpeg -x jpegoptim -s --all-progressive -m85 --quiet
}
# 2. PNG: Opt level 2, strip metadata, fix errors, clobber
fdpng(){
  echo "🎨 Optimizing PNGs..."
  fd . "${1:-.}" -e png -x optipng -o5 -strip all -fix -clobber -quiet
}

# Execution block
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TARGET="${1:-.}"
  echo "🚀 Running in-place optimization on '$TARGET'..."
  fdjpg "$TARGET"
  fdpng "$TARGET"
  echo "✅ Done."
fi
