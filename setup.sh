#!/data/data/com.termux/files/usr/bin/env bash
# Standalone Termux setup script - can be executed remotely via curl | bash
# Usage: curl -fsSL https://raw.githubusercontent.com/Ven0m0/dot-termux/main/setup.sh | bash
set -Eeuo pipefail; shopt -s nullglob globstar
IFS=$'\n\t'
export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive CARGO_HTTP_MULTIPLEXING=true CARGO_NET_GIT_FETCH_WITH_CLI=true OPT_LEVEL=3 CARGO_PROFILE_RELEASE_OPT_LEVEL=3 PYTHONOPTIMIZE=2

# ============================================================================
# INLINE UTILITIES (from common.sh for standalone execution)
# ============================================================================

# Color codes
readonly BLU=$'\e[34m' GRN=$'\e[32m' YLW=$'\e[33m' RED=$'\e[31m' DEF=$'\e[0m'

# Check if command exists
has(){ command -v -- "$1" &>/dev/null; }

# Ensure directory exists
ensure_dir(){
  local dir
  for dir in "$@"; do
    [[ -d $dir ]] || mkdir -p -- "$dir"
  done
}

# Universal find wrapper: fd with fallback to find
run_find(){
  if has fd; then
    fd "$@" 2>/dev/null || :
    return
  elif has fdfind; then
    fdfind "$@" 2>/dev/null || :
    return
  else
    find -O2 "$@" 2>/dev/null || :
    return
  fi

  # Fallback to find - parse common fd patterns
  local find_type="" find_path="." find_depth=""
  local -a find_names=() find_exec=() extra_args=()
  local null_sep=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -tf) find_type="-type f"; shift;;
      -td) find_type="-type d"; shift;;
      -e)
        shift
        find_names+=(-o -name "*.$1")
        shift
        ;;
      -d|--max-depth)
        shift
        find_depth="-maxdepth $1"
        shift
        ;;
      -x)
        shift
        extra_args+=(-executable)
        ;;
      -0) null_sep=1; shift;;
      .)
        shift
        ;;
      *)
        if [[ "$1" != -* ]]; then
          find_path="$1"
          shift
        else
          shift
        fi
        ;;
    esac
  done

  local -a cmd=("$find_path")
  [[ -n $find_depth ]] && cmd+=($find_depth)
  [[ -n $find_type ]] && cmd+=($find_type)
  if [[ ${#find_names[@]} -gt 0 ]]; then
    find_names=("${find_names[@]:1}")
    [[ ${#find_names[@]} -eq 1 ]] && cmd+=("${find_names[@]}") || cmd+=(\( "${find_names[@]}" \))
  fi
  [[ ${#extra_args[@]} -gt 0 ]] && cmd+=("${extra_args[@]}")
  [[ $null_sep -eq 1 ]] && cmd+=(-print0)
  find "${cmd[@]}" 2>/dev/null || :
}

# ============================================================================
# CONFIGURATION
# ============================================================================

REPO_URL="https://github.com/Ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"
LOG_FILE="$HOME/termux_setup.log"

# Logging helpers
log(){ printf '[%(%T)T] %s\n' -1 "$*" >>"$LOG_FILE"; }
step(){ printf "\n%s==>%s %s%s%s\n" "$BLU" "$DEF" "$GRN" "$*" "$DEF"; }

# --- Safe Remote Script Execution ---
run_installer(){
  local name=$1 url=$2
  step "Installing $name..."
  has "${name%%-*}" && {
    log "$name already installed."
    return 0
  }
  local script
  script=$(mktemp --suffix=".sh")
  if curl -fsSL --http2 --tcp-fastopen --connect-timeout 5 "$url" -o "$script"; then
    log "Downloaded $name. Executing..."
    (bash "$script" &>>"$LOG_FILE") || log "${RED}Failed to install $name${DEF}"
  else
    log "${RED}Failed to download $name installer from $url${DEF}"
  fi
  rm -f "$script"
}

# --- Setup Functions ---
setup_environment(){
  step "Setting up environment"
  ensure_dir "$HOME/.ssh" "$HOME/bin" "$HOME/.termux" "${XDG_CONFIG_HOME:-$HOME/.config}" \
    "${XDG_DATA_HOME:-$HOME/.local/share}" "${XDG_CACHE_HOME:-$HOME/.cache}"
  chmod 700 "$HOME/.ssh"
  [[ -f $HOME/.ssh/id_rsa ]] || {
    log "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
  }
}

configure_apt(){
  step "Configuring apt"
  local apt_conf_dir="/data/data/com.termux/files/usr/etc/apt/apt.conf.d"
  ensure_dir "$apt_conf_dir"
  cat >"$apt_conf_dir/99-termux-defaults" <<'EOF'
Dpkg::Options { "--force-confdef"; "--force-confold"; };
APT::Get::Assume-Yes "true";
APT::Get::allow-downgrades "true";
Acquire::Retries "3";
EOF
}

install_packages(){
  step "Updating repos and installing base packages"
  pkg up -y && pkg i -y tur-repo glibc-repo root-repo termux-api termux-services
  local -a pkgs=(
    stow yadm git gix gh zsh zsh-completions build-essential parallel rust rust-src sccache
    ripgrep fd sd eza bat dust nodejs uv esbuild fzf zoxide sheldon rush shfmt
    procps gawk jq aria2 topgrade imagemagick ffmpeg libwebp gifsicle pngquant
    optipng jpegoptim openjpeg chafa micro mold llvm openjdk-21 python python-pip
    aapt2 apksigner apkeditor android-tools binutils-is-llvm
  )
  log "Installing ${#pkgs[@]} packages..."
  pkg install -y "${pkgs[@]}" || log "${YLW}Some packages failed to install. Continuing...${DEF}"
}

install_fonts(){
  step "Installing JetBrains Mono font"
  local font_path="$HOME/.termux/font.ttf"
  [[ -f $font_path ]] && { log "Font already installed."; return 0; }
  local url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
  local tmp_zip; tmp_zip=$(mktemp --suffix=".zip")
  log "Downloading font..."
  curl -sL "$url" -o "$tmp_zip"
  unzip -jo "$tmp_zip" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$HOME/.termux/" &>/dev/null
  mv -f "$HOME/.termux/JetBrainsMono-Regular.ttf" "$font_path"
  rm -f "$tmp_zip"
  has termux-reload-settings && termux-reload-settings
}

install_rust_tools(){
  step "Installing additional Rust tools"
  export PATH="$HOME/.cargo/bin:$PATH"
  run_installer "cargo-binstall" "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh"
  local -a tools=(cargo-update oxipng rimage image-optimizer ffzap cargo-binstall minhtml simagef compresscli imgc)
  local -a missing=()
  for tool in "${tools[@]}"; do has "$tool" || missing+=("$tool"); done
  [[ ${#missing[@]} -gt 0 ]] && { cargo binstall -y "${missing[@]}" || cargo install "${missing[@]}"; }
}

install_third_party(){
  step "Installing third-party tools"
  run_installer "bun" "https://bun.sh/install"
  run_installer "mise" "https://mise.run"
  run_installer "pkgx" "https://pkgx.sh"
  run_installer "revancify" "https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh"
  if ! has jaq; then
    curl -fsL "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" -o "$HOME/bin/jaq" && chmod +x "$HOME/bin/jaq"
  fi
  if ! has apk.sh; then
    curl -fsL "https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh" -o "$HOME/bin/apk.sh" && chmod +x "$HOME/bin/apk.sh"
  fi
  if [[ ! -d "$HOME/DTL-X" ]]; then
    git clone --depth=1 "https://github.com/Gameye98/DTL-X.git" "$HOME/DTL-X" && bash "$HOME/DTL-X/termux_install.sh"
  fi
}

install_bat_extras(){
  step "Building and linking bat-extras"
  local repo="https://github.com/eth-p/bat-extras.git"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  local dest="$cache_dir/bat-extras"
  local inst_dir="${XDG_BIN_HOME:-$HOME/bin}"
  ensure_dir "$cache_dir" "$inst_dir"

  local git_cmd
  git_cmd=$(command -v gix || command -v git || printf '')
  [[ -n $git_cmd ]] || {
    log "git/gix not found; skipping bat-extras"
    return 0
  }

  if [[ -d "$dest/.git" ]]; then
    "$git_cmd" -C "$dest" pull -q --ff-only &>/dev/null || :
  else
    rm -rf "$dest"
    "$git_cmd" clone -q --depth=1 "$repo" "$dest" || {
      log "clone bat-extras failed"
      return 0
    }
  fi

  (cd "$dest" && chmod +x build.sh && bash build.sh --minify=all &>>"$LOG_FILE") || {
    log "build bat-extras failed"
    return 0
  }

  local -i count=0
  while IFS= read -r -d '' file; do
    ln -sf "$file" "$inst_dir/" || :
    ((count++))
  done < <(run_find -tf -x -d 2 . "$dest" -0)

  ((count > 0)) && log "Symlinked $count bat-extras executables to $inst_dir" || log "No bat-extras executables found"
}

setup_zsh(){
  step "Setting up Zsh and Sheldon"
  [[ ${SHELL##*/} != "zsh" ]] && chsh -s zsh
  # Sheldon will be configured via dotfiles
}

link_dotfiles(){
  step "Linking dotfiles using Stow"
  log "Stowing dotfiles from $REPO_PATH to $HOME"
  stow --dir="$REPO_PATH" --target="$HOME" --restow --no-folding zsh termux p10k

  log "Stowing scripts from $REPO_PATH/bin to $HOME/bin"
  while IFS= read -r -d '' script; do
    local base="${script##*/}"
    local target="$HOME/bin/${base%.sh}"
    ln -sf "$script" "$target"
    chmod +x "$target"
  done < <(run_find -tf -e sh . "$REPO_PATH/bin" -0)
}

finalize(){
  step "Finalizing setup"
  log "Applying Sheldon plugins..."
  sheldon lock
  zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do [[ -f $f ]] && zrecompile -pq "$f"; done' &>/dev/null || :
  cat >"$HOME/.welcome.msg" <<<"${BLU}🚀 Welcome to your optimized Termux environment 🚀${DEF}"
  step "✅ Setup Complete!"
  printf 'Restart Termux to apply all changes.\nLogs are in %s\n' "${YLW}$LOG_FILE${DEF}"
}

# --- Main Execution ---
main(){
  cd "$HOME"
  : >"$LOG_FILE"

  step "Ensuring essential tools are installed"
  pkg update -y &>/dev/null
  pkg install -y git curl gix &>/dev/null

  step "Bootstrapping dotfiles repository"
  if [[ -d $REPO_PATH/.git ]]; then
    log "Updating existing dot-termux repository..."
    (cd "$REPO_PATH" && git pull --rebase --autostash)
  else
    log "Cloning dot-termux repository..."
    git clone --depth=1 "$REPO_URL" "$REPO_PATH"
  fi

  setup_environment
  configure_apt
  install_packages &
  install_fonts &
  wait

  local -a pids=()
  install_rust_tools &
  pids+=($!)
  install_third_party &
  pids+=($!)
  install_bat_extras &
  pids+=($!)
  uv pip install -U TUIFIManager &
  pids+=($!)

  setup_zsh
  link_dotfiles

  log "Waiting for ${#pids[@]} background installations to finish..."
  for pid in "${pids[@]}"; do
    wait "$pid"
    log "Background task finished"
  done

  finalize
}

main "$@"
