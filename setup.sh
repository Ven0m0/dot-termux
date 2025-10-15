#!/data/data/com.termux/files/usr/bin/env bash
# Termux Ultra Setup: One-step environment configuration with Zinit and utilities
set -euo pipefail
IFS=$'\n\t'

# --- Configuration ---
declare -r REPO_URL="https://github.com/ven0m0/dot-termux.git"
declare -r REPO_PATH="$HOME/dot-termux"
declare -r LOG_FILE="$HOME/termux_setup_log.txt"
export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive

# Colors for output
declare -r RED="\033[0;31m" GREEN="\033[0;32m" BLUE="\033[0;34m" YELLOW="\033[0;33m" RESET="\033[0m"

# --- Self-bootstrapping Logic ---
if [[ "${BASH_SOURCE[0]:-}" != "$0" ]]; then
  echo -e "${BLUE}🚀 Setting up optimized Termux environment...${RESET}"
  pkg up -y && pkg i -y git curl zsh
  [[ -d "$REPO_PATH" ]] && { 
    echo -e "${GREEN}📁 Updating existing repository...${RESET}"
    (cd "$REPO_PATH" && git pull)
  } || {
    echo -e "${GREEN}📥 Cloning configuration repository...${RESET}"
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  }
  exec bash "$REPO_PATH/setup.sh" "$@"
  exit 0
else
  [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "-" ]] && 
    cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 || true
fi

# --- Helper Functions ---
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
print_step() { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1" | tee -a "$LOG_FILE"; }
check_internet() {
  print_step "Checking internet connection"
  ping -c 1 google.com >/dev/null 2>&1 || { echo "Error: No internet connection." >&2; exit 1; }
  log "Connection successful"
}
symlink_dotfile() {
  local src="$1" tgt="$2"
  mkdir -p "$(dirname "$tgt")"
  [[ -e "$tgt" || -L "$tgt" ]] && { log "Backing up '$tgt' to '${tgt}.bak'"; mv -f "$tgt" "${tgt}.bak"; }
  ln -sf "$src" "$tgt"
  log "Linked '$tgt' -> '$src'"
}

install_jetbrains_mono() {
  print_step "Installing JetBrains Mono font"
  local font_dir="$HOME/.termux" temp_zip url
  mkdir -p "$font_dir"
  url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
  
  # Try to get latest release URL
  local api_response
  api_response=$(curl -sL "https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest")
  if [[ "$api_response" =~ \"browser_download_url\":\ *\"(https://[^\"]+JetBrainsMono[^\"]+\.zip)\" ]]; then
    url="${BASH_REMATCH[1]}"
    log "Found JetBrains Mono release: $url"
  fi

  temp_zip=$(mktemp)
  curl -sL "$url" -o "$temp_zip" &&
    unzip -jo "$temp_zip" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$font_dir" >/dev/null 2>&1 &&
    mv -f "$font_dir/JetBrainsMono-Regular.ttf" "$font_dir/font.ttf" &&
    log "JetBrains Mono installed successfully" ||
    log "Font installation failed"
    
  termux-reload-settings >/dev/null 2>&1 || true
  rm -f "$temp_zip"
}

setup_zinit() {
  print_step "Setting up Zinit plugin manager"
  local zinit_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zinit"
  local zinit_git="$zinit_dir/zinit.git"
  
  [[ ! -d "$zinit_git" ]] && {
    mkdir -p "$zinit_dir"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$zinit_git" >/dev/null 2>&1 &&
      log "Zinit installed at $zinit_git" ||
      log "Zinit installation failed"
  } || {
    (cd "$zinit_git" && git pull >/dev/null 2>&1)
    log "Zinit updated"
  }

  # Create zinit config snippet
  local zshrc_zinit="$HOME/.zshrc.zinit"
  cat >"$zshrc_zinit" <<'EOF'
# Zinit plugin manager
typeset -gAH ZINIT
ZINIT[HOME_DIR]="${XDG_DATA_HOME:-$HOME/.local/share}/zinit"
ZINIT[BIN_DIR]="${ZINIT[HOME_DIR]}/zinit.git"
[[ -f "${ZINIT[BIN_DIR]}/zinit.zsh" ]] && source "${ZINIT[BIN_DIR]}/zinit.zsh"
if [[ ! -f "${ZINIT[BIN_DIR]}/zinit.zsh" ]]; then
  print -P "%F{blue}▓▒░ Installing Zinit...%f"
  command mkdir -p "${ZINIT[HOME_DIR]}"
  command git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "${ZINIT[BIN_DIR]}"
  source "${ZINIT[BIN_DIR]}/zinit.zsh"
fi

# Zinit annexes
zinit light-mode for zdharma-continuum/zinit-annex-bin-gem-node zdharma-continuum/zinit-annex-patch-dl zdharma-continuum/zinit-annex-rust

# OMZ libs
zinit lucid light-mode for OMZL::history.zsh OMZL::completion.zsh OMZL::key-bindings.zsh OMZL::clipboard.zsh OMZL::directories.zsh

# Syntax highlighting, completions, suggestions
zinit wait lucid light-mode for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zpcompinit; zpcdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf atpull'zinit creinstall -q .' \
    zsh-users/zsh-completions

# OMZ plugins
zinit wait lucid light-mode for \
  OMZP::colored-man-pages \
  OMZP::git \
  OMZP::command-not-found \
  OMZP::extract \
  OMZP::sudo

# FZF integration
[[ -d "$PREFIX/share/fzf" ]] && zinit wait lucid is-snippet for "$PREFIX/share/fzf/key-bindings.zsh" "$PREFIX/share/fzf/completion.zsh"

# Extras
zinit wait lucid light-mode for \
  MichaelAquilina/zsh-you-should-use \
  hlissner/zsh-autopair \
  agkozak/zsh-z

# Powerlevel10k
zinit ice depth=1
zinit light romkatv/powerlevel10k
EOF
  log "Zinit config created at $zshrc_zinit"
}

install_apk_sh() {
  print_step "Installing apk.sh to ~/bin"
  local apk_bin="$HOME/bin/apk.sh"
  mkdir -p "$HOME/bin"
  curl -fsSL https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh -o "$apk_bin" &&
    chmod +x "$apk_bin" &&
    log "apk.sh installed at $apk_bin" ||
    log "apk.sh installation failed"
}

setup_revanced_tools() {
  print_step "Setting up ReVanced tools"
  mkdir -p "$HOME/bin"
  
  # Link the already available revanced-helper.sh from repo
  if [[ -f "$REPO_PATH/bin/revanced-helper.sh" ]]; then
    ln -sf "$REPO_PATH/bin/revanced-helper.sh" "$HOME/bin/revanced-helper"
    chmod +x "$REPO_PATH/bin/revanced-helper.sh"
    log "ReVanced helper script linked"
  fi
  
  # Install additional tools in background
  local -a tools=(
    "Revancify-Xisr|https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh|revancify-xisr"
    "Simplify|https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh|simplify"
  )
  
  for tool_info in "${tools[@]}"; do
    IFS="|" read -r name url cmd_name <<<"$tool_info"
    
    (
      log "Installing $name..."
      case "$name" in
        "Revancify-Xisr")
          if ! curl -sL "$url" | bash >/dev/null 2>&1; then
            log "Warning: $name installation failed"
          elif [[ -d "$HOME/revancify-xisr" ]]; then
            ln -sf "$HOME/revancify-xisr/revancify.sh" "$HOME/bin/$cmd_name" 2>/dev/null
          fi
          ;;
        "Simplify")
          if curl -sL -o "$HOME/.Simplify.sh" "$url" 2>/dev/null; then
            ln -sf "$HOME/.Simplify.sh" "$HOME/bin/$cmd_name" 2>/dev/null
          else
            log "Warning: $name installation failed"
          fi
          ;;
      esac
      log "$name installation complete"
    ) &
  done
  
  { log "Installing X-CMD..."; curl -fsSL https://get.x-cmd.com | bash >/dev/null 2>&1 && log "X-CMD installed" || log "X-CMD installation failed"; } &
  { log "Installing SOAR..."; curl -fsSL https://soar.qaidvoid.dev/install.sh | sh >/dev/null 2>&1 && log "SOAR installed" || log "SOAR installation failed"; } &
  
  log "ReVanced tools installation started in background"
}

setup_adb_rish() {
  print_step "Setting up ADB and RISH"
  curl -s https://raw.githubusercontent.com/ConzZah/csb/main/csb | bash
  log "ADB and RISH setup complete"
}

create_welcome_message() {
  print_step "Creating welcome message"
  cat >"$HOME/.welcome.msg" <<EOF
${BLUE}╔════════════════════════════════════════════════╗${RESET}
${BLUE}║                                                ║${RESET}
${BLUE}║  Welcome to your optimized Termux environment  ║${RESET}
${BLUE}║                                                ║${RESET}
${BLUE}╚════════════════════════════════════════════════╝${RESET}

Available tools:
• ${GREEN}revancify-xisr${RESET} - Launch Revancify tool
• ${GREEN}simplify${RESET}       - Launch Simplify tool
• ${GREEN}rvx-builder${RESET}    - ReVanced builder
• ${GREEN}apk.sh${RESET}         - APK inspection tool
• ${GREEN}zoxide${RESET}         - Smart directory jumper
• ${GREEN}atuin${RESET}          - Better shell history

Type ${GREEN}help${RESET} for more information.
EOF
  log "Welcome message created"
}

optimize_zsh() {
  print_step "Optimizing Zsh performance"
  zsh -c '
    autoload -Uz zrecompile
    for f in ~/.zshrc ~/.zshenv ~/.zshrc.zinit ~/.p10k.zsh; do
      [[ -f "$f" ]] && zrecompile -pq "$f" >/dev/null 2>&1 || true
    done
  ' >/dev/null 2>&1 || true
  log "Zsh startup optimized"
}

# --- Main Setup Logic ---
main() {
  : >"$LOG_FILE"
  log "Starting Termux setup..."
  
  check_internet
  
  print_step "Setting up Termux storage"
  termux-setup-storage
  
  print_step "Adding repositories"
  pkg i -y tur-repo glibc-repo
  
  print_step "Updating package database"
  pkg up -y
  
  print_step "Upgrading critical packages"
  pkg i --only-upgrade apt bash coreutils openssl -y
  
  print_step "Installing essential packages"
  pkg i -y zsh git curl wget eza bat fzf micro zoxide atuin broot dust termux-api \
    openjdk-17 nano man figlet ncurses-utils build-essential bash-completion \
    zsh-completions aria2 android-tools ripgrep ripgrep-all libwebp optipng \
    pngquant jpegoptim gifsicle gifski aapt2 pkgtop parallel fd sd fclones \
    apksigner yazi
  
  install_jetbrains_mono
  
  print_step "Setting Zsh as default shell"
  [[ "$(basename "$SHELL")" != "zsh" ]] && {
    chsh -s zsh
    log "Zsh is now the default shell"
  } || log "Zsh is already the default shell"
  
  print_step "Managing dotfiles repository"
  if [[ -d "$REPO_PATH" ]]; then
    log "Updating existing repository"
    cd "$REPO_PATH" && git pull
  else
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
    log "Repository cloned"
  fi
  
  # Setup Zinit with plugins
  setup_zinit
  
  # Install apk.sh
  install_apk_sh
  
  print_step "Linking configuration files"
  local -a dotfiles=(
    "$REPO_PATH/.zshrc:$HOME/.zshrc"
    "$REPO_PATH/.zshenv:$HOME/.zshenv"
    "$REPO_PATH/.p10k.zsh:$HOME/.p10k.zsh"
    "$REPO_PATH/.nanorc:$HOME/.nanorc"
    "$REPO_PATH/.inputrc:$HOME/.inputrc"
    "$REPO_PATH/.ripgreprc:$HOME/.ripgreprc"
    "$REPO_PATH/.editorconfig:$HOME/.editorconfig"
    "$REPO_PATH/.curlrc:$HOME/.curlrc"
    "$REPO_PATH/.termux/termux.properties:$HOME/.termux/termux.properties"
    "$REPO_PATH/.config/bash/bash_functions.bash:$HOME/.config/bash/bash_functions.bash"
    "$REPO_PATH/.ignore:$HOME/.config/fd/ignore"
  )
  
  for item in "${dotfiles[@]}"; do
    IFS=":" read -r src tgt <<<"$item"
    symlink_dotfile "$src" "$tgt"
  done
  
  print_step "Linking utility scripts"
  mkdir -p "$HOME/bin"
  for script in "$REPO_PATH/bin"/*.sh; do
    [[ -f "$script" ]] || continue
    local script_name
    script_name=$(basename "$script" .sh)
    ln -sf "$script" "$HOME/bin/$script_name"
    chmod +x "$script"
    log "Linked $script_name"
  done
  
  setup_adb_rish
  setup_revanced_tools
  
  print_step "Creating cache directories"
  mkdir -p "$HOME/.zsh/cache" "${XDG_CACHE_HOME:-$HOME/.cache}"
  
  optimize_zsh
  create_welcome_message
  
  print_step "🚀 Setup Complete! 🚀"
  cat <<EOF
Please restart Termux for all changes to take effect.

📦 Installed components:
  • Zinit with turbo-mode plugins
  • OMZ libs and plugins
  • Fast syntax highlighting
  • Powerlevel10k theme
  • ReVanced toolchains
  • apk.sh APK inspector

⚙️ ReVanced tools are installing in background.
   Check $LOG_FILE for progress.
EOF

  log "Setup completed successfully at $(date +'%Y-%m-%d %H:%M:%S')"
}

main "$@"
