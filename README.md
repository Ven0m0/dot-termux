# dot-termux

Optimized Termux environment with Android toolkit for APK patching, filesystem cleaning, and media optimization.

## 🚀 Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/Ven0m0/dot-termux/main/setup.sh | bash
```

After installation, restart Termux for all changes to take effect.

## ✨ Features

- **Fast shell setup** with Zinit plugin manager and Powerlevel10k theme
- **APK patching tools** for ReVanced, YouTube, and more
- **Android filesystem cleaning** with comprehensive cache management
- **Media optimization** with WebP conversion and video re-encoding
- **100+ utility scripts** and interactive functions
- **Rich completions** and syntax highlighting

## 📦 Interactive Android Toolkit

Run `android-help` in your shell to see all available commands.

### APK Patching

```bash
patch-apk        # Interactive APK patcher (ReVanced)
apk-patch        # Alias for patch-apk
revancify        # Launch Revancify-Xisr tool
simplify         # Launch Simplify patcher
```

### Filesystem Cleaning

**New unified `clean` command** consolidates all cleaning functionality:

```bash
clean -q               # Quick clean (packages, cache, logs)
clean -d               # Deep clean (includes media, downloads)
clean -w               # Clean WhatsApp media (files older than 30 days)
clean -t               # Clean Telegram media (files older than 30 days)
clean -s               # Clean system cache (requires root/ADB/Shizuku)
clean -a               # Use ADB for cleaning operations
clean -n -d            # Dry run of deep clean (preview only)
clean -q -w -t -y      # Quick clean + WhatsApp + Telegram (no prompts)
```

Legacy shell function aliases:
```bash
clean            # Maps to: clean -q
deep             # Maps to: clean -d
android-clean    # Maps to: clean with interactive prompts
```

### Media Optimization

**New unified `optimize` command** with subcommands:

```bash
# Optimize images
optimize image photo.jpg
optimize image -q 90 -f webp *.png
optimize image -o ~/optimized/ *.jpg

# Optimize videos
optimize video -c 25 movie.mp4
optimize video --preset fast *.mp4

# Batch optimize directory
optimize batch ~/Pictures
optimize batch -t image -r ~/media

# Options:
#   -q, --quality N     Quality setting (1-100, default: 85)
#   -f, --format FMT    Convert to format (png, jpg, webp, avif)
#   -c, --crf N         Video CRF (0-51, default: 27, lower=better)
#   -r, --recursive     Process directories recursively
#   -t, --type TYPE     Filter by type (image, video, audio, all)
```

Legacy shell function aliases:
```bash
opt-img ~/DCIM         # Use: optimize batch ~/DCIM
opt-media              # Use: optimize batch with options
opt-msg                # Optimize WhatsApp/Telegram media
reencode-video         # Use: optimize video
```

## 📝 Examples

```bash
# Patch an APK with ReVanced
patch-apk

# Clean your system
clean -q           # Quick clean
clean -d           # Deep clean with media
clean -w -t -y     # Clean WhatsApp and Telegram (no prompts)

# Optimize images
optimize image photo.jpg
optimize image -q 90 -f webp *.png
optimize batch ~/storage/shared/DCIM/Camera

# Optimize videos
optimize video -c 25 movie.mp4
optimize batch -t video ~/Movies

# Optimize messaging app media
opt-msg
```

## 🏗️ Architecture

### Shared Library

All scripts now use a common library (`.config/bash/common.sh`) providing:
- Dependency checking functions
- Logging utilities
- File operations helpers
- Path manipulation
- Tool detection (sd/sed, fd/find)
- Network helpers
- String utilities

### Consolidated Scripts

**`bin/optimize`** - Unified media optimization tool
- Consolidates: `media.sh`, `opt-img.sh`, `img.sh`, `imgopt`
- Subcommands: `image`, `video`, `audio`, `batch`
- Supports: jpg, png, webp, avif, mp4, mkv, mov, webm, flac

**`bin/clean`** - Unified cleaning tool
- Consolidates: `clean.sh`, `termux-cleaner.sh`, `adbcc.sh`
- Flags: `-q` (quick), `-d` (deep), `-w` (whatsapp), `-t` (telegram), `-a` (adb)
- Supports: Direct access, Shizuku, ADB, root

### Coding Standards

All scripts follow these standards:
- 2-space indentation
- Bash-native idioms (no external dependencies when possible)
- Nameref for function returns
- Silent error handling: `>/dev/null 2>&1 || :`
- Prefer `fd` over `find`, `sd` over `sed` when available
- `LC_ALL=C` for performance
- `|| :` instead of `|| true`
- Function definitions: `func(){}` instead of `func() {}`

## 🔧 Manual Tools

### Revanced:

Simplify
```bash
pkg update && pkg install --only-upgrade apt bash coreutils openssl -y; curl -sL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh" && bash "$HOME/.Simplify.sh"
```
RVX builder
```bash
curl -sLo rvx-builder.sh https://raw.githubusercontent.com/inotia00/rvx-builder/revanced-extended/android-interface.sh && chmod +x rvx-builder.sh && ./rvx-builder.sh
```
Revancify
```bash
curl -sL https://raw.githubusercontent.com/decipher3114/Revancify/main/install.sh | bash
```
Revancify-Xisr
```bash
curl -sL https://raw.githubusercontent.com/Xisrr1/Revancify-Xisr/main/install.sh | bash
```

curl -fsSL lure.sh/install | bash

eval "$(curl https://get.x-cmd.com)"

curl -fsSL https://soar.qaidvoid.dev/install.sh | sh

Cargo binstall
```bahs
curl -sL --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
```

fix
```bash
curl -s https://raw.githubusercontent.com/ConzZah/csb/main/csb | bash
```

### Media Optimization Scripts

The repository includes consolidated scripts in the `bin/` directory:

- `optimize` - **NEW** Unified media optimization tool (replaces media.sh, opt-img.sh, img.sh, imgopt)
- `clean` - **NEW** Unified cleaning tool (replaces clean.sh, termux-cleaner.sh, adbcc.sh)
- `termux-media-optimizer.sh` - Legacy comprehensive media optimizer (kept for compatibility)
- `termux-cleaner.sh` - Legacy Android filesystem cleaner (kept for compatibility)
- `revanced-helper.sh` - ReVanced APK patcher

**Migration Guide:**
- Old: `bash bin/opt-img.sh ~/Pictures` → New: `optimize batch ~/Pictures`
- Old: `bash bin/clean.sh` → New: `clean -q`
- Old: `bash bin/termux-cleaner.sh -y` → New: `clean -d -y`
- Old: Multiple media scripts → New: Single `optimize` command with subcommands

The legacy scripts are retained for backwards compatibility but the new consolidated tools are recommended.

### ADB over mobile data:

- https://xdaforums.com/t/mod-no-root-supershell-adb-shell-over-mobile-data.4706512/
- https://gist.github.com/kairusds/1d4e32d3cf0d6ca44dc126c1a383a48d

```sh
adb tcpip 5555
IP=`adb shell ip route | awk '{print $9}'`
adb connect "$IP":5555
# adb pair "$IP":5555
```

- https://github.com/TechnoIndian/apk-mitm.git
