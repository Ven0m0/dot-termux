#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

BLU=$'\e[1;34m' GRN=$'\e[1;32m' DEF=$'\e[0m'
REPO_URL="https://github.com/Ven0m0/dot-termux.git"
REPO_PATH="$HOME/dot-termux"

echo -e "${BLU}🚀 Starting optimized Termux environment setup...${DEF}"

# Ensure essential packages are present
echo -e "${GRN}📦 Ensuring git and curl are installed...${DEF}"
pkg update -y &>/dev/null
pkg install -y git curl gitoxide uv &>/dev/null

# Clone or update the repository
if [[ -d "$REPO_PATH" ]]; then
  echo -e "${GRN}📁 Updating existing dot-termux repository...${DEF}"
  git -C "$REPO_PATH" pull --rebase --autostash
else
  echo -e "${GRN}📥 Cloning dot-termux repository...${DEF}"
  git clone --depth=1 --filter='blob:none' "$REPO_URL" "$REPO_PATH"
fi

# Execute the main setup script
echo -e "${GRN}⚙️ Running main setup script...${DEF}"
bash "$REPO_PATH/setup.sh"

echo -e "${GRN}✅ Initial setup complete! Restart Termux to apply changes.${DEF}"
