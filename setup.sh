#!/usr/bin/env bash
# Termux setup script - resilient error handling
set -eo pipefail; shopt -s nullglob globstar
IFS=$'\n\t'; export LC_ALL=C LANG=C
cache=${XDG_CACHE_HOME:-$HOME/.cache}; [[ -d $cache ]] || cache=$HOME
logf=$HOME/termux_setup.log
repo_url=https://github.com/Ven0m0/dot-termux.git
repo_path=$HOME/dot-termux
has(){ command -v "$1" &>/dev/null; }
step(){ printf '==> %s\n' "$*"; }
log(){ printf '[%(%T)T] %s\n' -1 "$*" >>"$logf"; }
ensure(){ [[ -d $1 ]] || mkdir -p "$1"; }
download(){ curl -fsSL --connect-timeout 10 "$@"; }
yes | apt update --fix-missing; yes | pkg up -y; pkg upgrade -y
run_installer(){
  if has "${1%%-*}"; then log "$1 already installed."; return 0; fi
  local s=$cache/$1.sh
  if download "$2" -o "$s"; then
    bash "$s" &>>"$logf" || log "Failed: $1"
  else
    log "Failed: $1"
  fi; rm -f "$s"
}
setup_env(){
  ensure "$HOME/.ssh"; ensure "$HOME/bin"; ensure "$HOME/.termux"
  ensure "${XDG_CONFIG_HOME:-$HOME/.config}"
  ensure "${XDG_DATA_HOME:-$HOME/.local/share}"
  ensure "${XDG_CACHE_HOME:-$HOME/.cache}"
  chmod 700 "$HOME/.ssh"
  [[ -f $HOME/.ssh/id_rsa ]] || ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N "" &>/dev/null
}
install_pkgs(){
  step "Packages"
  pkg up -y || { log "pkg update failed"; return 1; }
  pkg i -y tur-repo glibc-repo root-repo termux-api termux-services || :
  local -a pkgs=(
    stow yadm git gh zsh zsh-completions build-essential parallel rust rust-src
    ripgrep sd eza bat dust nodejs fzf zoxide sheldon shfmt
    procps gawk jq aria2 imagemagick ffmpeg libwebp gifsicle pngquant
    optipng jpegoptim chafa micro mold llvm openjdk-21 python
    aapt2 apksigner android-tools binutils-is-llvm uv gitoxide
  )
  log "Installing ${#pkgs[@]} packages..."
  pkg install -y "${pkgs[@]}" || log "Some packages failed"
}
try_install_nerd_font(){
  local font=$1 tmp=$2
  download https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz -o "$tmp" 2>>"$logf" || return 1
  tar -xJf "$tmp" -C "$HOME/.termux/" JetBrainsMonoNerdFont-Regular.ttf 2>/dev/null || return 1
  mv "$HOME/.termux/JetBrainsMonoNerdFont-Regular.ttf" "$font" 2>/dev/null || return 1
  rm -f "$tmp"; log "Installed Nerd Font"
  has termux-reload-settings && termux-reload-settings || :
  return 0
}
try_install_regular_font(){
  local font=$1 tmp=$2
  has unzip || return 1
  download "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" -o "$tmp" 2>>"$logf" || return 1
  unzip -jo "$tmp" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$HOME/.termux/" &>/dev/null || return 1
  mv -f "$HOME/.termux/JetBrainsMono-Regular.ttf" "$font" 2>/dev/null || return 1
  rm -f "$tmp"; log "Installed regular JetBrains Mono"
  has termux-reload-settings && termux-reload-settings || :
  return 0
}
install_font(){
  step "Font"
  local font=$HOME/.termux/font.ttf tmp=$cache/jbm.tar.xz
  [[ -f $font ]] && { log "Font already installed"; return 0; }
  ensure "$HOME/.termux"
  try_install_nerd_font "$font" "$tmp" && return 0
  rm -f "$tmp"
  try_install_regular_font "$font" "$tmp" && return 0
  rm -f "$tmp"; log "Failed to install font"
}
install_rust_tools(){
  step "Rust tools"
  export PATH=$HOME/.cargo/bin:$PATH
  if ! has cargo; then log "No cargo"; return 1; fi
  run_installer "cargo-binstall" "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh"
  has cargo-binstall || return 0
  local -a tools=(cargo-update oxipng)
  local -a missing=()
  for t in "${tools[@]}"; do has "$t" || missing+=("$t"); done
  ((${#missing[@]})) && { cargo binstall -y "${missing[@]}" &>>"$logf" || cargo install --locked "${missing[@]}" &>>"$logf"; }
}
install_third_party(){
  step "3rd party"
  run_installer "bun" "https://bun.sh/install"
  if ! has jaq; then
    if download "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" -o "$HOME/.local/bin/jaq"; then
      chmod +x "$HOME/.local/bin/jaq" || :
    fi
  fi
  if ! has apk.sh; then
    if download "https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh" -o "$HOME/bin/apk.sh"; then
      chmod +x "$HOME/.local/bin/apk.sh" || :
    fi
  fi
}
install_bat_extras(){
  step "bat-extras"
  local repo=https://github.com/eth-p/bat-extras.git
  local dest=$cache/bat-extras inst=$HOME/bin
  ensure "$cache"; ensure "$inst"
  has git || return 0
  if [[ -d $dest/.git ]]; then
    git -C "$dest" pull -q --ff-only &>/dev/null || { rm -rf "$dest"; git clone -q --depth=1 "$repo" "$dest" || return 0; }
  else
    rm -rf "$dest"; git clone -q --depth=1 "$repo" "$dest" || return 0
  fi
  (cd "$dest" && bash build.sh --minify=all &>>"$logf") || return 0
  while IFS= read -r -d '' f; do
    if ln -sf "$f" "$inst/"; then chmod +x "$inst/${f##*/}" || :; fi
  done < <(find "$dest/bin" -type f -executable -maxdepth 2 -print0)
}
bootstrap_dotfiles(){
  step "Dotfiles"
  has git || return 1
  if [[ -d $repo_path/.git ]]; then
    git -C "$repo_path" pull --rebase --autostash &>/dev/null || {
      git clone --depth=1 "$repo_url" "$repo_path" || { log "Failed to sync repo"; return 1; }
    }
  else
    git clone --depth=1 "$repo_url" "$repo_path" || { log "Failed to sync repo"; return 1; }
  fi
  if has yadm; then
    if [[ ! -d $HOME/.local/share/yadm/repo.git ]]; then
      if yadm init &>>"$logf"; then yadm remote add origin "$repo_url" &>>"$logf"; fi
      if yadm fetch origin &>>"$logf"; then
        yadm reset --hard origin/main &>>"$logf" || yadm reset --hard origin/master &>>"$logf"
      fi
      if yadm checkout . &>>"$logf"; then
        [[ -x $HOME/.yadm/bootstrap ]] && bash "$HOME/.yadm/bootstrap" &>>"$logf" || :
      fi
    else
      yadm pull --rebase &>>"$logf" || log "Failed to pull yadm updates"
    fi
  fi
  if [[ -d $repo_path/bin ]]; then
    find "$repo_path/bin" -type f -executable -print0 | while IFS= read -r -d '' s; do
      if ln -sf "$s" "$HOME/bin/${s##*/}"; then chmod +x "$HOME/bin/${s##*/}"; fi
    done
  fi
}
setup_zsh(){
  has zsh && [[ ${SHELL##*/} != zsh ]] && chsh -s zsh || :
}
finalize(){
  has sheldon && sheldon lock &>/dev/null || log "Sheldon lock failed"
  if has zsh; then
    zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do [[ -f $f ]] && zrecompile -pq "$f"; done' &>/dev/null || log "Zsh recompile failed"
  fi
  echo "Welcome to optimized Termux" >"$HOME/.welcome.msg"
  step "Setup complete."; printf 'Restart Termux. Logs: %s\n' "$logf"
  has termux-setup-storage || log "termux-setup-storage not available"
}
main(){
  cd "$HOME" || { echo "Failed to change to HOME directory"; exit 1; }
  : >"$logf"
  step "Base tools"
  pkg update -y &>/dev/null || { echo "Failed to update pkg, continuing anyway..."; log "pkg update failed"; }
  pkg install -y git curl stow yadm &>/dev/null || { echo "Failed to install some base tools, continuing..."; log "Some base tools failed to install"; }
  bootstrap_dotfiles || log "bootstrap_dotfiles failed"
  setup_env || log "setup_env failed"
  install_pkgs || log "install_pkgs failed"
  install_font || log "install_font failed"
  install_rust_tools || log "install_rust_tools failed"
  install_third_party || log "install_third_party failed"
  install_bat_extras || log "install_bat_extras failed"
  setup_zsh || log "setup_zsh failed"
  finalize || log "finalize failed"
  echo; echo "Setup process completed. Check $logf for any errors."
}
main "$@"
