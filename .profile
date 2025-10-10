export PATH="$PATH:/data/data/com.termux/files/home/.local/bin:/data/data/com.termux/files/home/.local/share/soar/bin"

[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

# Shizuku environment
[ -f ~/.shizuku_env ] && source ~/.shizuku_env
export PATH=$PATH:~/bin

/data/data/com.termux/files/home/.cargo/bin

export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8 LANGUAGE=C.UTF-8
export TZ='Europe/Berlin'
export TIME_STYLE='+%d-%m %H:%M'
export EDITOR='micro'
export CLICOLOR=1 MICRO_TRUECOLOR=1

export CARGO_CACHE_RUSTC_INFO=1
export RUSTC_WRAPPER="sccache"
export GITOXIDE_CORE_MULTIPACKINDEX="true"
export GITOXIDE_HTTP_SSLVERSIONMAX="tls1.3"
export GITOXIDE_HTTP_SSLVERSIONMIN="tls1.2"
