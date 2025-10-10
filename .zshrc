# =============================================================================
# ~/.zshrc - Optimized for Termux with Zinit
# =============================================================================

autoload -Uz compinit zrecompile
zrecompile -pq ~/.zshrc ~/.zshenv 2>/dev/null || {
  zcompile ~/.zshrc 2>/dev/null || true
  zcompile ~/.zshenv 2>/dev/null || true
}

# Only recompile if needed (check modification time)
for file in "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.zprofile"; do
  if [[ -f "$file" && ( ! -f "${file}.zwc" || "$file" -nt "${file}.zwc" ) ]]; then
    zrecompile -q -p "$file"
  fi
done

# Basic ZSH Settings (Arch Wiki optimized)
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS EXTENDED_GLOB GLOB_DOTS NO_BEEP
setopt PUSHD_SILENT PUSHD_TO_HOME 
setopt NUMERIC_GLOB_SORT RC_QUOTES AUTOPARAMSLASH INTERACTIVE_COMMENTS
unsetopt FLOW_CONTROL NOMATCH

# History optimization (from Arch Wiki)
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS INC_APPEND_HISTORY EXTENDED_HISTORY
setopt HIST_REDUCE_BLANKS HIST_SAVE_NO_DUPS SHARE_HISTORY HIST_IGNORE_SPACE
setopt HIST_VERIFY HIST_EXPIRE_DUPS_FIRST

stty -ixon -ixoff -ixany
ENABLE_CORRECTION="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"
skip_global_compinit=1
setopt no_global_rcs
SHELL_SESSIONS_DISABLE=1
DIRSTACKSIZE=10

# History settings
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
HISTTIMEFORMAT="%F %T "
HISTIGNORE="&:[bf]g:clear:cls:exit:history:bash:fish:?:??"
HISTCONTROL="erasedups:ignoreboth"

# =============================================================================
# ZINIT SETUP - ULTRA FAST PLUGIN MANAGER
# =============================================================================

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit"
if [[ ! -f $ZINIT_HOME/zinit.git/zinit.zsh ]]; then
    command mkdir -p "$ZINIT_HOME"
    command git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME/zinit.git"
fi
source "$ZINIT_HOME/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Enable Turbo mode for a significant speedup
zinit light-mode for \
    zdharma-continuum/z-a-rust \
    zdharma-continuum/z-a-bin-gem-node

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================

SHELL=zsh
export EDITOR='micro'
export VISUAL="$EDITOR"
export PAGER='bat'
export LANG='C.UTF-8' LC_ALL='C.UTF-8'
export TERM="xterm-256color"
export TZ='Europe/Berlin'
export TIME_STYLE='+%d-%m %H:%M'
export CLICOLOR=1 MICRO_TRUECOLOR=1

# Path setup
typeset -U path
path=("$HOME/.local/bin" "$HOME/.bin" "$HOME/bin" $path)

# Less/Man colors
: "${LESS_TERMCAP_mb:=$'\e[1;32m'}"
: "${LESS_TERMCAP_md:=$'\e[1;32m'}"
: "${LESS_TERMCAP_me:=$'\e[0m'}"
: "${LESS_TERMCAP_se:=$'\e[0m'}"
: "${LESS_TERMCAP_so:=$'\e[01;33m'}"
: "${LESS_TERMCAP_ue:=$'\e[0m'}"
: "${LESS_TERMCAP_us:=$'\e[1;4;31m'}"
export "${!LESS_TERMCAP@}"
export LESSHISTFILE=- LESSCHARSET=utf-8
export BAT_STYLE=auto LESSQUIET=1

# Better colors with vivid (Arch Wiki recommendation)
if (( $+commands[vivid] )); then
  export LS_COLORS="$(vivid generate molokai)"
elif (( $+commands[dircolors] )); then
  eval "$(dircolors -b)" &>/dev/null
fi

# Man improvements
export MANPAGER="sh -c 'col -bx | bat -lman -ps --squeeze-limit 0'" MANROFFOPT="-c"

# Python optimizations
export PYTHONOPTIMIZE=2 PYTHON_JIT=1 PYENV_VIRTUALENV_DISABLE_PROMPT=1 PYTHON_COLORS=1 UV_COMPILE_BYTECODE=1

# Other environmental optimizations
export ZSTD_NBTHREADS=0 ELECTRON_OZONE_PLATFORM_HINT=auto _JAVA_AWT_WM_NONREPARENTING=1

# FZF configuration
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND='fd -tf -gH -c always -strip-cwd-prefix -E ".git"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd -td -gH -c always"

# =============================================================================
# PLUGINS - PRIORITIZED BY STARTUP IMPACT
# =============================================================================

# --- Essential Fast Loading Plugins ---
zinit wait lucid light-mode for \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
        zdharma-continuum/fast-syntax-highlighting \
    atload"!_zsh_autosuggest_start" \
        zsh-users/zsh-autosuggestions \
    blockf atpull'zinit creinstall -q .' \
        zsh-users/zsh-completions

# --- Powerlevel10k Prompt (loads instantly) ---
zinit ice depth=1
zinit light romkatv/powerlevel10k

# --- Utilities (deferred loading) ---
zinit wait lucid for \
    zsh-users/zsh-history-substring-search \
    hl2b/zsh-autopair

# --- Zoxide (smarter cd command) ---
zinit wait'0' lucid as'program' from'gh-r' for \
    ajeetdsouza/zoxide
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# --- FZF Tab Completions ---
zinit ice lucid wait'0'
zinit light Aloxaf/fzf-tab

# =============================================================================
# COMPLETIONS & KEYBINDINGS
# =============================================================================

# Fast compinit with caching - runs only once every 24 hours
fast_compinit() {
  emulate -L zsh
  setopt extendedglob local_options
  
  local zdump_loc="${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump"
  local skip=0
  
  # Check dump file age properly
  if [[ -f "$zdump_loc" ]]; then
    # More portable way to check file age
    local now=$(date +%s)
    local mtime=$(stat -c %Y "$zdump_loc" 2>/dev/null || stat -f %m "$zdump_loc" 2>/dev/null)
    [[ -n "$mtime" ]] && (( now - mtime < 86400 )) && skip=1
  fi
  
  # Run compinit appropriately
  if (( skip )); then
    compinit -C -d "$zdump_loc"
  else
    compinit -d "$zdump_loc"
    # Background compilation
    { zcompile "$zdump_loc" } &!
  fi
}

# Initialize completions
autoload -Uz compinit
fast_compinit

# Completion styles
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zsh/cache"
zstyle ':completion:*' insert-unambiguous true
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:processes' command 'ps -au$USER'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always $realpath'
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
export KEYTIMEOUT=1

zstyle ':omz:plugins:eza' 'icons' yes
zstyle ':omz:plugins:eza' 'dirs-first' yes

# Keybindings
bindkey -e # Emacs mode
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey "^[[Z" reverse-menu-complete    # Shift-Tab to go backward in menu

# =============================================================================
# ALIASES & FUNCTIONS
# =============================================================================

# --- Navigation ---
if (( $+commands[zoxide] )); then
  alias ..='z ..'
  alias ...='z ../..'
  alias ....='z ../../..'
  alias .....='z ../../../..'
  alias ......='z ../../../../..'
  alias bd='z "$OLDPWD"'
  alias cd-="z -"
  alias cd='z'
else
  alias ..='cd ..'
  alias ...='cd ../..'
  alias ....='cd ../../..'
  alias .....='cd ../../../..'
  alias ......='cd ../../../../..'
  alias bd='cd "$OLDPWD"'
  alias cd-="cd -"
  unalias cd 2>/dev/null || true
fi
alias dirs='dirs -v'

# --- Developer tools ---
alias pip='python -m pip'

# --- File listings ---
alias ls='eza --icons -F --color=auto --group-directories-first'
alias la='eza -a --icons -F --color=auto --group-directories-first'
alias ll='eza -al --icons -F --color=auto --group-directories-first --git'
alias lt='eza --tree --level=3 --icons -F --color=auto'
alias which='command -v '

# --- File operations ---
touchf(){ command mkdir -p -- "$(dirname -- "$1")" && command touch -- "$1"; }
mkcd(){ mkdir -p -- "$1" && cd -- "$1" || return; }

# --- Suffix aliases (Arch Wiki recommendation) ---
alias -s {txt,md}="$EDITOR"
alias -s {jpg,jpeg,png,gif}="termux-share"
alias -s {zip,gz,tar,bz2,xz}="tar -tvf"

# --- Git ---
alias gst='git status'
alias gco='git checkout'
alias gpl='git pull'
alias gps='git push'
alias gclone='git clone --filter=blob:none --depth 1'

# --- Termux ---
alias reload='termux-reload-settings'
alias battery='termux-battery-status'
alias clipboard='termux-clipboard-get'
alias copy='termux-clipboard-set'
alias share='termux-share'
alias notify='termux-notification'

# --- Shell management ---
alias bash='SHELL=bash bash'
alias zsh='SHELL=zsh zsh'
alias fish='SHELL=fish fish'
alias cls='clear'

# --- Editor and utilities ---
alias e="\$EDITOR"
alias r='\bat -p'

# --- Global aliases ---
alias -g -- -h='-h 2>&1 | bat --language=help --style=plain -s --squeeze-limit 0'
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain -s --squeeze-limit 0'
alias -g L="| ${PAGER:-less}"
alias -g G="| rg -i"
alias -g NE="2>/dev/null"
alias -g NUL=">/dev/null 2>&1"


# --- Help functions ---
h(){ curl cheat.sh/${@:-cheat}; }
cht(){
  local query="${*// /\/}"
  if ! LC_ALL=C curl -sfZ4 --compressed -m 5 --connect-timeout 3 "cht.sh/${query}"; then
    LC_ALL=C curl -sfZ4 --compressed -m 5 --connect-timeout 3 "cht.sh/:help"
  fi
}

# --- Quick Revancify/Simplify launchers ---
revancify() {
  if [[ ! -d "$HOME/revancify-xisr" ]]; then
    echo "Installing Revancify-Xisr..."
    curl -sL https://github.com/Xisrr1/Revancify-Xisr/raw/main/install.sh | bash
  else
    cd "$HOME/revancify-xisr" && ./revancify.sh
  fi
}

simplify() {
  if [[ ! -f "$HOME/.Simplify.sh" ]]; then
    echo "Installing Simplify..."
    curl -sL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh"
  fi
  bash "$HOME/.Simplify.sh"
}

# --- Utility functions ---
# Search and edit file with fzf
fe() {
  local files
  files=($(fzf --query="$1" --multi --select-1 --exit-0))
  [[ -n "$files" ]] && ${EDITOR:-micro} "${files[@]}"
}

# cd with fzf
fcd() {
  local dir
  dir=$(find "${1:-.}" -path '*/\.*' -prune -o -type d -print 2>/dev/null | fzf --preview 'eza --tree --color=always {}') && cd "$dir" || return
}

# --- System maintenance ---
termux-clean() {
  echo "🧹 Cleaning Termux..."
  pkg clean && pkg autoclean
  apt clean && apt autoclean && apt-get -y autoremove --purge
  rm -f "$HOME"/.zcompdump* 2>/dev/null
  rm -f "$HOME"/.zinit/trash/* 2>/dev/null
  find ~ -type d -empty -delete 2>/dev/null || true
  find ~ -type f -name "*.log" -delete 2>/dev/null || true
  echo "✅ Termux cleanup complete."
}

# --- Precmd hook ---
autoload -Uz add-zsh-hook
precmd() {
  # Update terminal title
  print -Pn "\e]0;%n@%m: %~\a"
}
add-zsh-hook precmd precmd

# =============================================================================
# POWERLEVEL10K CONFIGURATION
# =============================================================================
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
