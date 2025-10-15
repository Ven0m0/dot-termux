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

```bash
clean            # Quick clean (packages, cache, logs)
deep             # Deep clean (includes WhatsApp, Telegram media)
android-clean    # Comprehensive Android cleaner with options
```

### Media Optimization

```bash
opt-img ~/DCIM                    # Optimize images (WebP conversion)
opt-media                         # Full media optimizer
opt-msg                           # Optimize WhatsApp/Telegram media
reencode-video input.mp4 out.mp4  # Re-encode video for compression
```

## 📝 Examples

```bash
# Patch an APK with ReVanced
patch-apk

# Clean your system
clean              # Quick clean
deep               # Deep clean with media

# Optimize all images in camera folder
opt-img ~/storage/shared/DCIM/Camera

# Optimize messaging app media
opt-msg

# Re-encode a video
reencode-video large-video.mp4 optimized.mp4
```

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

The repository includes several helper scripts in the `bin/` directory:

- `termux-media-optimizer.sh` - Comprehensive media optimizer
- `termux-cleaner.sh` - Android filesystem cleaner
- `revanced-helper.sh` - ReVanced APK patcher
- `opt-img.sh` - Image optimization script

These scripts are automatically linked to `~/bin/` during setup and are wrapped by the interactive shell functions.

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
