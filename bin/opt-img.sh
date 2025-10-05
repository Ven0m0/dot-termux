#!/bin/bash
#
# Image optimization script for Termux using repo-only packages.
# Processes JPEG, PNG, and WebP files.

set -euo pipefail

# --- Configuration ---
readonly QUALITY=85       # Quality for lossy formats (JPEG/WebP)
readonly SUFFIX="_opt"    # Suffix for processed files

# --- Functions ---
# Check for required command-line tools from pkg.
check_deps() {
  local dep missing=0
  for dep in jpegoptim optipng cwebp; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "Error: Dependency '$dep' not found." >&2
      missing=1
    fi
  done
  ((missing)) && { echo "Install via: pkg install jpegoptim optipng libwebp" >&2; exit 1; }
}

# Process a single file based on its extension.
process_file() {
  local file=$1
  if [[ "$file" == *"$SUFFIX".* ]]; then
    echo "Skipping: $file (already processed)"
    return
  fi

  local name="${file%.*}"
  local ext="${file##*.}"
  local out_file="${name}${SUFFIX}.${ext}"

  echo "Processing: $file"
  case "${ext,,}" in
    jpg|jpeg)
      # jpegoptim modifies the file in place, so we copy first.
      cp "$file" "$out_file" >/dev/null 2>&1 || true
      jpegoptim -m"$QUALITY" --strip-all --overwrite "$out_file" >/dev/null 2>&1 || true
      ;;
    png)
      # optipng also modifies the file in place.
      cp "$file" "$out_file" >/dev/null 2>&1 || true
      optipng -o7 -strip all "$out_file" >/dev/null 2>&1 || true
      ;;
    webp)
      # cwebp creates a new output file directly.
      cwebp -q "$QUALITY" "$file" -o "$out_file" >/dev/null 2>&1 || true
      ;;
    *)
      echo "Unsupported: $file"
      ;;
  esac
}

# --- Main ---
check_deps

if [[ $# -eq 0 ]]; then
  while read -r file; do
    [[ -f "$file" ]] && process_file "$file"
  done
else
  for file in "$@"; do
    [[ -f "$file" ]] && process_file "$file"
  done
fi
