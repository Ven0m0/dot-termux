#!/data/data/com.termux/files/usr/bin/bash

termux-setup-storage

pkg up -y
pkg upgrade -y
apt update -yapt upgrade -y
apt dist-upgrade -y
apt full-upgrade -y
dpkg --configure -a
apt --fix-broken install -y
apt install --fix-missing -y


pkg install termux-api termux-gui-package tur-repo -y

pkg install wget aria2c zip unzip git -y
pkg install micro mc  -y

zsh zsh-completions -y
chsh -s zsh
git clone https://github.com/Sohil876/Termux-zsh.git && cd Termux-zsh && bash setup.sh

pkg install android-tools aapt2 apksigner -y
pkg install bat zoxide ripgrep-all -y
pkg install micro mc -y
#binutils-libs
#binutils-bin
#binutils-is-llvm
#pkgtop

pkg install libheif libwebp optipng pngquant jpegoptim gifsicle gifski imagemagick -y
#graphicsmagick go-findimagedupes cavif-rs

apt clean && apt autoclean && apt-get -y autoremove --purge


curl -fsSL https://raw.githubusercontent.com/ashish0kumar/fzfm/main/fzfm -o ~/.local/bin/fzfm
chmod +x ~/.local/bin/fzfm
