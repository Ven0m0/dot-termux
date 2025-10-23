#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive

# --- Config ---
declare -r REPO_URL="https://github.com/ven0m0/dot-termux.git"
declare -r REPO_PATH="$HOME/dot-termux"
declare -r LOG_FILE="$HOME/termux_setup_log.txt"
declare -r RED="\033[0;31m" GREEN="\033[0;32m" BLUE="\033[0;34m" YELLOW="\033[0;33m" RESET="\033[0m"

# --- Helpers ---
has(){ command -v -- "$1" >/dev/null 2>&1; }
log(){ printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
print_step(){ printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$1"; }
ensure_dir(){ [[ -d $1 ]] || mkdir -p "$1"; }

err(){ printf 'Error: %s\n' "$*" >&2; }
backup_file(){
  local f=$1 bak="${f}.bak.$(date +%Y%m%d_%H%M%S)"
  [[ -e $f ]] && cp -p "$f" "$bak"
}

symlink_dotfile(){
  local src=$1 tgt=$2
  ensure_dir "$(dirname "$tgt")"
  [[ -e $tgt || -L $tgt ]] && { log "Backing up '$tgt'"; mv -f "$tgt" "${tgt}.bak"; }
  ln -sf "$src" "$tgt"
  log "Linked '$tgt' -> '$src'"
}

check_internet(){
  print_step "Checking internet"
  if has curl; then
    curl -s --connect-timeout 3 -o /dev/null http://www.google.com >/dev/null 2>&1 || { err "No connection"; exit 1; }
  elif has ping; then
    ping -c 1 google.com >/dev/null 2>&1 || { err "No connection"; exit 1; }
  fi
  log "Connected"
}

install_jetbrains_mono(){
  print_step "Installing JetBrains Mono font"
  local font_dir="$HOME/.termux"
  ensure_dir "$font_dir"
  local url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
  local api_response
  if api_response=$(curl -sL "https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest"); then
    if [[ $api_response =~ \"browser_download_url\":\ *\"(https://[^\"]+JetBrainsMono[^\"]+\.zip)\" ]]; then
      url="${BASH_REMATCH[1]}"
      log "Found release: $url"
    fi
  fi
  local temp_zip
  temp_zip=$(mktemp)
  curl -sL "$url" -o "$temp_zip" &&
    unzip -jo "$temp_zip" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$font_dir" >/dev/null 2>&1 &&
    mv -f "$font_dir/JetBrainsMono-Regular.ttf" "$font_dir/font.ttf" &&
    log "Font installed" ||
    log "Font install failed"
  has termux-reload-settings && termux-reload-settings >/dev/null 2>&1 || :
  rm -f "$temp_zip"
}

setup_zinit(){
  print_step "Setting up Zinit"
  local zinit_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zinit"
  local zinit_git="$zinit_dir/zinit.git"
  if [[ ! -d $zinit_git ]]; then
    ensure_dir "$zinit_dir"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$zinit_git" >/dev/null 2>&1 &&
      log "Zinit installed" ||
      log "Zinit install failed"
  else
    (cd "$zinit_git" && git pull >/dev/null 2>&1) || :
    log "Zinit updated"
  fi

  cat >"$HOME/.zshrc.zinit" <<'EOF'
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

zinit light-mode for zdharma-continuum/zinit-annex-bin-gem-node zdharma-continuum/zinit-annex-patch-dl zdharma-continuum/zinit-annex-rust
zinit lucid light-mode for OMZL::history.zsh OMZL::completion.zsh OMZL::key-bindings.zsh OMZL::clipboard.zsh OMZL::directories.zsh
zinit wait lucid light-mode for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zpcompinit; zpcdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf atpull'zinit creinstall -q .' \
    zsh-users/zsh-completions
zinit wait lucid light-mode for \
  OMZP::colored-man-pages \
  OMZP::git \
  OMZP::command-not-found \
  OMZP::extract \
  OMZP::sudo

[[ -d "$PREFIX/share/fzf" ]] && zinit wait lucid is-snippet for "$PREFIX/share/fzf/key-bindings.zsh" "$PREFIX/share/fzf/completion.zsh"

zinit wait lucid light-mode for \
  MichaelAquilina/zsh-you-should-use \
  hlissner/zsh-autopair \
  agkozak/zsh-z
zinit ice depth=1
zinit light romkatv/powerlevel10k
EOF
  log "Zinit config created"
}

install_cargo_binstall(){
  print_step "Installing cargo-binstall"
  local binstall_bin="$HOME/.cargo/bin/cargo-binstall"
  if [[ ! -x $binstall_bin ]]; then
    curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash >/dev/null 2>&1 &&
      log "cargo-binstall installed" ||
      { log "cargo-binstall failed"; return 1; }
  else
    log "cargo-binstall already installed"
  fi
}

install_rust_tools(){
  print_step "Installing Rust tools via cargo-binstall"
  [[ -x "$HOME/.cargo/bin/cargo-binstall" ]] || { log "cargo-binstall not available"; return 1; }
  local -a tools=(
    eza
    bat
    fd-find
    ripgrep
    zoxide
    dust
    sd
    tokei
    hyperfine
    procs
    bottom
    gitoxide
  )
  
  {
    for tool in "${tools[@]}"; do
      log "Installing $tool..."
      "$HOME/.cargo/bin/cargo-binstall" -y "$tool" >/dev/null 2>&1 || log "$tool install failed"
    done
    log "Rust tools installation complete"
  } &
}

install_apk_sh(){
  print_step "Installing apk.sh"
  local apk_bin="$HOME/bin/apk.sh"
  ensure_dir "$HOME/bin"
  curl -fsSL https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh -o "$apk_bin" &&
    chmod +x "$apk_bin" && log "apk.sh installed" || log "apk.sh failed"
}

install_uv(){
  print_step "Installing uv"
  curl -sSfL https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 &&
    log "uv installed" || log "uv install failed"
}

setup_revanced_tools(){
  print_step "Setting up ReVanced tools"
  ensure_dir "$HOME/bin"
  { # Install Revancify-Xisr
    log "Installing Revancify-Xisr..."
    curl -sL "https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh" | bash >/dev/null 2>&1 &&
      [[ -d $HOME/revancify-xisr ]] && ln -sf "$HOME/revancify-xisr/revancify.sh" "$HOME/bin/revancify-xisr" >/dev/null 2>&1 || true
    log "Revancify-Xisr done"
  } &
  { # Install Simplify
    log "Installing Simplify..."
    curl -sL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh" >/dev/null 2>&1 &&
      ln -sf "$HOME/.Simplify.sh" "$HOME/bin/simplify" >/dev/null 2>&1 || true
    log "Simplify done"
  } &
  { log "Installing X-CMD..."; curl -fsSL https://get.x-cmd.com | bash >/dev/null 2>&1 && log "X-CMD done" || log "X-CMD failed"; } &
  { log "Installing SOAR..."; curl -fsSL https://soar.qaidvoid.dev/install.sh | sh >/dev/null 2>&1 && log "SOAR done" || log "SOAR failed"; } &
  log "ReVanced tools installing in background"
}

setup_adb_rish(){
  print_step "Setting up ADB and RISH"
  curl -sL https://raw.githubusercontent.com/ConzZah/csb/main/csb | bash >/dev/null 2>&1 || true
  log "ADB/RISH done"
}

create_welcome(){
  print_step "Creating welcome message"
  cat >"$HOME/.welcome.msg" <<EOF
${BLUE}╔════════════════════════════════════════════════╗${RESET}
${BLUE}║                                                ║${RESET}
${BLUE}║  Welcome to your optimized Termux environment  ║${RESET}
${BLUE}║                                                ║${RESET}
${BLUE}╚════════════════════════════════════════════════╝${RESET}

Tools:
• ${GREEN}revancify-xisr${RESET} - ReVanced patcher
• ${GREEN}simplify${RESET}       - Simplify tool
• ${GREEN}apk.sh${RESET}         - APK inspector
• ${GREEN}gix${RESET}            - Git operations (gitoxide)
• ${GREEN}aria2c${RESET}         - Fast downloads
• ${GREEN}uv${RESET}             - Python package manager

Rust tools installing in background via cargo-binstall.
Type ${GREEN}help${RESET} for more.
EOF
  log "Welcome created"
}

optimize_zsh(){
  print_step "Optimizing Zsh"
  zsh -c '
    autoload -Uz zrecompile
    for f in ~/.zshrc ~/.zshenv ~/.zshrc.zinit ~/.p10k.zsh ~/.config/zsh/wrappers.zsh; do
      [[ -f "$f" ]] && zrecompile -pq "$f" >/dev/null 2>&1 || :
    done
  ' >/dev/null 2>&1 || :
  log "Zsh optimized"
}

# --- Main ---
main(){
  : >"$LOG_FILE"
  log "Starting setup..."
  
  check_internet
  
  print_step "Updating packages and adding repos"
  pkg up -y && pkg in -y tur-repo glibc-repo
  print_step "Upgrading critical"
  pkg i --only-upgrade apt bash coreutils openssl -y
  
  print_step "Installing essentials"
  local -a pkgs=(
    zsh git curl wget micro aria2 termux-api openjdk-17 nano man figlet 
    ncurses-utils build-essential bash-completion zsh-completions android-tools 
    libwebp optipng pngquant jpegoptim gifsicle gifski aapt2 pkgtop parallel 
    apksigner yazi rust fzf
    # Rust tools (eza, bat, fd, ripgrep, zoxide) removed here, prioritized via cargo-binstall
  )
  pkg i -y "${pkgs[@]}"
  
  install_jetbrains_mono
  
  print_step "Setting Zsh as default"
  [[ "$(basename "$SHELL")" != "zsh" ]] && { chsh -s zsh; log "Zsh is default"; } || log "Zsh already default"
  
  print_step "Managing repo"
  if [[ -d "$REPO_PATH" ]]; then
    log "Updating repo"
    git -C "$REPO_PATH" pull -r -p
  else
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
    log "Repo cloned"
  fi
  
  setup_zinit
  install_apk_sh
  install_cargo_binstall
  install_rust_tools
  install_uv
  
  print_step "Linking dotfiles"
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
    "$HOME/.bash_functions.wrapper:$HOME/.config/bash/bash_functions.wrapper"
    "$REPO_PATH/.config/bash/bash_functions.bash:$HOME/.config/bash/bash_functions.bash"
    "$REPO_PATH/.ignore:$HOME/.config/fd/ignore"
  )
  for item in "${dotfiles[@]}"; do
    IFS=":" read -r src tgt <<<"$item"
    symlink_dotfile "$src" "$tgt"
  done
  
  print_step "Linking scripts"
  ensure_dir "$HOME/bin"
  for script in "$REPO_PATH/bin"/*.sh; do
    [[ -f $script ]] || continue
    local script_name
    script_name=$(basename "$script" .sh)
    ln -sf "$script" "$HOME/bin/$script_name"
    chmod +x "$script"
    log "Linked $script_name"
  done
  
  setup_adb_rish
  setup_revanced_tools
  
  print_step "Creating cache dirs"
  ensure_dir "$HOME/.zsh/cache"
  ensure_dir "${XDG_CACHE_HOME:-$HOME/.cache}"
  ensure_dir "$HOME/.config/zsh"
  
  optimize_zsh
  create_welcome
  
  print_step "🚀 Setup Complete! 🚀"
  cat <<EOF

Restart Termux for changes.

Installed:
  • Zinit + plugins
  • OMZ libs/plugins
  • Fast syntax highlighting
  • Powerlevel10k
  • ReVanced tools
  • cargo-binstall + Rust tools
  • apk.sh, uv

Background jobs installing additional tools.
Check $LOG_FILE for progress.
EOF

  log "Setup complete at $(date +'%Y-%m-%d %H:%M:%S')"
}

main "$@"
