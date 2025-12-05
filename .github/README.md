# dot-termux

Optimized Termux environment with Android toolkit for APK patching, filesystem cleaning, and media optimization.

## 🚀 Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/Ven0m0/dot-termux/main/setup.sh | bash
```
```bash
curl -s https://raw.githubusercontent.com/bbk14/TermuxDebian/main/Termux/installation.sh | bash
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

**Unified `media-opt` command** for all media optimization tasks:

```bash
# Optimize images
media-opt image photo.jpg
media-opt image -q 90 -f webp *.png
media-opt image -o ~/optimized/ *.jpg

# Optimize videos
media-opt video -c 25 movie.mp4
media-opt video --preset fast *.mp4

# Batch optimize directory
media-opt batch ~/Pictures
media-opt batch -t image -r ~/media

# Options:
#   -q, --quality N     Quality setting (1-100, default: 85)
#   -f, --format FMT    Convert to format (png, jpg, webp, avif, jxl)
#   -c, --crf N         Video CRF (0-51, default: 27, lower=better)
#   -r, --recursive     Process directories recursively
#   -t, --type TYPE     Filter by type (image, video, audio, all)
#   -n, --dry-run       Preview changes without executing
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
media-opt image photo.jpg
media-opt image -q 90 -f webp *.png
media-opt batch ~/storage/shared/DCIM/Camera

# Optimize videos
media-opt video -c 25 movie.mp4
media-opt batch -t video ~/Movies
```

## 🏗️ Architecture

### Consolidated Scripts

**`bin/media-opt`** - Unified media optimization tool

- Consolidates: `media.sh`, `opt-img.sh`, `img.sh`, `imgopt`
- Subcommands: `image`, `video`, `audio`, `batch`
- Supports: jpg, png, webp, avif, jxl, gif, svg, mp4, mkv, mov, webm, flac
- Features: Parallel processing, codec detection, quality presets, dry-run mode

**`bin/clean`** - Unified cleaning tool

- Consolidates: `clean.sh`, `termux-cleaner.sh`, `adbcc.sh`
- Flags: `-q` (quick), `-d` (deep), `-w` (whatsapp), `-t` (telegram), `-s` (system), `-a` (adb)
- Supports: Direct access, Shizuku, ADB, root
- Features: Age-based filtering, dry-run mode, batch operations

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

### Revanced

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

eval "$(curl <https://get.x-cmd.com>)"

curl -fsSL <https://soar.qaidvoid.dev/install.sh> | sh

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

- `media-opt` - Unified media optimization tool (replaces legacy: media.sh, opt-img.sh, img.sh, imgopt)
- `clean` - Unified cleaning tool (replaces legacy: clean.sh, termux-cleaner.sh, adbcc.sh)
- `tools` - Shared library with helper functions
- `supershell` - ADB over WiFi connection utility
- `rxfetch` - System information display

### ADB over mobile data

- <https://xdaforums.com/t/mod-no-root-supershell-adb-shell-over-mobile-data.4706512/>
- <https://gist.github.com/kairusds/1d4e32d3cf0d6ca44dc126c1a383a48d>

```sh
adb tcpip 5555
IP=`adb shell ip route | awk '{print $9}'`
adb connect "$IP":5555
# adb pair "$IP":5555
```

- <https://github.com/TechnoIndian/apk-mitm.git>
- https://rv.aun.rest
