#!/data/data/com.termux/files/usr/bin/env zsh
export SHELL_SESSIONS_DISABLE=1
skip_global_compinit=1
setopt no_global_rcs

# Enable zsh compiler for even faster startup
if [[ -f $HOME/.zshrc.zwc ]]; then
  # Use compiled .zshrc if it exists and is newer than the source
  if [[ $HOME/.zshrc -nt $HOME/.zshrc.zwc ]]; then
    zcompile $HOME/.zshrc
  fi
else
  # Create compiled version if it doesn't exist
  zcompile $HOME/.zshrc
fi

# Preload common paths to speed up command resolution
export PATH="$HOME/.bin:$HOME/bin:$HOME/.local/bin:$PATH"

# Set XDG base directories
# export XDG_CONFIG_HOME="$HOME/.config"
# export XDG_DATA_HOME="$HOME/.local/share"
# export XDG_CACHE_HOME="$HOME/.cache"
