#!/data/data/com.termux/files/usr/bin/bash



ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
MAGIC_ENTER_GIT_COMMAND='git status -u .'
MAGIC_ENTER_OTHER_COMMAND='ls -lh .'

[[ -z "${plugins[*]}" ]] && plugins=(
git fzf aliases colored-man-pages colorize command-not-found eza debian common-aliases alias-finder frontend-search
git-extras gitfast history man python rust shrink-path ssh ssh-agent thefuck themes tldr universalarchive zoxide zsh-interactive-cd
zsh-navigation-tools extract gnu-utils magic-enter
)
# starship
source $ZSH/oh-my-zsh.sh
export HISTIGNORE="&:[bf]g:c:clear:history:exit:q:pwd:* --help"
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

HISTFILE=${HOME}/.zsh_history
HISTSIZE=10000 SAVEHIST="$HISTSIZE"
export HISTIGNORE="&:[bf]g:c:clear:history:exit:q:pwd:* --help"
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt PROMPT_SUBST
stty -ixon

export TERM="xterm-256color" 
export EDITOR=micro
export VISUAL=micro

alias mkdir='mkdir -p'


mcd () { mkdir -p -- "$1" && cd "$1"; }

