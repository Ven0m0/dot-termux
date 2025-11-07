#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob globstar extglob dotglob
IFS=$'\n\t'
export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive

# --- Configuration ---
REPO_URL="https://github.com/ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"
LOG_FILE="$HOME/termux_setup.log"
DOTFILES=("$REPO_PATH/.zshrc:$HOME/.zshrc" "$REPO_PATH/.zshenv:$HOME/.zshenv" "$REPO_PATH/.p10k.zsh:$HOME/.p10k.zsh")

# --- Colors and Helpers ---
BLU=$'\e[1;34m' GRN=$'\e[1;32m' YLW=$'\e[33m' RED=$'\e[1;31m' DEF=$'\e[0m'
log() { printf '[%s] %s\n' "$(date '+%T')" "$*" >>"$LOG_FILE"; }
step() { printf "\n%s==>%s %s%s\n" "$BLU" "$DEF" "$GRN" "$*" "$DEF"; }
has() { command -v "$1" &>/dev/null; }
ensure_dir() { for dir; do [[ -d $dir ]] || mkdir -p "$dir"; done; }

# --- Safe Remote Script Execution ---
run_installer() {
  local name=$1 url=$2
  step "Installing $name..."
  has "${name%%-*}" && { log "$name already installed."; return 0; }
  local script; script=$(mktemp --suffix=".sh")
  if curl -fsSL --http2 --tcp-fastopen --connect-timeout 5 "$url" -o "$script"; then
    log "Downloaded $name. Executing..."
    (bash "$script" &>>"$LOG_FILE") || log "${RED}Failed to install $name${DEF}"
  else
    log "${RED}Failed to download $name installer from $url${DEF}"
  fi
  rm -f "$script"
}

# --- Setup Functions ---
setup_environment() {
  step "Setting up environment"
  : >"$LOG_FILE"
  ensure_dir "$HOME/.ssh" "$HOME/bin" "$HOME/.termux" "${XDG_DATA_HOME:-$HOME/.local/share}" "${XDG_CACHE_HOME:-$HOME/.cache}"
  chmod 700 "$HOME/.ssh"
  [[ -f $HOME/.ssh/id_rsa ]] || { log "Generating SSH key..."; ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""; };
}

configure_apt() {
  step "Configuring apt"
  cat >"/data/data/com.termux/files/usr/etc/apt/apt.conf.d/99-termux-defaults" <<'EOF'
Dpkg::Options { "--force-confdef"; "--force-confold"; };
APT::Get::Assume-Yes "true";
APT::Get::allow-downgrades "true";
Acquire::Retries "3";
EOF
}

install_packages() {
  step "Updating repos and installing base packages"
  pkg up -y && pkg i -y tur-repo glibc-repo root-repo termux-api termux-services
  local -a pkgs=(
    git gix gh zsh zsh-completions build-essential parallel rust rust-src sccache
    ripgrep fd sd eza bat dust nodejs uv esbuild fzf zoxide sheldon rush shfmt
    procps gawk jq aria2 topgrade imagemagick ffmpeg libwebp gifsicle pngquant
    optipng jpegoptim openjpeg chafa micro mold llvm openjdk-21 python python-pip
    aapt2 apksigner apkeditor android-tools binutils-is-llvm
  )
  log "Installing ${#pkgs[@]} packages..."
  pkg install -y "${pkgs[@]}" || log "${YLW}Some packages failed to install. Continuing...${DEF}"
}

install_fonts() {
  step "Installing JetBrains Mono font"
  local font_path="$HOME/.termux/font.ttf"
  [[ -f $font_path ]] && { log "Font already installed."; return 0; }
  local url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
  local tmp_zip; tmp_zip=$(mktemp --suffix=".zip")
  curl -sL "$url" -o "$tmp_zip"
  unzip -jo "$tmp_zip" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$HOME/.termux/" &>/dev/null
  mv -f "$HOME/.termux/JetBrainsMono-Regular.ttf" "$font_path"
  rm -f "$tmp_zip"
  has termux-reload-settings && termux-reload-settings
}

install_rust_tools() {
  step "Installing additional Rust tools"
  export PATH="$HOME/.cargo/bin:$PATH"
  run_installer "cargo-binstall" "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh"
  local -a tools=(cargo-update oxipng)
  for tool in "${tools[@]}"; do has "$tool" || cargo binstall -y "$tool" || cargo install "$tool"; done
}

install_third_party() {
  step "Installing third-party tools"
  run_installer "bun" "https://bun.sh/install"
  run_installer "mise" "https://mise.run"
  run_installer "pkgx" "https://pkgx.sh"
  run_installer "revancify" "https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh"
  curl -fsL "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" -o "$HOME/bin/jaq" && chmod +x "$HOME/bin/jaq"
  has apk.sh || { curl -fsL "https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh" -o "$HOME/bin/apk.sh" && chmod +x "$HOME/bin/apk.sh"; }
  [[ -d "$HOME/DTL-X" ]] || git clone --depth=1 "https://github.com/Gameye98/DTL-X.git" "$HOME/DTL-X" && bash "$HOME/DTL-X/termux_install.sh"
}

setup_zsh() {
  step "Setting up Zsh and Antidote"
  [[ $(basename "$SHELL") != zsh ]] && chsh -s zsh
  local antidote_dir="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
  [[ -d $antidote_dir ]] || gix clone --depth=1 https://github.com/mattmc3/antidote.git "$antidote_dir"
}

link_dotfiles() {
  step "Linking dotfiles and scripts"
  for item in "${DOTFILES[@]}"; do
    IFS=: read -r src tgt <<<"$item"
    [[ -e $tgt || -L $tgt ]] && mv -f "$tgt" "${tgt}.bak"
    ln -sf "$src" "$tgt"
  done
  ensure_dir "$HOME/bin"
  for script in "$REPO_PATH/bin"/*.sh; do
    local target="$HOME/bin/$(basename "$script" .sh)"
    ln -sf "$script" "$target"
    chmod +x "$target"
  done
}

finalize() {
  step "Finalizing setup"
  zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do [[ -f $f ]] && zrecompile -pq "$f"; done' &>/dev/null ||:
  cat >"$HOME/.welcome.msg" <<<"${BLU}🚀 Welcome to your optimized Termux environment 🚀${DEF}"
  step "✅ Setup Complete!"
  printf 'Restart Termux to apply all changes.\nLogs are in %s\n' "${YLW}$LOG_FILE${DEF}"
}

# --- Main Execution ---
main() {
  cd "$HOME"
  if [[ -d $REPO_PATH/.git ]]; then gix -C "$REPO_PATH" fetch || git -C "$REPO_PATH" pull --rebase; else gix clone --depth=1 "$REPO_URL" "$REPO_PATH" || git clone --depth=1 "$REPO_URL" "$REPO_PATH"; fi

  setup_environment
  configure_apt
  install_packages &
  install_fonts &
  wait # Wait for packages and fonts before proceeding

  local -i pid_count=0
  local -a pids
  install_rust_tools & pids+=($!); ((pid_count++))
  install_third_party & pids+=($!); ((pid_count++))
  uv pip install -U TUIFIManager & pids+=($!); ((pid_count++))

  setup_zsh
  link_dotfiles

  log "Waiting for $pid_count background installations to finish..."
  while ((pid_count > 0)); do
    wait -n "${pids[@]}"
    ((pid_count--))
    log "A background task finished. Remaining: $pid_count"
  done

  finalize
}

main "$@"
