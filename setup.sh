#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
#
# Termux + Debian proot setup - MINIMAL SPACE OPTIMIZED
#
# This script sets up Termux with a minimal proot-distro Debian environment
# optimized for minimal storage usage. By default, only essential packages
# are installed. Optional features can be enabled via environment variables.
#
# USAGE:
#   ./setup.sh                           # Minimal install
#   INSTALL_FONTS=1 ./setup.sh           # Include fonts
#   INSTALL_DEVTOOLS=1 ./setup.sh        # Include dev tools (Python, Node, etc.)
#   INSTALL_MEDIA_TOOLS=1 ./setup.sh     # Include media tools (ffmpeg, etc.)
#
# MINIMAL INSTALL INCLUDES:
#   - Essential Termux packages: git, zsh, curl, wget, proot-distro
#   - Minimal Debian: sudo, locales, curl, ca-certificates
#   - X11 support: termux-x11, pulseaudio
#   - Total size: ~400-600MB (vs 2-3GB with all tools)
#
# SPACE SAVING FEATURES:
#   - Aggressive cache cleanup after each install
#   - Shallow git clones (--depth=1)
#   - No build tools by default
#   - Removed duplicate packages
#   - Minimal Debian base (no docs, man pages)
#
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C DEBIAN_FRONTEND=noninteractive; IFS=$'\n\t'
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
cache=${XDG_CACHE_HOME:-${HOME}/.cache}; [[ -d $cache ]] || cache=${HOME}
logf=${HOME}/termux_setup.log
repo_url=https://github.com/Ven0m0/dot-termux.git
repo_path=${HOME}/dot-termux
deb_user="${USER:-user}"
# Optional features (set to 1 to enable)
INSTALL_FONTS=${INSTALL_FONTS:-0}
INSTALL_DEVTOOLS=${INSTALL_DEVTOOLS:-0}
INSTALL_MEDIA_TOOLS=${INSTALL_MEDIA_TOOLS:-0}
has(){ command -v -- "$1" &>/dev/null; }
step(){ printf '==> %s\n' "$*"; }
log(){ printf '[%(%T)T] %s\n' -1 "$*" >>"$logf"; }
ensure(){ [[ -d $1 ]] || mkdir -p -- "$1"; }
download(){ curl -fsSL --connect-timeout 10 "$@"; }
setup_env(){
  ensure "${HOME}/bin" "${HOME}/.termux"
  ensure "${XDG_CONFIG_HOME:-${HOME}/.config}" "${XDG_DATA_HOME:-${HOME}/.local/share}" "${XDG_CACHE_HOME:-${HOME}/.cache}"
  ensure "${XDG_DATA_HOME:-${HOME}/.local/share}/bin"
  # Skip SSH key generation for minimal setup - create manually if needed
}
install_termux_pkgs(){
  step "Termux packages (minimal)"
  pkg update -y || log "pkg update failed"
  apt-get install -f || :
  # Install only essential repos
  pkg install -y x11-repo || log "x11-repo installation failed"

  # Core packages (essential only)
  local -a core_pkgs=(
    git zsh zsh-completions curl wget
    proot-distro pulseaudio termux-x11-nightly
    ncurses-utils unzip zip
  )

  # Optional media tools (large)
  local -a media_pkgs=(
    ffmpeg graphicsmagick libwebp gifsicle
    optipng jpegoptim chafa aria2
  )

  # Optional dev tools
  local -a dev_pkgs=(
    python nodejs build-essential
    ripgrep eza bat fzf jq
  )

  log "Installing ${#core_pkgs[@]} core packages..."
  pkg i -y "${core_pkgs[@]}" || log "Some core packages failed"

  if [[ $INSTALL_MEDIA_TOOLS -eq 1 ]]; then
    log "Installing ${#media_pkgs[@]} media packages..."
    pkg i -y "${media_pkgs[@]}" || log "Some media packages failed"
  fi

  if [[ $INSTALL_DEVTOOLS -eq 1 ]]; then
    log "Installing ${#dev_pkgs[@]} dev packages..."
    pkg i -y "${dev_pkgs[@]}" || log "Some dev packages failed"
  fi

  # Aggressive cleanup
  pkg clean || :
  apt-get clean || :
  rm -rf "${PREFIX}/tmp/"* 2>/dev/null || :
}
setup_fonts(){
  [[ $INSTALL_FONTS -eq 0 ]] && { log "Skipping fonts (INSTALL_FONTS=0)"; return 0; }
  step "Installing Fonts"
  local font_dir="${HOME}/.termux"
  ensure "$font_dir"
  if [[ ! -f "${font_dir}/font.ttf" ]]; then
    log "Downloading JetBrains Mono Nerd Font..."
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
      | tar -xJ -C "${font_dir}" "JetBrainsMonoNerdFont-Regular.ttf"
    mv "${font_dir}/JetBrainsMonoNerdFont-Regular.ttf" "${font_dir}/font.ttf"
    has termux-reload-settings && termux-reload-settings || true
  fi
}
install_zimfw(){
  step "Zimfw"
  local zim_home=${ZIM_HOME:-${HOME}/.zim}
  [[ -d $zim_home ]] && { log "Zimfw exists"; return 0; }
  has zsh || { log "Zsh not installed, skipping zimfw"; return 0; }
  download https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh || log "Zimfw install failed"
}
install_debian(){
  step "Debian proot"
  has proot-distro || { log "proot-distro missing"; return 1; }
  if ! proot-distro list 2>/dev/null | grep -q '^debian'; then
    proot-distro install debian || { log "Debian install failed"; return 1; }
  else
    log "Debian already installed"
  fi
}
configure_debian(){
  step "Debian configuration (minimal)"
  proot-distro login debian --shared-tmp -- /bin/bash <<'DEBEOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# Minimal packages only - no build-essential by default
apt-get install -y -qq --no-install-recommends \
  sudo locales curl ca-certificates
# Optional: add git and zsh only if needed
# apt-get install -y -qq --no-install-recommends git zsh
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 >/dev/null 2>&1
update-locale LANG=en_US.UTF-8
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
id -u user &>/dev/null || useradd -m -s /bin/bash user
echo "user ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/user
chmod 440 /etc/sudoers.d/user
# Aggressive cleanup to minimize space
apt-get autoremove -y -qq
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/*
DEBEOF
}
install_debian_devtools(){
  [[ $INSTALL_DEVTOOLS -eq 0 ]] && { log "Skipping debian devtools (INSTALL_DEVTOOLS=0)"; return 0; }
  step "Debian dev tools (mise, rust, bun)"
  proot-distro login debian --shared-tmp --user "$deb_user" -- /bin/bash <<'DEVEOF'
set -e
export HOME=/home/user
export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:$PATH"
mkdir -p "${HOME}/.local/bin"
# mise
if ! command -v mise &>/dev/null; then
  curl -fsSL https://mise.run | sh
  export PATH="${HOME}/.local/bin:$PATH"
fi
# rust via mise
if ! command -v cargo &>/dev/null && command -v mise &>/dev/null; then
  mise use -g rust
  eval "$(mise activate bash)"
fi
# cargo-binstall / oxipng / bun
if command -v mise &>/dev/null; then
  mise use -g cargo-binstall oxipng bun
fi
# bun fallback
if ! command -v bun &>/dev/null && command -v mise &>/dev/null; then
  mise use -g bun
fi
# Cleanup
rm -rf "${HOME}/.cache/"* "${HOME}/.cargo/registry/cache"
DEVEOF
}
install_third_party(){
  [[ $INSTALL_DEVTOOLS -eq 0 ]] && { log "Skipping 3rd party tools (INSTALL_DEVTOOLS=0)"; return 0; }
  step "3rd party (Termux)"
  if ! has jaq; then
    ensure "${HOME}/.local/bin"
    if download "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" -o "${HOME}/.local/bin/jaq"; then
      chmod +x "${HOME}/.local/bin/jaq" || :
    fi
  fi
}
bootstrap_dotfiles(){
  step "Dotfiles (minimal)"
  has git || { log "Git not installed, skipping dotfiles"; return 0; }

  # Shallow clone for minimal space
  if [[ -d $repo_path/.git ]]; then
    git -C "$repo_path" pull --rebase --autostash &>>"$logf" || log "Repo pull failed"
  else
    git clone --depth=1 --single-branch "$repo_url" "$repo_path" &>>"$logf" || { log "Clone failed"; return 1; }
  fi

  # Link bin scripts only
  if [[ -d $repo_path/bin ]]; then
    ensure "${HOME}/bin"
    while IFS= read -r -d '' s; do
      ln -sf "$s" "${HOME}/bin/${s##*/}"
      chmod +x "${HOME}/bin/${s##*/}"
    done < <(find "$repo_path/bin" -type f -executable -print0)
  fi

  # Skip yadm for minimal setup - users can run manually if needed
  log "Skipping yadm for minimal install (run manually if needed)"
}
create_debian_launcher(){
  step "Debian launcher"
  cat >"${HOME}/bin/debian" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
pkill -9 -f termux.x11 2>/dev/null || :
rm -rf "${TMPDIR:-/tmp}/"*pulse* 2>/dev/null || :
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 2>/dev/null || :
export XDG_RUNTIME_DIR=${TMPDIR:-/tmp}
termux-x11 :0 >/dev/null 2>&1 &
sleep 2
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || :
exec proot-distro login debian --shared-tmp -- /bin/bash
LAUNCHER
  chmod +x "${HOME}/bin/debian"
}
setup_zsh(){ has zsh && [[ ${SHELL##*/} != zsh ]] && chsh -s zsh || :; }
finalize(){
  has zsh && zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv; do [[ -f $f ]] && zrecompile -pq "$f"; done' &>/dev/null || :
  echo "Welcome to optimized Termux + Debian" >"${HOME}/.welcome.msg"
  step "Setup complete."; printf 'Restart Termux. Logs: %s\n' "$logf"
  has termux-setup-storage || log "termux-setup-storage unavailable"
}
main(){
  cd "${HOME}" || { echo "Failed to cd HOME"; exit 1; }
  : >"$logf"

  step "Minimal Termux + Debian Setup"
  log "INSTALL_FONTS=${INSTALL_FONTS}, INSTALL_DEVTOOLS=${INSTALL_DEVTOOLS}, INSTALL_MEDIA_TOOLS=${INSTALL_MEDIA_TOOLS}"

  step "Base tools (minimal)"
  pkg update -y &>/dev/null || log "pkg update failed"
  pkg upgrade -y --with-new-pkgs &>/dev/null || :
  pkg i -y git curl &>/dev/null || log "Base tools partial fail"

  setup_env || log "setup_env failed"
  bootstrap_dotfiles || log "bootstrap_dotfiles failed"
  install_termux_pkgs || log "install_termux_pkgs failed"
  setup_fonts || log "setup_fonts failed"
  install_zimfw || log "install_zimfw failed"
  install_third_party || log "install_third_party failed"
  install_debian || log "install_debian failed"
  configure_debian || log "configure_debian failed"
  install_debian_devtools || log "install_debian_devtools failed"
  create_debian_launcher || log "create_debian_launcher failed"
  setup_zsh || log "setup_zsh failed"
  finalize || log "finalize failed"

  # Final cleanup
  step "Final cleanup"
  pkg clean || :
  apt-get clean || :
  rm -rf "${PREFIX}/tmp/"* "${PREFIX}/var/cache/"* 2>/dev/null || :
  rm -rf "${HOME}/.cache/"* 2>/dev/null || :

  echo; echo "Minimal setup complete. Check $logf for errors."
  echo "To enable optional features, set environment variables:"
  echo "  INSTALL_FONTS=1 ./setup.sh        # Install fonts"
  echo "  INSTALL_DEVTOOLS=1 ./setup.sh     # Install dev tools"
  echo "  INSTALL_MEDIA_TOOLS=1 ./setup.sh  # Install media tools"
}
main "$@"
