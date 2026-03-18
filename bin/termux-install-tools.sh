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
  log "Installing Enhancify..."
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

# Install LURE
install_lure(){
  log "Installing LURE..."
  download https://lure.sh/install | bash || err "LURE install failed"
  log "LURE installed"
}

# Install Soar
install_soar(){
  log "Installing Soar..."
  download https://soar.qaidvoid.dev/install.sh | sh || err "Soar install failed"
  log "Soar installed"
}

# Install Revancify-Xisr
install_revancify_xisr(){
  log "Installing Revancify-Xisr..."
  download https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh | bash || err "Revancify-Xisr install failed"
  log "Revancify-Xisr installed"
}

# Install Revancify
install_revancify(){
  log "Installing Revancify..."
  download https://raw.githubusercontent.com/decipher3114/Revancify/main/install.sh | bash || err "Revancify install failed"
  log "Revancify installed"
}

# Install RVX Builder
install_rvx_builder(){
  log "Installing RVX Builder..."
  download -o rvx-builder.sh https://raw.githubusercontent.com/inotia00/rvx-builder/revanced-extended/android-interface.sh || err "Download failed"
  chmod +x rvx-builder.sh
  ./rvx-builder.sh || err "RVX Builder install failed"
  log "RVX Builder installed"
}

# Install GitHub Copilot
install_copilot(){
  log "Installing GitHub Copilot..."
  npm install -g @github/copilot || err "npm install failed"
  download https://gh.io/copilot-install | bash || err "Copilot install failed"
  log "GitHub Copilot installed"
}

# Install Anthropic Claude Code
install_claude(){
  log "Installing Anthropic Claude Code..."
  download https://claude.ai/install.sh | bash || err "Claude install failed"
  npm install -g @anthropic-ai/claude-code || err "npm install failed"
  log "Anthropic Claude Code installed"
}

# Install Coding Agent
install_coding_agent(){
  log "Installing Coding Agent..."
  npm install -g @mariozechner/pi-coding-agent || err "npm install failed"
  log "Coding Agent installed"
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
  enhancify           Install Enhancify
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
  copilot             Install GitHub Copilot
  claude              Install Anthropic Claude Code
  coding-agent        Install Coding Agent

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
    enhancify) install_enhancify ;;
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
    copilot) install_copilot ;;
    claude) install_claude ;;
    coding-agent) install_coding_agent ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
