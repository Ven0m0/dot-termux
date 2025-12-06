#!/usr/bin/env bash
# Termux + Debian proot setup - resilient error handling
set -eo pipefail; shopt -s nullglob globstar; IFS=$'\n\t'; export LC_ALL=C LANG=C DEBIAN_FRONTEND=noninteractive
cache=${XDG_CACHE_HOME:-$HOME/.cache}; [[ -d $cache ]] || cache=$HOME
logf=$HOME/termux_setup.log
repo_url=https://github.com/Ven0m0/dot-termux.git
repo_path=$HOME/dot-termux
deb_user=user

has(){ command -v -- "$1" &>/dev/null; }
step(){ printf '==> %s\n' "$*"; }
log(){ printf '[%(%T)T] %s\n' -1 "$*" >>"$logf"; }
ensure(){ [[ -d $1 ]] || mkdir -p "$1"; }
download(){ curl -fsSL --connect-timeout 10 "$@"; }

setup_env(){
  ensure "$HOME/.ssh"; ensure "$HOME/bin"; ensure "$HOME/.termux"
  ensure "${XDG_CONFIG_HOME:-$HOME/.config}"; ensure "${XDG_DATA_HOME:-$HOME/.local/share}"; ensure "${XDG_CACHE_HOME:-$HOME/.cache}"
  chmod 700 "$HOME/.ssh"
  [[ -f $HOME/.ssh/id_rsa ]] || ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N "" &>/dev/null
}

install_termux_pkgs(){
  step "Termux packages"
  pkg update -y; apt-get install -f
  pkg i -y tur-repo glibc-repo root-repo termux-api termux-services x11-repo || :
  local -a pkgs=(
    stow yadm git gh zsh zsh-completions build-essential parallel
    ripgrep sd eza bat dust nodejs fzf zoxide shfmt
    procps gawk jq aria2 imagemagick ffmpeg libwebp gifsicle pngquant
    optipng jpegoptim chafa micro mold llvm openjdk-21 python
    aapt2 apksigner android-tools binutils-is-llvm gitoxide
    proot-distro pulseaudio termux-x11-nightly
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
}

try_install_regular_font(){
  local font=$1 tmp=$2
  has unzip || return 1
  download "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" -o "$tmp" 2>>"$logf" || return 1
  unzip -jo "$tmp" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$HOME/.termux/" &>/dev/null || return 1
  mv -f "$HOME/.termux/JetBrainsMono-Regular.ttf" "$font" 2>/dev/null || return 1
  rm -f "$tmp"; log "Installed regular JetBrains Mono"
  has termux-reload-settings && termux-reload-settings || :
}

install_font(){
  step "Font"
  local font=$HOME/.termux/font.ttf tmp=$cache/jbm.tar.xz
  [[ -f $font ]] && { log "Font exists"; return 0; }
  ensure "$HOME/.termux"
  try_install_nerd_font "$font" "$tmp" && return 0
  rm -f "$tmp"
  try_install_regular_font "$font" "$tmp" && return 0
  rm -f "$tmp"; log "Font install failed"
}

install_zimfw(){
  step "Zimfw"
  local zim_home=${ZIM_HOME:-$HOME/.zim}
  [[ -d $zim_home ]] && { log "Zimfw exists"; return 0; }
  download https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh || log "Zimfw install failed"
}

install_debian(){
  step "Debian proot"
  has proot-distro || { log "proot-distro missing"; return 1; }
  if ! proot-distro list 2>/dev/null | grep -q '^debian'; then
    proot-distro install debian || { log "Debian install failed"; return 1; }
  else
    log "Debian already installed"
  fi
}

configure_debian(){
  step "Debian configuration"
  proot-distro login debian --shared-tmp -- /bin/bash <<'DEBEOF'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  sudo locales curl git zsh ca-certificates xz-utils build-essential
sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen en_US.UTF-8 >/dev/null
update-locale LANG=en_US.UTF-8
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
id -u user &>/dev/null || useradd -m -s /bin/zsh user
echo "user ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/user
chmod 440 /etc/sudoers.d/user
apt-get autoremove -y -qq; apt-get clean
DEBEOF
}

install_debian_devtools(){
  step "Debian dev tools (mise, rust, bun)"
  proot-distro login debian --shared-tmp --user "$deb_user" -- /bin/bash <<'DEVEOF'
set -e
export HOME=/home/user
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
mkdir -p "$HOME/.local/bin"
# mise
if ! command -v mise &>/dev/null; then
  curl -fsSL https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
# rust via mise
if ! command -v cargo &>/dev/null; then
  mise use -g rust
  eval "$(mise activate bash)"
fi
# cargo-binstall
if command -v mise &>/dev/null; then
  mise use -g cargo-binstall oxipng bun
  #curl -fsSL https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
fi
# bun
if ! command -v bun &>/dev/null; then
  mise use -g 
fi
# zimfw in debian
# if [[ ! -d $HOME/.zim ]]; then
  # curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh || :
# fi
DEVEOF
}

install_third_party(){
  step "3rd party (Termux)"
  if !has jaq; then
    ensure "$HOME/.local/bin"
    if download "https://github.com/01mf02/jaq/releases/latest/download/jaq-$(uname -m)-unknown-linux-musl" -o "$HOME/.local/bin/jaq"; then
      chmod +x "$HOME/.local/bin/jaq" || :
    fi
  fi
  if !has apk.sh; then
    ensure "$HOME/bin"
    if download "https://raw.githubusercontent.com/ax/apk.sh/main/apk.sh" -o "$HOME/bin/apk.sh"; then
      chmod +x "$HOME/bin/apk.sh" || :
    fi
  fi
}

bootstrap_dotfiles(){
  step "Dotfiles"
  has git || return 1
  if [[ -d $repo_path/.git ]]; then
    git -C "$repo_path" pull --rebase --autostash &>/dev/null || \
      git clone --depth=1 --filter=blob:none "$repo_url" "$repo_path" || { log "Repo sync failed"; return 1; }
  else
    git clone --depth=1 --filter=blob:none "$repo_url" "$repo_path" || { log "Clone failed"; return 1; }
  fi
  if has yadm; then
    if [[ ! -d $HOME/.local/share/yadm/repo.git ]]; then
      yadm init &>>"$logf" && yadm remote add origin "$repo_url" &>>"$logf"
      yadm fetch origin &>>"$logf" && \
        { yadm reset --hard origin/main &>>"$logf" || yadm reset --hard origin/master &>>"$logf"; }
      yadm checkout . &>>"$logf"
      [[ -x $HOME/.yadm/bootstrap ]] && bash "$HOME/.yadm/bootstrap" &>>"$logf" || :
    else
      yadm pull --rebase &>>"$logf" || log "Yadm pull failed"
    fi
  fi
  if [[ -d $repo_path/bin ]]; then
    while IFS= read -r -d '' s; do
      ln -sf "$s" "$HOME/bin/${s##*/}"; chmod +x "$HOME/bin/${s##*/}"
    done < <(find "$repo_path/bin" -type f -executable -print0)
  fi
}

create_debian_launcher(){
  step "Debian launcher"
  cat >"$HOME/bin/debian" <<'LAUNCHER'
#!/usr/bin/env bash
set -eo pipefail
pkill -9 -f termux.x11 2>/dev/null || :
rm -rf "${TMPDIR:-/tmp}/"*pulse* 2>/dev/null || :
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 2>/dev/null || :
export XDG_RUNTIME_DIR=${TMPDIR:-/tmp}
termux-x11 :0 >/dev/null 2>&1 &
sleep 2
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || :
exec proot-distro login debian --shared-tmp -- /bin/bash
LAUNCHER
  chmod +x "$HOME/bin/debian"
}
setup_zsh(){ has zsh && [[ ${SHELL##*/} != zsh ]] && chsh -s zsh || :; }
finalize(){
  has zsh && zsh -c 'autoload -Uz zrecompile; for f in ~/.zshrc ~/.zshenv; do [[ -f $f ]] && zrecompile -pq "$f"; done' &>/dev/null || :
  echo "Welcome to optimized Termux + Debian" >"$HOME/.welcome.msg"
  step "Setup complete."; printf 'Restart Termux. Logs: %s\n' "$logf"
  has termux-setup-storage || log "termux-setup-storage unavailable"
}
main(){
  cd "$HOME" || { echo "Failed to cd HOME"; exit 1; }
  : >"$logf"
  step "Base tools"
  yes | pkg update -m &>/dev/null || log "pkg update failed"
  yes | pkg upgrade -y --with-new-pkgs --allow-unauthenticated &>/dev/null || :
  pkg i -y git curl stow yadm &>/dev/null || log "Base tools partial fail"
  bootstrap_dotfiles || log "bootstrap_dotfiles failed"
  setup_env || log "setup_env failed"
  install_termux_pkgs || log "install_termux_pkgs failed"
  install_font || log "install_font failed"
  install_zimfw || log "install_zimfw failed"
  install_third_party || log "install_third_party failed"
  install_debian || log "install_debian failed"
  configure_debian || log "configure_debian failed"
  install_debian_devtools || log "install_debian_devtools failed"
  create_debian_launcher || log "create_debian_launcher failed"
  setup_zsh || log "setup_zsh failed"
  finalize || log "finalize failed"
  echo; echo "Setup complete.Check $logf for errors."
}
main "$@"
