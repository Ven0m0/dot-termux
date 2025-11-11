#!/data/data/com.termux/files/usr/bin/env zsh
# other.zsh - Additional Zsh-specific functions and configurations

has(){ command -v -- "$1" &>/dev/null; }

quick-clean() {
  pkg clean && pkg autoclean
  command -v apt &>/dev/null && {
    apt clean; apt autoclean
  }
  rm -f "$HOME"/.zcompdump* &>/dev/null
  rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/.zcompdump* &>/dev/null
  find "$HOME" -type f -name "*.log" -mtime +7 -delete
  find "$HOME" -type d -empty -delete && find "$HOME" -type f -empty -delete
  printf 'Quick clean finished\n'
}



# revancify / simplify bootstrappers (light wrappers)
revancify() {
  if [[ -f $HOME/revancify-xisr/revancify.sh ]]; then
    bash "$HOME/revancify-xisr/revancify.sh"
  else
    curl -sL https://github.com/Xisrr1/Revancify-Xisr/raw/main/install.sh | bash
  fi
}
simplify() {
  [[ -f $HOME/.Simplify.sh ]] || curl -sL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh"
  bash "$HOME/.Simplify.sh"
}

# git, curl, and pip wrappers are now provided by common.sh
