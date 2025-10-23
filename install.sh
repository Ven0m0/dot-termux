#!/data/data/com.termux/files/usr/bin/env bash
# Termux Fast Setup Script with Zinit and ReVanced support
set -euo pipefail

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RESET="\033[0m"

echo -e "${BLUE}🚀 Setting up optimized Termux environment with Zinit and ReVanced support...${RESET}"

# 1. Update and install essential packages
echo -e "${GREEN}📦 Updating package repositories...${RESET}"
pkg in -y git curl zsh tur-repo glibc-repo

# Force refresh after adding repos
pkg update -y || :

# 2. Clone repository with configurations
REPO="https://github.com/Ven0m0/dot-termux.git"
REPO_DIR="$HOME/dot-termux"

if [ -d "$REPO_DIR" ]; then
  echo -e "${GREEN}📁 Updating existing repository...${RESET}"
  cd "$REPO_DIR" && git pull
else
  echo -e "${GREEN}📥 Cloning configuration repository...${RESET}"
  git clone --depth=1 "$REPO" "$REPO_DIR"
fi

# 3. Run setup script
echo -e "${GREEN}⚙️ Running setup script...${RESET}"
bash "$REPO_DIR/setup.sh"

# 4. Optimize zsh startup with compiler
echo -e "${GREEN}🔧 Optimizing Zsh startup with zcompiler...${RESET}"
zsh -c 'zmodload zsh/zcompiler; zcompile ~/.zshrc; zcompile ~/.zshenv'

# 5. Set zsh as default shell
chsh -s zsh

# 6. Create welcome message
cat > "$HOME/.welcome.msg" <<EOL
${BLUE}╔════════════════════════════════════════════════╗${RESET}
${BLUE}║                                                ║${RESET}
${BLUE}║  Welcome to your optimized Termux environment  ║${RESET}
${BLUE}║                                                ║${RESET}
${BLUE}╚════════════════════════════════════════════════╝${RESET}

Available tools:
• ${GREEN}revancify${RESET}      - Launch Revancify tool
• ${GREEN}simplify${RESET}       - Launch Simplify tool
• ${GREEN}zoxide${RESET}         - Smart directory jumper
• ${GREEN}atuin${RESET}          - Better shell history

Type ${GREEN}help${RESET} for more information.
EOL

echo -e "${GREEN}✅ Setup complete! Restart Termux to apply changes.${RESET}"
echo -e "${GREEN}   Your environment now has Zinit, tur-repo, and glibc-repo!${RESET}"
