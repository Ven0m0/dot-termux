#!/bin/bash
# PocketCode Setup Script
# https://github.com/rajbreno/PocketCode
# One command to setup AI coding agents on Android
set -euo pipefail

echo "🚀 PocketCode Setup Starting..."

# Step 1: Update Termux
echo "📦 Updating Termux..."
pkg update -y >/dev/null 2>&1
pkg upgrade -y >/dev/null 2>&1

# Step 2: Install proot-distro
echo "📦 Installing Linux container..."
pkg i -i proot-distro >/dev/null 2>&1
proot-distro install debian >/dev/null 2>&1 || true

# Step 3: Setup inside Debian
echo "⚙️ Setting up development environment..."
proot-distro login debian -- bash -c '
  apt update > /dev/null 2>&1
  apt install curl git build-essential python3 -y > /dev/null 2>&1

  # Secure NodeSource installation
  NODE_SETUP_TMP=$(mktemp)
  if curl -fsSL https://deb.nodesource.com/setup_20.x -o "$NODE_SETUP_TMP" 2>/dev/null; then
    bash "$NODE_SETUP_TMP" > /dev/null 2>&1
    rm -f "$NODE_SETUP_TMP"
    apt install nodejs -y > /dev/null 2>&1
  else
    echo "❌ NodeSource setup download failed"
    rm -f "$NODE_SETUP_TMP"
  fi

  # Secure OpenCode installation
  OPENCODE_SETUP_TMP=$(mktemp)
  if curl -fsSL https://opencode.ai/install -o "$OPENCODE_SETUP_TMP" 2>/dev/null; then
    bash "$OPENCODE_SETUP_TMP" > /dev/null 2>&1
    rm -f "$OPENCODE_SETUP_TMP"
  else
    echo "❌ OpenCode setup download failed"
    rm -f "$OPENCODE_SETUP_TMP"
  fi
  echo "alias opencode-web=\"opencode web --hostname 127.0.0.1 --port 4096\"" >> ~/.bashrc
'

# Step 4: Create shortcut alias
echo "🔗 Creating shortcuts..."
echo 'alias pocketcode="proot-distro login debian --termux-home"' >> ~/.bashrc
echo 'alias pocketcode="proot-distro login debian --termux-home"' >> ~/.zshrc
source ~/.bashrc

echo ""
echo "✅ Setup Complete!"
echo ""
echo "📱 Quick Start:"
echo "   Type: pocketcode"
echo "   Then: opencode (terminal) or opencode-web (browser)"
echo ""
echo "📁 To edit files visually, install Acode from Play Store"
echo ""
