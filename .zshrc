#!/data/data/com.termux/files/usr/bin/bash

# Enable Powerlevel10k instant prompt (optimized)
#typeset p10k_instant_prompt_file="${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
#[[ -r "$p10k_instant_prompt_file" ]] && source "$p10k_instant_prompt_file"

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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

#ulimit -n 10240

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
fzf aliases colored-man-pages colorize eza man shrink-path ssh zoxide
zsh-navigation-tools zsh-autopair fast-syntax-highlighting zsh-autosuggestions enhancd
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
setopt nonomatch
setopt auto_resume
setopt glob_dots
setopt extended_glob
setopt numericglobsort
setopt magicequalsubst
setopt pushd_ignore_dups
setopt pushd_minus
export WORDCHARS='*?[]~=&;!#$%^(){}<>'
setopt extended_history        # save timestamps with history entries
setopt inc_append_history      # write to history file immediately, not on shell exit
setopt hist_expire_dups_first  # expire duplicate entries first when trimming history
setopt hist_ignore_all_dups    # delete old entry if new entry is a duplicate
setopt hist_find_no_dups       # don't display previously found duplicates in search
setopt hist_save_no_dups       # don't write duplicate entries to history file
setopt hist_reduce_blanks      # remove superfluous blanks before recording

# Large history buffers for comprehensive tracking
SAVEHIST=10000
HISTSIZE=10000
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "$terminfo[kcuu1]" history-beginning-search-backward-end
bindkey "$terminfo[kcud1]" history-beginning-search-forward-end

stty -ixon

export TERM="xterm-256color" 
export EDITOR=micro
export VISUAL=micro

alias mkdir='mkdir -p'

alias zshrc='${=EDITOR} ~/.zshrc'
mcd () { mkdir -p -- "$1" && cd "$1"; }

