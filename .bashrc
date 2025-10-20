#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
shopt -s nullglob globstar
export LC_ALL=C LANG=C LANGUAGE=C
[[ $- != *i* ]] && return

# --- Config ---
SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="${SELF%/*}"
readonly SELF SCRIPT_DIR
cd -P -- "$SCRIPT_DIR" >/dev/null 2>&1 || :
PATH="$SCRIPT_DIR:$PATH"

# Source common library
COMMON_LIB="$HOME/.config/bash/common.sh"
[[ -f $COMMON_LIB ]] && source "$COMMON_LIB"

# --- Helpers (inline for fallback) ---
has(){ command -v -- "$1" >/dev/null 2>&1; }
sleepy(){ read -rt "${1:-1}" -- <> <(:) >/dev/null 2>&1 || :; }
bname(){ local t=${1%${1##*[!/]}}; t=${t##*/}; [[ $2 && $t == *"$2" ]] && t=${t%$2}; printf '%s\n' "${t:-/}"; }
dname(){ local p=${1:-.}; [[ $p != *[!/]* ]] && { printf '/\n'; return; }; p=${p%${p##*[!/]}}; [[ $p != */* ]] && { printf '.\n'; return; }; p=${p%/*}; p=${p%${p##*[!/]}}; printf '%s\n' "${p:-/}"; }
match(){ printf '%s\n' "$1" | grep -E -o "$2" >/dev/null 2>&1 || return 1; }

# --- Gitoxide wrapper ---
git_wrapper(){
  if has gix; then gix "$@"; else git "$@"; fi
}

# --- Lazy loading (adapted from bash-lazyrc.sh) ---
FUNC_DIRS=("$HOME/.bash/functions.d")
CONFIG_DIRS=("$HOME/.bash/configs")
AUTOLOAD_CACHE="$HOME/.cache/bash_autoload.list"
CONFIG_CACHE="$HOME/.cache/bash_config.loaded"

lazyfile() {
  local src=$1; shift
  for f; do
    eval "$f() { unset -f $*; source \"$src\"; $f \"\$@\"; }"
  done
}

autoload_parse() {
  local src=$1 funcs
  if has rg; then
    funcs=$(rg -n --no-heading '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)' "$src")
  else
    funcs=$(grep -Eo '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)' "$src")
  fi
  if has sd; then
    funcs=$(printf '%s\n' "$funcs" | sd '^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\).*' '$1')
  else
    funcs=$(printf '%s\n' "$funcs" | sed -E 's/^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\).*/\1/')
  fi
  printf '%s\n' "$funcs"
}

autoload_init() {
  local cache_valid=1 config_valid=1
  [[ -f "$AUTOLOAD_CACHE" ]] || cache_valid=0
  if (( cache_valid == 1 )); then
    for src in "${FUNC_DIRS[@]}"; do
      [[ "$src"/*.sh ]] && for f in "$src"/*.sh; do [[ "$f" -nt "$AUTOLOAD_CACHE" ]] && { cache_valid=0; break; }; done
    done
  fi
  [[ -f "$CONFIG_CACHE" ]] || config_valid=0
  if (( config_valid == 1 )); then
    for src in "${CONFIG_DIRS[@]}"; do
      [[ "$src"/*.sh ]] && for f in "$src"/*.sh; do [[ "$f" -nt "$CONFIG_CACHE" ]] && { config_valid=0; break; }; done
    done
  fi
  if (( cache_valid == 0 )); then
    : >"$AUTOLOAD_CACHE"
    for src in "${FUNC_DIRS[@]}"; do
      [[ "$src"/*.sh ]] && for f in "$src"/*.sh; do
        autoload_parse "$f" | while IFS= read -r fn; do echo "$fn $f" >>"$AUTOLOAD_CACHE"; done
      done
    done
  fi
  while IFS= read -r fn src; do
    [[ $src == "${FUNC_DIRS[0]}"* ]] && lazyfile "$src" "$fn"
  done <"$AUTOLOAD_CACHE"
  if (( config_valid == 0 )); then
    : >"$CONFIG_CACHE"
    for src in "${CONFIG_DIRS[@]}"; do
      [[ "$src"/*.sh ]] && for f in "$src"/*.sh; do source "$f"; echo "$f" >>"$CONFIG_CACHE"; done
    done
  else
    while IFS= read -r src; do [[ -f "$src" ]] && source "$src"; done <"$CONFIG_CACHE"
  fi
}

# --- Sourcing ---
dot=("$HOME"/.{bash_aliases,bash_functions,bash_completions,bash.d/cht.sh,config/bash/cht.sh})
for p in "${dot[@]}"; do [[ -r "$p" ]] && source "$p"; done
unset p dot
[[ -r "$HOME/.inputrc" ]] && export INPUTRC="$HOME/.inputrc"
ifsource(){ [[ -r "$1" ]] && source "$1"; }
ifsource "$HOME/navita.sh"

# --- Env ---
prependpath(){ [[ -d $1 ]] && [[ :$PATH: != *":$1:"* ]] && PATH="$1${PATH:+:$PATH}"; }
prependpath "$HOME/.local/bin"
prependpath "$HOME/.bin"
prependpath "$HOME/bin"

# --- History / Prompt ---
HISTSIZE=1000
HISTFILESIZE=2000
HISTCONTROL="erasedups:ignoreboth:autoshare"
HISTIGNORE="&:[bf]g:clear:cls:exit:history:bash:fish:?:??"
export HISTTIMEFORMAT="%F %T " IGNOREEOF=100 PROMPT_DIRTRIM=2 HISTFILE="$HOME/.bash_history" PROMPT_COMMAND="history -a"

# --- Core ---
CDPATH=".:$HOME:/"
ulimit -c 0
set -o noclobber
bind -r '\C-s'
stty -ixon -ixoff -ixany
set +H

# Editor
if has micro; then EDITOR=micro; else EDITOR=nano; fi
export MICRO_TRUECOLOR=1 VISUAL="$EDITOR" VIEWER="$EDITOR" GIT_EDITOR="$EDITOR" SYSTEMD_EDITOR="$EDITOR" FCEDIT="$EDITOR" SUDO_EDITOR="$EDITOR"

# Pagers/colors
export PAGER=bat BATPIPE=color BAT_STYLE=auto LESSQUIET=1 LESSCHARSET='utf-8' LESSHISTFILE=-
if has vivid; then export LS_COLORS="$(vivid generate molokai)"; elif has dircolors; then eval "$(dircolors -b)" >/dev/null 2>&1; fi
: "${CLICOLOR:=$(tput colors)}"
export CLICOLOR SYSTEMD_COLORS=1

export CURL_HOME="$HOME" WGETRC="$HOME/.wgetrc"

# Cheat.sh
export CHEAT_USE_FZF=true CHTSH_CURL_OPTIONS="-sfLZ4 --compressed -m 5 --connect-timeout 3"
cht(){
  local query="${*// /\/}"
  if ! LC_ALL=C curl -sfZ4 --compressed -m 5 --connect-timeout 3 "cht.sh/${query}"; then
    LC_ALL=C curl -sfZ4 --compressed -m 5 --connect-timeout 3 "cht.sh/:help"
  fi
}

# Python/UV
export PYTHONOPTIMIZE=2 PYTHONUTF8=1 PYTHONNODEBUGRANGES=1 PYTHON_JIT=1 PYENV_VIRTUALENV_DISABLE_PROMPT=1 PYTHONSTARTUP="{$HOME}/.pythonstartup" PYTHON_COLORS=1
unset PYTHONDONTWRITEBYTECODE
if has uv; then export UV_COMPILE_BYTECODE=1 UV_LINK_MODE=hardlink; fi

export ZSTD_NBTHREADS=0 _JAVA_AWT_WM_NONREPARENTING=1

# Git clone (using git_wrapper)
gclone(){ LC_ALL=C git_wrapper clone --progress --filter=blob:none --depth 1 "$@" && command cd "$1"; ls -A; }
alias pip='python -m pip' py3='python3' py='python'

touchf(){ ensure_dir "$(dirname -- "$1")" && command touch -- "$1"; }

# Eza aliases (consolidated from zshrc)
if has eza; then
  alias ls='eza -F --color=auto --group-directories-first --icons=auto'
  alias la='eza -AF --color=auto --group-directories-first --icons=auto'
  alias ll='eza -AlF --color=auto --group-directories-first --icons=auto --no-time --no-git --smart-group --no-user --no-permissions'
  alias lt='eza -ATF -L 3 --color=auto --group-directories-first --icons=auto --no-time --no-git --smart-group --no-user --no-permissions'
else
  alias ls='ls --color=auto --group-directories-first -BhLC'
  alias la='ls --color=auto --group-directories-first -ABhLgGoC'
  alias ll='ls --color=auto --group-directories-first -ABhLgGo'
  alias lt='ls --color=auto --group-directories-first -ABhLgGo'
fi

alias nano='nano -/' mi=micro

# Bat helpers
bathelp() { "$@" --help 2>&1 | bat -splhelp --squeeze-limit 0; }

# Man helpers (consolidated)
manol() {
  [[ $# -eq 0 ]] && { printf 'Usage: manol [section] <page>\nExample: manol 3 printf\n' >&2; return 1; }
  local page section url base_url="https://man.archlinux.org/man"
  if [[ $# -eq 1 ]]; then page="$1"; url="${base_url}/${page}"; else section="$1"; page="$2"; url="${base_url}/${page}.${section}"; fi
  curl -sL --user-agent "curl-manpage-viewer/1.0" --compressed "$url" | "${PAGER:-less}" -R
}

fman() {
  local -a less_env=(LESS_TERMCAP_md=$'\e[01;31m' LESS_TERMCAP_me=$'\e[0m' LESS_TERMCAP_us=$'\e[01;32m' LESS_TERMCAP_ue=$'\e[0m' LESS_TERMCAP_so=$'\e[45;93m' LESS_TERMCAP_se=$'\e[0m')
  local -a bat_env=(LANG='C.UTF-8' MANROFFOPT='-c' BAT_STYLE='full' BAT_PAGER="less -RFQs --use-color --no-histdups --mouse --wheel-lines=2")
  if has batman; then env "${bat_env[@]}" "${less_env[@]}" batman "$@"; elif has bat; then env "${bat_env[@]}" "${less_env[@]}" MANPAGER="sh -c 'col -bx | bat -splman --squeeze-limit 0 --tabs 2'" man "$@"; else env "${less_env[@]}" PAGER="less -RFQs --use-color --no-histdups --mouse --wheel-lines=2" man "$@"; fi
}

catt() {
  for i in "$@"; do [[ -d "$i" ]] && eza "$i" || bat -p "$i"; done
}

# Navigation (consolidated from zshrc, gated on zoxide)
if has zoxide; then
  export _ZO_DOCTOR=0 _ZO_ECHO=0 _ZO_EXCLUDE_DIRS="${HOME}:.cache:go"
  export _ZO_FZF_OPTS="--cycle -0 -1 --inline-info --no-multi --no-sort --preview 'eza --no-quotes --color=always --color-scale-mode=fixed --group-directories-first --oneline {2..}'"
  ifsource "$HOME/.config/bash/zoxide.bash" && eval "$(zoxide init bash)"
  cd(){ if [[ -n "$1" ]]; then z "$@" && eza; else z ~ && eza; fi; }
  alias ..='z ..' ...='z ../..' ....='z ../../..' .....='z ../../../..' ......='z ../../../../..' bd='z "$OLDPWD"' cd-="z -" cd='z'
else
  alias ..='cd ..' ...='cd ../..' ....='cd ../../..' .....='cd ../../../..' ......='cd ../../../../..' bd='cd "$OLDPWD"' cd-="cd -"
fi
alias dirs='dirs -v'

# Aliases (consolidated)
alias home='cd ~' cd..='cd ..' ..='cd ..' ...='cd ../..' ....='cd ../../..' .....='cd ../../../..' ......='cd ../../../../..'
alias cls='clear' c='clear' h='history'
alias 000='chmod -R 000' 644='chmod -R 644' 666='chmod -R 666' 755='chmod -R 755' 777='chmod -R 777'

# LESS colors
: "${LESS:=}"
: "${LESS_TERMCAP_mb:=$'\e[1;32m'}" "${LESS_TERMCAP_md:=$'\e[1;32m'}" "${LESS_TERMCAP_me:=$'\e[0m'}" "${LESS_TERMCAP_se:=$'\e[0m'}" "${LESS_TERMCAP_so:=$'\e[01;33m'}" "${LESS_TERMCAP_ue:=$'\e[0m'}" "${LESS_TERMCAP_us:=$'\e[1;4;31m'}"
export "${!LESS_TERMCAP@}"

alias h="history | grep "
alias p="ps aux | grep "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"
alias f="find . | grep "
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

alias mktar='tar -cvf' mkbz2='tar -cvjf' mkgz='tar -cvzf' untar='tar -xvf' unbz2='tar -xvjf' ungz='tar -xvzf'

trim(){ local var=$*; var="${var#"${var%%[![:space:]]*}"}"; var="${var%"${var##*[![:space:]]}"}"; printf '%s\n' "$var"; }

# Bindings
bind 'set completion-query-items 250' 'set page-completions off' 'set show-all-if-ambiguous on' 'set show-all-if-unmodified on' 'set menu-complete-display-prefix on' "set completion-ignore-case on" "set completion-map-case on" 'set mark-directories on' "set mark-symlinked-directories on" "set bell-style none" 'set skip-completed-text on' 'set colored-stats on' 'set colored-completion-prefix on' 'set expand-tilde on' '"Space": magic-space' '"\C-o": kill-whole-line' '"\C-a": beginning-of-line' '"\C-e": end-of-line' '"\e[1;5D": backward-word' '"\e[1;5C": forward-word'
bind '"\e[A":history-substring-search-backward' '"\e[B":history-substring-search-forward'
bind '"\M-\C-e": redraw-current-line' '"\M-\C-v": "\C-a\C-k$\C-y\M-\C-e\C-a\C-y="' '"\M-\C-b": "\C-e > /dev/null 2>&1 &\C-m"'
bind '"\t": menu-complete' '"\e[Z": menu-complete-backward'

# Prompt (gated experimental)
configure_prompt(){
  if has starship; then eval "$(LC_ALL=C starship init bash)"; return; fi
  local MGN='\[\e[35m\]' BLU='\[\e[34m\]' YLW='\[\e[33m\]' BLD='\[\e[1m\]' UND='\[\e[4m\]' GRN='\[\e[32m\]' CYN='\[\e[36m\]' DEF='\[\e[0m\]' RED='\[\e[31m\]' PNK='\[\e[38;5;205m\]' USERN HOSTL
  USERN="${MGN}\u${DEF}"; [[ $EUID -eq 0 ]] && USERN="${RED}\u${DEF}"
  HOSTL="${BLU}\h${DEF}"; [[ -n $SSH_CONNECTION ]] && HOSTL="${YLW}\h${DEF}"
  exstat(){ [[ $? == 0 ]] && printf '%s:)${DEF}' || printf '%sD:${DEF}'; }
  PS1="[${USERN}@${HOSTL}${UND}|${DEF}${CYN}\w${DEF}]>${PNK}\A${DEF}|\$(exstat) ${BLD}\$${DEF} "
  PS2='> '
  if has __git_ps1; then
    export GIT_PS1_OMITSPARSESTATE=1 GIT_PS1_HIDE_IF_PWD_IGNORED=1
    unset GIT_PS1_SHOWDIRTYSTATE GIT_PS1_SHOWSTASHSTATE GIT_PS1_SHOWUPSTREAM GIT_PS1_SHOWUNTRACKEDFILES
    PROMPT_COMMAND="LC_ALL=C __git_ps1 2>/dev/null; ${PROMPT_COMMAND:-}"
  fi
  # Experimental: mommy prompt
  EXPERIMENTAL="${EXPERIMENTAL:-0}"
  if (( EXPERIMENTAL == 1 )) && has mommy && [[ "${stealth:-0}" -ne 1 ]] && [[ ${PROMPT_COMMAND:-} != *mommy* ]]; then
    PROMPT_COMMAND="LC_ALL=C mommy -1 -s \$?; ${PROMPT_COMMAND:-}"
  fi
}
configure_prompt

# Dedupe path
dedupe_path(){
  local IFS=: dir s
  for dir in $PATH; do [[ -n $dir && -z ${seen[$dir]} ]] && seen[$dir]=1 && s="${s:+$s:}$dir"; done
  [[ -n $s ]] && export PATH="$s"
}
dedupe_path

# ADB connect
adb-connect(){
  if ! adb devices >/dev/null 2>&1; then exit 1; fi
  local IP="${1:-$(adb shell ip route | awk '{print $9}')}" PORT="${2:-5555}"
  adb tcpip "$PORT" >/dev/null 2>&1 || :
  adb connect "${IP}:${PORT}"
}

unset -f ifsource prependpath
autoload_init  # Init lazy loading
unset -f autoload_init autoload_parse lazyfile
