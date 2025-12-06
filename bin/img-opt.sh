#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t'; LC_ALL=C; LANG=C; DEBIAN_FRONTEND=noninteractive

has(){ command -v -- "$1" &>/dev/null; }
img-opt(){ has image-optimizer && image-optimizer --png-optimization-level max -r --zopfli-iterations "${2:-50}" --max-size "${3:-1920}" -i "${1:-.}" || :; }
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TARGET="${1:-.}"; echo "Optimizing images in '$TARGET'..."
  img-opt "$TARGET"
  echo "Done."
fi
