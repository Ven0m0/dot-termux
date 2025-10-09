#!/data/data/com.termux/files/usr/bin/env bash
# Termux Ultra Setup: One-step environment configuration with Zinit and ReVanced tools

# --- Configuration ---
REPO_URL="https://github.com/ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"
LOG_FILE="$HOME/termux_setup_log.txt"
export LC_ALL=C LANG=C LANGUAGE=C

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# --- Self-bootstrapping Logic ---
if [[ "${BASH_SOURCE[0]:-}" != "$0" && -z "$REPO_PATH" ]]; then
  # Running via curl | bash, clone repo first
  echo -e "${BLUE}🚀 Setting up optimized Termux environment...${RESET}"
  # Update package repos and install essentials
  pkg update -y && pkg upgrade -y
  pkg in -y git curl zsh
  # Clone repo and execute local copy
  if [[ -d "$REPO_PATH" ]]; then
    echo -e "${GREEN}📁 Updating existing repository...${RESET}"
    cd "$REPO_PATH" && git pull
  else
    echo -e "${GREEN}📥 Cloning configuration repository...${RESET}"
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  fi
  
  exec bash "$REPO_PATH/setup.sh"
  exit 0
else
  # Running from file
  shopt -s nullglob globstar extglob
  [[ -n "${BASH_SOURCE[0]}" && "${BASH_SOURCE[0]}" != "-" ]] && 
    cd -P -- "$(cd -P -- "${BASH_SOURCE[0]%/*}" && echo "$PWD")" 2>/dev/null || true
fi

# --- Helper Functions ---
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
print_step() { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1" | tee -a "$LOG_FILE"; }

check_internet() {
  print_step "Checking internet connection..."
  if ! ping -c 1 google.com >/dev/null 2>&1; then
    echo "Error: No internet connection. Please connect and try again." >&2
    exit 1
  fi
  log "Connection successful."
}

symlink_dotfile() {
  local source_file="$1" target_file="$2"
  mkdir -p "$(dirname "$target_file")"
  [[ -f "$target_file" || -L "$target_file" ]] && {
    log "Backing up existing '$target_file' to '${target_file}.bak'"
    mv "$target_file" "${target_file}.bak"
  }
  ln -sf "$source_file" "$target_file"
  log "Linked '$target_file' -> '$source_file'"
}

install_jetbrains_mono() {
  print_step "Installing JetBrains Mono font"
  local font_dir="$HOME/.termux/font"
  mkdir -p "$font_dir"
  
  local temp_json temp_zip url version
  temp_json=$(mktemp)
  
  if curl -sL "https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest" -o "$temp_json"; then
    version=$(grep -o '"tag_name": *"[^"]*"' "$temp_json" | cut -d'"' -f4)
    url=$(grep -o '"browser_download_url": *"[^"]*"' "$temp_json" | head -1 | cut -d'"' -f4)
    log "Found JetBrains Mono version: $version"
  else
    url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
    log "Using fallback version v2.304"
  fi
  
  temp_zip=$(mktemp)
  if curl -sL "$url" -o "$temp_zip" &&
     unzip -j "$temp_zip" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$font_dir" >/dev/null 2>&1 &&
     mv "$font_dir/JetBrainsMono-Regular.ttf" "$font_dir/font.ttf"; then
    log "JetBrains Mono installed successfully"
    termux-reload-settings >/dev/null 2>&1 || true
  else
    log "Font installation failed"
  fi
  
  rm -f "$temp_json" "$temp_zip"
}

setup_revanced_tools() {
  print_step "Setting up ReVanced tools (background process)"
  mkdir -p "$HOME/bin"
  
  local -a tools=(
    "Revancify-Xisr|https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh|revancify-xisr"
    "Simplify|https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh|simplify"
    "RVX-Builder|https://raw.githubusercontent.com/inotia00/rvx-builder/revanced-extended/android-interface.sh|rvx-builder"
  )
  
  for tool_info in "${tools[@]}"; do
    IFS="|" read -r name url cmd_name <<< "$tool_info"
    
    (
      log "Installing $name..."
      case "$name" in
        "Revancify-Xisr")
          curl -sL "$url" | bash >/dev/null 2>&1
          [[ -d "$HOME/revancify-xisr" ]] && 
            ln -sf "$HOME/revancify-xisr/revancify.sh" "$HOME/bin/$cmd_name" >/dev/null 2>&1 || true
          ;;
        "Simplify")
          curl -sL -o "$HOME/.Simplify.sh" "$url" &&
            ln -sf "$HOME/.Simplify.sh" "$HOME/bin/$cmd_name" >/dev/null 2>&1 || true
          ;;
        "RVX-Builder")
          curl -sL -o "$HOME/bin/rvx-builder.sh" "$url" &&
            chmod +x "$HOME/bin/rvx-builder.sh" &&
            ln -sf "$HOME/bin/rvx-builder.sh" "$HOME/bin/$cmd_name" >/dev/null 2>&1 || true
          ;;
      esac
      log "$name installation complete"
    ) &
  done
  
  { log "Installing X-CMD..."; curl -fsSL https://get.x-cmd.com | bash >/dev/null 2>&1; log "X-CMD installation complete"; } &
  { log "Installing SOAR..."; curl -fsSL https://soar.qaidvoid.dev/install.sh | sh >/dev/null 2>&1; log "SOAR installation complete"; } &
  
  log "ReVanced tools installation started in background"
}

setup_adb_rish() {
  print_step "Setting up ADB and RISH"
  curl -s https://raw.githubusercontent.com/ConzZah/csb/main/csb | bash
  log "ADB and RISH setup complete"
}

create_welcome_message() {
  print_step "Creating welcome message"
  cat > "$HOME/.welcome.msg" <<EOF
${BLUE}╔════════════════════════════════════════════════╗${RESET}
${BLUE}║                                                ║${RESET}
${BLUE}║  Welcome to your optimized Termux environment  ║${RESET}
${BLUE}║                                                ║${RESET}
${BLUE}╚════════════════════════════════════════════════╝${RESET}

Available tools:
• ${GREEN}revancify-xisr${RESET} - Launch Revancify tool
• ${GREEN}simplify${RESET}       - Launch Simplify tool
• ${GREEN}rvx-builder${RESET}    - ReVanced builder
• ${GREEN}zoxide${RESET}         - Smart directory jumper
• ${GREEN}atuin${RESET}          - Better shell history

Type ${GREEN}help${RESET} for more information.
EOF
  log "Welcome message created"
}

optimize_zsh() {
  print_step "Optimizing Zsh performance"
  zsh -c 'zmodload zsh/zcompiler; zcompile ~/.zshrc; zcompile ~/.zshenv'
  log "Zsh startup optimized"
}

# --- Main Setup Logic ---
main() {
  # Initialize log
  : > "$LOG_FILE"
  log "Starting Termux setup..."
  
  # Core setup phases
  check_internet
  
  print_step "Setting up Termux storage..."
  termux-setup-storage
  
  print_step "Adding repositories..."
  pkg in -y tur-repo glibc-repo
  
  print_step "Updating package database..."
  pkg update -y && pkg upgrade -y
  
  print_step "Upgrading critical packages..."
  pkg in --only-upgrade apt bash coreutils openssl -y
  
  print_step "Installing essential packages..."
  pkg in -y \
    zsh git curl wget eza bat fzf micro \
    zoxide atuin broot dust termux-api openjdk-17 \
    nano man figlet ncurses-utils build-essential \
    bash-completion zsh-completions aria2 android-tools \
    ripgrep ripgrep-all libwebp optipng pngquant jpegoptim \
    gifsicle gifski aapt2 pkgtop parallel fd sd fclones \
    apksigner yazi
  
  # Install JetBrains Mono font
  install_jetbrains_mono
  
  print_step "Setting Zsh as default shell..."
  [[ "$(basename "$SHELL")" != "zsh" ]] && {
    chsh -s zsh
    log "Zsh is now the default shell."
  } || log "Zsh is already the default shell."
  
  print_step "Managing dotfiles repository..."
  if [[ -d "$REPO_PATH" ]]; then
    log "Updating existing repository..."
    cd "$REPO_PATH" && git pull
  else
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  fi
  
  print_step "Setting up Zinit plugin manager..."
  ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
  if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$ZINIT_HOME"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME/zinit.git"
    log "Zinit installed successfully."
  else
    log "Zinit is already installed."
  fi
  
  print_step "Linking configuration files..."
  symlink_dotfile "$REPO_PATH/.zshrc" "$HOME/.zshrc"
  symlink_dotfile "$REPO_PATH/.zshenv" "$HOME/.zshenv"
  symlink_dotfile "$REPO_PATH/.p10k.zsh" "$HOME/.p10k.zsh"
  symlink_dotfile "$REPO_PATH/.nanorc" "$HOME/.nanorc"
  symlink_dotfile "$REPO_PATH/.inputrc" "$HOME/.inputrc"
  symlink_dotfile "$REPO_PATH/.ripgreprc" "$HOME/.ripgreprc"
  symlink_dotfile "$REPO_PATH/.editorconfig" "$HOME/.editorconfig"
  symlink_dotfile "$REPO_PATH/.curlrc" "$HOME/.curlrc"
  symlink_dotfile "$REPO_PATH/.termux/termux.properties" "$HOME/.termux/termux.properties"
  symlink_dotfile "$REPO_PATH/.config/bash/bash_functions.bash" "$HOME/.config/bash/bash_functions.bash"
  symlink_dotfile "$REPO_PATH/.ignore" "$HOME/.config/fd/ignore"
  
  # Setup advanced functionality
  setup_adb_rish
  setup_revanced_tools
  
  print_step "Creating cache directories..."
  mkdir -p "$HOME/.zsh/cache" "${XDG_CACHE_HOME:-$HOME/.cache}"
  
  # Final optimizations
  optimize_zsh
  create_welcome_message
  
  # Complete
  print_step "🚀 Setup Complete! 🚀"
  cat <<EOF
Please restart Termux for all changes to take effect.
After restarting, your prompt will be ready with Zinit and PowerLevel10k.

ReVanced tools are installing in the background. Check $LOG_FILE for progress.
Available tools after installation completes:
 - revancify-xisr: Revancify fork by Xisrr1
 - simplify: Simplify by arghya339
 - rvx-builder: RVX Builder by inotia00
 - X-CMD and SOAR package managers

ADB and RISH have been set up via CSB.
EOF
  
  log "Setup completed successfully at $(date +'%Y-%m-%d %H:%M:%S')"
}

# Execute main function
main "$@"
