#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail # Exit on error, unset variable, or pipe failure

# --- Configuration ---
REPO_URL="https://github.com/ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"

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

symlink_dotfile() {
    local source_file="$1"
    local target_file="$2"

    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$target_file")"

    # Backup existing file before creating symlink
    if [[ -f "$target_file" || -L "$target_file" ]]; then
        echo "Backing up existing '$target_file' to '${target_file}.bak'"
        mv "$target_file" "${target_file}.bak"
    fi

    # Create the symlink
    ln -s "$source_file" "$target_file"
    echo "Linked '$target_file' -> '$source_file'"
}

# --- Main Setup Logic ---
main() {
  # 1. Initial Setup
  check_internet
  print_step "Setting up Termux storage..."
  termux-setup-storage

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

  # 5. Clone Dotfiles Repository
  print_step "Cloning your dotfiles repository from GitHub..."
  if [[ -d "$REPO_PATH" ]]; then
    echo "Repository already exists. Pulling latest changes..."
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
  
  # 7. Final Instructions
  print_step "🚀 Setup Complete! 🚀"
  echo "Please restart Termux for all changes to take effect."
  echo "After restarting, your prompt should be ready."
  echo "To update your dotfiles in the future, just run \`cd ~/dot-termux && git pull\`."
}

# Run the main function
main "$@"
