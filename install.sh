#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob globstar extglob dotglob
IFS=$'\n\t'
export LC_ALL=C LANG=C

BLU=$'\e[1;34m' GRN=$'\e[1;32m' DEF=$'\e[0m'
REPO_URL="https://github.com/Ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"

log() { printf '%s\n' "$*"; }

log "${BLU}🚀 Starting optimized Termux environment setup...${DEF}"

log "${GRN}📦 Ensuring essential tools are installed...${DEF}"
pkg update -y &>/dev/null
pkg install -y git curl gix uv &>/dev/null

# Clone/update repo in parallel with package installs
if [[ -d $REPO_PATH/.git ]]; then
  log "${GRN}📁 Updating existing dot-termux repository...${DEF}"
  (cd "$REPO_PATH" && git pull --rebase --autostash &)
else
  log "${GRN}📥 Cloning dot-termux repository...${DEF}"
  (git clone --depth=1 --filter='blob:none' "$REPO_URL" "$REPO_PATH" &)
fi
wait # Wait for clone/pull to finish

log "${GRN}⚙️ Running main setup script...${DEF}"
if [[ -f "$REPO_PATH/setup.sh" ]]; then
  bash "$REPO_PATH/setup.sh"
else
  log "\e[1;31mERROR: setup.sh not found in repository.${DEF}" >&2
  exit 1
fi

log "${GRN}✅ Initial setup complete! Restart Termux to apply changes.${DEF}"
