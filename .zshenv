#!/data/data/com.termux/files/usr/bin/env zsh
export SHELL_SESSIONS_DISABLE=1
skip_global_compinit=1
setopt no_global_rcs

# Add paths
export PATH="$HOME/.bin:$HOME/bin:$HOME/.local/bin:${PATH:-}"
