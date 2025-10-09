#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail 

# --- Configuration ---
REPO_URL="https://github.com/ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"
LOG_FILE="$HOME/termux_setup_log.txt"
LC_ALL=C LANG=C LANGUAGE=C
shopt -s nullglob globstar extglob
cd -P -- "$(cd -P -- "${BASH_SOURCE[0]%/*}" && echo "$PWD")" || exit 1

# --- Helper Functions ---
log(){ echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
print_step(){ printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1" | tee -a "$LOG_FILE"; }
check_internet(){
  print_step "Checking internet connection..."
  if ! ping -c 1 google.com >/dev/null 2>&1; then
    echo "Error: No internet connection. Please connect and try again." >&2; exit 1
  fi
  log "Connection successful."
}
symlink_dotfile(){
  local source_file="$1" target_file="$2"
  # Create parent directory if it doesn't exist
  mkdir -p "$(dirname "$target_file")"
  # Backup existing file before creating symlink
  if [[ -f "$target_file" || -L "$target_file" ]]; then
    log "Backing up existing '$target_file' to '${target_file}.bak'"
    mv "$target_file" "${target_file}.bak"
  fi
  # Create the symlink
  ln -sf "$source_file" "$target_file"
  log "Linked '$target_file' -> '$source_file'"
}

# Install ReVanced tools in background (non-blocking)
setup_revanced_tools(){
  print_step "Setting up ReVanced tools (background process)"
  # Create directories
  mkdir -p "$HOME/bin"
  # Tool definitions - uses arrays for cleaner code
  local -a tools=(
    "Revancify-Xisr|https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh|revancify-xisr"
    "Simplify|https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh|simplify"
    "RVX-Builder|https://raw.githubusercontent.com/inotia00/rvx-builder/revanced-extended/android-interface.sh|rvx-builder"
  )
  
  # Process each tool in background
  for tool_info in "${tools[@]}"; do
    IFS="|" read -r name url cmd_name <<< "$tool_info"
    # Install in background
    (
      log "Installing $name..."
      case "$name" in
        "Revancify-Xisr")
          curl -sL "$url" | bash >/dev/null 2>&1
          if [[ -d "$HOME/revancify-xisr" ]]; then
            ln -sf "$HOME/revancify-xisr/revancify.sh" "$HOME/bin/$cmd_name" 2>/dev/null || true
          fi
          ;;
        "Simplify")
          curl -sL -o "$HOME/.Simplify.sh" "$url"
          ln -sf "$HOME/.Simplify.sh" "$HOME/bin/$cmd_name" 2>/dev/null || true
          ;;
        "RVX-Builder")
          curl -sL -o "rvx-builder.sh" "$url"
          chmod +x "rvx-builder.sh"
          ;;
      esac
      log "$name installation complete"
    ) &
  done
  
  # Install X-CMD in background
  (
    log "Installing X-CMD..."
    curl -fsSL https://get.x-cmd.com | bash >/dev/null 2>&1
    log "X-CMD installation complete"
  ) &
  # Install SOAR in background
  (
    log "Installing SOAR..."
    curl -fsSL https://soar.qaidvoid.dev/install.sh | sh >/dev/null 2>&1
    log "SOAR installation complete"
  ) &
  log "ReVanced tools installation started in background"
  log "Tools will be available in $HOME/bin after installation completes"
}

# Setup ADB and RISH with CSB
setup_adb_rish(){
  print_step "Setting up ADB and RISH"
  # Install CSB (ConzZah's Setup)
  curl -s https://raw.githubusercontent.com/ConzZah/csb/main/csb | bash
  log "ADB and RISH setup complete"
}

# --- Main Setup Logic ---
main(){
  # Create log file
  : > "$LOG_FILE"
  log "Starting Termux setup..."
  # 1. Initial Setup
  check_internet
  print_step "Setting up Termux storage..."
  termux-setup-storage
  # 2. Add Repositories
  print_step "Adding additional repositories..."
  pkg in -y tur-repo glibc-repo
  # 3. Update and Upgrade Packages
  print_step "Updating and upgrading all packages..."
  pkg update -y && pkg upgrade -y
  # 4. Upgrade critical packages first
  print_step "Upgrading critical packages..."
  pkg in --only-upgrade apt bash coreutils openssl -y
  # 5. Install All Essential Packages - Enhanced list
  print_step "Installing essential packages..."
  pkg in -y \
    zsh git curl wget eza bat fzf micro \
    zoxide atuin broot dust termux-api openjdk-17 \
    nano man figlet ncurses-utils build-essential \
    bash-completion zsh-completions aria2 android-tools \
    ripgrep ripgrep-all libwebp optipng pngquant jpegoptim \
    gifsicle gifski aapt2 pkgtop parallel fd sd fclones \
    apksigner yazi
  # 6. Set Zsh as Default Shell
  print_step "Setting Zsh as the default shell..."
  if [[ "$(basename "$SHELL")" != "zsh" ]]; then
    chsh -s zsh
    log "Zsh is now the default shell."
  else
    log "Zsh is already the default shell."
  fi
  # 7. Clone Dotfiles Repository
  print_step "Cloning your dotfiles repository from GitHub..."
  if [[ -d "$REPO_PATH" ]]; then
    log "Repository already exists. Pulling latest changes..."
    cd "$REPO_PATH" && git pull
  else
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  fi
  # 8. Install Zinit Plugin Manager
  print_step "Setting up Zinit plugin manager..."
  ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
  if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$ZINIT_HOME"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME/zinit.git"
    log "Zinit installed successfully."
  else
    log "Zinit is already installed."
  fi
  # 9. Symlink Configuration Files
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
  # 10. Setup ADB and RISH
  setup_adb_rish
  # 11. Create Zsh Cache Directory
  print_step "Creating Zsh cache directory..."
  mkdir -p "$HOME/.zsh/cache"
  mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
  # 12. Setup ReVanced tools in the background
  setup_revanced_tools
  # 13. Final Instructions
  print_step "🚀 Setup Complete! 🚀"
  echo "Please restart Termux for all changes to take effect."
  echo "After restarting, your prompt should be ready with Zinit and PowerLevel10k."
  echo ""
  echo "ReVanced tools are installing in the background. Check $LOG_FILE for progress."
  echo "Available tools after installation completes:"
  echo " - Revancify-Xisr: run 'revancify-xisr'"
  echo " - Simplify: run 'simplify'"
  echo " - RVX Builder: run 'rvx-builder'"
  echo " - X-CMD: available in path"
  echo " - SOAR: available in path"
  echo ""
  echo "ADB and RISH have been set up via CSB."
  # Log completion time
  log "Setup completed successfully at $(date +'%Y-%m-%d %H:%M:%S')"
}
# Run the main function
main "$@"
