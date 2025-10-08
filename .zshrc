# =============================================================================
# ~/.zshrc - Optimized for Termux with Zinit
# =============================================================================

# Basic ZSH Settings
setopt auto_cd auto_pushd pushd_ignore_dups extended_glob glob_dots
setopt no_beep numeric_glob_sort rc_quotes autoparamslash interactive_comments
unsetopt flow_control

# Performance optimization
skip_global_compinit=1
setopt no_global_rcs
SHELL_SESSIONS_DISABLE=1

# History settings
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt share_history extended_history hist_ignore_all_dups hist_ignore_space

# =============================================================================
# ZINIT SETUP - ULTRA FAST PLUGIN MANAGER
# =============================================================================

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
if [[ ! -f $ZINIT_HOME/zinit.git/zinit.zsh ]]; then
    command mkdir -p "$ZINIT_HOME"
    command git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME/zinit.git"
fi
source "$ZINIT_HOME/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Enable Turbo mode for speed
zinit light-mode for \
    zdharma-continuum/z-a-rust \
    zdharma-continuum/z-a-bin-gem-node

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================

export EDITOR='micro'
export VISUAL="$EDITOR"
export PAGER='bat'
export LANG='C.UTF-8' LC_ALL='C.UTF-8'
export TERM="xterm-256color"
export BAT_THEME="Dracula"

# Path setup
[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"
[[ -d "${HOME}/.bin" ]] && export PATH="${HOME}/.bin:${PATH}"
[[ -d "${HOME}/bin" ]] && export PATH="${HOME}/bin:${PATH}"

# =============================================================================
# PLUGINS - PRIORITIZED BY STARTUP IMPACT
# =============================================================================

# --- Essential Fast Loading Plugins ---
zinit wait lucid light-mode for \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
        zdharma-continuum/fast-syntax-highlighting \
    atload"!_zsh_autosuggest_start" \
        zsh-users/zsh-autosuggestions \
    blockf atpull'zinit creinstall -q .' \
        zsh-users/zsh-completions

# --- Powerlevel10k Prompt (loads instantly) ---
zinit ice depth=1
zinit light romkatv/powerlevel10k

# --- Utilities (deferred loading) ---
zinit wait lucid for \
    zsh-users/zsh-history-substring-search \
    hl2b/zsh-autopair

# --- Rust-powered CLI tools ---
zinit wait'1' lucid from'gh-r' as'program' for \
    Canop/broot \
    bootandy/dust

# --- Atuin History Manager (enhanced history search) ---
zinit wait'1' lucid from'gh-r' as'program' for \
    atuinsh/atuin
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi

# --- Zoxide (smarter cd command) ---
zinit wait'0' lucid as'program' from'gh-r' for \
    ajeetdsouza/zoxide
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# =============================================================================
# COMPLETIONS & KEYBINDINGS
# =============================================================================

# Setup completions
autoload -Uz compinit
compinit -C -d "${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump"

# Completion styles
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"
zstyle ':completion:*:*:*:*:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always $realpath'

# Keybindings
bindkey -e # Emacs mode
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# =============================================================================
# ALIASES & FUNCTIONS
# =============================================================================

# --- Navigation ---
alias ...='cd ../..'
alias ..='cd ..'
alias bd='cd "$OLDPWD"'

# --- File listings ---
alias ls='eza --icons -F --color=auto --group-directories-first'
alias la='eza -a --icons -F --color=auto --group-directories-first'
alias ll='eza -al --icons -F --color=auto --group-directories-first --git'
alias lt='eza --tree --level=3 --icons -F --color=auto'

# --- Git ---
alias gst='git status'
alias gco='git checkout'
alias gpl='git pull'
alias gps='git push'
alias gclone='git clone --filter=blob:none --depth 1'

# --- Termux ---
alias reload='termux-reload-settings'
alias battery='termux-battery-status'
alias clipboard='termux-clipboard-get'
alias copy='termux-clipboard-set'
alias share='termux-share'
alias notify='termux-notification'

# --- Quick Revancify/Simplify launchers ---
revancify() {
  if [[ ! -d "$HOME/revancify" ]]; then
    echo "Installing Revancify..."
    curl -sL https://github.com/decipher3114/Revancify/raw/main/install.sh | bash
  else
    cd "$HOME/revancify" && bash revancify.sh
  fi
}

simplify() {
  if [[ ! -f "$HOME/.Simplify.sh" ]]; then
    echo "Installing Simplify..."
    pkg update && pkg install --only-upgrade apt bash coreutils openssl -y
    curl -sL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh"
  fi
  bash "$HOME/.Simplify.sh"
}

# --- Utility functions ---
# Search and edit file with fzf
fe() {
  local IFS=$'\n' line files=()
  while IFS='' read -r line; do files+=("$line"); done < <(fzf -q "$1" -m --inline-info -1 -0 --layout=reverse-list)
  [[ -n "${files[0]}" ]] && ${EDITOR:-micro} "${files[@]}"
}

# cd with fzf
fcd() {
  local dir
  dir=$(find "${1:-.}" -path '*/\.*' -prune -o -type d -print 2>/dev/null | fzf +m) && cd "$dir" || return
}

# --- System maintenance ---
termux-clean() {
  echo "🧹 Cleaning Termux..."
  apt clean && apt autoclean && apt-get -y autoremove --purge
  find ~ -type d -empty -delete 2>/dev/null || true
  echo "✅ Termux cleanup complete."
}

# =============================================================================
# POWERLEVEL10K CONFIGURATION
# =============================================================================
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
