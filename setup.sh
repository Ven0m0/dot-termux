#!/data/data/com.termux/files/usr/bin/env bash
set -uo pipefail; IFS=$'\n\t'
export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive
REPO_URL="https://github.com/ven0m0/dot-termux.git"; REPO_PATH="$HOME/dot-termux"; LOG_FILE="$HOME/termux_setup_log.txt"
RED="\033[0;31m"; GREEN="\033[0;32m"; BLUE="\033[0;34m"; YELLOW="\033[0;33m"; RESET="\033[0m"
SOAR_VERSION=latest; APT_CONF="/data/data/com.termux/files/usr/etc/apt/apt.conf.d/99-termux"
has(){ command -v -- "$1" >/dev/null 2>&1; }; log(){ printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
print_step(){ printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$1"; }
ensure_dir(){ [[ -d $1 ]] || mkdir -p "$1"; }; err(){ printf 'Error: %s\n' "$*" >&2; }

setup_apt_dpkg(){ print_step "Configuring apt/dpkg"; ensure_dir "$(dirname "$APT_CONF")"; cat >"$APT_CONF"<<'EOF'
Dpkg::Options { "--force-confdef"; "--force-confold"; }
APT::Get::Assume-Yes "true"; APT::Get::allow-downgrades "true"; APT::Get::allow-remove-essential "false"; APT::Get::allow-change-held-packages "false";
Acquire::Retries "3";
EOF
log "apt/dpkg configured"; }

symlink_dotfile(){ local src=$1 tgt=$2; ensure_dir "$(dirname "$tgt")"; [[ -e $tgt || -L $tgt ]] && mv -f "$tgt" "${tgt}.bak"; ln -sf "$src" "$tgt"; log "Linked '$tgt'"; }
check_internet(){ print_step "Checking internet"; has curl && curl -s --connect-timeout 3 -o /dev/null http://www.google.com || { err "No connection"; exit 1; }; log "Connected"; }

install_pkgs(){
  DEBIAN_FRONTEND=noninteractive pkg up -y && DEBIAN_FRONTEND=noninteractive pkg i -y tur-repo glibc-repo root-repo termux-api curl wget git -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
  local -a pkgs=(fd sd gitoxide gh python zoxide zsh zsh-completions uv shfmt rush
  runit rust rust-src sccache ripgrep procps sheldon parallel build-essential bash-completion libwebp gifsicle
  pngquant pngcrush optipng openjpeg imagemagick graphicsmagick jpegoptim ffmpeg 
  nodejs micro mold make llvm gawk fzf dust esbuild eza chafa bat openjdk-21 esbuild
  apksigner apkeditor aapt2 android-tools binutils-is-llvm jq python-pip topgrade aria2)
  DEBIAN_FRONTEND=noninteractive pkg i -y "${pkgs[@]}" -o 'Dpkg::Options::="--force-confdef"' -o 'Dpkg::Options::="--force-confold"' -o 'APT::Get::Assume-Yes "true"' || :
}
install_jetbrains_mono(){ print_step "Installing JetBrains Mono font"
  local font_dir="$HOME/.termux" url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
  ensure_dir "$font_dir"; local temp_zip=$(mktemp)
  curl -sL "$url" -o "$temp_zip" && unzip -jo "$temp_zip" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$font_dir" &>/dev/null && mv -f "$font_dir/JetBrainsMono-Regular.ttf" "$font_dir/font.ttf"
  has termux-reload-settings && termux-reload-settings &>/dev/null || :; rm -f "$temp_zip"; log "Font done"
}
setup_antidote(){ print_step "Setting up Antidote"
  local dir="${XDG_DATA_HOME:-$HOME/.local/share}/antidote"
  [[ -d $dir ]] || { ensure_dir "${dir%/*}"; git clone --depth 1 --filter='blob:none' --no-tags https://github.com/mattmc3/antidote "$dir" &>/dev/null || :; }
  log "Antidote ready"
}
install_rust_tools_fallback(){ print_step "Installing Rust tools (fallback)"
  [[ -x "$HOME/.cargo/bin/cargo-binstall" ]] || { curl -fsL https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash &>/dev/null; }
  local -a tools=(oxipng)
  for tool in "${tools[@]}"; do has "$tool" || "$HOME/.cargo/bin/cargo-binstall" -y "$tool" &>/dev/null & done
  log "Rust fallback tools installing"
}
install_node_tools(){ print_step "Installing bun"
  { has bun || { curl -fsL https://bun.sh/install | bash &>/dev/null; log "bun done"; } } &
}
install_mise(){ print_step "Installing mise"; has mise || { curl -fsL https://mise.run | sh &>/dev/null; log "mise done"; }; }
install_soar(){ print_step "Installing SOAR"; has soar || { curl -fsL https://soar.qaidvoid.dev/install.sh | sh &>/dev/null; log "SOAR done"; }; }
install_pkgx(){ print_step "Installing pkgx"; has pkgx || { curl -fsL https://pkgx.sh | sh &>/dev/null; log "pkgx done"; }; }

setup_revanced_tools(){ print_step "Setting up ReVanced tools"; ensure_dir "$HOME/bin"
  { curl -sL "https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh" | bash &>/dev/null && [[ -d $HOME/revancify-xisr ]] && ln -sf "$HOME/revancify-xisr/revancify.sh" "$HOME/bin/revancify-xisr" || :; log "Revancify done"; } &
  { curl -sL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh" && ln -sf "$HOME/.Simplify.sh" "$HOME/bin/simplify" && log "Simplify done"; } &
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
  { curl -fsL https://astral.sh/uv/install.sh | sh &>/dev/null; } &
  { curl -fsL https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh -o "$HOME/bin/apk.sh" && chmod +x "$HOME/bin/apk.sh"; } &
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
