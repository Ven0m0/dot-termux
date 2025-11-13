#!/usr/bin/env bash
# common.sh - Shared utility functions for bash/zsh configurations

# Helper to check if a command exists
has() { command -v -- "$1" &>/dev/null; }

# Ensure directory exists
ensure_dir() {
  [[ -d $1 ]] || mkdir -p -- "$1"
}

# Git wrapper with error handling and retry logic
git() {
  local retries=3 delay=2
  while ((retries > 0)); do
    if command git "$@" 2>&1; then
      return 0
    fi
    ((retries--))
    ((retries > 0)) && sleep "$delay" && ((delay *= 2))
  done
  return 1
}

# Curl wrapper with better defaults
curl() {
  command curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 --max-time 60 "$@"
}

# Pip wrapper to ensure proper module invocation
pip() {
  python -m pip "$@"
}

# Update function for package managers
updt() {
  if has pkg; then
    pkg update -y && pkg upgrade -y
  elif has apt; then
    sudo apt update && sudo apt upgrade -y
  elif has dnf; then
    sudo dnf upgrade -y
  elif has pacman; then
    sudo pacman -Syu --noconfirm
  fi

  # Update Rust tools
  if has cargo; then
    has cargo-update && cargo install-update -a
  fi

  # Update mise/asdf tools
  has mise && mise upgrade

  # Update bun
  has bun && bun upgrade
}

# Clean up home directory
sweep_home() {
  local -a targets=(
    "$HOME/.cache"
    "$HOME/.local/share/Trash"
    "$HOME/tmp"
    "$HOME/.tmp"
  )

  for dir in "${targets[@]}"; do
    if [[ -d $dir ]]; then
      echo "Cleaning $dir..."
      find "$dir" -type f -atime +7 -delete 2>/dev/null
      find "$dir" -type d -empty -delete 2>/dev/null
    fi
  done

  # Clean package manager caches
  if has pkg; then
    pkg clean
  elif has apt; then
    sudo apt autoclean && sudo apt autoremove -y
  fi

  echo "Sweep complete."
}

# Export functions for use in subshells
export -f has ensure_dir git curl pip updt sweep_home
