#!/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t'; export LC_ALL=C LANG=C 

cache="${XDG_CACHE_HOME:-$HOME/.cache}"; [[ -d $cache ]] || cache="$HOME"
logf="$HOME/termux_setup.log"
repo_url="https://github.com/Ven0m0/dot-termux.git"
repo_path="$HOME/dot-termux"

has(){ command -v "$1" &>/dev/null; }
step(){ printf '==> %s\n' "$*"; }
log(){ printf '[%(%T)T] %s\n' -1 "$*" >>"$logf"; }
ensure(){ [[ -d $1 ]] || mkdir -p "$1"; }

run_installer(){
  has "${1%%-*}" && { log "$1 already installed."; return 0; }
  local s="$cache/$1.sh"
  curl -fsSL --connect-timeout 10 "$2" -o "$s" && bash "$s" &>>"$logf" || log "Failed: $1"
  rm -f "$s"
}

setup_env(){
  ensure "$HOME/.ssh"; ensure "$HOME/bin"; ensure "$HOME/.termux"
  ensure "${XDG_CONFIG_HOME:-$HOME/.config}"
  ensure "${XDG_DATA_HOME:-$HOME/.local/share}"
  ensure "${XDG_CACHE_HOME:-$HOME/.cache}"
  mkdir -p "$HOME/bin"
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

install_font(){
  step "Font"
  local font="$HOME/.termux/font.ttf" tmp="$cache/jbm.tar.xz"
  [[ -f $font ]] && return 0
  curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz -o "$tmp" &&
    tar -xJf "$tmp" -C "$HOME/.termux/" JetBrainsMonoNerdFont-Regular.ttf 2>/dev/null &&
    mv "$HOME/.termux/JetBrainsMonoNerdFont-Regular.ttf" "$font" &&
    rm -f "$tmp" || {
      curl -fsSL "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" -o "$tmp"
      unzip -jo "$tmp" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$HOME/.termux/" &>/dev/null
      mv -f "$HOME/.termux/JetBrainsMono-Regular.ttf" "$font"
      rm -f "$tmp"
    }
  has termux-reload-settings && termux-reload-settings || :
}

install_rust_tools(){
  step "Rust tools"
  export PATH="$HOME/.cargo/bin:$PATH"
  has cargo || { log "No cargo"; return 1; }
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
  run_installer "mise" "https://mise.run"
  has jaq || curl -fsSL "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" -o "$HOME/bin/jaq" && chmod +x "$HOME/bin/jaq" || :
  has apk.sh || curl -fsSL "https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh" -o "$HOME/bin/apk.sh" && chmod +x "$HOME/bin/apk.sh" || :
}

install_bat_extras(){
  step "bat-extras"
  local repo="https://github.com/eth-p/bat-extras.git"
  local dest="$cache/bat-extras" inst="$HOME/bin"
  ensure "$cache"; ensure "$inst"
  has git || return 0
  [[ -d $dest/.git ]] && git -C "$dest" pull -q --ff-only &>/dev/null || { rm -rf "$dest"; git clone -q --depth=1 "$repo" "$dest" || return 0; }
  (cd "$dest" && bash build.sh --minify=all &>>"$logf") || return 0
  while IFS= read -r -d '' f; do ln -sf "$f" "$inst/" && chmod +x "$inst/${f##*/}" || :; done < <(find "$dest/bin" -type f -executable -maxdepth 2 -print0)
}

bootstrap_dotfiles(){
  step "Dotfiles"
  has git || return 1
  [[ -d $repo_path/.git ]] && git -C "$repo_path" pull --rebase --autostash &>/dev/null || git clone --depth=1 "$repo_url" "$repo_path"
  if has yadm && [[ ! -d $HOME/.local/share/yadm/repo.git ]]; then
    yadm clone --bootstrap "$repo_url" &>>"$logf" || { yadm init && yadm remote add origin "$repo_url" && yadm pull --rebase &>>"$logf"; }
  elif has yadm; then
    yadm pull --rebase &>>"$logf" || :
  fi
  if has stow && [[ -d $repo_path ]]; then
    for d in zsh termux p10k; do [[ -d $repo_path/$d ]] && stow --dir="$repo_path" --target="$HOME" --restow --no-folding "$d" &>>"$logf" || :; done
  fi
  [[ -d $repo_path/bin ]] && while IFS= read -r -d '' s; do tgt="$HOME/bin/${s##*/}"; tgt="${tgt%.sh}"; ln -sf "$s" "$tgt"; chmod +x "$tgt"; done < <(find "$repo_path/bin" -type f -name "*.sh" -print0)
}

setup_zsh(){
  has zsh && [[ ${SHELL##*/} != zsh ]] && chsh -s zsh || :
}

finalize(){
  has sheldon && sheldon lock &>/dev/null || :
  has zsh && zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do [[ -f $f ]] && zrecompile -pq "$f"; done' &>/dev/null || :
  echo "🚀 Welcome to optimized Termux 🚀" >"$HOME/.welcome.msg"
  step "Setup complete."
  printf 'Restart Termux. Logs: %s\n' "$logf"
  termux-setup-storage
  termux-change-repo
}

main(){
  cd "$HOME" || exit 1
  : >"$logf"
  step "Base tools"
  pkg update -y &>/dev/null || { echo "Failed to update pkg"; exit 1; }
  pkg install -y git curl stow yadm &>/dev/null || { echo "Failed to install base tools"; exit 1; }
  bootstrap_dotfiles
  setup_env
  install_pkgs
  install_font
  install_rust_tools
  install_third_party
  install_bat_extras
  setup_zsh
  finalize
}

main "$@"
