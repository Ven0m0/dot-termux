#!/data/data/com.termux/files/usr/bin/bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
# SSH utilities for Termux
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'

# Colors
readonly GRN=$'\e[32m' YLW=$'\e[33m' RED=$'\e[31m' DEF=$'\e[0m'

has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '%s[INFO]%s %s\n' "$GRN" "$DEF" "$*"; }
warn(){ printf '%s[WARN]%s %s\n' "$YLW" "$DEF" "$*" >&2; }
err(){ printf '%s[ERROR]%s %s\n' "$RED" "$DEF" "$*" >&2; exit 1; }

# Generate SSH key
ssh_keygen(){
  local ssh_dir="$HOME/.ssh"
  local key_path="$ssh_dir/id_rsa"
  
  log "Setting up SSH key..."
  
  # Create .ssh directory
  if [[ ! -d "$ssh_dir" ]]; then
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    log "Created $ssh_dir"
  fi
  
  # Generate key if not exists
  if [[ -f "$key_path" ]]; then
    log "SSH key already exists at $key_path"
    return 0
  fi
  
  log "Generating SSH key..."
  ssh-keygen -t rsa -b 4096 -f "$key_path" -N "" || err "Key generation failed"
  log "SSH key generated at $key_path"
  
  # Display public key
  echo
  log "Public key:"
  cat "${key_path}.pub"
}

# Start SSH server
ssh_start(){
  has sshd || err "OpenSSH not installed. Install with: pkg install openssh"
  
  # Ensure SSH key exists
  [[ -f "$HOME/.ssh/id_rsa" ]] || ssh_keygen
  
  log "Starting SSH server..."
  sshd || err "Failed to start SSH server"
  
  local user
  user=$(id -un)
  log "SSH server started"
  log "Connect using: ssh -p 8022 $user@<device-ip>"
  log "Find device IP with: ifconfig | grep inet"
}

# Stop SSH server
ssh_stop(){
  log "Stopping SSH server..."
  pkill sshd && log "SSH server stopped" || warn "SSH server not running"
}

# Show SSH status
ssh_status(){
  if pgrep -f sshd &>/dev/null; then
    log "SSH server is running"
    local user
    user=$(id -un)
    log "Connect with: ssh -p 8022 $user@<device-ip>"
    return 0
  else
    log "SSH server is not running"
    return 1
  fi
}

# Usage
usage(){
  cat <<EOF
SSH utilities for Termux

USAGE:
  $(basename "$0") keygen    Generate SSH key
  $(basename "$0") start     Start SSH server
  $(basename "$0") stop      Stop SSH server
  $(basename "$0") status    Check SSH server status

EXAMPLES:
  $(basename "$0") keygen
  $(basename "$0") start
  $(basename "$0") status
EOF
}

main(){
  case "${1:-}" in
    keygen) ssh_keygen ;;
    start) ssh_start ;;
    stop) ssh_stop ;;
    status) ssh_status ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
