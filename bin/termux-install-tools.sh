#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
# Third-party tool installers
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'

# Colors
readonly GRN=$'\e[32m' YLW=$'\e[33m' RED=$'\e[31m' DEF=$'\e[0m'

has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '%s[INFO]%s %s\n' "$GRN" "$DEF" "$*"; }
warn(){ printf '%s[WARN]%s %s\n' "$YLW" "$DEF" "$*" >&2; }
err(){ printf '%s[ERROR]%s %s\n' "$RED" "$DEF" "$*" >&2; exit 1; }
download(){ curl -fsSLZ --http2 --skip-existing --connect-timeout 10 "$@"; }

# Install TermuxVoid repo
install_termuxvoid(){
  log "Installing TermuxVoid repo..."
  download https://termuxvoid.github.io/repo/install.sh | bash || err "TermuxVoid install failed"
  log "TermuxVoid repo installed"
}

# Install TermuxVoid theme
install_termuxvoid_theme(){
  log "Installing TermuxVoid theme..."
  local content
  content=$(download https://github.com/termuxvoid/TermuxVoid-Theme/raw/main/termuxvoid-theme.sh) || err "Download failed"
  bash -c "$content" termuxvoid-theme.sh
  log "TermuxVoid theme installed"
}

install_enhancify(){
  log "Insta installing Enhancify..."
  LC_ALL=C git clone --depth 1 --filter=blob:none -c protocol.version=2 -c http.version="HTTP/2" -c index.version=4 -q https://github.com/Graywizard888/Enhancify.git Enhancify
  cd Enhancify
  bash install.sh || err "Setup failed"
  log "Enhancify installed"
}

# Install X-CMD
install_xcmd(){
  log "Installing X-CMD..."
  eval "$(download https://get.x-cmd.com)" || err "X-CMD install failed"
  log "X-CMD installed"
}

# Install cargo-binstall
install_cargo_binstall(){
  log "Installing cargo-binstall..."
  has cargo || err "Cargo not installed"
  download --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash || err "cargo-binstall install failed"
  log "cargo-binstall installed"
}

# Install CSB (ConzZah Script Bundle)
install_csb(){
  log "Installing CSB..."
  download https://raw.githubusercontent.com/ConzZah/csb/main/csb | bash || err "CSB install failed"
  log "CSB installed"
}

# Install termux-shizuku-tools
install_shizuku_tools(){
  log "Installing termux-shizuku-tools..."
  local dir="$HOME/termux-shizuku-tools"
  if [[ -d "$dir" ]]; then
    log "Updating existing installation..."
    git -C "$dir" pull --rebase || warn "Update failed"
  else
    LC_ALL=C git clone --depth 1 --filter=blob:none -c protocol.version=2 -c http.version="HTTP/2" -c index.version=4 -q https://github.com/jecis-repos/termux-shizuku-tools.git "$dir" || err "Clone failed"
  fi
  cd "$dir"
  chmod +x setup.sh
  bash setup.sh || err "Setup failed"
  log "termux-shizuku-tools installed"
}

# Install Simplify
install_simplify(){
  log "Installing Simplify..."
  pkg update &>/dev/null || :
  pkg i -y --only-upgrade apt bash coreutils openssl &>/dev/null || :
  download -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh" || err "Download failed"
  bash "$HOME/.Simplify.sh" || err "Installation failed"
  log "Simplify installed"
}

# Usage
usage(){
  cat <<EOF
Third-party tool installers for Termux

USAGE:
  ${0##*/} <tool>

TOOLS:
  termuxvoid          Install TermuxVoid repo
  termuxvoid-theme    Install TermuxVoid theme
  xcmd                Install X-CMD
  lure                Install LURE package manager
  soar                Install Soar package manager
  cargo-binstall      Install cargo-binstall
  csb                 Install CSB
  shizuku-tools       Install termux-shizuku-tools
  revancify-xisr      Install Revancify-Xisr
  revancify           Install Revancify
  rvx-builder         Install RVX Builder
  simplify            Install Simplify

EXAMPLES:
  ${0##*/} termuxvoid
  ${0##*/} xcmd
  ${0##*/} revancify-xisr
EOF
}

main(){
  case "${1:-}" in
    termuxvoid) install_termuxvoid ;;
    termuxvoid-theme) install_termuxvoid_theme ;;
    xcmd) install_xcmd ;;
    lure) install_lure ;;
    soar) install_soar ;;
    cargo-binstall) install_cargo_binstall ;;
    csb) install_csb ;;
    shizuku-tools) install_shizuku_tools ;;
    revancify-xisr) install_revancify_xisr ;;
    revancify) install_revancify ;;
    rvx-builder) install_rvx_builder ;;
    simplify) install_simplify ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
