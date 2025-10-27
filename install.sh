#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
RED="\033[0;31m"; GREEN="\033[0;32m"; BLUE="\033[0;34m"; RESET="\033[0m"
echo -e "${BLUE}🚀 Setting up optimized Termux environment with Antidote and ReVanced support...${RESET}"
echo -e "${GREEN}📦 Updating package repositories...${RESET}"; pkg in -y git curl zsh tur-repo glibc-repo; pkg update -y || :
REPO="https://github.com/Ven0m0/dot-termux.git"; REPO_DIR="$HOME/dot-termux"
if [ -d "$REPO_DIR" ]; then echo -e "${GREEN}📁 Updating existing repository...${RESET}"; cd "$REPO_DIR" && git pull
else echo -e "${GREEN}📥 Cloning configuration repository...${RESET}"; git clone --depth=1 "$REPO" "$REPO_DIR"; fi
echo -e "${GREEN}⚙️ Running setup script...${RESET}"; bash "$REPO_DIR/setup.sh"
echo -e "${GREEN}🔧 Optimizing Zsh startup with zcompiler...${RESET}"; zsh -c 'zmodload zsh/zcompiler; zcompile ~/.zshrc; zcompile ~/.zshenv'
chsh -s zsh
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
echo -e "${GREEN}   Your environment now has Antidote, tur-repo, and glibc-repo!${RESET}"
