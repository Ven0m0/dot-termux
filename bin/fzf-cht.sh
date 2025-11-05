#!/data/data/com.termux/files/usr/bin/env bash
# https://github.com/beauwilliams/Dotfiles/blob/master/Shell/zsh/.config/zsh/plugins/fzf-cht.sh
CHT_SH_LIST_CACHE=$HOME/'.cache/cht_sh_cached_list'

# Cache the list on first run
if [[ ! -f $CHT_SH_LIST_CACHE ]]; then
  echo "First time run. Downloading cht.sh/:list to cache..."
  curl -fsSL cht.sh/:list -o "$CHT_SH_LIST_CACHE" || {
    echo "Failed to download cht.sh list" >&2
    exit 1
  }
fi

#Select a cht.sh cheat from the list
selected=$(cat "$CHT_SH_LIST_CACHE" | fzf --reverse --height 75% --border -m --ansi --nth 2..,.. --prompt='CHT.SH> ' --preview='curl -s cht.sh/{-1}' --preview-window=right:60%)
if [[ -z $selected ]]; then
  exit 0
fi

#Ask the user what they would like to query
read -p "Type a $selected topic to query (Empty query prints $selected summary): " query

# Retrieve the cheatsheet from cht.sh
query=$(echo "$query" | tr ' ' '+')
if [[ -z $query ]]; then
  echo "curl cht.sh/$selected" && curl -s cht.sh/"$selected"
else
  echo "curl cht.sh/$selected/$query" && curl -s cht.sh/"$selected"/"$query"
fi
