#!/data/data/com.termux/files/usr/bin/bash

# Enable Powerlevel10k instant prompt (optimized)
typeset p10k_instant_prompt_file="${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
[[ -r "$p10k_instant_prompt_file" ]] && source "$p10k_instant_prompt_file"

#if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  #source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
#fi

function zcompile-many() {
  local f; for f; do zcompile -R -- "$f".zwc "$f"; done
}

if [[ ! -e ~/zsh-defer ]]; then
  git clone --depth=1 https://github.com/romkatv/zsh-defer.git ~/zsh-defer
  zcompile-many ~/zsh-defer/zsh-defer.plugin.zsh
fi


if [[ ! -e ~/zsh-autosuggestions ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ~/zsh-autosuggestions
  zcompile-many ~/zsh-autosuggestions/{zsh-autosuggestions.zsh,src/**/*.zsh}
fi

#Allow more system resources and open files to the shell
#Hopefully fix vim open files leaks
ulimit -n 10240

# Basic auto/tab complete:
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
MAGIC_ENTER_GIT_COMMAND='git status -u .'
MAGIC_ENTER_OTHER_COMMAND='ls -lh .'

[[ -z "${plugins[*]}" ]] && plugins=(
git fzf aliases colored-man-pages colorize command-not-found eza debian common-aliases frontend-search
git-extras gitfast history man shrink-path ssh ssh-agent thefuck themes zoxide zsh-interactive-cd
zsh-navigation-tools zsh-autopair
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

alias zshrc='${=EDITOR} ~/.zshrc'
mcd () { mkdir -p -- "$1" && cd "$1"; }

