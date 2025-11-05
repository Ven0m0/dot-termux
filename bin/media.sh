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
# Check for command-line tool availability
has() {
  command -v "$1" >/dev/null 2>&1
}

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

# Check for required command-line tools
check_deps() {
  local missing=()

  # Check for image optimization tools
  if ! has rimage && ! has imgc && ! has image-optimizer; then
    missing+=("rimage or imgc (cargo install rimage imgc)")
  fi

  if ! has oxipng && ! has optipng; then
    missing+=("oxipng or optipng (cargo install oxipng OR pkg install optipng)")
  fi

  if ! has ffmpeg; then
    missing+=("ffmpeg (pkg install ffmpeg)")
  fi

  if ! has flaca && [[ "$*" == *".flac"* ]]; then
    warn "flaca not found, FLAC optimization will be skipped"
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing critical dependencies:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    exit 1
  fi
}

# Process a single file based on its extension
process_file() {
  local file=$1
  if [[ $file == *"$SUFFIX".* ]]; then
    log "Skipping: $file (already processed)"
    return 0
  fi

  local name="${file%.*}"
  local ext="${file##*.}"
  local out_file="${name}${SUFFIX}.${ext}"

  log "Processing: $file"
  local success=0

  case "${ext,,}" in
  jpg | jpeg | webp | avif)
    # Tool preference: image-optimizer -> imgc -> rimage
    if has image-optimizer; then
      image-optimizer -i "$file" -o "$(dirname "$out_file")" -q "$IMG_QUALITY" 2>/dev/null && success=1
    elif has imgc; then
      imgc "$file" "${ext,,}" -q "$IMG_QUALITY" -o "$(dirname "$out_file")" 2>/dev/null && success=1
    elif has rimage; then
      rimage -q "$IMG_QUALITY" "$file" -o "$out_file" 2>/dev/null && success=1
    else
      warn "No suitable image optimizer found for $file"
      return 1
    fi
    ;;
  png)
    # Tool preference: oxipng -> optipng
    if has oxipng; then
      oxipng -o max --strip safe "$file" --out "$out_file" 2>/dev/null && success=1
    elif has optipng; then
      cp "$file" "$out_file" && optipng -o7 -strip all -quiet "$out_file" 2>/dev/null && success=1
    else
      warn "No PNG optimizer found for $file"
      return 1
    fi
    ;;
  mp4 | mov | mkv | webm)
    if has ffmpeg; then
      ffmpeg -i "$file" -c:v libx265 -preset medium -crf "$VID_CRF" \
        -c:a copy -tag:v hvc1 -y "$out_file" -loglevel error 2>&1 && success=1
    else
      warn "ffmpeg not found, cannot process $file"
      return 1
    fi
    ;;
  flac)
    if has flaca; then
      cp "$file" "$out_file" 2>/dev/null || return 1
      flaca --best "$out_file" 2>/dev/null && success=1
    else
      warn "flaca not found, skipping $file"
      return 1
    fi
    ;;
  *)
    warn "Unsupported file type: $file"
    return 1
    ;;
  esac

  if [[ $success -eq 1 ]]; then
    log "Successfully optimized: $out_file"
    return 0
  else
    warn "Failed to optimize: $file"
    return 1
  fi
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
