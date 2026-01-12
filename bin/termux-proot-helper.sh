#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
# Proot-distro helper utilities
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'

# Colors (trans palette)
readonly LBLU=$'\e[38;5;117m' PNK=$'\e[38;5;218m' BWHT=$'\e[97m'
readonly RED=$'\e[31m' GRN=$'\e[32m' YLW=$'\e[33m' DEF=$'\e[0m'

has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '%s[INFO]%s %s\n' "$GRN" "$DEF" "$*"; }
warn(){ printf '%s[WARN]%s %s\n' "$YLW" "$DEF" "$*" >&2; }
err(){ printf '%s[ERROR]%s %s\n' "$RED" "$DEF" "$*" >&2; exit 1; }

# Run command in proot-distro
# Usage: proot_run <distro> <command>
proot_run(){
  local distro="${1:?distro required}"
  local cmd="${2:?command required}"
  has proot-distro || err "proot-distro not installed"
  
  log "Running in proot ($distro): $cmd"
  proot-distro login "$distro" --shared-tmp -- bash -c "$cmd"
}

# Patch activity manager for performance
# https://github.com/termux/termux-api/issues/552#issuecomment-1382722639
patch_am(){
  local am_path="${PREFIX:-/data/data/com.termux/files/usr}/bin/am"
  local pat="app_process"
  local patch="-Xnoimage-dex2oat"
  
  [[ ! -f "$am_path" ]] && { warn "am not found at $am_path"; return 1; }
  
  if grep -q "$patch" "$am_path"; then
    log "AM already patched"
    return 0
  fi
  
  log "Patching AM for performance..."
  sed -i "/$pat/!b; /$patch/b; s/$pat/& $patch/" "$am_path" || err "Failed to patch AM"
  log "AM patched successfully"
}

# Setup proot-distro debian with essentials
setup_proot_debian(){
  has proot-distro || err "proot-distro not installed"
  
  if proot-distro list 2>/dev/null | grep -q '^debian'; then
    log "Debian proot already installed"
  else
    log "Installing Debian proot..."
    proot-distro install debian || err "Failed to install Debian"
  fi
  
  log "Updating Debian packages..."
  proot_run debian 'apt update && apt upgrade -y' || warn "Update failed"
  
  log "Installing essential packages..."
  proot_run debian 'apt install -y git gcc binutils make' || warn "Package install partial fail"
}

# Show usage
usage(){
  cat <<EOF
Proot-distro helper utilities

USAGE:
  $(basename "$0") patch-am              Patch activity manager
  $(basename "$0") setup-debian          Setup Debian proot
  $(basename "$0") run <distro> <cmd>    Run command in proot

EXAMPLES:
  $(basename "$0") patch-am
  $(basename "$0") setup-debian
  $(basename "$0") run debian "apt update && apt upgrade -y"
EOF
}

main(){
  case "${1:-}" in
    patch-am) patch_am ;;
    setup-debian) setup_proot_debian ;;
    run) shift; proot_run "$@" ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
