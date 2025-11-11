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
  chmod 700 "$HOME/.ssh"
  [[ -f $HOME/.ssh/id_rsa ]] || ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N "" &>/dev/null
}

install_pkgs(){
  step "Packages"
  pkg update -y || { log "pkg update failed"; return 1; }
  pkg install -y tur-repo glibc-repo root-repo termux-api termux-services || :
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
    ripgrep sd eza bat dust nodejs fzf zoxide sheldon shfmt
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
  done < <(find_files -type f -x -d 2 -0 -- "$dest/bin")
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
    done < <(find_files -type f -name sh -0 -- "$REPO_PATH/bin")
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

main "$@"      -*) shift;;
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
