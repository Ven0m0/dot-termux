#!/data/data/com.termux/files/usr/bin/env zsh

# =========================================================
# PRE-EXEC
# =========================================================
# Exit if not running interactively
[[ $- != *i* ]] && return

# Load Powerlevel10k instant prompt if available
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# =========================================================
# CORE SETUP & HELPERS
# =========================================================
setopt EXTENDED_GLOB NULL_GLOB GLOB_DOTS NO_BEEP
export LC_ALL=C LANG=C.UTF-8 LANGUAGE=C
stty stop undef 2>/dev/null # Disable accidental Ctrl-S freeze

# Helper functions
has(){ command -v -- "$1" >/dev/null 2>&1; }
ifsource(){ [[ -r "$1" ]] && source "$1"; }
ensure_dir(){ [[ -d "$1" ]] || mkdir -p -- "$1"; }

# =========================================================
# ENVIRONMENT
# =========================================================
export SHELL=zsh
export EDITOR="${EDITOR:-micro}" VISUAL="$EDITOR"
export PAGER="${PAGER:-bat}"
export TERM="${TERM:-xterm-256color}"
export CLICOLOR=1 MICRO_TRUECOLOR=1 KEYTIMEOUT=1
export TZ='Europe/Berlin' TIME_STYLE='+%d-%m %H:%M'

# Less/man
export LESS='-g -i -M -R -S -w -z-4'
export LESSHISTFILE=- LESSCHARSET=utf-8
export MANPAGER="sh -c 'col -bx | ${PAGER:-bat} -lman -ps --squeeze-limit 0'"

# FZF
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline --cycle --bind='ctrl-y:preview-up,ctrl-e:preview-down'"
export FZF_DEFAULT_COMMAND='fd -tf -H --strip-cwd-prefix -E ".git"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd -td -H'

# =========================================================
# PATH & HISTORY
# =========================================================
typeset -gU cdpath fpath mailpath path
path=($HOME/{,s}bin(N) $HOME/.local/{,s}bin(N) $HOME/.cargo/bin(N) $HOME/go/bin(N) $path)

HISTFILE="${HOME}/.zsh_history"
HISTSIZE=50000 SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY

# Load Shizuku environment if available
ifsource ~/.shizuku_env

# =========================================================
# ZINIT (Plugin Manager)
# =========================================================
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d $ZINIT_HOME ]]; then
  mkdir -p "$(dirname -- "$ZINIT_HOME")"
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" &>/dev/null
fi
source "${ZINIT_HOME}/zinit.zsh" 2>/dev/null || return

# Annexes
zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-rust

# Theme (immediate)
zinit ice depth=1; zinit light romkatv/powerlevel10k

# Core plugins (fast, lucid)
zinit wait lucid light-mode for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf atpull'zinit creinstall -q .' \
    zsh-users/zsh-completions

# Utility plugins (lazy)
zinit wait'1' lucid for \
  zsh-users/zsh-history-substring-search \
  hlissner/zsh-autopair \
  MichaelAquilina/zsh-you-should-use

# Binary tools (loaded in parallel)
zinit wait'0a' lucid as'program' from'gh-r' for \
  mv'*/bat -> bat' atload'export BAT_THEME=Dracula' sharkdp/bat \
  mv'*/fd -> fd' sharkdp/fd \
  mv'*/rg -> rg' BurntSushi/ripgrep \
  ajeetdsouza/zoxide

# =========================================================
# COMPLETION
# =========================================================
# Initialize completion system (cached)
() {
  emulate -L zsh
  setopt extendedglob local_options
  local zdump="${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump"
  if [[ -f $zdump ]] && [[ $(find "$zdump" -mtime -1 2>/dev/null) ]]; then
    compinit -C -d "$zdump"
  else
    compinit -d "$zdump"
    { zcompile "$zdump" } &!
  fi
}

# --- Styling ---
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*' squeeze-slashes false
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' insert-unambiguous true
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle ':completion:*:match:*' original only

# Group matches and provide descriptions
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{red}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{purple}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{green} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{yellow}-- no matches found --%f'
zstyle ':completion:*' format ' %F{blue}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'

# Colors
if has vivid; then
  export LS_COLORS="$(vivid generate molokai)"
elif has dircolors; then
  eval "$(dircolors -b)" &>/dev/null
fi
LS_COLORS=${LS_COLORS:-'di=34:ln=35:so=32:pi=33:ex=31:'}
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# FZF tab completion
if [[ -f ${PREFIX:-/data/data/com.termux/files/usr}/share/fzf-tab-completion/zsh/fzf-zsh-completion.sh ]]; then
  source ${PREFIX:-/data/data/com.termux/files/usr}/share/fzf-tab-completion/zsh/fzf-zsh-completion.sh && bindkey '^I' fzf_completion
fi

# =========================================================
# KEYBINDINGS
# =========================================================
bindkey -e
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^R' history-incremental-pattern-search-backward
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[Z' reverse-menu-complete
bindkey '.' dot-expansion

# =========================================================
# ALIASES
# =========================================================
alias ls='eza --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale'
alias ll='eza --all --header --long --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale'
alias llm='ll --sort=modified'
alias la='eza -lbhHigUmuSa'
alias tree='eza -T'
alias grep='grep --color=auto'

alias python='python3'
alias pip='python3 -m pip'
alias make="make -j$(nproc)"
alias ninja="ninja -j$(nproc)"
alias mkdir='mkdir -p'
alias e='$EDITOR'
alias r='bat -p'
alias dirs='dirs -v'
alias which='command -v'

# Termux helpers
alias open='termux-open'
alias reload='termux-reload-settings'
alias battery='termux-battery-status'
alias clipboard='termux-clipboard-get'
alias copy='termux-clipboard-set'
alias share='termux-share'
alias notify='termux-notification'

# Suffix aliases
alias -s {css,gradle,html,js,json,md,patch,properties,txt,xml,yml}=$PAGER
alias -s gz='gzip -l'
alias -s {log,out}='tail -F'

# Global aliases for pipelines
alias -g -- -h='-h 2>&1 | bat -plhelp'
alias -g -- --help='--help 2>&1 | bat -plhelp'
alias -g L="| ${PAGER:-less}" G="| rg -i" NE="2>/dev/null" NUL=">/dev/null 2>&1"

# =========================================================
# FUNCTIONS
# =========================================================
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

fcd() {
  local root="." q sel preview
  [[ $# -gt 0 && -d $1 ]] && { root="$1"; shift; }
  q="${*:-}"
  preview=$(( $+commands[eza] )) && preview='eza -T -L2 --color=always {}' || preview='ls -la --color=always {}'
  if (( $+commands[fd] )); then
    sel="$(fd -HI -t d . "$root" 2>/dev/null | fzf --ansi --height ${FZF_HEIGHT:-60%} --layout=reverse --border --select-1 --exit-0 --preview "$preview" ${q:+--query "$q"})"
  else
    sel="$(find "$root" -type d -not -path '*/.git/*' -print 2>/dev/null | fzf --ansi --height ${FZF_HEIGHT:-60%} --layout=reverse --border --select-1 --exit-0 --preview "$preview" ${q:+--query "$q"})"
  fi
  [[ -n $sel ]] && cd -- "$sel"
}

fe() {
  local -a files; local q="${*:-}" preview
  if (( $+commands[bat] )); then
    preview='bat -n --style=plain --color=always --line-range=:500 {}'
  else
    preview='head -n 500 {}'
  fi
  if (( $+commands[fzf] )); then
    files=("${(@f)$(fzf --multi --select-1 --exit-0 ${q:+--query="$q"} --preview "$preview")}")
  else
    print -r -- "fzf not found" >&2; return 127
  fi
  [[ ${#files} -gt 0 ]] && "${EDITOR:-micro}" "${files[@]}"
}

h(){ curl -s "cheat.sh/${@:-}"; }

dot-expansion(){ if [[ $LBUFFER = *.. ]]; then LBUFFER+='/..'; else LBUFFER+='.'; fi; }
zle -N dot-expansion

# =========================================================
# INTEGRATIONS & FINALIZATION
# =========================================================
# Load theme
ifsource ~/.p10k.zsh

# Init tools
has zoxide && eval "$(zoxide init zsh --cmd cd)"
has thefuck && eval "$(thefuck --alias)"
has mise && eval "$(mise activate zsh)"

# Display system info on login (non-blocking)
if [[ -o INTERACTIVE && -t 2 ]]; then
  { has fastfetch && fastfetch || has neofetch && neofetch } &>/dev/null
fi >&2

# Smart precompilation of zsh files
() {
  local zcompdir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcomp"
  ensure_dir "$zcompdir"

  local compile_if_needed() {
    local src=$1 dst="$zcompdir/${src:t}.zwc"
    if [[ -f $src && (! -f $dst || $src -nt $dst) ]]; then
      zcompile -U "$dst" "$src" 2>/dev/null && ln -sf "$dst" "${src}.zwc" 2>/dev/null
    fi
  }
  {
    for f in ~/.zsh{rc,env} ~/.p10k.zsh ~/.config/zsh/*.zsh(N); do
      compile_if_needed "$f"
    done
  } &!
}
