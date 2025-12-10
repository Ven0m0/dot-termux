#!/data/data/com.termux/files/usr/bin/sh
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
# Usage: termux-fix-shebang <files>
# Optimization: Parallel processing with xargs
if [ $# -eq 0 ]; then
  echo "Usage: $0 file1 [file2 ...]"; exit 1
fi
# Use xargs to batch-process files with sed
printf '%s\0' "$@" | xargs -0 sed -i -E "1 s@^#\!(.*)/[sx]?bin/(.*)@#\!/data/data/com.termux/files/usr/bin/\2@"
