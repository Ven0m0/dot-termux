# ~/.bashrc
# https://www.gnu.org/software/bash/manual/bash.html
[[ $- != *i* ]] && return
#============ Helpers ============
# Check for command
has(){ [[ -x $(command -v -- "$1" >/dev/null) ]]; }
#hconv(){ printf '%s\n' "${1/#\~\//${HOME}/}"; }
# Safely source file if it exists ( ~ -> $HOME )
ifsource(){ [[ -r "${1/#\~\//${HOME}/}" ]] && . "${1/#\~\//${HOME}/}" 2>/dev/null; }
# Safely prepend only if not already in PATH ( ~ -> $HOME )
prependpath(){ [[ -d "${1/#\~\//${HOME}/}" ]] && [[ ":$PATH:" != *":${1/#\~\//${HOME}/}:"* ]] && PATH="${1/#\~\//${HOME}/}${PATH:+:$PATH}"; }
#============ Sourcing ============
dot=("$HOME"/.{bash_aliases,bash_functions,bash_completions,bash.d/cht.sh,config/bash/cht.sh})
for p in "${dot[@]}"; do ifsource "$p"; done; unset p dot

[[ -r "${HOME}/.inputrc" ]] && export INPUTRC="${HOME}/.inputrc"

ifsource "${HOME}/navita.sh"

#============ Env ============
prependpath "${HOME}/.local/bin"
prependpath "${HOME}/.bin"
prependpath "${HOME}/bin"
#============ History / Prompt basics ============
# PS1='[\u@\h|\w] \$' # bash-prompt-generator.org
# https://github.com/glabka/configs/blob/master/home/.bashrc
HISTSIZE=1000
HISTFILESIZE=2000
HISTCONTROL="erasedups:ignoreboth:autoshare"
HISTIGNORE="&:[bf]g:clear:cls:exit:history:bash:fish:?:??"
export HISTTIMEFORMAT="%F %T " IGNOREEOF=100
HISTFILE="${HOME}/.bash_history"
PROMPT_DIRTRIM=2 
PROMPT_COMMAND="history -a"
#============ Core ============
CDPATH=".:${HOME}:/"
ulimit -c 0 # disable core dumps
export FIGNORE="argo.lock"#
shopt -s histappend cmdhist checkwinsize dirspell cdable_vars cdspell \
         autocd cdable_vars hostcomplete no_empty_cmd_completion globstar nullglob
# Disable Ctrl-s, Ctrl-q
set -o noclobber
bind -r '\C-s'
stty -ixon -ixoff -ixany
set +H
#============
# Editor selection: prefer micro, fallback to nano
command -v micro &>/dev/null && EDITOR=micro; export ${EDITOR:=nano}
export MICRO_TRUECOLOR=1
export VISUAL="$EDITOR" VIEWER="$EDITOR" GIT_EDITOR="$EDITOR" SYSTEMD_EDITOR="$EDITOR" FCEDIT="$EDITOR" SUDO_EDITOR="$EDITOR"
# https://wiki.archlinux.org/title/Locale
#export LANG=C.UTF-8 LC_COLLATE=C.UTF-8 LC_CTYPE=C.UTF-8 MEASUREMENT.UTF-8
#export LC_MEASUREMENT=C TZ='Europe/Berlin' TIME_STYLE='+%d-%m %H:%M'
unset LC_ALL POSIXLY_CORRECT

#=======
export PAGER=bat BATPIPE=color BAT_STYLE=auto LESSQUIET=1
export LESSCHARSET='utf-8' LESSHISTFILE=-

if has vivid; then
  export LS_COLORS="$(vivid generate molokai)"
elif has dircolors; then
  eval "$(dircolors -b)" &>/dev/null
fi
: "${CLICOLOR:=$(tput colors)}"
export CLICOLOR SYSTEMD_COLORS=1

export CURL_HOME="$HOME" WGETRC="${HOME}/.wgetrc"

# Cheat.sh
export CHEAT_USE_FZF=true
export CHTSH_CURL_OPTIONS="-sfLZ4 --compressed -m 5 --connect-timeout 3"
cht(){
  # join all arguments with '/', so “topic sub topic” → “topic/sub/topic”
  local query="${*// /\/}"
  if ! LC_ALL=C curl -sfZ4 --compressed -m 5 --connect-timeout 3 "cht.sh/${query}"; then
    LC_ALL=C curl -sfZ4 --compressed -m 5 --connect-timeout 3 "cht.sh/:help"
  fi
}

export PYTHONOPTIMIZE=2 PYTHONUTF8=1 PYTHONNODEBUGRANGES=1 PYTHON_JIT=1 PYENV_VIRTUALENV_DISABLE_PROMPT=1 \
  PYTHONSTARTUP="{$HOME}/.pythonstartup" PYTHON_COLORS=1
unset PYTHONDONTWRITEBYTECODE

if has uv; then
  export UV_COMPILE_BYTECODE=1 UV_LINK_MODE=hardlink
fi

export ZSTD_NBTHREADS=0 _JAVA_AWT_WM_NONREPARENTING=1

gclone(){ LC_ALL=C command git clone --progress --filter=blob:none --depth 1 "$@" && command cd "$1"; ls -A; }
alias pip='python -m pip' py3='python3' py='python'

touchf(){ command mkdir -p -- "$(dirname -- "$1")" && command touch -- "$1"; }

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

# Get help for a command with bat
bathelp() {
  "$@" --help 2>&1 | command bat -splhelp --squeeze-limit 0
}

# Display online manpages using curl
manol() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: manol [section] <page>" >&2
    echo "Example: manol 3 printf" >&2
    return 1
  fi
  local page section url
  local base_url="https://man.archlinux.org/man"
  local pager="${PAGER:-less}"
  if [[ $# -eq 1 ]]; then
    page="$1"
    url="${base_url}/${page}"
  else
    section="$1"
    page="$2"
    url="${base_url}/${page}.${section}"
  fi
  curl -sL --user-agent "curl-manpage-viewer/1.0" --compressed "$url" | "$pager" -R
}

# Fancy man pages with bat
fman() {
  local -a less_env=(LESS_TERMCAP_md=$'\e[01;31m' LESS_TERMCAP_me=$'\e[0m' LESS_TERMCAP_us=$'\e[01;32m' LESS_TERMCAP_ue=$'\e[0m' LESS_TERMCAP_so=$'\e[45;93m' LESS_TERMCAP_se=$'\e[0m')
  local -a bat_env=(LANG='C.UTF-8' MANROFFOPT='-c' BAT_STYLE='full' BAT_PAGER="less -RFQs --use-color --no-histdups --mouse --wheel-lines=2")
  
  if command -v batman &>/dev/null; then
    env "${bat_env[@]}" "${less_env[@]}" command batman "$@"
  elif command -v bat &>/dev/null; then
    env "${bat_env[@]}" "${less_env[@]}" MANPAGER="sh -c 'col -bx | bat -splman --squeeze-limit 0 --tabs 2'" command man "$@"
  else
    env "${less_env[@]}" PAGER="less -RFQs --use-color --no-histdups --mouse --wheel-lines=2" command man "$@"
  fi
}

# Cat^2 (cat for files and directories)
catt() {
  for i in "$@"; do
    if [[ -d "$i" ]]; then
      eza "$i"
    else
      bat -p "$i"
    fi
  done
}

# Change directory aliases
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# cd into the old directory
alias bd='cd "$OLDPWD"'

alias cls='clear' c='clear'
alias h='history'

# alias chmod commands
alias 000='chmod -R 000'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# https://github.com/Bash-it/bash-it/blob/master/plugins/available/man.plugin.bash
: "${LESS:=}"
: "${LESS_TERMCAP_mb:=$'\e[1;32m'}"
: "${LESS_TERMCAP_md:=$'\e[1;32m'}"
: "${LESS_TERMCAP_me:=$'\e[0m'}"
: "${LESS_TERMCAP_se:=$'\e[0m'}"
: "${LESS_TERMCAP_so:=$'\e[01;33m'}"
: "${LESS_TERMCAP_ue:=$'\e[0m'}"
: "${LESS_TERMCAP_us:=$'\e[1;4;31m'}"
export "${!LESS_TERMCAP@}"

# Search command line history
alias h="history | grep "

# Search running processes
alias p="ps aux | grep "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"

# Search files in the current folder
alias f="find . | grep "

# Alias's to show disk space and space used in a folder
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# Alias's for archives
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

# Trim leading and trailing spaces (for scripts)
trim() {
	local var=$*
	var="${var#"${var%%[![:space:]]*}"}" # remove leading whitespace characters
	var="${var%"${var##*[![:space:]]}"}" # remove trailing whitespace characters
	echo -n "$var"
}

alias pip='python -m pip' py3='python3' py='python'
#============ Bindings (readline) ============
bind 'set completion-query-items 250'
bind 'set page-completions off'
bind 'set show-all-if-ambiguous on'
bind 'set show-all-if-unmodified on'
bind 'set menu-complete-display-prefix on'
bind "set completion-ignore-case on"
bind "set completion-map-case on"
bind 'set mark-directories on'
bind "set mark-symlinked-directories on"
bind "set bell-style none"
bind 'set skip-completed-text on'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set expand-tilde on'
bind '"Space": magic-space'
bind '"\C-o": kill-whole-line'
bind '"\C-a": beginning-of-line'
bind '"\C-e": end-of-line'
bind '"\e[1;5D": backward-word'
bind '"\e[1;5C": forward-word'
# https://github.com/Bash-it/bash-it/blob/master/plugins/available/history-substring-search.plugin.bash
bind '"\e[A":history-substring-search-backward'
bind '"\e[B":history-substring-search-forward'
# prefixes the line with sudo , if Alt+s is pressed
#bind '"\ee": "\C-asudo \C-e"'
#bind '"\es":"\C-asudo "'
# https://wiki.archlinux.org/title/Bash
run-help(){ help "$READLINE_LINE" 2>/dev/null || command man "$READLINE_LINE"; }
bind -m vi-insert -x '"\eh": run-help'
bind -m emacs -x     '"\eh": run-help'
#============ Prompt 2 ============
configure_prompt(){
  command -v starship &>/dev/null && { eval "$(LC_ALL=C starship init bash)"; return; }
  local MGN='\[\e[35m\]' BLU='\[\e[34m\]' YLW='\[\e[33m\]' BLD='\[\e[1m\]' UND='\[\e[4m\]' GRN='\[\e[32m\]' \
        CYN='\[\e[36m\]' DEF='\[\e[0m\]' RED='\[\e[31m\]'  PNK='\[\e[38;5;205m\]' USERN HOSTL
  USERN="${MGN}\u${DEF}"; [[ $EUID -eq 0 ]] && USERN="${RED}\u${DEF}"
  HOSTL="${BLU}\h${DEF}"; [[ -n $SSH_CONNECTION ]] && HOSTL="${YLW}\h${DEF}"
  exstat(){ [[ $? == 0 ]] && echo -e '${GRN}:)${DEF}' || echo -e '${RED}D:${DEF}'; }
  PS1="[${USERN}@${HOSTL}${UND}|${DEF}${CYN}\w${DEF}]>${PNK}\A${DEF}|\exstat ${BLD}\$${DEF} "
  PS2='> '
  if command -v __git_ps1 &>/dev/null && [[ ${PROMPT_COMMAND:-} != *git_ps1* ]]; then
    export GIT_PS1_OMITSPARSESTATE=1 GIT_PS1_HIDE_IF_PWD_IGNORED=1
    unset GIT_PS1_SHOWDIRTYSTATE GIT_PS1_SHOWSTASHSTATE GIT_PS1_SHOWUPSTREAM GIT_PS1_SHOWUNTRACKEDFILES
    PROMPT_COMMAND="LC_ALL=C __git_ps1 2>/dev/null; ${PROMPT_COMMAND:-}"
  fi
  # Only add if not in stealth mode and not already present in PROMPT_COMMAND
  if command -v mommy &>/dev/null && [[ "${stealth:-0}" -ne 1 ]] && [[ ${PROMPT_COMMAND:-} != *mommy* ]]; then
    PROMPT_COMMAND="LC_ALL=C mommy -1 -s \$?; ${PROMPT_COMMAND:-}" # mommy https://github.com/fwdekker/mommy
    # PROMPT_COMMAND="LC_ALL=C mommy \$?; ${PROMPT_COMMAND:-}" # Shell-mommy https://github.com/sleepymincy/mommy
  fi
}
configure_prompt
#============ End ============
dedupe_path(){
  local IFS=: dir s; declare -A seen
  for dir in $PATH; do
    [[ -n $dir && -z ${seen[$dir]} ]] && seen[$dir]=1 && s="${s:+$s:}$dir"
  done
  [[ -n $s ]] && export PATH="$s"
}
dedupe_path
#============ Jumping ============
if command -v zoxide &>/dev/null; then
  export _ZO_DOCTOR=0 _ZO_ECHO=0 _ZO_EXCLUDE_DIRS="${HOME}:.cache:go" 
  export _ZO_FZF_OPTS="--cycle -0 -1 --inline-info --no-multi --no-sort \
    --preview 'eza --no-quotes --color=always --color-scale-mode=fixed --group-directories-first --oneline {2..}'"
  [[ ! -r "${HOME}/.config/bash/zoxide.bash" ]] && zoxide init bash >| "${HOME}/.config/bash/zoxide.sh"
  ifsource "${HOME}/.config/bash/zoxide.sh" && eval "$(zoxide init bash)"
fi

# Automatically do an ls after each cd, z, or zoxide
cd()
{
	if [ -n "$1" ]; then
		z "$@" && eza
	else
		z ~ && eza
	fi
}

adb-connect(){
  local IP PORT
  if ! adb devices >/dev/null 2>&1; then
    exit 1
  fi
  IP="${1:-$(adb shell ip route | awk '{print $9}')}"
  PORT="${2:-5555}"
  adb tcpip "$PORT" >/dev/null 2>&1
  adb connect "${IP}:${PORT}"
}

unset -f ifsource prependpath LC_ALL &>/dev/null
