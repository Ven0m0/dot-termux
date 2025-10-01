#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail # Exit on error, unset variable, or pipe failure

# --- Helper Functions ---
print_step() {
  printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1"
}

check_internet() {
  print_step "Checking internet connection..."
  if ! ping -c 1 google.com >/dev/null 2>&1; then
    echo "Error: No internet connection. Please connect and try again." >&2
    exit 1
  fi
  echo "Connection successful."
}

backup_file() {
  local file="$1"
  if [[ -f "$file" || -L "$file" ]]; then
    local backup_file="${file}.bak.$(date +%F-%T)"
    echo "Backing up existing '$file' to '$backup_file'"
    mv "$file" "$backup_file"
  fi
}

# --- Main Setup Logic ---
main() {
  # 1. Initial Setup
  check_internet
  print_step "Setting up Termux storage and vibrating on errors..."
  termux-setup-storage
  # Set bell-character to vibrate for feedback on errors
  mkdir -p "$HOME/.termux"
  echo "bell-character = vibrate" > "$HOME/.termux/termux.properties"

  # 2. Update and Upgrade Packages
  print_step "Updating and upgrading all packages..."
  pkg update -y && pkg upgrade -y

  # 3. Install All Essential Packages from Your Configs
  print_step "Installing essential packages..."
  pkg install -y \
    zsh git curl wget eza bat fzf micro ripgrep \
    zoxide atuin broot dust termux-api openjdk-17 \
    nano man figlet ncurses-utils

  # 4. Set Zsh as Default Shell
  print_step "Setting Zsh as the default shell..."
  if [[ "$(basename "$SHELL")" != "zsh" ]]; then
    chsh -s zsh
    echo "Zsh is now the default shell."
  else
    echo "Zsh is already the default shell."
  fi

  # 5. Backup Existing Configs
  print_step "Backing up existing configuration files..."
  backup_file "$HOME/.zshrc"
  backup_file "$HOME/.zshenv"
  backup_file "$HOME/.p10k.zsh"
  backup_file "$HOME/.nanorc"
  backup_file "$HOME/.inputrc"
  backup_file "$HOME/.ripgreprc"

  # 6. Create Configuration Files
  print_step "Creating optimized dotfiles..."

  # --- .zshenv ---
  cat > "$HOME/.zshenv" <<'EOF'
#!/bin/zsh
export SHELL_SESSIONS_DISABLE=1
skip_global_compinit=1
setopt no_global_rcs
EOF
  echo "Created .zshenv"

  # --- .zshrc ---
  # This is the highly optimized zshrc from our previous discussion
  cat > "$HOME/.zshrc" <<'EOF'
# =============================================================================
# ~/.zshrc - v3 Ultimate Termux Edition
# =============================================================================
# Focus: Blazing speed, superior completions (fzf-tab), and a powerful,
# user-friendly toolset tailored for development and system management.
# =============================================================================

# Defer the Zsh compiler for a faster startup
zmodload zsh/zcompiler
autoload -Uz zrecompile
zrecompile -q -p -i

# =============================================================================
# ZINIT PLUGIN MANAGER
# =============================================================================
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit"
if [[ ! -f $ZINIT_HOME/zinit.git/zinit.sh ]]; then
    command git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME/zinit.git"
fi
source "$ZINIT_HOME/zinit.git/zinit.sh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zinit light-mode for \
    zdharma-continuum/z-a-rust \
    zdharma-continuum/z-a-bin-gem-node

# =============================================================================
# CORE CONFIG & ENVIRONMENT
# =============================================================================
export EDITOR='micro' VISUAL="$EDITOR" PAGER='bat'
export LANG='C.UTF-8' LC_ALL='C.UTF-8'
export TERM="xterm-256color"

# =============================================================================
# ATUIN - REVOLUTIONIZED SHELL HISTORY
# =============================================================================
zinit ice as'program' from'gh-r'
zinit light atuinsh/atuin
eval "$(atuin init zsh --disable-up-arrow)" # Disable up-arrow to use history-substring-search

# =============================================================================
# ZINIT PLUGINS & TOOLS
# =============================================================================
zinit ice lucid wait'0' blockf atpull'zinit creinstall -q .'
zinit light romkatv/powerlevel10k

zinit ice lucid wait'0'
zinit light junegunn/fzf

zinit ice lucid wait'0'
zinit light Aloxaf/fzf-tab

zinit ice lucid wait'0'
zinit light zdharma-continuum/fast-syntax-highlighting

zinit ice lucid wait'0' atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay"
zinit light zsh-users/zsh-autosuggestions

zinit ice lucid wait'0'
zinit light zsh-users/zsh-history-substring-search

zinit ice lucid wait'0'
zinit light ajeetdsouza/zoxide

zinit ice lucid wait'0'
zinit light hl2b/zsh-autopair

zinit ice lucid wait'0'
zinit light zsh-users/zsh-completions

# =============================================================================
# COMPLETION SYSTEM
# =============================================================================
autoload -Uz compinit
compinit -C -d "${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump"
zstyle ':completion:*' menu select use-cache on cache-path "$HOME/.zsh/cache"
zstyle ':completion:*:*:*:*:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always $realpath'

# =============================================================================
# ALIASES & FUNCTIONS
# =============================================================================
alias ...='cd ../..'
alias ..='cd ..'
alias ls='eza --icons -F --color=auto --group-directories-first'
alias ll='eza -al --icons -F --color=auto --group-directories-first --git'
alias lt='eza --tree --level=3 --icons -F --color=auto'

build-revanced() {
  command -v java >/dev/null || { echo "Error: openjdk-17 is not installed." >&2; return 1; }
  local YT_VERSION="19.25.35" # IMPORTANT: Update to the version recommended by ReVanced
  local BUILD_DIR="$HOME/revanced-build"
  mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR" || return
  echo ">>> Downloading ReVanced tools..."
  curl -# -L -o rvx-cli.jar "https://github.com/inotia00/revanced-cli/releases/latest/download/revanced-cli.jar"
  curl -# -L -o rvx-patches.jar "https://github.com/inotia00/revanced-patches/releases/latest/download/revanced-patches.jar"
  curl -# -L -o rvx-integrations.apk "https://github.com/inotia00/revanced-integrations/releases/latest/download/revanced-integrations.apk"
  local APK_FILE="youtube-v${YT_VERSION}.apk"
  [[ -f "$APK_FILE" ]] || { echo "!!! YouTube APK not found. Download to ${BUILD_DIR} and name it ${APK_FILE}" >&2; return 1; }
  echo ">>> Starting patch process..."
  java -jar rvx-cli.jar patch --patch-bundle rvx-patches.jar --merge-apk rvx-integrations.apk --out "revanced-yt-${YT_VERSION}.apk" "$APK_FILE"
  echo ">>> Build complete! Find your APK in ${BUILD_DIR}"
}

termux-clean() {
    echo "🧹 Cleaning Termux..."
    pkg clean && pkg autoclean
    find ~ -type d -empty -delete
    echo "✅ Termux cleanup complete."
}
EOF
  echo "Created .zshrc"

  # --- .p10k.zsh ---
  # This uses your existing Powerlevel10k configuration
  cp "$HOME/ven0m0/dot-termux/dot-termux-cd950e11a07ea96431b97ac9c43e848779ae1818/.p10k.zsh" "$HOME/.p10k.zsh"
  echo "Copied .p10k.zsh"
  fc-cache -fv
  # --- Other Dotfiles ---
  mkdir -p "$HOME/.config/fd"
  cp "$HOME/ven0m0/dot-termux/dot-termux-cd950e11a07ea96431b97ac9c43e848779ae1818/.nanorc" "$HOME/.nanorc"
  echo "Copied .nanorc"
  cp "$HOME/ven0m0/dot-termux/dot-termux-cd950e11a07ea96431b97ac9c43e848779ae1818/.inputrc" "$HOME/.inputrc"
  echo "Copied .inputrc"
  cp "$HOME/ven0m0/dot-termux/dot-termux-cd950e11a07ea96431b97ac9c43e848779ae1818/.ripgreprc" "$HOME/.ripgreprc"
  echo "Copied .ripgreprc"
  cp "$HOME/ven0m0/dot-termux/dot-termux-cd950e11a07ea96431b97ac9c43e848779ae1818/.editorconfig" "$HOME/.editorconfig"
  echo "Copied .editorconfig"
  cp "$HOME/ven0m0/dot-termux/dot-termux-cd950e11a07ea96431b97ac9c43e848779ae1818/.curlrc" "$HOME/.curlrc"
  echo "Copied .curlrc"
  cp "$HOME/ven0m0/dot-termux/dot-termux-cd950e11a07ea96431b97ac9c43e848779ae1818/.ignore" "$HOME/.config/fd/ignore"
  echo "Copied fd ignore file"
  cat > "$HOME/.termux/termux.properties" <<'EOF'
use-black-ui=true
bell-character=ignore
allow-external-apps = true
disable-terminal-session-change-toast = true
volume-keys = volume
terminal-cursor-blink-rate = 0
terminal-cursor-style = bar
enforce-char-based-input = true
back-key=escape
extra-keys = [['ESC','|','/','PGUP','HOME','UP','END'],['TAB','CTRL','ALT','PGDN','LEFT','DOWN','RIGHT']]
EOF
  echo "Created termux.properties"

  # 7. Final Instructions
  print_step "🚀 Setup Complete! 🚀"
  echo "Please restart Termux for all changes to take effect."
  echo "After restarting, your prompt should be ready."
  echo "If it asks, run \`p10k configure\` to finalize the prompt setup."
  echo "You can now use the new functions: \`build-revanced\`, \`termux-clean\`."
}

# Run the main function
main "$@"
