#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t'; export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive
# Wrappers for video minification (VP9/AV1). Source or run.
# Usage: ./vid-min.sh [dir]
# Check dependencies
command -v ffmpeg &>/dev/null || { echo "❌ Missing: ffmpeg"; exit 1; }
command -v fd &>/dev/null || { echo "❌ Missing: fd"; exit 1; }
# 1. VP9: Balanced for Mobile
# -j 1: SEQUENTIAL processing (Critical for ffmpeg on phones)
# -cpu-used 3: Higher quality than 4, slightly slower
# Output: filename_min.mkv (Prevents overwriting input mkv)
fdvp9(){
  echo "🎬 Minifying to VP9 (.mkv)..."
  fd . "${1:-.}" -e mp4 -e mov -e mkv -e avi -e webm -j 1 \
    -x ffmpeg -hide_banner -loglevel error -y -i "{}" \
    -c:v libvpx-vp9 -b:v 0 -crf 32 -cpu-used 3 -row-mt 1 \
    -c:a libopus -b:a 96k \
    -n "{.}_min.mkv"
}
# 2. AV1: Best Size, Heavy Compute
# -preset 10: Fast enough for mobile
fdav1(){
  echo "🐌 Minifying to AV1 (.mkv)..."
  fd . "${1:-.}" -e mp4 -e mov -e mkv -e avi -e webm -j 1 \
    -x ffmpeg -hide_banner -loglevel error -y -i "{}" \
    -c:v libsvtav1 -crf 35 -preset 10 \
    -c:a libopus -b:a 96k \
    -n "{.}_min.mkv"
}
# Execution block
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TARGET="${1:-.}"
  echo "🚀 Video Minification on '$TARGET'..."
  echo "⚠️  Processing sequentially to save battery/RAM."
  fdvp9 "$TARGET"
  # fdav1 "$TARGET"
  echo "✅ Done."
fi
