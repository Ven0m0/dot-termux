#!/usr/bin/env bash

# Open the selected file in the default editor
fe() {
  local IFS=$'\n' line; local files=()
  while IFS='' read -r line; do files+=("$line"); done < <(fzf -q "$1" -m --inline-info -1 -0 --layout=reverse-list)
  [[ -n "${files[0]}" ]] && ${EDITOR:-nano} "${files[@]}"
}

# cd to the selected directory
fcd() {
  local dir
  dir=$(find "${1:-.}" -path '*/\.*' -prune \
      -o -type d -print 2> /dev/null | fzf +m) \
      && cd "$dir" || return 1
}

# Get help for a command with bat
bathelp() {
  "$@" --help 2>&1 | command bat -splhelp --squeeze-limit 0
}


# Cat^2 (cat for files and directories)
catt() {
  for i in "$@"; do
    if [[ -d "$i" ]]; then
      ls "$i"
    else
      cat "$i"
    fi
  done
}

alias edit='${EDITOR:--nano}'
alias pager='${PAGER:-less}'

faf(){ eval "$({ alias; declare -F | grep -v '^_'; } | fzf | cut -d= -f1)"; }
    

fzf-man(){
	MAN="/usr/bin/man"
	if [ -n "$1" ]; then
		$MAN "$@"
		return $?
	else
		$MAN -k . | fzf --reverse --preview="echo {1,2} | sed 's/ (/./' | sed -E 's/\)\s*$//' | xargs $MAN" | awk '{print $1 "." $2}' | tr -d '()' | xargs -r $MAN
		return $?
	fi
}
