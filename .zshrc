#!/usr/bin/env zsh
# =========================================================
# EARLY: powerlevel10k instant prompt
# =========================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# =========================================================
# CORE CONFIGURATION
# =========================================================
setopt EXTENDED_GLOB NULL_GLOB GLOB_DOTS
export LC_ALL=C LANG=C.UTF-8 LANGUAGE=C

# Return early for non-interactive shells
[[ $- != *i* ]] && return

# Source shared helpers if present (non-mandatory)
if [[ -r "${HOME}/.config/zsh/common.zsh" ]]; then
  source "${HOME}/.config/zsh/common.zsh"
else
  # minimal fallback helpers
  has() { command -v -- "$1" &>/dev/null; }
  ensure_dir(){ [[ -d $1 ]] || mkdir -p -- "$1"; }
fi

# ---------------------------
# Environment
# ---------------------------
export SHELL=zsh
export EDITOR="${EDITOR:-micro}" 
export VISUAL="$EDITOR"
export PAGER="${PAGER:-bat}"
export TERM="${TERM:-xterm-256color}"
export CLICOLOR=1 MICRO_TRUECOLOR=1
export KEYTIMEOUT="${KEYTIMEOUT:-1}"
export TZ='Europe/Berlin'
export TIME_STYLE='+%d-%m %H:%M'
export FZF_BASE="${FZF_BASE:-/data/data/com.termux/files/usr/share/fzf}"

# Less/man
export LESS='-g -i -M -R -S -w -z-4'
export LESSHISTFILE=- LESSCHARSET=utf-8
export MANPAGER="sh -c 'col -bx | ${PAGER:-bat} -lman -ps --squeeze-limit 0'"

# fzf defaults
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND='fd -tf -gH -c always -strip-cwd-prefix -E ".git"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd -td -gH -c always"

# ---------------------------
# Path and history
# ---------------------------
typeset -gU cdpath fpath mailpath path
path=($HOME/{,s}bin(N) $HOME/.local/{,s}bin(N) $HOME/.cargo/bin(N) $HOME/go/bin(N) $path)

HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
HISTTIMEFORMAT="%F %T "

# ---------------------------
# Zinit plugins (fast)
# ---------------------------
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d $ZINIT_HOME ]]; then
  mkdir -p "$(dirname -- "$ZINIT_HOME")"
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" &>/dev/null || :
fi
[[ -f "${ZINIT_HOME}/zinit.zsh" ]] && source "${ZINIT_HOME}/zinit.zsh"

zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-rust

zinit wait lucid light-mode for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf atpull'zinit creinstall -q .' \
    zsh-users/zsh-completions

zinit ice depth=1
zinit light romkatv/powerlevel10k

zinit wait lucid for \
  zsh-users/zsh-history-substring-search \
  hlissner/zsh-autopair \
  MichaelAquilina/zsh-you-should-use

zinit wait'0' lucid as'program' from'gh-r' for ajeetdsouza/zoxide

# ---------------------------
# Completion (fast)
# ---------------------------
() {
  emulate -L zsh
  setopt extendedglob local_options
  local zdump="${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump"
  local skip=0
  if [[ -f $zdump ]]; then
    local now=$(date +%s)
    local mtime=$(stat -c %Y "$zdump" 2>/dev/null || stat -f %m "$zdump" 2>/dev/null)
    [[ -n $mtime && $((now - mtime)) -lt 86400 ]] && skip=1
  fi
  if (( skip )); then
    compinit -C -d "$zdump"
  else
    compinit -d "$zdump"
    { zcompile "$zdump" } &!
  fi
}

zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*' insert-unambiguous true
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle ':completion:*:match:*' original only

# colorize completions
if has vivid; then
  export LS_COLORS="$(vivid generate molokai)"
elif has dircolors; then
  eval "$(dircolors -b)" &>/dev/null || :
fi
LS_COLORS=${LS_COLORS:-'di=34:ln=35:so=32:pi=33:ex=31:'}
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# fzf-tab completion
if [[ -f ${PREFIX:-/data/data/com.termux/files/usr}/share/fzf-tab-completion/zsh/fzf-zsh-completion.sh ]]; then
  source ${PREFIX:-/data/data/com.termux/files/usr}/share/fzf-tab-completion/zsh/fzf-zsh-completion.sh
  bindkey '^I' fzf_completion
fi

# ---------------------------
# Keybindings
# ---------------------------
bindkey -e
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[Z' reverse-menu-complete
bindkey '^R' history-incremental-pattern-search-backward
bindkey '.' dot-expansion

# ---------------------------
# Aliases
# ---------------------------
alias ls='eza --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale'
alias l='ls --git-ignore'
alias ll='eza --all --header --long --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale'
alias llm='ll --sort=modified'
alias la='eza -lbhHigUmuSa'
alias lt='eza --tree'
alias tree='eza --tree'
alias grep='grep --color=auto'

alias pip='python -m pip'
alias python='python3'
alias make="make -j$(nproc 2>/dev/null || echo 1)"
alias ninja="ninja -j$(nproc 2>/dev/null || echo 1)"
alias mkdir='mkdir -p'
alias e="$EDITOR"
alias r='bat -p'
alias dirs='dirs -v'

# Termux helpers (safe)
if has termux-clipboard-set; then
  copy_to_clipboard(){ termux-clipboard-set < "$1"; }
else
  copy_to_clipboard(){ echo "Clipboard not available" >&2; }
fi
alias reload='termux-reload-settings'
alias battery='termux-battery-status'
alias clipboard='termux-clipboard-get'
alias copy='termux-clipboard-set'
alias share='termux-share'
alias notify='termux-notification'

# ---------------------------
# Utilities (small, safe)
# ---------------------------
has(){ command -v -- "$1" >/dev/null 2>&1; }
mkcd(){ mkdir -p -- "$1" && cd -- "$1" || return 1; }

extract(){
  [[ -f $1 ]] || { printf 'File not found: %s\n' "$1" >&2; return 1; }
  case "${1##*.}" in
    tar|tgz) tar -xf "$1" ;;
    tar.gz) tar -xzf "$1" ;;
    tar.bz2|tbz2) tar -xjf "$1" ;;
    tar.xz|txz) tar -xJf "$1" ;;
    zip) unzip -q "$1" ;;
    rar) unrar x "$1" ;;
    gz) gunzip "$1" ;;
    bz2) bunzip2 "$1" ;;
    7z) 7z x "$1" ;;
    *) printf 'Unsupported archive: %s\n' "$1" >&2; return 2 ;;
  esac
}

fcd(){
  local dir
  if has fd; then
    dir=$(fd -t d . "${1:-.}" 2>/dev/null | fzf --preview 'eza --tree --color=always {}' --height=40%)
  else
    dir=$(find "${1:-.}" -path '*/\.*' -prune -o -type d -print 2>/dev/null | fzf --preview 'eza --tree --color=always {}' --height=40%)
  fi
  [[ -n $dir ]] && cd -- "$dir"
}

fe(){
  local files
  files=("${(@f)$(fzf --multi --select-1 --exit-0 <<<"${*:-}")}")
  [[ -n $files ]] && ${EDITOR:-micro} "${(@)files}"
}

h(){ curl -sS "https://cheat.sh/${@:-bash}" || true; }

dot-expansion(){
  if [[ $LBUFFER = *.. ]]; then LBUFFER+='/..'; else LBUFFER+='.'; fi
}
zle -N dot-expansion

# ---------------------------
# Tool integrations
# ---------------------------
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
has zoxide && eval "$(zoxide init zsh)"
has zellij && eval "$(zellij setup --generate-auto-start zsh)"
if has thefuck; then
  local thefuck_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/thefuck"
  ensure_dir "${thefuck_cache:h}" 2>/dev/null || :
  [[ ! -f $thefuck_cache ]] && thefuck --alias >| "$thefuck_cache" 2>/dev/null || :
  [[ -f $thefuck_cache ]] && source "$thefuck_cache" 2>/dev/null || :
fi
[[ -f $HOME/.local/bin/mise ]] && eval "$($HOME/.local/bin/mise activate zsh)" 2>/dev/null || :

# Display system info on login (non-blocking)
if [[ -o INTERACTIVE && -t 2 ]]; then
  has fastfetch && fastfetch &>/dev/null || has neofetch && neofetch &>/dev/null || :
fi >&2

# ---------------------------
# Final: recompile stubs if needed
# ---------------------------
autoload -Uz zrecompile
for f in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do
  [[ -f $f && ( ! -f ${f}.zwc || $f -nt ${f}.zwc ) ]] && zrecompile -pq "$f" &>/dev/null || :
done
