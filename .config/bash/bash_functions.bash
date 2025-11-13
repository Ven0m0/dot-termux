#!/usr/bin/env bash
# bash_functions.bash - Additional bash-specific functions

# Helper function (if not already defined)
has() { command -v -- "$1" &>/dev/null; }

# Open the selected file in the default editor
fe() {
  local IFS=$'\n'
  local -a files=()
  mapfile -t files < <(fzf -q "$1" -m --inline-info -1 -0 --layout=reverse-list)
  [[ -n ${files[0]} ]] && "${EDITOR:-nano}" "${files[@]}"
}

# cd to the selected directory
fcd() {
  local dir
  if has fd; then
    dir=$(fd -t d -d 5 . "${1:-.}" 2>/dev/null | fzf +m) && cd "$dir" || exit
  else
    dir=$(find "${1:-.}" -maxdepth 5 -path '*/\.*' -prune -o -type d -print 2>/dev/null | fzf +m) && cd "$dir" || exit
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
  local MAN
  if has man; then
    MAN="$(command -v man)"
  else
    echo "man command not found" >&2
    return 1
  fi

  [[ -n $1 ]] && {
    "$MAN" "$@"
    return
  }

  if ! has fzf; then
    echo "fzf not found, using regular man" >&2
    "$MAN" "$@"
    return 1
  fi

  if has sd; then
    "$MAN" -k . | fzf --reverse --preview="echo {1,2} | sd ' \(' '.' | sd '\)\s*$' '' | xargs $MAN" | awk '{print $1 "." $2}' | tr -d '()' | xargs -r "$MAN"
  else
    "$MAN" -k . | fzf --reverse --preview="echo {1,2} | sed 's/ (/./' | sed -E 's/\)\s*$//' | xargs $MAN" | awk '{print $1 "." $2}' | tr -d '()' | xargs -r "$MAN"
  fi
}
