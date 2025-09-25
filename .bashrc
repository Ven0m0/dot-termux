
source "${HOME}/navita.sh"

if command -v zoxide &>/dev/null &&
  export _ZO_FZF_OPTS=--no-mouse -0 -1 --cycle +m --inline-info"
  eval "$(_ZO_DOCTOR=0 zoxide init bash)"
fi

LC_COLLATE=C.UTF-8
LC_CTYPE=C.UTF-8

# Common use
alias grep='grep --color=auto -s'
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


alias cls='clear' c='clear'
alias h='history'








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
