#!/usr/bin/env bash
# Wrappers for video minification (VP9/AV1). Source or run.
# Usage: ./vid-min.sh [dir]
set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C
# Check dependencies
command -v ffmpeg &>/dev/null || { echo "❌ Missing: ffmpeg (pkg install ffmpeg)"; exit 1; }
command -v fd &>/dev/null || { echo "❌ Missing: fd (pkg install fd)"; exit 1; }

# 1. VP9: Good balance of Size vs. Battery/Time
# -crf 32: Aggressive compression (Youtube uses ~20-25)
# -cpu-used 4: Speed up encoding (0=slowest, 5=fastest)
# -row-mt 1: Enable row-based multithreading
fdvp9(){
  echo "🎬 Minifying to VP9 (.webm)..."
  fd . "${1:-.}" -e mp4 -e mov -e mkv -e avi -e webm \
    -x ffmpeg -hide_banner -loglevel error -y -i "{}" \
    -c:v libvpx-vp9 -b:v 0 -crf 32 -cpu-used 3 -row-mt 1 \
    -c:a libopus -b:a 96k -n "{.}.mkv"
}
# 2. AV1: Best Size, Heavy CPU usage
# -preset 10: SVT-AV1 Speed (0=glacial, 13=realtime)
# -crf 35: AV1 handles higher CRFs better than VP9
fdav1(){
  echo "🐌 Minifying to AV1 (.mkv)..."
  fd . "${1:-.}" -e mp4 -e mov -e mkv -e avi -e webm \
    -x ffmpeg -hide_banner -loglevel error -y -i "{}" \
    -c:v libsvtav1 -crf 35 -preset 10 \
    -c:a libopus -b:a 96k -n "{.}.mkv"
}

# Execution block
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  TARGET="${1:-.}"
  echo "🚀 Video Minification on '$TARGET'..."
  echo "⚠️  Note: Video encoding is battery intensive."
  # Defaulting to VP9 for sanity. Uncomment fdav1 to use AV1.
  fdvp9 "$TARGET"
  # fdav1 "$TARGET"
  echo "✅ Done."
fi
