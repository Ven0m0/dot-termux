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
export FIGNORE="argo.lock" IFS="${IFS:-$' \t\n'}"
shopt -s histappend cmdhist checkwinsize dirspell cdable_vars cdspell \
         autocd cdable_vars hostcomplete no_empty_cmd_completion globstar nullglob
# shopt -s force_fignore execfail varredir_close
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
export LANG=C.UTF-8 LC_COLLATE=C.UTF-8 LC_CTYPE=C.UTF-8 MEASUREMENT.UTF-8
export LC_MEASUREMENT=C TZ='Europe/Berlin' TIME_STYLE='+%d-%m %H:%M'
unset LC_ALL POSIXLY_CORRECT
jobs="$(nproc)"

#=======
source "${HOME}/navita.sh"

if command -v zoxide &>/dev/null &&
  export _ZO_FZF_OPTS="--no-mouse -0 -1 --cycle +m --inline-info"
  eval "$(_ZO_DOCTOR=0 zoxide init baLC_CTYPE=rep Common uautolias grep='grep --color=auto -s'
alias fgrep='\grep --color=auto -sF'
alias egrep='\grep --color=auto -sE'
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
alias nano='nano -/'


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

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'


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

# Automatically do an ls after each cd, z, or zoxide
cd ()
{
	if [ -n "$1" ]; then
		builtin cd "$@" && ls
	else
		builtin cd ~ && ls
	fi
}

# Trim leading and trailing spaces (for scripts)
trim() {
	local var=$*
	var="${var#"${var%%[![:space:]]*}"}" # remove leading whitespace characters
	var="${var%"${var##*[![:space:]]}"}" # remove trailing whitespace characters
	echo -n "$var"
}

alias pip='python -m pip' py3='python3' py='python'

#============ Prompt 2 ============
configure_prompt(){
  command -v starship &>/dev/null && { eval "$(LC_ALL=C starship init bash)"; return; }
  local MGN='\[\e[35m\]' BLU='\[\e[34m\]' YLW='\[\e[33m\]' BLD='\[\e[1m\]' UND='\[\e[4m\]' \
        CYN='\[\e[36m\]' DEF='\[\e[0m\]' RED='\[\e[31m\]'  PNK='\[\e[38;5;205m\]' USERN HOSTL
  USERN="${MGN}\u${DEF}"; [[ $EUID -eq 0 ]] && USERN="${RED}\u${DEF}"
  HOSTL="${BLU}\h${DEF}"; [[ -n $SSH_CONNECTION ]] && HOSTL="${YLW}\h${DEF}"
  PS1="[${USERN}@${HOSTL}${UND}|${DEF}${CYN}\w${DEF}]>${PNK}\A${DEF}|\$? ${BLD}\$${DEF} "
  PS2='> '
  if command -v __git_ps1 &>/dev/null && [[ $PROMPT_COMMAND != *git_ps1* ]]; then
    export GIT_PS1_OMITSPARSESTATE=1 GIT_PS1_HIDE_IF_PWD_IGNORED=1
    unset GIT_PS1_SHOWDIRTYSTATE GIT_PS1_SHOWSTASHSTATE GIT_PS1_SHOWUPSTREAM GIT_PS1_SHOWUNTRACKEDFILES
    PROMPT_COMMAND="LC_ALL=C __git_ps1 2>/dev/null; ${PROMPT_COMMAND:-}"
  fi
  if command -v mommy &>/dev/null && [[ ${PROMPT_COMMAND:-} != *mommy* ]]; then
    PROMPT_COMMAND="LC_ALL=C mommy -1 -s \$?; ${PROMPT_COMMAND:-}" # mommy https://github.com/fwdekker/mommy
    # PROMPT_COMMAND="LC_ALL=C mommy \$?; ${PROMPT_COMMAND:-}" # Shell-mommy https://github.com/sleepymincy/mommy
  fi
}
configure_prompt
#============ End ============
