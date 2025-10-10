#!/data/data/com.termux/files/usr/bin/env bash
# Termux Ultra Setup: One-step environment configuration with Zinit and ReVanced tools

# --- Configuration ---
declare -r REPO_URL="https://github.com/ven0m0/dot-termux.git"
declare -r REPO_PATH="$HOME/dot-termux"
declare -r LOG_FILE="$HOME/termux_setup_log.txt"
declare -r ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
export LC_ALL=C LANG=C LANGUAGE=C
export DEBIAN_FRONTEND=noninteractive

# Colors for output
declare -r RED="\033[0;31m"
declare -r GREEN="\033[0;32m"
declare -r BLUE="\033[0;34m"
declare -r YELLOW="\033[0;33m"
declare -r RESET="\033[0m"

# --- Self-bootstrapping Logic ---
# Detect if running via 'curl | bash'
if [[ "${BASH_SOURCE[0]:-}" != "$0" ]]; then
  echo -e "${BLUE}🚀 Setting up optimized Termux environment...${RESET}"

  pkg update -y && pkg upgrade -y
  pkg install -y git curl zsh

  if [[ -d "$REPO_PATH" ]]; then
    echo -e "${GREEN}📁 Updating existing repository...${RESET}"
    (cd "$REPO_PATH" && git pull)
  else
    echo -e "${GREEN}📥 Cloning configuration repository...${RESET}"
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  fi

  # Execute the local copy and exit
  exec bash "$REPO_PATH/setup.sh" "$@"
  exit 0
else
  # Ensure we are in the script's directory when run from a file
  if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "-" ]]; then
    cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null || true
  fi
fi

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
  log "Connection successful."
}

symlink_dotfile() {
  local src="$1" tgt="$2"
  mkdir -p "$(dirname "$tgt")"
  if [[ -e "$tgt" || -L "$tgt" ]]; then
    log "Backing up existing '$tgt' to '${tgt}.bak'"
    mv -f "$tgt" "${tgt}.bak"
  fi
  ln -sf "$src" "$tgt"
  log "Linked '$tgt' -> '$src'"
}

install_jetbrains_mono() {
  print_step "Installing JetBrains Mono font"
  local font_dir="$HOME/.termux"
  mkdir -p "$font_dir"

  local api_response url
  api_response=$(curl -sL "https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest")
  
  if [[ $api_response =~ \"browser_download_url\":[[:space:]]*\"(https://[^\"]+JetBrainsMono[^\"]+\.zip)\" ]]; then
    url="${BASH_REMATCH[1]}"
    log "Found JetBrains Mono release: $url"
  else
    log "Could not fetch latest release URL. Using fallback."
    url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
  fi

  local temp_zip
  temp_zip=$(mktemp)
  if curl -sL "$url" -o "$temp_zip"; then
    unzip -jo "$temp_zip" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$font_dir" >/dev/null 2>&1 &&
      mv -f "$font_dir/JetBrainsMono-Regular.ttf" "$font_dir/font.ttf"
    log "JetBrains Mono installed successfully."
    termux-reload-settings >/dev/null 2>&1 || true
  else
    log "Font installation failed."
  fi
  rm -f "$temp_zip"
}

setup_zinit() {
  print_step "Setting up Zinit plugin manager..."
  
  local zinit_dir="${ZINIT_HOME%/*}"
  if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$zinit_dir"
    log "Cloning Zinit from zdharma-continuum/zinit..."
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" >/dev/null 2>&1
    log "Zinit installed successfully at $ZINIT_HOME"
  else
    log "Zinit already installed. Updating..."
    (cd "$ZINIT_HOME" && git pull >/dev/null 2>&1) || true
  fi
  
  # Create zinit loader snippet for .zshrc if not exists
  local zshrc_zinit_section="$HOME/.zshrc.zinit"
  if [[ ! -f "$zshrc_zinit_section" ]]; then
    log "Creating Zinit configuration snippet..."
    cat > "$zshrc_zinit_section" <<'ZINIT_EOF'
# --- Zinit Plugin Manager ---
typeset -gAH ZINIT
ZINIT[HOME_DIR]="${XDG_DATA_HOME:-$HOME/.local/share}/zinit"
ZINIT[BIN_DIR]="${ZINIT[HOME_DIR]}/zinit.git"

# Initialize Zinit
[[ -f "${ZINIT[BIN_DIR]}/zinit.zsh" ]] && source "${ZINIT[BIN_DIR]}/zinit.zsh"

# Auto-install Zinit if missing
if [[ ! -f "${ZINIT[BIN_DIR]}/zinit.zsh" ]]; then
  print -P "%F{blue}▓▒░ Installing Zinit plugin manager...%f"
  command mkdir -p "${ZINIT[HOME_DIR]}" && command chmod g-rwX "${ZINIT[HOME_DIR]}"
  command git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "${ZINIT[BIN_DIR]}" && \
    print -P "%F{green}▓▒░ Zinit installation successful.%f" || \
    print -P "%F{red}▓▒░ Zinit installation failed.%f"
  source "${ZINIT[BIN_DIR]}/zinit.zsh"
fi

# Zinit annexes (extensions)
zinit light-mode for \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-rust

# Oh-My-Zsh libs (minimal, fast)
zinit lucid light-mode for \
  OMZL::history.zsh \
  OMZL::completion.zsh \
  OMZL::key-bindings.zsh \
  OMZL::clipboard.zsh \
  OMZL::directories.zsh

# Syntax highlighting, completions, auto-suggestions
zinit wait lucid light-mode for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zpcompinit; zpcdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf atpull'zinit creinstall -q .' \
    zsh-users/zsh-completions

# Oh-My-Zsh plugins
zinit wait lucid light-mode for \
  OMZP::colored-man-pages \
  OMZP::git \
  OMZP::command-not-found \
  OMZP::extract \
  OMZP::sudo

# FZF integration (Termux paths)
if [[ -d "$PREFIX/share/fzf" ]]; then
  zinit wait lucid is-snippet for \
    "$PREFIX/share/fzf/key-bindings.zsh" \
    "$PREFIX/share/fzf/completion.zsh"
fi

# Additional productivity plugins
zinit wait lucid light-mode for \
  MichaelAquilina/zsh-you-should-use \
  hlissner/zsh-autopair \
  agkozak/zsh-z

# Powerlevel10k theme (instant prompt supported)
zinit ice depth=1
zinit light romkatv/powerlevel10k
ZINIT_EOF
    log "Zinit configuration created at $zshrc_zinit_section"
  fi
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
    IFS="|" read -r name url cmd_name <<<"$tool_info"

    (
      log "Installing $name..."
      case "$name" in
      "Revancify-Xisr")
        curl -sL "$url" | bash >/dev/null 2>&1
        [[ -d "$HOME/revancify-xisr" ]] && ln -sf "$HOME/revancify-xisr/revancify.sh" "$HOME/bin/$cmd_name"
        ;;
      "Simplify")
        curl -sL -o "$HOME/.Simplify.sh" "$url" && ln -sf "$HOME/.Simplify.sh" "$HOME/bin/$cmd_name"
        ;;
      "RVX-Builder")
        curl -sL -o "$HOME/bin/rvx-builder.sh" "$url" && chmod +x "$HOME/bin/rvx-builder.sh" && ln -sf "$HOME/bin/rvx-builder.sh" "$HOME/bin/$cmd_name"
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
• ${GREEN}zoxide${RESET}         - Smart directory jumper
• ${GREEN}atuin${RESET}          - Better shell history

Type ${GREEN}help${RESET} for more information.
EOF
  log "Welcome message created"
}

optimize_zsh() {
  print_step "Optimizing Zsh performance"
  zsh -c 'autoload -U zrecompile; zrecompile -pq ~/.zshrc; zrecompile -pq ~/.zshenv' >/dev/null 2>&1 || true
  log "Zsh startup optimized"
}

# --- Main Setup Logic ---
main() {
  # Initialize log
  : > "$LOG_FILE"
  log "Starting Termux setup..."

  check_internet
  print_step "Setting up Termux storage..."
  termux-setup-storage

  print_step "Adding repositories..."
  pkg install -y tur-repo glibc-repo

  print_step "Updating package database..."
  pkg update -y && pkg upgrade -y

  print_step "Upgrading critical packages..."
  pkg install --only-upgrade -y apt bash coreutils openssl

  print_step "Installing essential packages..."
  pkg install -y \
    zsh git curl wget eza bat fzf micro \
    zoxide atuin broot dust termux-api openjdk-17 \
    nano man figlet ncurses-utils build-essential \
    bash-completion zsh-completions aria2 android-tools \
    ripgrep ripgrep-all libwebp optipng pngquant jpegoptim \
    gifsicle gifski aapt2 pkgtop parallel fd sd fclones \
    apksigner yazi

  install_jetbrains_mono

  print_step "Setting Zsh as default shell..."
  if [[ "$(basename "$SHELL")" != "zsh" ]]; then
    chsh -s zsh
    log "Zsh is now the default shell."
  else
    log "Zsh is already the default shell."
  fi

  print_step "Managing dotfiles repository..."
  if [[ ! -d "$REPO_PATH" ]]; then
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  else
    log "Updating existing repository..."
    (cd "$REPO_PATH" && git pull)
  fi

  # Setup Zinit with plugins
  setup_zinit

  print_step "Linking configuration files..."
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

  setup_adb_rish
  setup_revanced_tools

  print_step "Creating cache directories..."
  mkdir -p "$HOME/.zsh/cache" "${XDG_CACHE_HOME:-$HOME/.cache}"

  optimize_zsh
  create_welcome_message

  print_step "🚀 Setup Complete! 🚀"
  cat <<EOF
Please restart Termux for all changes to take effect.
After restarting, your prompt will be ready with Zinit and PowerLevel10k.

Zinit plugins configured:
 - fast-syntax-highlighting, zsh-autosuggestions, zsh-completions
 - Oh-My-Zsh libs (history, completion, key-bindings)
 - Oh-My-Zsh plugins (git, colored-man-pages, sudo, extract)
 - FZF integration, zsh-you-should-use, zsh-autopair, zsh-z

ReVanced tools are installing in the background. Check $LOG_FILE for progress.
EOF

  log "Setup completed successfully at $(date +'%Y-%m-%d %H:%M:%S')"
}

# Execute main function, passing all arguments
main "$@"
