#!/data/data/com.termux/files/usr/bin/bash

echo "=== Termux Shizuku Tools Setup ==="
echo ""
echo "This will set up all tools and dependencies"
echo ""

# Update packages
echo "[1/7] Updating Termux packages..."
pkg update -y

# Install dependencies
echo ""
echo "[2/7] Installing dependencies..."
pkg install -y \
    git \
    python \
    nodejs \
    curl \
    wget \
    openssh \
    nmap \
    android-tools \
    termux-api \
    root-repo \
    build-essential
    cloudflared
# vscode server
npm y -g code-server
# code-server --auth none

# Copy rish files
echo ""
echo "[3/7] Setting up rish..."
if [ -f "shizuku/rish" ]; then
    cp shizuku/rish ~/rish
    chmod +x ~/rish
fi

if [ -f "shizuku/rish_shizuku.dex" ]; then
    cp shizuku/rish_shizuku.dex ~/rish_shizuku.dex
fi

# Set up environment
echo ""
echo "[4/7] Configuring environment..."
if [ -f "shizuku/shizuku_env.sh" ]; then
    cp shizuku/shizuku_env.sh ~/.shizuku_env
    
    # Add to bashrc if not already there
    if ! grep -q "source ~/.shizuku_env" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# Shizuku environment" >> ~/.bashrc
        echo "[ -f ~/.shizuku_env ] && source ~/.shizuku_env" >> ~/.bashrc
    fi
fi

# Create symlinks for tools
echo ""
echo "[5/7] Creating tool symlinks..."
mkdir -p ~/bin

create_symlinks() {
    local pattern="$1"
    local script name
    # shellcheck disable=SC2086
    for script in $pattern; do
        if [ -f "$script" ]; then
            name=$(basename "$script")
            ln -sf "$PWD/$script" "$HOME/bin/$name"
        fi
    done
}

create_symlinks "lucky-patcher/*.sh"
create_symlinks "ai-tools/*"
create_symlinks "system/*.sh"

# Add bin to PATH if not already there
if ! grep -q "export PATH=\$PATH:~/bin" ~/.bashrc; then
    echo 'export PATH=$PATH:~/bin' >> ~/.bashrc
fi

# Install Python packages
echo ""
echo "[6/7] Installing Python packages..."
pip install --no-deps anthropic google-generativeai requests 2>/dev/null || true

# Create documentation
echo ""
echo "[7/7] Creating documentation..."
cat > ~/.termux_shizuku_help << 'EOF'
=== Termux Shizuku Tools Help ===

Quick Commands:
- shizuku-status     # Check if Shizuku is running
- spm               # Package manager with privileges
- sam               # Activity manager with privileges
- lp_ultimate.sh    # Lucky Patcher functions
- ai                # AI CLI tools

First Time Setup:
1. Install and start Shizuku app
2. Enable wireless debugging
3. Run: source ~/.bashrc
4. Test: shizuku-status

Documentation: ~/termux-shizuku-tools/docs/
EOF

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Run: source ~/.bashrc"
echo "2. Start Shizuku app"
echo "3. Test: shizuku-status"
echo ""
echo "For help: cat ~/.termux_shizuku_help"
