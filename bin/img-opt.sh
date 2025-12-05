#!/usr/bin/env bash
# Wrappers for image optimization. Source this file or run it.
# Usage: source img-opt.sh; fdjpg [dir]
#    OR: ./img-opt.sh [dir]
set -euo pipefail
# Dependencies: pkg install fd jpegoptim optipng libwebp
# 1. JPEG: Strip all metadata, progressive, quality 85
fdjpg(){ 
  LC_ALL=C fd . "${1:-.}" -e jpg -e jpeg -x jpegoptim -s --all-progressive -m85 --quiet
}
fdpng(){
  LC_ALL=C fd . "${1:-.}" -e png -x optipng -o2 -strip all -fix -clobber -quiet
}
fdwebp(){ 
  LC_ALL=C fd . "${1:-.}" -e jpg -e jpeg -e png -e webp -x cwebp -q 80 -quiet "{}" -o "{.}.webp"
}

# Execution block (only runs if script is executed, not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Quick dependency check
  if ! command -v fd >/dev/null; then echo "❌ Missing deps. Run: pkg install fd jpegoptim optipng libwebp"; exit 1; fi
  TARGET="${1:-.}"
  echo "🚀 Running optimizers on '$TARGET'..."
  fdjpg "$TARGET"
  fdpng "$TARGET"
  fdwebp "$TARGET"
  
  echo "✅ Done."
fi
