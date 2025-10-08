#!/data/data/com.termux/files/usr/bin/env bash
# Termux Fast Setup Script - Sets up optimized environment with Zinit and tools
set -e
LC_ALL=C
echo "🚀 Setting up optimized Termux environment..."

# 1. Update packages and install essentials
pkg update -y && pkg upgrade -y
pkg install -y git curl zsh zsh-completions bash-completion

# 2. Clone repository with configurations
REPO="https://github.com/Ven0m0/dot-termux.git"
REPO_DIR="$HOME/dot-termux"

if [ -d "$REPO_DIR" ]; then
  echo "📁 Updating existing repository..."
  cd "$REPO_DIR" && git pull
else
  echo "📥 Cloning configuration repository..."
  git clone --depth=1 "$REPO" "$REPO_DIR"
fi

# 3. Run setup script
echo "⚙️ Running setup script..."
bash "$REPO_DIR/setup.sh"

# 4. Set zsh as default shell
chsh -s zsh

echo "✅ Setup complete! Restart Termux to apply changes."
echo "   Then you can use: revancify, or simplify"
