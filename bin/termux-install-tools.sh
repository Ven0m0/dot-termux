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
download(){ curl -fsSL --connect-timeout 10 "$@"; }

# Install TermuxVoid repo
install_termuxvoid(){
  log "Installing TermuxVoid repo..."
  download https://termuxvoid.github.io/repo/install.sh | bash || err "TermuxVoid install failed"
  log "TermuxVoid repo installed"
}

# Install TermuxVoid theme
install_termuxvoid_theme(){
  log "Installing TermuxVoid theme..."
  local script="termuxvoid-theme.sh"
  download -o "$script" https://github.com/termuxvoid/TermuxVoid-Theme/raw/main/termuxvoid-theme.sh || err "Download failed"
  bash "$script"
  rm -f "$script"
  log "TermuxVoid theme installed"
}

# Install X-CMD
install_xcmd(){
  log "Installing X-CMD..."
  eval "$(download https://get.x-cmd.com)" || err "X-CMD install failed"
  log "X-CMD installed"
}

# Install LURE package manager
install_lure(){
  log "Installing LURE..."
  download https://lure.sh/install | bash || err "LURE install failed"
  log "LURE installed"
}

# Install Soar package manager
install_soar(){
  log "Installing Soar..."
  download https://soar.qaidvoid.dev/install.sh | sh || err "Soar install failed"
  log "Soar installed"
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
    git clone --depth 1 --filter blob:none https://github.com/jecis-repos/termux-shizuku-tools.git "$dir" || err "Clone failed"
  fi
  
  cd "$dir"
  chmod +x setup.sh
  bash setup.sh || err "Setup failed"
  log "termux-shizuku-tools installed"
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
  local script="rvx-builder.sh"
  download -o "$script" https://raw.githubusercontent.com/inotia00/rvx-builder/revanced-extended/android-interface.sh || err "Download failed"
  chmod +x "$script"
  log "RVX Builder downloaded to $script"
  log "Run: ./$script"
}

# Install Simplify
install_simplify(){
  log "Installing Simplify..."
  pkg update &>/dev/null || :
  pkg install --only-upgrade apt bash coreutils openssl -y &>/dev/null || :
  download -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh" || err "Download failed"
  bash "$HOME/.Simplify.sh" || err "Installation failed"
  log "Simplify installed"
}

# Usage
usage(){
  cat <<EOF
Third-party tool installers for Termux

USAGE:
  $(basename "$0") <tool>

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
  $(basename "$0") termuxvoid
  $(basename "$0") xcmd
  $(basename "$0") revancify-xisr
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
