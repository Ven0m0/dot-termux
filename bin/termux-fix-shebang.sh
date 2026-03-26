#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
# termux-fix-shebang.sh: Fix shebangs in files for Termux compatibility
# Usage: termux-fix-shebang <files>
# Optimization: Parallel processing with xargs
if [[ $# -eq 0 ]]; then
  echo "Usage: ${0##*/} file1 [file2 ...]"; exit 1
fi
# Use xargs to batch-process files with sed
printf '%s\0' "$@" | xargs -0 -r sed -i -E "1 s/[[:space:]]+$//; 1 s@^#\!(.*)/[sx]?bin/(.*)@#\!/data/data/com.termux/files/usr/bin/\2@"
