#!/data/data/com.termux/files/usr/bin/env bash
# Wrappers for video minification (VP9/AV1/ffzap). Source or run.
# Usage: ./vid-min.sh [dir]
set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C

# Check dependencies (ffmpeg+fd required; ffzap optional)
command -v ffmpeg &>/dev/null || { echo "Missing: ffmpeg"; exit 1; }
command -v fd &>/dev/null || { echo "Missing: fd"; exit 1; }

# Helper function to process a single file with ffzap
# This function is called by fd via bash -c
_ffzap_process_file(){
  local input="$1" out
  shift
  out="${input%.*}_min.mkv"
  ffzap --output "$out" "$input" -- "$@"
}

# Helper function for ffzap-based processing
# Args: $1=target_dir, $2..=ffmpeg_args
_process_with_ffzap(){
  local target_dir="$1"
  shift
  local -a ffmpeg_args=("$@")

  export -f _ffzap_process_file
  fd -tf -e mp4 -e mov -e mkv -e avi -e webm -j 1 . "$target_dir" \
    -x bash -c '_ffzap_process_file "$0" '"$(printf '"%s" ' "${ffmpeg_args[@]}")" {}
}

# 1. VP9: Balanced for Mobile (Fallback)
# -j 1: SEQUENTIAL processing (Critical for ffmpeg on phones)
# -cpu-used 3: Higher quality than 4, slightly slower
# Output: filename_min.mkv (Prevents overwriting input mkv)
fdvp9(){
  echo "Minifying to VP9 (.mkv)..."
  fd . "${1:-.}" -tf -e mp4 -e mov -e mkv -e avi -e webm -j 1 \
    -x ffmpeg -hide_banner -loglevel error -y -i "{}" \
    -c:v libvpx-vp9 -b:v 0 -crf 32 -cpu-used 3 -row-mt 1 \
    -c:a libopus -b:a 96k -n "{.}_min.mkv"
}

# 2. AV1: Best Size, Heavy Compute
# -preset 10: Fast enough for mobile
fdav1(){
  echo "Minifying to AV1 (.mkv)..."
  fd . "${1:-.}" -tf -e mp4 -e mov -e mkv -e avi -e webm -j 1 \
    -x ffmpeg -hide_banner -loglevel error -y -i "{}" \
    -c:v libsvtav1 -crf 35 -preset 10 \
    -c:a libopus -b:a 96k -n "{.}_min.mkv"
}

# 3. ffzap: Rust-based wrapper (Primary)
# Fallback to fdvp9 if ffzap is not installed.
fdzap(){
  if command -v ffzap &>/dev/null; then
    echo "Minifying with ffzap (VP9)..."
    _process_with_ffzap "${1:-.}" -c:v libvpx-vp9 -b:v 0 -crf 32 -cpu-used 3 -row-mt 1 -c:a libopus -b:a 96k
  else
    echo "ffzap not found (cargo install ffzap). Using VP9 fallback."
    fdvp9 "$@"
  fi
}

# 4. ffzap AV1: Best size via wrapper
fdzapav1(){
  if command -v ffzap &>/dev/null; then
    echo "Minifying with ffzap (AV1)..."
    _process_with_ffzap "${1:-.}" -c:v libsvtav1 -crf 35 -preset 10 -c:a libopus -b:a 96k
  else
    echo "ffzap not found (cargo install ffzap). Using AV1 fallback."
    fdav1 "$@"
  fi
}

# Execution block
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TARGET="${1:-.}"
  echo "Video Minification on '$TARGET'..."
  echo "Processing sequentially to save battery/RAM."
  # Try ffzap first (with fallback to VP9), or uncomment others
  fdzap "$TARGET"
  # fdzapav1 "$TARGET"
  # fdvp9 "$TARGET"
  # fdav1 "$TARGET"

  echo "Done."
fi
