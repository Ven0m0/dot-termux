#!/data/data/com.termux/files/usr/bin/env zsh
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
export SHELL_SESSIONS_DISABLE=1
skip_global_compinit=1
setopt no_global_rcs

# Add paths
export PATH="$HOME/.bin:$HOME/bin:$HOME/.local/bin:${PATH:-}"
