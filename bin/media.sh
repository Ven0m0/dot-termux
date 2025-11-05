#!/data/data/com.termux/files/usr/bin/env bash
#
# Quick media optimization script for Termux.
# - Images: rimage (lossy), oxipng (lossless)
# - Video:  ffmpeg (HEVC/H.265)
# - Audio:  flaca (FLAC)

set -euo pipefail

# --- Configuration ---
readonly IMG_QUALITY=85 # rimage quality (1-100)
readonly VID_CRF=27     # ffmpeg HEVC CRF (0-51, lower is better)
readonly SUFFIX="_opt"  # Suffix for processed files

# --- Functions ---
# Check for required command-line tools.
check_deps() {
  local dep missing=0
  for dep in rimage oxipng ffmpeg flaca; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "Error: Dependency '$dep' not found." >&2
      missing=1
    fi
  done
  ((missing)) && {
    echo "Install via: pkg install rust imagemagick ffmpeg flac" >&2
    exit 1
  }
  # rimage/oxipng are installed via `cargo` after installing `rust`.
  # if cargo command missing, pkg install rust. If rust is installed, cargo install rimage oxipng
}

# Process a single file based on its extension.
process_file() {
  local file=$1
  if [[ $file == *"$SUFFIX".* ]]; then
    echo "Skipping: $file (already processed)"
    return
  fi

  local name="${file%.*}"
  local ext="${file##*.}"
  local out_file="${name}${SUFFIX}.${ext}"

  echo "Processing: $file"
  case "${ext,,}" in
  jpg | jpeg | webp | avif)
    rimage -q "$IMG_QUALITY" "$file" -o "$out_file" >/dev/null 2>&1 || :
    ;;
  png)
    oxipng -o max --strip safe "$file" --out "$out_file" >/dev/null 2>&1 || :
    ;;
  mp4 | mov | mkv | webm)
    ffmpeg -i "$file" -c:v libx265 -preset medium -crf "$VID_CRF" \
      -c:a copy -tag:v hvc1 -y "$out_file" >/dev/null 2>&1 || :
    ;;
  flac)
    # flaca is for FLAC audio, not images.
    cp "$file" "$out_file" >/dev/null 2>&1 || :
    flaca --best "$out_file" >/dev/null 2>&1 || :
    ;;
  *)
    echo "Unsupported: $file"
    ;;
  esac
}

# --- Main ---
check_deps

if [[ $# -eq 0 ]]; then
  # Read file paths from standard input.
  while read -r file; do
    [[ -f $file ]] && process_file "$file"
  done
else
  # Read file paths from command-line arguments.
  for file in "$@"; do
    [[ -f $file ]] && process_file "$file"
  done
fi
