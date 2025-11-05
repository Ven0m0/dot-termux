#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive

# --- Configuration ---
REPO_URL="https://github.com/ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"
LOG_FILE="$HOME/termux_setup_log.txt"
ZSH_FILES=("$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.p10k.zsh")
DOTFILES=("$REPO_PATH/.zshrc:$HOME/.zshrc" "$REPO_PATH/.zshenv:$HOME/.zshenv" "$REPO_PATH/.p10k.zsh:$HOME/.p10k.zsh")

# --- Colors and Helpers ---
BLU=$'\e[1;34m' GRN=$'\e[1;32m' YLW=$'\e[33m' RED=$'\e[1;31m' DEF=$'\e[0m'
log() { printf '[%s] %s\n' "$(date '+%T')" "$*"; }
step() { printf "\n%s==>%s %s%s\n" "$BLU" "$DEF" "$GRN" "$*" "$DEF"; }
has() { command -v "$1" &>/dev/null; }
ensure_dir() { for dir in "$@"; do [[ -d "$dir" ]] || mkdir -p "$dir"; done; }

# --- Safe Remote Script Execution ---
run_installer() {
  local name="$1" url="$2"
  step "Installing $name..."
  has "${name%%-*}" && { log "$name already installed."; return 0; }
  local script
  script=$(mktemp --suffix=".sh")
  if curl -fsL --http2 --tcp-fastopen --tcp-nodelay --tls-earlydata --connect-timeout 5 "$url" -o "$script"; then
    log "Downloaded installer for $name. Executing..."
    (bash "$script") &>"$LOG_FILE.log" || log "${RED}Failed to install $name${DEF}"
  else
    log "${RED}Failed to download $name installer from $url${DEF}"
  fi
  rm -f "$script"
  log "$name installation process finished."
}
run_web(){
  local url="$1" file="$2"
  if has curl; then
    curl -fsL --http2 --tcp-fastopen --tcp-nodelay --tls-earlydata --connect-timeout 5 --retry 3 --retry-delay 2 "$url" -o "$file"
  elif has wget2; then
    wget2 -qO --tcp-fastopen - "$url"
  elif has wget; then
    wget -qO - "$url"
  fi
  chmod +x "$file"
}

# --- Setup Functions ---
setup_environment() {
  step "Setting up environment"
  : >"$LOG_FILE"
  ensure_dir "$HOME/.ssh" "$HOME/bin" "$HOME/.termux"
  ensure_dir "${XDG_DATA_HOME:-$HOME/.local/share}" "${XDG_CACHE_HOME:-$HOME/.cache}"
  chmod 700 "$HOME/.ssh"
  if [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
    log "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
    log "SSH key generated at ~/.ssh/id_rsa"
  fi
}

configure_apt() {
  step "Configuring apt"
  local apt_conf="/data/data/com.termux/files/usr/etc/apt/apt.conf.d/99-termux-defaults"
  ensure_dir "$(dirname "$apt_conf")"
  cat >"$apt_conf" <<'EOF'
Dpkg::Options { "--force-confdef"; "--force-confold"; }
APT::Get::Assume-Yes "true";
APT::Get::allow-downgrades "true";
Acquire::Retries "3";
EOF
  log "apt configured."
}

install_packages() {
  step "Updating repos and installing base packages"
  pkg up -y && pkg i -y tur-repo glibc-repo root-repo termux-api termux-services
  local -a pkgs=(
    # Core
    git gitoxide gh zsh zsh-completions build-essential parallel bash-completion
    # Rust Toolchain & Tools
    rust rust-src sccache ripgrep fd sd eza bat dust
    # JS/Node Toolchain & Tools
    nodejs uv esbuild
    # Shell utils
    fzf zoxide sheldon rush shfmt procps gawk jq aria2 topgrade
    # Image/Media
    imagemagick ffmpeg libwebp gifsicle pngquant optipng jpegoptim openjpeg chafa
    # Misc
    micro mold llvm openjdk-21 python python-pip requests beautifulsoup4
    # Android
    aapt2 apksigner apkeditor android-tools binutils-is-llvm
  )
  log "Installing ${#pkgs[@]} packages..."
  pkg install -y "${pkgs[@]}" || log "${YLW}Some packages failed to install. Continuing...${DEF}"
}

install_fonts() {
  step "Installing JetBrains Mono font"
  local font_path="$HOME/.termux/font.ttf"
  [[ -f "$font_path" ]] && { log "Font already installed."; return 0; }
  local url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
  local tmp_zip
  tmp_zip=$(mktemp --suffix=".zip")
  curl -sL "$url" -o "$tmp_zip"
  unzip -jo "$tmp_zip" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$HOME/.termux/" &>/dev/null
  mv -f "$HOME/.termux/JetBrainsMono-Regular.ttf" "$font_path"
  rm -f "$tmp_zip"
  has termux-reload-settings && termux-reload-settings
  log "JetBrains Mono font installed."
}

install_rust_tools() {
  step "Installing additional Rust tools"
  export PATH="$HOME/.cargo/bin:$PATH"
  run_installer "cargo-binstall" "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh"
  
  local -a tools=(cargo-update oxipng)
  for tool in "${tools[@]}"; do
    has "$tool" || cargo binstall -y "$tool" || cargo install "$tool"
  done
}

install_third_party() {
  step "Installing third-party tools"
  run_installer "bun" "https://bun.sh/install"
  run_installer "mise" "https://mise.run"
  run_installer "soar" "https://soar.qaidvoid.dev/install.sh"
  run_installer "pkgx" "https://pkgx.sh"
  run_installer "x-cmd" "https://get.x-cmd.com"
  run_installer "revancify" "https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh"
  run_installer "simplify" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh"
  run_installer "rish-setup" "https://raw.githubusercontent.com/ConzZah/csb/main/csb"
  curl -fsL "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" -o "$HOME/bin/jaq" && chmod +x "$HOME/bin/jaq"
  has apk.sh || {
    curl -fsL "https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh" -o "$HOME/bin/apk.sh" && chmod +x "$HOME/bin/apk.sh"
    log "apk.sh installed"
  }
  git clone --depth=1 --filter='blob:none' --no-tags https://github.com/Gameye98/DTL-X.git && bash DTL-X/termux_install.sh
}

setup_zsh() {
  step "Setting up Zsh and Antidote"
  [[ "$(basename "$SHELL")" != "zsh" ]] && chsh -s zsh
  local antidote_dir="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
  if [[ ! -d "$antidote_dir" ]]; then
    log "Cloning Antidote..."
    git clone --depth=1 --filter='blob:none' https://github.com/mattmc3/antidote.git "$antidote_dir"
  fi
}

link_dotfiles() {
  step "Linking dotfiles and scripts"
  for item in "${DOTFILES[@]}"; do
    IFS=: read -r src tgt <<<"$item"
    [[ -e $tgt || -L $tgt ]] && mv -f "$tgt" "${tgt}.bak"
    ln -sf "$src" "$tgt"
    log "Linked $tgt"
  done
  ensure_dir "$HOME/bin"
  for script in "$REPO_PATH/bin"/*.sh; do
    [[ -f $script ]] || continue
    local target="$HOME/bin/$(basename "$script" .sh)"
    ln -sf "$script" "$target"
    chmod +x "$target"
  done
}

finalize() {
  step "Finalizing setup"
  log "Compiling Zsh configuration for faster startup..."
  zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do [[ -f "$f" ]] && zrecompile -pq "$f"; done' &>/dev/null || :
  
  cat >"$HOME/.welcome.msg" <<EOF
${BLU}╔════════════════════════════════════════════════╗${DEF}
${BLU}║  Welcome to your optimized Termux environment  ║${DEF}
${BLU}╚════════════════════════════════════════════════╝${DEF}
Tools: ${GRN}revancify simplify gix soar mise bun zoxide${DEF}
Type ${GRN}help${DEF} for more.
EOF
  log "Welcome message created."

  step "🚀 Setup Complete! 🚀"
  cat <<EOF
Restart Termux to apply all changes.
Background installation logs are in ${YLW}$LOG_FILE.log${DEF}
EOF
  log "Setup finished. Check logs for details."
}

# --- Main Execution ---
main() {
  cd "$HOME"
  [[ -d "$REPO_PATH" ]] && git -C "$REPO_PATH" pull --rebase -p || git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  setup_environment
  configure_apt
  install_packages
  install_fonts
  {
    install_rust_tools
    install_third_party
    uv pip install -U TUIFIManager
  } &
  setup_zsh
  link_dotfiles
  finalize
}

main "$@"setup_antidote(){ print_step "Setting up Antidote"
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
  [[ -d $dir ]] || { ensure_dir "${dir%/*}"; git clone --depth 1 --filter='blob:none' --no-tags https://github.com/mattmc3/antidote "$dir" &>/dev/null || :; }
  log "Antidote ready"
}
install_rust_tools_fallback(){ print_step "Installing Rust tools (fallback)"
  [[ -x "$HOME/.cargo/bin/cargo-binstall" ]] || { curl -fsL https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash &>/dev/null; }
  local -a tools=(oxipng cargo-update)
  for tool in "${tools[@]}"; do has "$tool" || { "$HOME/.cargo/bin/cargo-binstall" "$tool" || cargo install "$tool"; }; done
  log "Rust fallback tools installing"
}
install_node_tools(){ print_step "Installing bun"
  { has bun || { curl -fsL https://bun.sh/install | bash &>/dev/null; log "bun done"; } } &
}
install_mise(){ print_step "Installing mise"; has mise || { curl -fsL https://mise.run | sh &>/dev/null; log "mise done"; }; }
install_soar(){ print_step "Installing SOAR"; has soar || { curl -fsL https://soar.qaidvoid.dev/install.sh | sh &>/dev/null; log "SOAR done"; }; }
install_pkgx(){ print_step "Installing pkgx"; has pkgx || { curl -fsL https://pkgx.sh | sh &>/dev/null; log "pkgx done"; }; }

setup_revanced_tools(){ print_step "Setting up ReVanced tools"; ensure_dir "$HOME/bin"
  { curl -sfL "https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh" | bash &>/dev/null && [[ -d $HOME/revancify-xisr ]] && ln -sf "$HOME/revancify-xisr/revancify.sh" "$HOME/bin/revancify-xisr" || :; log "Revancify done"; } &
  { curl -sfL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh" && ln -sf "$HOME/.Simplify.sh" "$HOME/bin/simplify" && log "Simplify done"; } &
  { curl -fsL https://get.x-cmd.com | bash &>/dev/null && log "X-CMD done"; } &
  log "ReVanced tools installing"
}
install_wapatch(){ git clone --depth=1 --filter='blob:none' --no-tags https://github.com/Schwartzblat/WhatsAppPatcher.git && uv pip install -r WhatsAppPatcher/requirements.txt; }
setup_adb_rish(){ print_step "Setting up ADB/RISH"; curl -sL https://raw.githubusercontent.com/ConzZah/csb/main/csb | bash &>/dev/null || :; log "ADB/RISH done"; }

create_welcome(){ cat >"$HOME/.welcome.msg"<<EOF
${BLUE}╔════════════════════════════════════════════════╗${RESET}
${BLUE}║  Welcome to optimized Termux environment      ║${RESET}
${BLUE}╚════════════════════════════════════════════════╝${RESET}
Tools: ${GREEN}revancify-xisr simplify gix soar mise bun pnpm${RESET}
Type ${GREEN}help${RESET} for more.
EOF
log "Welcome created"; }

optimize_zsh(){ print_step "Optimizing Zsh"
  zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do [[ -f "$f" ]] && zrecompile -pq "$f"; done' &>/dev/null || :
  log "Zsh optimized"
}

main(){
  : >"$LOG_FILE"; log "Starting setup..."
  check_internet
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  # Generate SSH key if not exists
  if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    echo "SSH key generated at ~/.ssh/id_rsa"
  fi
  print_step "Updating packages, adding repos and installing packages"
  install_pkgs
  install_jetbrains_mono
  print_step "Setting Zsh as default"; [[ "$(basename "$SHELL")" != "zsh" ]] && chsh -s zsh
  print_step "Managing repo"
  if [[ -d "$REPO_PATH" ]]; then git -C "$REPO_PATH" pull -r -p; else git clone --depth=1 "$REPO_URL" "$REPO_PATH"; fi
  setup_antidote
  install_rust_tools_fallback
  install_node_tools
  install_mise
  install_soar
  install_pkgx
  uv pip install TUIFIManager requests beautifulsoup4
  { curl -fsL https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh -o "$HOME/bin/apk.sh" && chmod +x "$HOME/bin/apk.sh"; }
  print_step "Linking dotfiles"
  local -a dotfiles=("$REPO_PATH/.zshrc:$HOME/.zshrc" "$REPO_PATH/.zshenv:$HOME/.zshenv" "$REPO_PATH/.p10k.zsh:$HOME/.p10k.zsh")
  for item in "${dotfiles[@]}"; do IFS=: read -r src tgt <<<"$item"; symlink_dotfile "$src" "$tgt"; done
  print_step "Linking scripts"; ensure_dir "$HOME/bin"
  for script in "$REPO_PATH/bin"/*.sh; do [[ -f $script ]] || continue; ln -sf "$script" "$HOME/bin/$(basename "$script" .sh)" && chmod +x "$script"; done
  setup_adb_rish
  setup_revanced_tools
  ensure_dir "$HOME/.zsh/cache" "${XDG_CACHE_HOME:-$HOME/.cache}" "$HOME/.config/zsh"
  optimize_zsh
  create_welcome
  print_step "🚀 Setup Complete! 🚀"
  cat <<EOF
Restart Termux. Installed: Antidote, OMZ snippets, Powerlevel10k, ReVanced tools, soar, mise, bun, pnpm
Background jobs installing. Check $LOG_FILE
EOF
  log "Setup complete"
}
main "$@"
