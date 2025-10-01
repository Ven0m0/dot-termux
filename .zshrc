# =============================================================================
# ~/.zshrc - v2 Optimized for Termux
# =============================================================================
# Focus: Maximum speed, powerful completions, and a rich toolset for
# development and system management on Termux.
# =============================================================================

# Sourced from .zshenv for reliability in Termux
setopt no_global_rcs
export SHELL_SESSIONS_DISABLE=1
skip_global_compinit=1

# Defer the Zsh compiler for a faster startup
zmodload zsh/zcompiler
autoload -Uz zrecompile
zrecompile -q -p -i

# =============================================================================
# ZINIT PLUGIN MANAGER
# =============================================================================

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
if [[ ! -f $ZINIT_HOME/zinit.git/zinit.zsh ]]; then
    command git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME/zinit.git"
fi
source "$ZINIT_HOME/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load Turbo mode for a significant speedup
zinit light-mode for \
    zdharma-continuum/z-a-rust \
    zdharma-continuum/z-a-bin-gem-node

# =============================================================================
# CORE CONFIG & ENVIRONMENT
# =============================================================================

export EDITOR='micro'
export VISUAL="$EDITOR"
export PAGER='bat'

# Prepend local bin paths if they exist
[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"
[[ -d "${HOME}/.bin" ]] && export PATH="${HOME}/.bin:${PATH}"
[[ -d "${HOME}/bin" ]] && export PATH="${HOME}/bin:${PATH}"

export LANG='C.UTF-8' LC_ALL='C.UTF-8'
export TERM="xterm-256color"

# =============================================================================
# ATUIN - REVOLUTIONIZED SHELL HISTORY
# =============================================================================
# Replaces default history with a searchable, syncable SQLite database.
# =============================================================================
zinit ice as'program' from'gh-r'
zinit light atuinsh/atuin
eval "$(atuin init zsh)"

# =============================================================================
# SHELL OPTIONS (setopt)
# =============================================================================
setopt auto_cd auto_pushd pushd_ignore_dups auto_remove_slash
setopt extended_glob glob_dots no_beep numeric_glob_sort rc_quotes
unsetopt flow_control

# =============================================================================
# ZINIT PLUGINS & TOOLS
# =============================================================================

# --- Powerlevel10k Prompt ---
zinit ice lucid wait'0' blockf atpull'zinit creinstall -q .'
zinit light romkatv/powerlevel10k

# --- FZF (Core fuzzy-finder) ---
zinit ice lucid wait'0'
zinit light junegunn/fzf

# --- FZF Tab Completions (!! GAME CHANGER !!) ---
zinit ice lucid wait'0'
zinit light Aloxaf/fzf-tab

# --- Syntax Highlighting (Fast) ---
zinit ice lucid wait'0'
zinit light zdharma-continuum/fast-syntax-highlighting

# --- Auto Suggestions ---
zinit ice lucid wait'0' atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay"
zinit light zsh-users/zsh-autosuggestions

# --- History Substring Search ---
zinit ice lucid wait'0'
zinit light zsh-users/zsh-history-substring-search

# --- Zoxide (Smarter `cd`) ---
zinit ice lucid wait'0'
zinit light ajeetdsouza/zoxide

# --- Auto-pair ---
zinit ice lucid wait'0'
zinit light hl2b/zsh-autopair

# --- Zsh Completions ---
zinit ice lucid wait'0'
zinit light zsh-users/zsh-completions

# --- Additional Binaries (Rust Tools) ---
zinit ice as'program' from'gh-r'
zinit light Canop/broot # `br` to navigate dirs
zinit ice as'program' from'gh-r'
zinit light bootandy/dust # `dust` as a better `du`

# =============================================================================
# COMPLETION SYSTEM
# =============================================================================
autoload -Uz compinit
compinit -C -d "${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump"

zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"
zstyle ':completion:*:*:*:*:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always $realpath'

# =============================================================================
# KEYBINDINGS
# =============================================================================
bindkey -e # Emacs keybindings

# Standard navigation
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# History substring search on arrow keys
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# =============================================================================
# ALIASES & FUNCTIONS
# =============================================================================

# --- Aliases ---
alias ...='cd ../..'
alias ..='cd ..'
alias bd='cd "$OLDPWD"'
alias ls='eza --icons -F --color=auto --group-directories-first'
alias la='eza -a --icons -F --color=auto --group-directories-first'
alias ll='eza -al --icons -F --color=auto --group-directories-first --git'
alias lt='eza --tree --level=3 --icons -F --color=auto'
alias gclone='command git clone --filter=blob:none --depth 1'

# --- Termux ---
alias reload='termux-reload-settings'
alias battery='termux-battery-status'

# --- Revanced Builder ---
build-revanced() {
  for tool in java curl; do
    if ! command -v "$tool" &>/dev/null; then
      echo "Error: '${tool}' is not installed. Please install it first."
      return 1
    fi
  done

  local YT_VERSION="19.25.35" # <-- IMPORTANT: Update to the version recommended by ReVanced
  local BUILD_DIR="$HOME/revanced-build"
  
  echo ">>> Setting up build environment in ${BUILD_DIR}..."
  mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR" || return

  echo ">>> Downloading latest ReVanced tools..."
  local dl_cmd="curl -# -L -o"
  $dl_cmd rvx-cli.jar "https://github.com/inotia00/revanced-cli/releases/latest/download/revanced-cli.jar"
  $dl_cmd rvx-patches.jar "https://github.com/inotia00/revanced-patches/releases/latest/download/revanced-patches.jar"
  $dl_cmd rvx-integrations.apk "https://github.com/inotia00/revanced-integrations/releases/latest/download/revanced-integrations.apk"
  
  local APK_FILE="youtube-v${YT_VERSION}.apk"
  if [[ ! -f "$APK_FILE" ]]; then
    echo "!!! YouTube APK not found."
    echo "!!! Please download it to ${BUILD_DIR} and name it ${APK_FILE}"
    return 1
  fi
  
  echo ">>> Starting patch process..."
  java -jar rvx-cli.jar patch \
    --patch-bundle rvx-patches.jar \
    --merge-apk rvx-integrations.apk \
    --out "revanced-yt-${YT_VERSION}.apk" \
    --exclude "GmsCore support" \
    --include "Custom branding" \
    --include "Amoled" \
    "$APK_FILE"

  echo ">>> Build complete! Find your APK in ${BUILD_DIR}"
}

# --- Phone/Termux Cleaning ---
termux-clean() {
    echo "🧹 Cleaning Termux..."
    apt clean && apt autoclean && apt-get -y autoremove --purge
    find ~ -type d -empty -delete
    echo "✅ Termux cleanup complete."
}

phone-clean-cache() {
    if [[ $(id -u) -eq 0 ]]; then
        echo "🧹 Clearing all app caches (requires root)..."
        pm trim-caches 999G
        echo "✅ App caches trimmed."
    else
        echo "🛑 Root access is required to clear all app caches."
    fi
}

# =============================================================================
# PROMPT - POWERLEVEL10K
# =============================================================================
# To customize, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
