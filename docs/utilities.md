# Utility Scripts Quick Reference

This document provides a quick reference for all utility scripts in the `bin/` directory.

## Installation

During setup, you can enable helper scripts installation:
```bash
INSTALL_HELPERS=1 ./setup.sh
```

Or install them manually after setup:
```bash
cd ~/dot-termux
for f in bin/termux-*-helper.sh; do
  chmod +x "$f"
  ln -sf "$PWD/$f" ~/bin/
done
```

## Proot Utilities (`termux-proot-helper.sh`)

Manage proot-distro and optimize performance.

```bash
# Patch activity manager for better performance
termux-proot-helper.sh patch-am

# Setup Debian proot with essentials
termux-proot-helper.sh setup-debian

# Run command in proot
termux-proot-helper.sh run debian "apt update && apt upgrade -y"
```

## ADB Utilities (`termux-adb-helper.sh`)

Optimize Android device and manage ADB connections.

```bash
# Optimize device performance
termux-adb-helper.sh optimize

# Clear system caches
termux-adb-helper.sh clear-cache

# Disable verbose logging
termux-adb-helper.sh disable-logs

# Run idle maintenance
termux-adb-helper.sh idle-maint

# Setup ADB over WiFi
termux-adb-helper.sh wifi-setup

# Connect to device over WiFi
termux-adb-helper.sh connect 192.168.1.100
```

## SSH Management (`termux-ssh-helper.sh`)

Manage SSH keys and server.

```bash
# Generate SSH key pair
termux-ssh-helper.sh keygen

# Start SSH server
termux-ssh-helper.sh start

# Stop SSH server
termux-ssh-helper.sh stop

# Check SSH server status
termux-ssh-helper.sh status
```

## Third-Party Tools Installer (`termux-install-tools.sh`)

Install various third-party tools and utilities.

```bash
# Install TermuxVoid repository
termux-install-tools.sh termuxvoid

# Install TermuxVoid theme
termux-install-tools.sh termuxvoid-theme

# Install X-CMD
termux-install-tools.sh xcmd

# Install package managers
termux-install-tools.sh lure
termux-install-tools.sh soar

# Install Rust tools
termux-install-tools.sh cargo-binstall

# Install other utilities
termux-install-tools.sh csb
termux-install-tools.sh shizuku-tools

# Install ReVanced patchers
termux-install-tools.sh revancify
termux-install-tools.sh revancify-xisr
termux-install-tools.sh rvx-builder
termux-install-tools.sh simplify
```

## Media Optimization

### Image Optimization (`media-opt.sh`)

```bash
# Optimize JPEGs
media-opt.sh jpg ~/Pictures

# Optimize PNGs
media-opt.sh png ~/Pictures

# Convert to WebP
media-opt.sh webp ~/Pictures -q 85

# Optimize all images
media-opt.sh all ~/Pictures
```

### WebP Conversion (`img-webp.sh`)

```bash
# Convert images to WebP (deletes originals)
img-webp.sh ~/Pictures
```

### Audio Optimization (`audio-opt.sh`)

```bash
# Convert audio files to Opus (deletes originals)
audio-opt.sh ~/Music
```

### Video Minimization (`vid-min.sh`)

```bash
# Encode to AV1 (default)
vid-min.sh ~/Videos

# Encode to VP9
vid-min.sh -m vp9 ~/Videos

# Custom CRF (lower = better quality)
vid-min.sh -c 25 ~/Videos

# Replace originals
vid-min.sh -r ~/Videos

# Dry run
vid-min.sh -n ~/Videos
```

## System Cleaning (`clean.sh`)

```bash
# Quick clean (cache, tmp, logs)
clean.sh -q

# Deep clean (includes downloads, junk)
clean.sh -d

# Clean WhatsApp media (>30 days)
clean.sh -w

# Clean Telegram media (>30 days)
clean.sh -t

# System cache clean (requires root/ADB/Shizuku)
clean.sh -s

# Dry run
clean.sh -n -d
```

## Other Utilities

### Mirror Configuration (`termux-change-repo`)

```bash
# Interactive mode
termux-change-repo

# Non-interactive by region
termux-change-repo --europe
termux-change-repo --asia
termux-change-repo --all

# Specific mirror
termux-change-repo --mirror packages.termux.dev

# Update packages after mirror change
termux-change-repo --europe --update
```

### Storage Setup (`termux-setup-storage`)

```bash
# Request storage permissions
termux-setup-storage
```

### Fix Shebangs (`termux-fix-shebang.sh`)

```bash
# Fix shebangs in scripts
termux-fix-shebang.sh script1.sh script2.sh
```

### AntiSplit (`antisplit.sh`)

```bash
# Merge and sign split APKs
antisplit.sh app.apks
```

## Tips

1. **Parallel Processing**: Most media tools use `fd` for faster parallel processing. Install with `pkg install fd`.

2. **Performance**: Set `JOBS` environment variable to control parallel jobs:
   ```bash
   JOBS=4 media-opt.sh jpg ~/Pictures
   ```

3. **Dry Run**: Use `-n` flag to preview changes without executing:
   ```bash
   clean.sh -n -d
   vid-min.sh -n ~/Videos
   ```

4. **Logging**: Check `~/termux_setup.log` for setup logs.

5. **Help**: All scripts support `-h` or `--help` for usage information:
   ```bash
   termux-adb-helper.sh --help
   ```
