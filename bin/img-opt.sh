#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t' LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive

img-opt(){
  if command -v image-optimizer &>/dev/null; then
    image-optimizer --png-optimization-level max -r --zopfli-iterations "${2:-50}" --max-size 1920 -i "${1:-.}" || :
  fi
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TARGET="${1:-.}"
  echo "Optimizing images in '$TARGET'..."
  img-opt "$TARGET"
  echo "Done."
fi
