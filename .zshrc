# =============================================================================
# ~/.zshrc - Optimized for Termux
# =============================================================================
# This configuration prioritizes speed, using zinit for plugin management,
# lazy-loading features, and providing useful functions for your workflow.
# =============================================================================

# Sourced from .zshenv for reliability in Termux
setopt no_global_rcs
export SHELL_SESSIONS_DISABLE=1
skip_global_compinit=1

# For a faster startup, we defer the Zsh compiler
zmodload zsh/zcompiler
autoload -Uz zrecompile
zrecompile -q -p -i

# =============================================================================
# ZINIT PLUGIN MANAGER
# =============================================================================
# Fast, simple, and powerful plugin manager.
# Replaces manual git clone and sourcing.
# =============================================================================

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
mkdir -p "$(dirname $ZINIT_HOME)"
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

# Set preferred editor and essential paths
export EDITOR='micro'
export VISUAL="$EDITOR"
export PAGER='bat'

# Prepend local bin paths if they exist
[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"
[[ -d "${HOME}/.bin" ]] && export PATH="${HOME}/.bin:${PATH}"
[[ -d "${HOME}/bin" ]] && export PATH="${HOME}/bin:${PATH}"

# Locale settings for consistency
export LANG='C.UTF-8'
export LC_ALL='C.UTF-8'

# Set TERM for 256 color support
export TERM="xterm-256color"

# =============================================================================
# HISTORY
# =============================================================================

HISTFILE=${HOME}/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt extended_history        # Save timestamps and duration
setopt hist_expire_dups_first  # Expire duplicates first
setopt hist_ignore_all_dups    # Remove older duplicate entries
setopt hist_find_no_dups       # Don't show duplicates in search
setopt hist_reduce_blanks      # Remove extra blanks
setopt inc_append_history      # Write to history immediately
unsetopt share_history         # Avoids conflicts with multiple sessions

# =============================================================================
# SHELL OPTIONS (setopt)
# =============================================================================
# Tweaks for a better interactive experience.
# =============================================================================

setopt auto_cd                 # cd by typing directory name
setopt auto_pushd              # Keep a directory stack
setopt pushd_ignore_dups       # No duplicates in directory stack
setopt auto_remove_slash       # Remove trailing slashes
setopt extended_glob           # Use extended globbing features
setopt glob_dots               # Include dotfiles in globs
setopt no_beep                 # No audible bell
setopt numeric_glob_sort       # Sort filenames numerically
setopt rc_quotes               # Allow '' in variables
setopt mail_warning            # Don't check for mail
unsetopt flow_control          # Disable Ctrl-S/Ctrl-Q flow control

# =============================================================================
# ZINIT PLUGINS
# =============================================================================
# Load plugins asynchronously for a non-blocking prompt.
# =============================================================================

# --- Completions ---
zinit ice wait'0' lucid
zinit light zsh-users/zsh-completions

# --- Syntax Highlighting (Fast) ---
zinit ice wait'0' lucid
zinit light zdharma-continuum/fast-syntax-highlighting

# --- Auto Suggestions ---
zinit ice wait'0' lucid atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay"
zinit light zsh-users/zsh-autosuggestions

# --- Zoxide (Smarter cd) ---
zinit ice lucid wait'0'
zinit light ajeetdsouza/zoxide

# --- FZF (Fuzzy Finder) ---
zinit ice lucid wait'0'
zinit light junegunn/fzf

# --- Enhancd (Advanced cd) ---
zinit ice lucid wait'0'
zinit light babarot/enhancd

# --- Auto-pair ---
zinit ice lucid wait'0'
zinit light hl2b/zsh-autopair

# =============================================================================
# COMPLETION SYSTEM
# =============================================================================
# Optimized compinit call, cached for speed.
# =============================================================================
autoload -Uz compinit
if [[ -n ${XDG_CACHE_HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit -i -d "${XDG_CACHE_HOME}/.zcompdump"
else
  compinit -C -d "${XDG_CACHE_HOME}/.zcompdump"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"
zstyle ':completion:*:*:*:*:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'

# =============================================================================
# KEYBINDINGS
# =============================================================================
# Based on your .zshrc and .inputrc for a familiar feel.
# =============================================================================

bindkey -e                               # Emacs keybindings
bindkey ' ' magic-space                  # Perform history expansion on space
bindkey '^[[H' beginning-of-line         # Home
bindkey '^[[F' end-of-line               # End
bindkey '^[[3~' delete-char              # Delete
bindkey '^[[1;5C' forward-word           # Ctrl + Right Arrow
bindkey '^[[1;5D' backward-word          # Ctrl + Left Arrow

# History search bound to up/down arrows
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "${terminfo[kcuu1]}" history-beginning-search-backward-end
bindkey "${terminfo[kcud1]}" history-beginning-search-forward-end

# =============================================================================
# ALIASES
# =============================================================================
# A combination of your existing aliases and new ones for your tasks.
# =============================================================================

# --- General ---
alias ...='cd ../..'
alias ....='cd ../../..'
alias ..='cd ..'
alias bd='cd "$OLDPWD"' # Go back
alias c='clear'
alias h='history'
alias p='ps aux | grep'
alias ls='eza -F --color=auto --group-directories-first --icons=auto'
alias la='eza -AF --color=auto --group-directories-first --icons=auto'
alias ll='eza -AlF --color=auto --group-directories-first --icons=auto --no-time --no-git --smart-group --no-user --no-permissions'
alias lt='eza -ATF -L 3 --color=auto --group-directories-first --icons=auto'
alias gclone='command git clone --progress --filter=blob:none --depth 1'

# --- System & Cleaning ---
alias cleanup='find . -type f -name "*.DS_Store" -ls -delete'
alias apt-clean='sudo apt-get clean && sudo apt-get autoremove -y'

# --- Termux Specific ---
alias reload='termux-reload-settings'
alias battery='termux-battery-status'

# =============================================================================
# FUNCTIONS
# =============================================================================
# Custom functions for Revanced building and phone cleaning.
# =============================================================================

# --- Revanced Builder ---
# Downloads necessary tools and builds a Revanced APK.
build-revanced() {
  local YT_VERSION="19.25.35" # <-- CHANGE THIS to the recommended version
  local BUILD_DIR="$HOME/revanced-build"
  
  echo ">>> Setting up build environment in ${BUILD_DIR}..."
  mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

  # Download the latest CLI tools
  echo ">>> Downloading latest ReVanced tools..."
  curl -sLo rvx-cli.jar "https://github.com/inotia00/revanced-cli/releases/latest/download/revanced-cli.jar"
  curl -sLo rvx-patches.jar "https://github.com/inotia00/revanced-patches/releases/latest/download/revanced-patches.jar"
  curl -sLo rvx-integrations.apk "https://github.com/inotia00/revanced-integrations/releases/latest/download/revanced-integrations.apk"
  
  # Download YouTube APK
  echo ">>> Downloading YouTube v${YT_VERSION}..."
  # You may need to find the correct download link from a site like APKMirror
  # This is a placeholder command
  # apkmirror-dl --arm64 -v "${YT_VERSION}" "com.google.android.youtube"
  
  local APK_FILE="com.google.android.youtube_${YT_VERSION}.apk"
  
  if [[ ! -f "$APK_FILE" ]]; then
    echo "!!! YouTube APK not found. Please download it to ${BUILD_DIR} and name it ${APK_FILE}"
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

# --- Termux Cleaner ---
# Cleans package caches and removes junk within the Termux environment.
termux-clean() {
    echo "🧹 Cleaning Termux..."
    # Clean apt cache
    apt clean
    apt autoclean
    apt-get -y autoremove --purge
    # Remove empty directories in home
    find ~ -type d -empty -delete
    echo "✅ Termux cleanup complete."
}

# --- Phone Cache Cleaner (Root Required) ---
# Attempts to clear the cache for all installed Android apps.
phone-clean-cache() {
    if [[ $(id -u) -eq 0 ]]; then
        echo "🧹 Clearing all app caches (requires root)..."
        pm trim-caches 999G
        echo "✅ App caches trimmed."
    else
        echo "🛑 Root access is required to clear all app caches."
        echo "You can try running 'su' first."
    fi
}

# --- Find Large Files ---
# Interactively find and delete large files/folders to free up space.
find-large-files() {
    echo "🔍 Searching for largest files and directories in /sdcard..."
    du -ah /sdcard 2>/dev/null | sort -hr | head -n 20 | fzf --preview 'ls -ld {}' --header "Press Enter to delete, CTRL-C to cancel" | xargs -r rm -r
}

# =============================================================================
# PROMPT - POWERLEVEL10K
# =============================================================================
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# Your existing .p10k.zsh is sourced here.
# =============================================================================
zinit ice wait'0' lucid blockf atpull'zinit creinstall -q .'
zinit light romkatv/powerlevel10k
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# =============================================================================
# ZSH-DEFER
# =============================================================================
# Defers execution of commands until the shell is idle, speeding up startup.
# =============================================================================
zinit ice lucid wait'0'
zinit light romkatv/zsh-defer
zsh-defer source ~/.zshrc_deferred.zsh &>/dev/null
