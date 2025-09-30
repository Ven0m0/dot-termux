#!/data/data/com.termux/files/usr/bin/bash

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

termux-setup-storage

pkg up -y
pkg upgrade -y
apt update -yapt upgrade -y
apt dist-upgrade -y
apt full-upgrade -y
dpkg --configure -a
apt --fix-broken install -y
apt install --fix-missing -y

pkg install -y termux-api tur-repo 
pkg install -y wget aria2 zip unzip git 
pkg install -y micro mc 
pkg install -y fzf 

zsh zsh-completions -y
chsh -s zsh

termux-reload-settings

# git clone https://github.com/Sohil876/Termux-zsh.git && cd Termux-zsh && bash setup.sh

git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/fast-syntax-highlighting
git clone https://github.com/babarot/enhancd.git ${ZSH_CUSTOM}/plugins/enhancd

fc-cache -vf

#pkg install -y android-tools aapt2 apksigner -y
pkg install -y bat zoxide ripgrep ripgrep-all -y
#binutils-libs
#binutils-bin
#binutils-is-llvm
#pkgtop

pkg in -y nala 

pkg in -y uv tealdeer 

#pkg install libheif libwebp optipng pngquant jpegoptim gifsicle gifski imagemagick -y
#graphicsmagick go-findimagedupes cavif-rs

apt clean && apt autoclean && apt-get -y autoremove --purge

mkdir -p "${HOME}/.local/bin"
curl -fsSL https://raw.githubusercontent.com/ashish0kumar/fzfm/main/fzfm -o "${HOME}/.local/bin/fzfm"
chmod +x ~/.local/bin/fzfm

curl https://raw.githubusercontent.com/CodesOfRishi/navita/main/navita.sh -o "${HOME}/navita.sh"


git clone https://github.com/felipefacundes/fzffm.git
chmod +x fzffm/fzffm
ln -s fzffm/fzffm $(pwd)/fzffm

