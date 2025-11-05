#!/data/data/com.termux/files/usr/bin/env bash

# List all executables on PATH
# https://unix.stackexchange.com/questions/120786/list-all-binaries-from-path
{
  set -f
  IFS=:
  for d in "${PATH[@]}"; do
    set +f
    [[ $d != "" ]] || d=.
    for f in "$d"/. "$d"/..?* "$d"/*; do
      [[ -f $f ]] && [[ -x $f ]] && printf '%s\0' "${f##*/}"
    done
  done
} | sort -uz | tr '\0' '\n'
