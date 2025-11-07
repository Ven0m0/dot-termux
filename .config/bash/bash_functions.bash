#!/usr/bin/env bash

# Open the selected file in the default editor
fe() {
  local IFS=$'\n' line
  local files=()
  while IFS='' read -r line; do files+=("$line"); done < <(fzf -q "$1" -m --inline-info -1 -0 --layout=reverse-list)
  [[ -n ${files[0]} ]] && "${EDITOR:-nano}" "${files[@]}"
}

# cd to the selected directory
fcd() {
  local dir
  if has fd; then
    dir=$(fd -t d -d 5 . "${1:-.}" 2>/dev/null | fzf +m) && cd "$dir" || exit
  else
    dir=$(find "${1:-.}" -O3 -maxdepth 5 -path '*/\.*' -prune -o -type d -print 2>/dev/null | fzf +m) && cd "$dir" || exit
  fi
}

# Get help for a command with bat
bathelp() {
  "$@" --help 2>&1 | command bat -splhelp --squeeze-limit 0
}

# Cat^2 (cat for files and directories)
catt() {
  for i in "$@"; do
    if [[ -d $i ]]; then
      ls "$i"
    else
      cat "$i"
    fi
  done
}

alias edit='${EDITOR:--nano}'
alias pager='${PAGER:-less}'

faf() { eval "$({
  alias
  declare -F | grep -v '^_'
} | fzf | cut -d= -f1)"; }

fzf-man() {
  local MAN="/usr/bin/man"
  [[ -n $1 ]] && {
    "$MAN" "$@"
    return
  }
  if has sd; then
    "$MAN" -k . | fzf --reverse --preview="echo {1,2} | sd ' \(' '.' | sd '\)\s*$' '' | xargs $MAN" | awk '{print $1 "." $2}' | tr -d '()' | xargs -r "$MAN"
  else
    "$MAN" -k . | fzf --reverse --preview="echo {1,2} | sed 's/ (/./' | sed -E 's/\)\s*$//' | xargs $MAN" | awk '{print $1 "." $2}' | tr -d '()' | xargs -r "$MAN"
  fi
}

git() {
  local subcmd="${1:-}"
  if has gix; then
    case "$subcmd" in
    clone | fetch | pull | init | status | diff | log | rev-parse | rev-list | commit-graph | verify-pack | index-from-pack | pack-explode | remote | config | exclude | free | mailmap | odb | commitgraph | pack)
      gix "$@"
      ;;
    *)
      command git "$@"
      ;;
    esac
  else
    command git "$@"
  fi
}

# Curl -> Aria2 wrapper
curl() {
  if ! has aria2c; then
    command curl "$@"
    return
  fi

  local -a args=() aria_args=()
  local out_file="" out_dir="" url=""

  # Parse arguments more efficiently
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -o | --output)
      out_file="$2"
      shift 2
      ;;
    -L | --location | -s | --silent | -S | --show-error | -f | --fail)
      shift # Skip curl-specific flags
      ;;
    http* | ftp*)
      url="$1"
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
    esac
  done

  if [[ -n $url ]]; then
    aria_args=(-x16 -s16 -k1M -j16 --file-allocation=none --summary-interval=0)
    if [[ -n $out_file ]]; then
      aria_args+=(-d "$(dirname "$out_file")" -o "$(basename "$out_file")")
    fi
    aria2c "${aria_args[@]}" "$url" "${args[@]}"
  else
    command curl "$@"
  fi
}

# Pip -> UV wrapper
pip() {
  if has uv; then
    case "${1:-}" in
    install | uninstall | list | show | freeze | check)
      uv pip "$@"
      ;;
    *)
      command pip "$@"
      ;;
    esac
  else
    command pip "$@"
  fi
}
