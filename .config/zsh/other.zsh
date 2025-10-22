#!/data/data/com.termux/files/usr/bin/env zsh

quick-clean() {
  pkg clean && pkg autoclean
  command -v apt >/dev/null && { apt clean; apt autoclean; }
  rm -f "${HOME}"/.zcompdump* >/dev/null
  rm -f "${XDG_CACHE_HOME:-$HOME/.cache}"/.zcompdump* >/dev/null
  find "$HOME" -type f -name "*.log" -mtime +7 -delete
  find "$HOME" -type d -empty -delete && find "$HOME" -type f -empty -delete
  printf 'Quick clean finished\n'
}

# revancify / simplify bootstrappers (light wrappers)
revancify(){
  if [[ -f $HOME/revancify-xisr/revancify.sh ]]; then
    bash "$HOME/revancify-xisr/revancify.sh"
  else
    curl -sL https://github.com/Xisrr1/Revancify-Xisr/raw/main/install.sh | bash
  fi
}
simplify(){
  [[ -f $HOME/.Simplify.sh ]] || curl -sL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh"
  bash "$HOME/.Simplify.sh"
}

# Git -> Gix wrapper (gitoxide)
git(){
  local subcmd="${1:-}"
  if (( $+commands[gix] )); then
    case "$subcmd" in
      clone|fetch|pull|init|status|diff|log|rev-parse|rev-list|commit-graph|verify-pack|index-from-pack|pack-explode|remote|config|exclude|free|mailmap|odb|commitgraph|pack)
        gix "$@"
        ;;
      *)
        command git "$@"
        ;;
    esac
  else
    command git "$@"
  fi
}

# Curl -> Aria2 wrapper
curl(){
  local -a args=() out_file=""
  if (( $+commands[aria2c] )); then
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -o|--output)
          out_file="$2"
          shift 2
          ;;
        -L|--location|-s|--silent|-S|--show-error|-f|--fail)
          shift
          ;;
        http*|ftp*)
          args+=("$1")
          shift
          ;;
        *)
          args+=("$1")
          shift
          ;;
      esac
    done
    if [[ ${#args[@]} -gt 0 ]]; then
      if [[ -n $out_file ]]; then
        aria2c -x16 -s16 -k1M -j16 --file-allocation=none --summary-interval=0 -d "${out_file:h}" -o "${out_file:t}" "${args[@]}"
      else
        aria2c -x16 -s16 -k1M -j16 --file-allocation=none --summary-interval=0 "${args[@]}"
      fi
    else
      command curl "$@"
    fi
  else
    command curl "$@"
  fi
}

# Pip -> UV wrapper
pip(){
  if (( $+commands[uv] )); then
    case "${1:-}" in
      install|uninstall|list|show|freeze|check)
        uv pip "$@"
        ;;
      *)
        command pip "$@"
        ;;
    esac
  else
    command pip "$@"
  fi
}
