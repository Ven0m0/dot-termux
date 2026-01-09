#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t' LC_ALL=C
has(){ command -v -- "$1" &>/dev/null; }

finder(){
  local dir="${1:-.}"
  if has fd; then
    fd "$dir" -tf -u -e log -e old -e tmp -e temp -e tmp -e bak -e ~ -e backup -e pyc --one-file-system -x rm -f {} + 2>/dev/null || :
  else
    find "$dir" -type f \( -name "*.old" -o -name "*.bak" -o -name "*.log" -o -name "*.tmp" -o -name "*.temp" -o -name "*.pyc" -o -name "*.backup" -o -name "*.~" \) -delete 2>/dev/null || :
  fi
}
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  target=${1:-.}
  echo "Starting cleanup"
  finder "$target"
  echo "Cleanup finished"
fi
