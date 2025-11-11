#!/data/data/com.termux/files/usr/bin/env bash
set -Eeuo pipefail; shopt -s nullglob globstar extglob
IFS=$'\n\t'
export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive CARGO_HTTP_MULTIPLEXING=true CARGO_NET_GIT_FETCH_WITH_CLI=true OPT_LEVEL=3 CARGO_PROFILE_RELEASE_OPT_LEVEL=3 PYTHONOPTIMIZE=2

# ============================================================================
# CONFIGURATION
# ============================================================================
REPO_URL="https://github.com/Ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"
LOG_FILE="$HOME/termux_setup.log"
readonly BLU=$'\e[34m' GRN=$'\e[32m' YLW=$'\e[33m' RED=$'\e[31m' DEF=$'\e[0m'

# ============================================================================
# UTILITIES
# ============================================================================
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
  # Fallback: parse common fd patterns for find
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
    names=("${names[@]:1}")
    ((${#names[@]} == 1)) && cmd+=("${names[@]}") || cmd+=(\( "${names[@]}" \))
  fi
  [[ ${#extra[@]} -gt 0 ]] && cmd+=("${extra[@]}")
  ((null)) && cmd+=(-print0)
  find -O2 "${cmd[@]}" 2>/dev/null || :
}

run_installer(){
  local name=$1 url=$2
  step "Installing $name..."
  has "${name%%-*}" && { log "$name already installed."; return 0; }
  local script; script=$(mktemp --suffix=".sh")
  if curl -fsSL --http2 --tcp-fastopen --connect-timeout 5 "$url" -o "$script"; then
    log "Downloaded $name. Executing..."
    bash "$script" &>>"$LOG_FILE" || log "${RED}Failed: $name${DEF}"
  else
    log "${RED}Download failed: $name${DEF}"
  fi
  rm -f "$script"
}

# ============================================================================
# SETUP STAGES
# ============================================================================
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

configure_apt(){
  step "Configuring apt"
  local apt_conf="/data/data/com.termux/files/usr/etc/apt/apt.conf.d/99-termux-defaults"
  ensure_dir "${apt_conf%/*}"
  cat >"$apt_conf" <<'EOF'
Dpkg::Options { "--force-confdef"; "--force-confold"; };
APT::Get::Assume-Yes "true";
APT::Get::allow-downgrades "true";
Acquire::Retries "3";
EOF
}

install_packages(){
  step "Updating repos and installing packages"
  pkg up -y && pkg i -y tur-repo glibc-repo root-repo termux-api termux-services
  local -a pkgs=(
    stow yadm git gix gh zsh zsh-completions build-essential parallel rust rust-src sccache
    ripgrep fd sd eza bat dust nodejs uv esbuild fzf zoxide sheldon rush shfmt
    procps gawk jq aria2 topgrade imagemagick ffmpeg libwebp gifsicle pngquant
    optipng jpegoptim openjpeg chafa micro mold llvm openjdk-21 python python-pip
    aapt2 apksigner apkeditor android-tools binutils-is-llvm
  )
  log "Installing ${#pkgs[@]} packages..."
  pkg install -y "${pkgs[@]}" || log "${YLW}Some packages failed${DEF}"
}

install_fonts(){
  step "Installing JetBrains Mono font"
  local font="$HOME/.termux/font.ttf"
  [[ -f $font ]] && { log "Font exists."; return 0; }
  local url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
  local tmp; tmp=$(mktemp --suffix=".zip")
  curl -sL "$url" -o "$tmp"
  unzip -jo "$tmp" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$HOME/.termux/" &>/dev/null
  mv -f "$HOME/.termux/JetBrainsMono-Regular.ttf" "$font"
  rm -f "$tmp"
  has termux-reload-settings && termux-reload-settings || :
}

install_rust_tools(){
  step "Installing Rust tools"
  export PATH="$HOME/.cargo/bin:$PATH"
  run_installer "cargo-binstall" "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh"
  local -a tools=(cargo-update oxipng rimage image-optimizer ffzap minhtml simagef compresscli imgc)
  local -a missing=()
  for t in "${tools[@]}"; do has "$t" || missing+=("$t"); done
  ((${#missing[@]})) && {
    cargo binstall -y "${missing[@]}" || \
    cargo install -Zunstable-options -Zgit -Zgitoxide -Zavoid-dev-deps --locked -f "${missing[@]}"
  }
}

install_third_party(){
  step "Installing third-party tools"
  run_installer "bun" "https://bun.sh/install"
  run_installer "mise" "https://mise.run"
  run_installer "pkgx" "https://pkgx.sh"
  run_installer "revancify" "https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh"
  has jaq || {
    curl -fsL "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" \
      -o "$HOME/bin/jaq" && chmod +x "$HOME/bin/jaq"
  }
  has apk.sh || {
    curl -fsL "https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh" \
      -o "$HOME/bin/apk.sh" && chmod +x "$HOME/bin/apk.sh"
  }
  [[ -d $HOME/DTL-X ]] || {
    git clone --depth=1 "https://github.com/Gameye98/DTL-X.git" "$HOME/DTL-X" && \
    bash "$HOME/DTL-X/termux_install.sh" &>>"$LOG_FILE"
  }
}

install_bat_extras(){
  step "Building bat-extras"
  local repo="https://github.com/eth-p/bat-extras.git"
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}"
  local dest="$cache/bat-extras"
  local inst="${XDG_BIN_HOME:-$HOME/bin}"
  ensure_dir "$cache" "$inst"
  local git_cmd; git_cmd=$(command -v gix || command -v git || :)
  [[ -z $git_cmd ]] && { log "No git; skip bat-extras"; return 0; }
  if [[ -d $dest/.git ]]; then
    "$git_cmd" -C "$dest" pull -q --ff-only &>/dev/null || :
  else
    rm -rf "$dest"
    "$git_cmd" clone -q --depth=1 "$repo" "$dest" || { log "Clone failed"; return 0; }
  fi
  (cd "$dest" && chmod +x build.sh && bash build.sh --minify=all &>>"$LOG_FILE") || { log "Build failed"; return 0; }
  local -i count=0
  while IFS= read -r -d '' f; do
    ln -sf "$f" "$inst/" && ((count++)) || :
  done < <(run_find -tf -x -d 2 . "$dest" -0)
  log "Symlinked $count bat-extras to $inst"
}

bootstrap_dotfiles(){
  step "Bootstrapping dotfiles"
  has yadm || { log "Installing yadm..."; pkg install -y yadm &>/dev/null; }
  has stow || { log "Installing stow..."; pkg install -y stow &>/dev/null; }
  if [[ -d $REPO_PATH/.git ]]; then
    log "Updating dot-termux..."
    (cd "$REPO_PATH" && git pull --rebase --autostash &>/dev/null) || :
  else
    log "Cloning dot-termux..."
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  fi
  # Use yadm for git-tracked dotfiles
  if [[ ! -d $HOME/.local/share/yadm/repo.git ]]; then
    log "Initializing yadm..."
    yadm clone --bootstrap "$REPO_URL" &>>"$LOG_FILE" || \
    yadm init && yadm remote add origin "$REPO_URL" && yadm pull --rebase &>>"$LOG_FILE" || :
  else
    log "Updating yadm..."
    yadm pull --rebase &>>"$LOG_FILE" || :
  fi
  # Use stow for organized configs
  if [[ -d $REPO_PATH ]]; then
    log "Stowing dotfiles..."
    local -a stow_dirs=(zsh termux p10k)
    for d in "${stow_dirs[@]}"; do
      [[ -d $REPO_PATH/$d ]] && {
        stow --dir="$REPO_PATH" --target="$HOME" --restow --no-folding "$d" &>>"$LOG_FILE" || :
      }
    done
  fi
  # Link scripts
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
  [[ ${SHELL##*/} != zsh ]] && chsh -s zsh
}

finalize(){
  step "Finalizing setup"
  has sheldon && { log "Locking Sheldon..."; sheldon lock &>/dev/null || :; }
  zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do [[ -f $f ]] && zrecompile -pq "$f"; done' &>/dev/null || :
  cat >"$HOME/.welcome.msg" <<<"${BLU}🚀 Welcome to optimized Termux 🚀${DEF}"
  step "✅ Complete!"
  printf 'Restart Termux. Logs: %s\n' "${YLW}$LOG_FILE${DEF}"
}

# ============================================================================
# MAIN
# ============================================================================
main(){
  cd "$HOME"
  : >"$LOG_FILE"
  step "Ensuring base tools"
  pkg update -y &>/dev/null
  pkg install -y git curl gix stow yadm &>/dev/null
  bootstrap_dotfiles
  setup_environment
  configure_apt
  install_packages &
  install_fonts &
  wait
  local -a pids=()
  install_rust_tools & pids+=($!)
  install_third_party & pids+=($!)
  install_bat_extras & pids+=($!)
  uv pip install -U TUIFIManager &>/dev/null & pids+=($!)
  setup_zsh
  log "Waiting for ${#pids[@]} background tasks..."
  for p in "${pids[@]}"; do wait "$p"; done
  finalize
}

main "$@"
