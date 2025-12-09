#!/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar; IFS=$'\n\t'; LC_ALL=C; LANG=C; DEBIAN_FRONTEND=noninteractive
# 1. Config & Dependencies
readonly V_CODEC="libsvtav1"  # Efficient AV1 encoder
readonly V_OPTS="-preset 8 -crf 32" # Speed/Quality balance
readonly V_FILT="scale=-2:'min(1080,ih)'" # Cap height 1080p, keep AR
readonly A_CODEC="libopus" A_OPTS="-b:a 128k" EXT_OUT=".av1.mkv"
# Check tools
cmd="ffmpeg"
if command -v ffzap &>/dev/null; then
  cmd="ffzap"
elif ! command -v ffmpeg &>/dev/null; then
  printf "Error: neither 'ffzap' nor 'ffmpeg' found.\n" >&2; exit 1
fi
# 2. Conversion Function
convert_video(){
  local in="$1"; local out="${in%.*}${EXT_OUT}"
  # Skip if output exists
  if [[ -f "$out" ]]; then
    printf "⏭️  Skipping (exists): %s\n" "$in"; return
  fi
  printf "⚡ Converting: %s -> AV1/Opus (1080p)\n" "$in"
  # Run conversion
  # -y: overwrite output (handled by check above, but safe to keep)
  # -hide_banner -loglevel error: quiet output
  "$cmd" -hide_banner -loglevel error -stats -i "$in" \
    -c:v "$V_CODEC" $V_OPTS -vf "$V_FILT" \
    -c:a "$A_CODEC" $A_OPTS -y "$out"
}
# 3. Execution Logic
main(){
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    printf "Usage: %s <file|folder>\n" "$0" >&2; exit 1
  fi
  if [[ -f "$target" ]]; then
    convert_video "$target"
  elif [[ -d "$target" ]]; then
    # Use fd if avail, else find. Look for common video exts.
    local exts="mp4|mkv|avi|mov|webm|flv"
    if command -v fd &>/dev/null; then
      fd -t f -e mp4 -e mkv -e avi -e mov -e webm -e flv . "$target" -x bash -c 'convert_video "$1"' _ {}
    else
      # Fallback to find + loop (slower but standard)
      find "$target" -type f -regextype posix-extended -iregex ".*\.($exts)$" | while read -r file; do
        convert_video "$file"
      done
    fi
  else
    printf "❌ Error: Invalid input '%s'\n" "$target" >&2; exit 1
  fi
}
# Export func for subshells (needed for fd/parallel exec)
export -f convert_video
export V_CODEC V_OPTS V_FILT A_CODEC A_OPTS EXT_OUT cmd

main "$@"
