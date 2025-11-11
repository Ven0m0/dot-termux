#!/usr/bin/env bash
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t'
export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
[[ -d $CACHE ]] || CACHE="$HOME"

REPO_URL="https://github.com/Ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"
LOG_FILE="$HOME/termux_setup.log"
readonly BLU=$'\e[34m' GRN=$'\e[32m' YLW=$'\e[33m' RED=$'\e[31m' DEF=$'\e[0m'

has(){ command -v -- "$1" &>/dev/null; }
ensure_dir(){ local d; for d in "$@"; do [[ -d $d ]] || mkdir -p -- "$d"; done; }
log(){ printf '[%(%T)T] %s\n' -1 "$*" >>"$LOG_FILE"; }
step(){ printf "\n%s==>%s %s%s%s\n" "$BLU" "$DEF" "$GRN" "$*" "$DEF"; }

run_find(){
  local fd_cmd=""
  has fd && fd_cmd="fd" || { has fdfind && fd_cmd="fdfind"; }
  if [[ -n $fd_cmd ]]; then
    $fd_cmd "$@" 2>/dev/null || :
    return
  fi
  local type="" path="." depth="" null=0
  local -a names=() extra=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -tf) type="-type f"; shift;;
      -td) type="-type d"; shift;;
      -e) shift; names+=(-o -name "*.$1"); shift;;
      -d|--max-depth) shift; depth="-maxdepth $1"; shift;;
      -x) extra+=(-executable); shift;;
      -0) null=1; shift;;
      .) shift;;
      -*) shift;;
      *) path="$1"; shift;;
    esac
  done
  local -a cmd=("$path")
  [[ -n $depth ]] && cmd+=($depth)
  [[ -n $type ]] && cmd+=($type)
  if [[ ${#names[@]} -gt 0 ]]; then
    local -a fixed_names=("${names[@]}")
    [[ ${fixed_names[0]} == "-o" ]] && fixed_names=("${fixed_names[@]:1}")
    if (( ${#fixed_names[@]} == 1 )); then
      cmd+=("${fixed_names[@]}")
    else
      cmd+=( \( "${fixed_names[@]}" \) )
    fi
  fi
  [[ ${#extra[@]} -gt 0 ]] && cmd+=("${extra[@]}")
  ((null)) && cmd+=(-print0)
  find "${cmd[@]}" 2>/dev/null || :
}

run_installer(){
  local name=$1 url=$2
  step "Installing $name..."
  has "${name%%-*}" && { log "$name already installed."; return 0; }
  local script="$CACHE/${name}.sh"
  if curl -fsSL --connect-timeout 10 "$url" -o "$script"; then
    log "Downloaded $name. Executing..."
    bash "$script" &>>"$LOG_FILE" || log "${RED}Failed: $name${DEF}"
  else
    log "${RED}Download failed: $name${DEF}"
  fi
  rm -f "$script"
}

setup_environment(){
  step "Setting up environment"
  ensure_dir "$HOME/.ssh" "$HOME/bin" "$HOME/.termux" \
    "${XDG_CONFIG_HOME:-$HOME/.config}" \
    "${XDG_DATA_HOME:-$HOME/.local/share}" \
    "${XDG_CACHE_HOME:-$HOME/.cache}"
  chmod 700 "$HOME/.ssh"
  [[ -f $HOME/.ssh/id_rsa ]] || {
    log "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N "" &>/dev/null
  }
}

install_packages(){
  step "Updating repos and installing packages"
  pkg update -y || { log "${RED}pkg update failed${DEF}"; return 1; }
  pkg install -y tur-repo glibc-repo root-repo termux-api termux-services || :
  local -a pkgs=(
    stow yadm git gh zsh zsh-completions build-essential parallel rust rust-src
    ripgrep fd sd eza bat dust nodejs fzf zoxide sheldon shfmt
    procps gawk jq aria2 imagemagick ffmpeg libwebp gifsicle pngquant
    optipng jpegoptim chafa micro mold llvm openjdk-21 python
    aapt2 apksigner android-tools binutils-is-llvm uv gitoxide
  )
  log "Installing ${#pkgs[@]} packages..."
  pkg install -y "${pkgs[@]}" || log "${YLW}Some packages failed${DEF}"
}

install_fonts(){
  step "Installing JetBrains Mono font"
  local font="$HOME/.termux/font.ttf"
  [[ -f $font ]] && { log "Font exists."; return 0; }
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
  local tmp="$CACHE/font.tar.xz"
  if curl -fsSL "$url" -o "$tmp"; then
    tar -xJf "$tmp" -C "$HOME/.termux/" "JetBrainsMonoNerdFont-Regular.ttf" 2>/dev/null && \
    mv -f "$HOME/.termux/JetBrainsMonoNerdFont-Regular.ttf" "$font" || {
      log "${YLW}Fallback to non-nerd font${DEF}"
      curl -fsSL "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" -o "$tmp"
      unzip -jo "$tmp" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$HOME/.termux/" &>/dev/null
      mv -f "$HOME/.termux/JetBrainsMono-Regular.ttf" "$font"
    }
    rm -f "$tmp"
    has termux-reload-settings && termux-reload-settings || :
  else
    log "${RED}Font download failed${DEF}"
  fi
}

install_rust_tools(){
  step "Installing Rust tools"
  export PATH="$HOME/.cargo/bin:$PATH"
  has cargo || { log "${RED}Cargo not found${DEF}"; return 1; }
  run_installer "cargo-binstall" "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh"
  has cargo-binstall || return 0
  local -a tools=(cargo-update oxipng)
  local -a missing=()
  for t in "${tools[@]}"; do has "$t" || missing+=("$t"); done
  ((${#missing[@]})) && {
    log "Installing ${#missing[@]} Rust tools..."
    cargo binstall -y "${missing[@]}" &>>"$LOG_FILE" || \
    cargo install --locked "${missing[@]}" &>>"$LOG_FILE" || :
  }
}

install_third_party(){
  step "Installing third-party tools"
  run_installer "bun" "https://bun.sh/install"
  run_installer "mise" "https://mise.run"
  has jaq || {
    curl -fsSL "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" \
      -o "$HOME/bin/jaq" && chmod +x "$HOME/bin/jaq" || :
  }
  has apk.sh || {
    curl -fsSL "https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh" \
      -o "$HOME/bin/apk.sh" && chmod +x "$HOME/bin/apk.sh" || :
  }
}

install_bat_extras(){
  step "Building bat-extras"
  local repo="https://github.com/eth-p/bat-extras.git"
  local dest="$CACHE/bat-extras"
  local inst="$HOME/bin"
  ensure_dir "$CACHE" "$inst"
  has git || { log "No git; skip bat-extras"; return 0; }
  if [[ -d $dest/.git ]]; then
    git -C "$dest" pull -q --ff-only &>/dev/null || :
  else
    rm -rf "$dest"
    git clone -q --depth=1 "$repo" "$dest" || { log "Clone failed"; return 0; }
  fi
  (cd "$dest" && bash build.sh --minify=all &>>"$LOG_FILE") || { log "Build failed"; return 0; }
  local -i count=0
  while IFS= read -r -d '' f; do
    ln -sf "$f" "$inst/" && ((count++)) || :
  done < <(run_find -tf -x -d 2 . "$dest/bin" -0)
  log "Symlinked $count bat-extras"
}

bootstrap_dotfiles(){
  step "Bootstrapping dotfiles"
  has git || { log "${RED}Git required${DEF}"; return 1; }
  if [[ -d $REPO_PATH/.git ]]; then
    log "Updating dot-termux..."
    git -C "$REPO_PATH" pull --rebase --autostash &>/dev/null || :
  else
    log "Cloning dot-termux..."
    git clone --depth=1 "$REPO_URL" "$REPO_PATH" || return 1
  fi
  if has yadm && [[ ! -d $HOME/.local/share/yadm/repo.git ]]; then
    log "Initializing yadm..."
    yadm clone --bootstrap "$REPO_URL" &>>"$LOG_FILE" || {
      yadm init && yadm remote add origin "$REPO_URL" && yadm pull --rebase &>>"$LOG_FILE"
    }
  elif has yadm; then
    log "Updating yadm..."
    yadm pull --rebase &>>"$LOG_FILE" || :
  fi
  if has stow && [[ -d $REPO_PATH ]]; then
    log "Stowing dotfiles..."
    local -a stow_dirs=(zsh termux p10k)
    for d in "${stow_dirs[@]}"; do
      [[ -d $REPO_PATH/$d ]] && {
        stow --dir="$REPO_PATH" --target="$HOME" --restow --no-folding "$d" &>>"$LOG_FILE" || :
      }
    done
  fi
  [[ -d $REPO_PATH/bin ]] && {
    log "Linking scripts..."
    while IFS= read -r -d '' script; do
      local target="$HOME/bin/${script##*/}"; target="${target%.sh}"
      ln -sf "$script" "$target" && chmod +x "$target"
    done < <(run_find -tf -e sh . "$REPO_PATH/bin" -0)
  }
}

setup_zsh(){
  step "Setting up Zsh"
  has zsh || { log "${RED}Zsh not installed${DEF}"; return 1; }
  [[ ${SHELL##*/} != zsh ]] && chsh -s zsh || :
}

finalize(){
  step "Finalizing setup"
  has sheldon && { log "Locking Sheldon..."; sheldon lock &>/dev/null || :; }
  has zsh && zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do [[ -f $f ]] && zrecompile -pq "$f"; done' &>/dev/null || :
  cat >"$HOME/.welcome.msg" <<<"${BLU}🚀 Welcome to optimized Termux 🚀${DEF}"
  step "✅ Complete!"
  printf 'Restart Termux. Logs: %s\n' "${YLW}$LOG_FILE${DEF}"
}

main(){
  cd "$HOME" || exit 1
  : >"$LOG_FILE"
  step "Ensuring base tools"
  pkg update -y &>/dev/null || { echo "${RED}Failed to update pkg${DEF}"; exit 1; }
  pkg install -y git curl stow yadm &>/dev/null || { echo "${RED}Failed to install base tools${DEF}"; exit 1; }
  bootstrap_dotfiles || { log "${RED}Dotfiles failed${DEF}"; exit 1; }
  setup_environment
  install_packages
  install_fonts
  install_rust_tools
  install_third_party
  install_bat_extras
  setup_zsh
  finalize
}

main "$@"  done
  local -a cmd=("$path")
  [[ -n $depth ]] && cmd+=($depth)
  [[ -n $type ]] && cmd+=($type)
  if [[ ${#names[@]} -gt 0 ]]; then
    names=("${names[@]:1}")
    ((${#names[@]} == 1)) && cmd+=("${names[@]}") || cmd+=(\( "${names[@]}" \))
  fi
  [[ ${#extra[@]} -gt 0 ]] && cmd+=("${extra[@]}")
  ((null)) && cmd+=(-print0)
  find "${cmd[@]}" 2>/dev/null || :
}

run_installer(){
  local name=$1 url=$2
  step "Installing $name..."
  has "${name%%-*}" && { log "$name already installed."; return 0; }
  local script="$TMPDIR/${name}.sh"
  if curl -fsSL --connect-timeout 10 "$url" -o "$script"; then
    log "Downloaded $name. Executing..."
    bash "$script" &>>"$LOG_FILE" || log "${RED}Failed: $name${DEF}"
  else
    log "${RED}Download failed: $name${DEF}"
  fi
  rm -f "$script"
}

setup_environment(){
  step "Setting up environment"
  ensure_dir "$HOME/.ssh" "$HOME/bin" "$HOME/.termux" \
    "${XDG_CONFIG_HOME:-$HOME/.config}" \
    "${XDG_DATA_HOME:-$HOME/.local/share}" \
    "${XDG_CACHE_HOME:-$HOME/.cache}"
  chmod 700 "$HOME/.ssh"
  [[ -f $HOME/.ssh/id_rsa ]] || {
    log "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N "" &>/dev/null
  }
}

install_packages(){
  step "Updating repos and installing packages"
  pkg update -y || { log "${RED}pkg update failed${DEF}"; return 1; }
  pkg install -y tur-repo glibc-repo root-repo termux-api termux-services || :
  local -a pkgs=(
    stow yadm git gh zsh zsh-completions build-essential parallel rust rust-src
    ripgrep fd sd eza bat dust nodejs fzf zoxide sheldon shfmt
    procps gawk jq aria2 imagemagick ffmpeg libwebp gifsicle pngquant
    optipng jpegoptim chafa micro mold llvm openjdk-21 python
    aapt2 apksigner android-tools binutils-is-llvm uv gitoxide
  )
  log "Installing ${#pkgs[@]} packages..."
  pkg install -y "${pkgs[@]}" || log "${YLW}Some packages failed${DEF}"
}

install_fonts(){
  step "Installing JetBrains Mono font"
  local font="$HOME/.termux/font.ttf"
  [[ -f $font ]] && { log "Font exists."; return 0; }
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
  local tmp="$TMPDIR/font.tar.xz"
  if curl -fsSL "$url" -o "$tmp"; then
    tar -xJf "$tmp" -C "$HOME/.termux/" "JetBrainsMonoNerdFont-Regular.ttf" 2>/dev/null && \
    mv -f "$HOME/.termux/JetBrainsMonoNerdFont-Regular.ttf" "$font" || {
      log "${YLW}Fallback to non-nerd font${DEF}"
      curl -fsSL "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" -o "$tmp"
      unzip -jo "$tmp" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$HOME/.termux/" &>/dev/null
      mv -f "$HOME/.termux/JetBrainsMono-Regular.ttf" "$font"
    }
    rm -f "$tmp"
    has termux-reload-settings && termux-reload-settings || :
  else
    log "${RED}Font download failed${DEF}"
  fi
}

install_rust_tools(){
  step "Installing Rust tools"
  export PATH="$HOME/.cargo/bin:$PATH"
  has cargo || { log "${RED}Cargo not found${DEF}"; return 1; }
  run_installer "cargo-binstall" "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh"
  has cargo-binstall || return 0
  local -a tools=(cargo-update oxipng)
  local -a missing=()
  for t in "${tools[@]}"; do has "$t" || missing+=("$t"); done
  ((${#missing[@]})) && {
    log "Installing ${#missing[@]} Rust tools..."
    cargo binstall -y "${missing[@]}" &>>"$LOG_FILE" || \
    cargo install --locked "${missing[@]}" &>>"$LOG_FILE" || :
  }
}

install_third_party(){
  step "Installing third-party tools"
  run_installer "bun" "https://bun.sh/install"
  run_installer "mise" "https://mise.run"
  has jaq || {
    curl -fsSL "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" \
      -o "$HOME/bin/jaq" && chmod +x "$HOME/bin/jaq" || :
  }
  has apk.sh || {
    curl -fsSL "https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh" \
      -o "$HOME/bin/apk.sh" && chmod +x "$HOME/bin/apk.sh" || :
  }
}

install_bat_extras(){
  step "Building bat-extras"
  local repo="https://github.com/eth-p/bat-extras.git"
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}"
  local dest="$cache/bat-extras"
  local inst="$HOME/bin"
  ensure_dir "$cache" "$inst"
  has git || { log "No git; skip bat-extras"; return 0; }
  if [[ -d $dest/.git ]]; then
    git -C "$dest" pull -q --ff-only &>/dev/null || :
  else
    rm -rf "$dest"
    git clone -q --depth=1 "$repo" "$dest" || { log "Clone failed"; return 0; }
  fi
  (cd "$dest" && bash build.sh --minify=all &>>"$LOG_FILE") || { log "Build failed"; return 0; }
  local -i count=0
  while IFS= read -r -d '' f; do
    ln -sf "$f" "$inst/" && ((count++)) || :
  done < <(run_find -tf -x -d 2 . "$dest/bin" -0)
  log "Symlinked $count bat-extras"
}

bootstrap_dotfiles(){
  step "Bootstrapping dotfiles"
  has git || { log "${RED}Git required${DEF}"; return 1; }
  if [[ -d $REPO_PATH/.git ]]; then
    log "Updating dot-termux..."
    git -C "$REPO_PATH" pull --rebase --autostash &>/dev/null || :
  else
    log "Cloning dot-termux..."
    git clone --depth=1 "$REPO_URL" "$REPO_PATH" || return 1
  fi
  if has yadm && [[ ! -d $HOME/.local/share/yadm/repo.git ]]; then
    log "Initializing yadm..."
    yadm clone --bootstrap "$REPO_URL" &>>"$LOG_FILE" || {
      yadm init && yadm remote add origin "$REPO_URL" && yadm pull --rebase &>>"$LOG_FILE"
    }
  elif has yadm; then
    log "Updating yadm..."
    yadm pull --rebase &>>"$LOG_FILE" || :
  fi
  if has stow && [[ -d $REPO_PATH ]]; then
    log "Stowing dotfiles..."
    local -a stow_dirs=(zsh termux p10k)
    for d in "${stow_dirs[@]}"; do
      [[ -d $REPO_PATH/$d ]] && {
        stow --dir="$REPO_PATH" --target="$HOME" --restow --no-folding "$d" &>>"$LOG_FILE" || :
      }
    done
  fi
  [[ -d $REPO_PATH/bin ]] && {
    log "Linking scripts..."
    while IFS= read -r -d '' script; do
      local target="$HOME/bin/${script##*/}"; target="${target%.sh}"
      ln -sf "$script" "$target" && chmod +x "$target"
    done < <(run_find -tf -e sh . "$REPO_PATH/bin" -0)
  }
}

setup_zsh(){
  step "Setting up Zsh"
  has zsh || { log "${RED}Zsh not installed${DEF}"; return 1; }
  [[ ${SHELL##*/} != zsh ]] && chsh -s zsh || :
}

finalize(){
  step "Finalizing setup"
  has sheldon && { log "Locking Sheldon..."; sheldon lock &>/dev/null || :; }
  has zsh && zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do [[ -f $f ]] && zrecompile -pq "$f"; done' &>/dev/null || :
  cat >"$HOME/.welcome.msg" <<<"${BLU}🚀 Welcome to optimized Termux 🚀${DEF}"
  step "✅ Complete!"
  printf 'Restart Termux. Logs: %s\n' "${YLW}$LOG_FILE${DEF}"
}

main(){
  cd "$HOME" || exit 1
  : >"$LOG_FILE"
  step "Ensuring base tools"
  pkg update -y &>/dev/null || { echo "${RED}Failed to update pkg${DEF}"; exit 1; }
  pkg install -y git curl stow yadm &>/dev/null || { echo "${RED}Failed to install base tools${DEF}"; exit 1; }
  bootstrap_dotfiles || { log "${RED}Dotfiles failed${DEF}"; exit 1; }
  setup_environment
  install_packages
  install_fonts
  install_rust_tools
  install_third_party
  install_bat_extras
  setup_zsh
  finalize
}

main "$@"
