export PATH="$PATH:/data/data/com.termux/files/home/.local/bin:/data/data/com.termux/files/home/.local/share/soar/bin"

[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

# Shizuku environment
[ -f ~/.shizuku_env ] && source ~/.shizuku_env
export PATH=$PATH:~/bin
export PATH=/data/data/com.termux/files/home/.cargo/bin:~/bin

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8 LANGUAGE=C.UTF-8 TZ='Europe/Berlin'
export TIME_STYLE='+%d-%m %H:%M'
export EDITOR='micro'
