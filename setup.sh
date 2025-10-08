#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail # Strict mode for better error handling
LC_ALL=C

# --- Configuration ---
REPO_URL="https://github.com/ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"
LOG_FILE="$HOME/termux_setup_log.txt"

# --- Helper Functions ---
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

print_step() {
  printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$1" | tee -a "$LOG_FILE"
}

check_internet() {
  print_step "Checking internet connection..."
  if ! ping -c 1 google.com >/dev/null 2>&1; then
    echo "Error: No internet connection. Please connect and try again." >&2
    exit 1
  fi
  echo "Connection successful."
}

symlink_dotfile() {
    local source_file="$1"
    local target_file="$2"

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

# --- Main Setup Logic ---
main() {
  # Create log file
  : > "$LOG_FILE"
  log "Starting Termux setup..."

  # 1. Initial Setup
  check_internet
  print_step "Setting up Termux storage..."
  termux-setup-storage
  termux-change-repo
  
  # 2. Update and Upgrade Packages
  print_step "Updating and upgrading all packages..."
  pkg update -y && pkg upgrade -y
  apt dist-upgrade -y & apt full-upgrade -y
  dpkg --configure -a
  apt --fix-broken install -y && apt install --fix-missing -y

  # 3. Install All Essential Packages
  print_step "Installing essential packages..."
  pkg install -y \
    zsh git curl wget eza bat fzf micro \
    zoxide atuin broot dust termux-api openjdk-17 \
    nano man figlet ncurses-utils build-essential \
    bash-completion zsh-completions aria2 android-tools \
    ripgrep ripgrep-all libwebp optipng pngquant jpegoptim \
    gifsicle gifski aapt2 pkgtop parallel fd sd fclones \
    apksigner yazi

  # 4. Set Zsh as Default Shell
  print_step "Setting Zsh as the default shell..."
  if [[ "$(basename "$SHELL")" != "zsh" ]]; then
    chsh -s zsh
    log "Zsh is now the default shell."
  else
    log "Zsh is already the default shell."
  fi

  # 5. Clone Dotfiles Repository
  print_step "Cloning your dotfiles repository from GitHub..."
  if [[ -d "$REPO_PATH" ]]; then
    log "Repository already exists. Pulling latest changes..."
    cd "$REPO_PATH" && git pull
  else
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  fi

  # 6. Symlink Configuration Files
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
  
  # 7. Install Zinit Plugin Manager (optimized for speed)
  print_step "Setting up Zinit plugin manager..."
  ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
  if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$ZINIT_HOME"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME/zinit.git"
    log "Zinit installed successfully."
  else
    log "Zinit is already installed."
  fi
  
  # Log completion time
  log "Setup completed successfully at $(date +'%Y-%m-%d %H:%M:%S')"
}

# Run the main function
main "$@"
