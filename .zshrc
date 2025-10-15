#!/usr/bin/env zsh
# Optimized Zsh configuration with Zinit plugin manager

# =========================================================
# EARLY INITIALIZATION - POWERLEVEL10K INSTANT PROMPT
# =========================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# =========================================================
# CORE CONFIGURATION
# =========================================================
# Strict early configuration
set -euo pipefail
setopt EXTENDED_GLOB NULL_GLOB GLOB_DOTS

# Export LC settings early for consistency
export LC_ALL=C LANG=C LANGUAGE=C

# Skip if not interactive
[[ $- != *i* ]] && return

# =========================================================
# ENVIRONMENT VARIABLES
# =========================================================
export SHELL=zsh
export EDITOR=micro
export VISUAL=micro
export PAGER='bat'
export TERM="xterm-256color" 
export CLICOLOR=1
export MICRO_TRUECOLOR=1
export HISTCONTROL=ignoreboth
export HISTIGNORE="&:[bf]g:c:clear:history:exit:q:pwd:* --help"
export KEYTIMEOUT=1
export TZ='Europe/Berlin'
export TIME_STYLE='+%d-%m %H:%M'

# Less/Man colors
export LESS='-g -i -M -R -S -w -z-4'
export LESSHISTFILE=- LESSCHARSET=utf-8
export MANPAGER="sh -c 'col -bx | bat -lman -ps --squeeze-limit 0'" 
export MANROFFOPT="-c"

# FZF configuration
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --info=inline"
export FZF_DEFAULT_COMMAND='fd -tf -gH -c always -strip-cwd-prefix -E ".git"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd -td -gH -c always"
export FZF_BASE=/usr/share/fzf

# =========================================================
# ZSH OPTIONS
# =========================================================
# Directory navigation
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT PUSHD_TO_HOME
setopt PUSHD_MINUS CD_SILENT

# Globbing and completion
setopt EXTENDED_GLOB GLOB_DOTS NULL_GLOB GLOB_STAR_SHORT
setopt NUMERIC_GLOB_SORT HASH_EXECUTABLES_ONLY

# History
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS INC_APPEND_HISTORY EXTENDED_HISTORY
setopt HIST_REDUCE_BLANKS HIST_SAVE_NO_DUPS SHARE_HISTORY HIST_IGNORE_SPACE
setopt HIST_VERIFY HIST_EXPIRE_DUPS_FIRST HIST_FCNTL_LOCK

# Input/Output behavior
setopt INTERACTIVE_COMMENTS RC_QUOTES NO_BEEP NO_FLOW_CONTROL
setopt NO_CLOBBER AUTO_RESUME COMBINING_CHARS NO_MAIL_WARNING
setopt CORRECT CORRECT_ALL LONG_LIST_JOBS TRANSIENT_RPROMPT

# =========================================================
# PATH CONFIGURATION
# =========================================================
# Ensure path arrays do not contain duplicates
typeset -gU cdpath fpath mailpath path

# Set the list of directories that Zsh searches for programs
if [[ ! -v prepath ]]; then
  typeset -ga prepath
  prepath=(
    $HOME/{,s}bin(N)
    $HOME/.local/{,s}bin(N)
  )
fi
path=(
  $prepath
  /opt/{homebrew,local}/{,s}bin(N)
  /usr/local/{,s}bin(N)
  $path
)

# Android-specific paths
if [[ "$OSTYPE" == linux-android ]]; then
  path+=("$HOME/.cargo/bin" "$HOME/go/bin")
fi

# =========================================================
# HISTORY CONFIGURATION
# =========================================================
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
HISTTIMEFORMAT="%F %T "

# =========================================================
# ZINIT PLUGIN MANAGER SETUP
# =========================================================
# Install Zinit if it's not already installed
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname $ZINIT_HOME)"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Load Zinit
source "${ZINIT_HOME}/zinit.zsh"

# Load annexes
zinit light-mode for \
  zdharma-continuum/zinit-annex-as-monitor \
  zdharma-continuum/zinit-annex-bin-gem-node \
  zdharma-continuum/zinit-annex-patch-dl \
  zdharma-continuum/zinit-annex-rust

# Fast loading essential plugins
zinit wait lucid light-mode for \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions \
  blockf atpull'zinit creinstall -q .' \
    zsh-users/zsh-completions

# Load powerlevel10k theme
zinit ice depth=1
zinit light romkatv/powerlevel10k

# Additional plugins
zinit wait lucid for \
  zsh-users/zsh-history-substring-search \
  hlissner/zsh-autopair \
  MichaelAquilina/zsh-you-should-use

# Load zoxide if available
zinit wait'0' lucid as'program' from'gh-r' for ajeetdsouza/zoxide

# =========================================================
# COMPLETION SYSTEM CONFIGURATION
# =========================================================
# Fast compinit with caching
() {
  local zdump_loc="${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump"
  local skip=0
  
  # Only rebuild zcompdump once per day
  if [[ -f "$zdump_loc" ]]; then
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

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*' insert-unambiguous true
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle ':completion:*:match:*' original only

# Group matches and provide descriptions
zstyle ':completion:*:*:*:*:*' menu select
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

# Process completion
zstyle ':completion:*:processes' command 'ps -au$USER'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:kill:*' force-list always

# SSH/SCP/RSYNC completion
zstyle ':completion:*:(ssh|scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|::)([[:xdigit:].]##:(#c,2))##(|%*))' '127.0.0.<->' '255.255.255.255' '::1' 'fe80::*'

# Ignore completion functions for commands you don't have
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'

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

# --- Android Toolkit Shortcuts ---
alias apk-patch='patch-apk'
alias clean='quick-clean'
alias deep='deep-clean'
alias opt-img='simple-optimize-images'
alias opt-media='optimize-media'
alias opt-msg='optimize-messaging-media'

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

# =========================================================
# UTILITY FUNCTIONS
# =========================================================
# Check if command exists
has() { command -v -- "$1" >/dev/null 2>&1; }

# Create directory and cd into it
mkcd() {
  mkdir -p -- "$1" && cd -- "$1" || return
}

# =============================================================================
# ANDROID TOOLKIT - APK PATCHING, CLEANING & MEDIA OPTIMIZATION
# =============================================================================

# --- APK Patching Functions ---
# Interactive APK patcher menu
patch-apk() {
  if command -v revanced-helper >/dev/null 2>&1; then
    revanced-helper
  elif [[ -f "$HOME/bin/revanced-helper.sh" ]]; then
    bash "$HOME/bin/revanced-helper.sh"
  else
    echo "🔧 ReVanced helper not found. Setting up..."
    if [[ -f ~/dot-termux/bin/revanced-helper.sh ]]; then
      ln -sf ~/dot-termux/bin/revanced-helper.sh ~/bin/revanced-helper
      chmod +x ~/dot-termux/bin/revanced-helper.sh
      revanced-helper
    else
      echo "❌ Please run setup.sh first to install required tools"
    fi
  fi
}

# Quick launchers for specific patchers
revancify() {
  if [[ ! -d "$HOME/revancify-xisr" ]]; then
    echo "📦 Installing Revancify-Xisr..."
    curl -sL https://github.com/Xisrr1/Revancify-Xisr/raw/main/install.sh | bash
  else
    echo "File does not exist: $1"
  fi
}

simplify() {
  if [[ ! -f "$HOME/.Simplify.sh" ]]; then
    echo "📦 Installing Simplify..."
    curl -sL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh"
  fi
  bash "$HOME/.Simplify.sh"
}

# --- Android Filesystem Cleaning Functions ---
# Comprehensive Android cleaner
android-clean() {
  if command -v termux-cleaner >/dev/null 2>&1; then
    termux-cleaner "$@"
  elif [[ -f "$HOME/bin/termux-cleaner.sh" ]]; then
    bash "$HOME/bin/termux-cleaner.sh" "$@"
  else
    echo "🧹 Termux cleaner not found. Using built-in clean function..."
    termux-clean
  fi
}

# Quick clean with common options
quick-clean() {
  echo "🧹 Running quick Android cleanup..."
  
  # Clean Termux packages
  echo "📦 Cleaning package cache..."
  pkg clean && pkg autoclean
  apt clean && apt autoclean && apt-get -y autoremove --purge 2>/dev/null
  
  # Clean shell cache
  echo "🐚 Cleaning shell cache..."
  rm -f "$HOME"/.zcompdump* 2>/dev/null
  rm -f "$HOME"/.zinit/trash/* 2>/dev/null
  rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}"/.zcompdump* 2>/dev/null
  
  # Clean empty directories and log files
  echo "📁 Cleaning empty directories and logs..."
  find "$HOME" -type d -empty -delete 2>/dev/null || true
  find "$HOME" -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true
  
  # Run comprehensive cleaner if available
  if [[ -f "$HOME/bin/termux-cleaner.sh" ]]; then
    echo "🔧 Running comprehensive cleaner..."
    bash "$HOME/bin/termux-cleaner.sh" -y
  fi
  
  echo "✅ Quick cleanup complete!"
}

# Deep clean with WhatsApp/Telegram media
deep-clean() {
  echo "🧹 Running deep Android cleanup..."
  
  if command -v termux-cleaner >/dev/null 2>&1; then
    termux-cleaner -y --clean-whatsapp --clean-telegram --clean-system-cache
  elif [[ -f "$HOME/bin/termux-cleaner.sh" ]]; then
    bash "$HOME/bin/termux-cleaner.sh" -y
  else
    echo "❌ Deep clean requires termux-cleaner.sh"
    echo "💡 Run: bash ~/dot-termux/setup.sh"
  fi
}

# --- Media Optimization Functions ---
# Optimize media files (images/videos)
optimize-media() {
  if command -v termux-media-optimizer >/dev/null 2>&1; then
    termux-media-optimizer "$@"
  elif [[ -f "$HOME/bin/termux-media-optimizer.sh" ]]; then
    bash "$HOME/bin/termux-media-optimizer.sh" "$@"
  else
    echo "🖼️  Media optimizer not found. Using simple optimization..."
    simple-optimize-images "$@"
  fi
}

# Simple image optimization using available tools
simple-optimize-images() {
  local target_dir="${1:-.}"
  
  if ! command -v fd >/dev/null 2>&1; then
    echo "❌ fd not installed. Install with: pkg install fd"
    return 1
  fi
  
  echo "🖼️  Optimizing images in: $target_dir"
  
  if command -v cwebp >/dev/null 2>&1; then
    echo "Converting images to WebP..."
    fd -e jpg -e jpeg -e png . "$target_dir" -x sh -c 'cwebp -quiet -q 80 -metadata none "{}" -o "{.}.webp" && echo "✓ {}"'
  elif command -v jpegoptim >/dev/null 2>&1 || command -v optipng >/dev/null 2>&1; then
    echo "Optimizing images in-place..."
    if command -v jpegoptim >/dev/null 2>&1; then
      fd -e jpg -e jpeg . "$target_dir" -x jpegoptim --strip-all --quiet '{}'
    fi
    if command -v optipng >/dev/null 2>&1; then
      fd -e png . "$target_dir" -x optipng -quiet -o2 '{}'
    fi
  else
    echo "❌ No optimization tools found. Install with:"
    echo "   pkg install libwebp jpegoptim optipng"
    return 1
  fi
  
  echo "✅ Image optimization complete!"
}

# Re-encode videos for better compression
reencode-video() {
  local input="$1"
  local output="${2:-${input%.*}_optimized.mp4}"
  
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "❌ ffmpeg not installed. Install with: pkg install ffmpeg"
    return 1
  fi
  
  if [[ ! -f "$input" ]]; then
    echo "❌ Input file not found: $input"
    return 1
  fi
  
  echo "🎬 Re-encoding video: $input"
  echo "   Output: $output"
  
  ffmpeg -i "$input" -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k "$output"
  
  if [[ -f "$output" ]]; then
    local old_size=$(stat -f%z "$input" 2>/dev/null || stat -c%s "$input")
    local new_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output")
    local saved=$((old_size - new_size))
    local percent=$((saved * 100 / old_size))
    echo "✅ Re-encoding complete!"
    echo "   Original: $(numfmt --to=iec-i --suffix=B $old_size 2>/dev/null || echo $old_size bytes)"
    echo "   Optimized: $(numfmt --to=iec-i --suffix=B $new_size 2>/dev/null || echo $new_size bytes)"
    echo "   Saved: ${percent}%"
  fi
}

# Batch optimize media in WhatsApp/Telegram folders
optimize-messaging-media() {
  local storage_dir="${HOME}/storage/shared"
  
  if [[ ! -d "$storage_dir" ]]; then
    echo "📱 Setting up storage access..."
    termux-setup-storage
    sleep 2
  fi
  
  echo "🖼️  Optimizing messaging app media..."
  
  local -a media_dirs=(
    "$storage_dir/WhatsApp/Media/WhatsApp Images"
    "$storage_dir/WhatsApp/Media/WhatsApp Video"
    "$storage_dir/Telegram/Telegram Images"
    "$storage_dir/Telegram/Telegram Video"
  )
  
  for dir in "${media_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      echo "Processing: $dir"
      simple-optimize-images "$dir"
    fi
  done
  
  echo "✅ Messaging media optimization complete!"
}

# --- Utility functions ---
# Search and edit file with fzf
fe() {
  local files
  files=($(fzf --query="$1" --multi --select-1 --exit-0))
  [[ -n "$files" ]] && ${EDITOR:-micro} "${files[@]}"
}

# Help function using cheat.sh
h() { curl cheat.sh/${@:-cheat}; }

# Dot expansion for quick navigation upwards
dot-expansion() {
  if [[ $LBUFFER = *.. ]]; then
    LBUFFER+='/..'
  else
    LBUFFER+='.'
  fi
}
zle -N dot-expansion

# Prepend sudo
prepend-sudo() {
  if [[ "$BUFFER" != su(do|)\ * ]]; then
    BUFFER="sudo $BUFFER"
    (( CURSOR += 5 ))
  fi
}
zle -N prepend-sudo

# --- Help/Documentation ---
android-help() {
  cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║           TERMUX ANDROID TOOLKIT - QUICK REFERENCE           ║
╚══════════════════════════════════════════════════════════════╝

📦 APK PATCHING:
  patch-apk         Interactive APK patcher (ReVanced)
  apk-patch         Alias for patch-apk
  revancify         Launch Revancify-Xisr tool
  simplify          Launch Simplify patcher

🧹 FILESYSTEM CLEANING:
  clean             Quick clean (packages, cache, logs)
  quick-clean       Same as clean
  deep              Deep clean (includes WhatsApp, Telegram)
  deep-clean        Same as deep
  android-clean     Comprehensive Android cleaner (with options)
  termux-clean      Basic Termux cleanup

🖼️  MEDIA OPTIMIZATION:
  opt-img [dir]     Optimize images in directory (WebP conversion)
  opt-media [opts]  Full media optimizer with all features
  opt-msg           Optimize WhatsApp/Telegram media
  optimize-media    Same as opt-media
  reencode-video    Re-encode video for better compression

📝 EXAMPLES:
  # Patch an APK
  patch-apk
  
  # Clean system
  clean              # Quick clean
  deep               # Deep clean with media
  
  # Optimize images
  opt-img ~/storage/shared/DCIM/Camera
  opt-msg            # Optimize messaging apps
  
  # Re-encode video
  reencode-video input.mp4 output.mp4

💡 TIP: Run 'android-help' anytime to see this help message.
EOF
}

# --- Precmd hook ---
autoload -Uz add-zsh-hook
precmd() {
  # Update terminal title
  print -Pn "\e]0;%n@%m: %~\a"
}

# =========================================================
# ALIASES
# =========================================================
# General aliases
alias ls='eza --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale'
alias l='ls --git-ignore'
alias ll='eza --all --header --long --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale'
alias llm='ll --sort=modified'
alias la='eza -lbhHigUmuSa'
alias lx='eza -lbhHigUmuSa@'
alias lt='eza --tree'
alias tree='eza --tree'
alias grep='grep --color=auto'

# Platform-specific aliases
if [[ "$OSTYPE" == linux-android ]]; then
  alias open='termux-open'
  alias pbcopy='termux-clipboard-set'
  alias pbpaste='termux-clipboard-get'
elif (( $+commands[xdg-open] )); then
  alias open='xdg-open'
elif (( $+commands[wl-copy] && $+commands[wl-paste] )); then
  alias pbcopy='wl-copy'
  alias pbpaste='wl-paste'
fi

# Python aliases
alias pip=pip3
alias python=python3

# Build aliases
alias make="make -j$(nproc)"
alias ninja="ninja -j$(nproc)"
alias mkdir='mkdir -p'

# Suffix aliases
alias -s {css,gradle,html,js,json,md,patch,properties,txt,xml,yml}=$PAGER
alias -s gz='gzip -l'
alias -s {log,out}='tail -F'

# Misc aliases
alias e="$EDITOR"
alias r='bat -p'
alias which='command -v'
alias dirs='dirs -v'

# Global aliases for pipelines
alias -g -- -h='-h 2>&1 | bat --language=help --style=plain -s --squeeze-limit 0'
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain -s --squeeze-limit 0'
alias -g L="| ${PAGER:-less}"
alias -g G="| rg -i"
alias -g NE="2>/dev/null"
alias -g NUL=">/dev/null 2>&1"

# =========================================================
# KEYBINDINGS
# =========================================================
bindkey -e  # Emacs mode

# Better history search with up/down arrows
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Navigation
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[Z' reverse-menu-complete    # Shift-Tab to go backward in menu

# Custom bindings
bindkey '\e\e' prepend-sudo  # Alt+Alt to prepend sudo
bindkey '^R' history-incremental-pattern-search-backward

# =========================================================
# TOOL INTEGRATIONS
# =========================================================
# Initialize Powerlevel10k theme
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Load zoxide if available
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# Load zellij if available 
(( $+commands[zellij] )) && eval "$(zellij setup --generate-auto-start zsh)"

# Load Intelli-shell if available
(( $+commands[intelli-shell] )) && eval "$(intelli-shell init zsh)"

# Load thefuck if available
if (( $+commands[thefuck] )); then
  [[ ! -a $ZSH_CACHE_DIR/thefuck ]] && thefuck --alias > $ZSH_CACHE_DIR/thefuck
  source $ZSH_CACHE_DIR/thefuck
fi

# Load theshit if available
(( $+commands[theshit] )) && eval "$($HOME/.cargo/bin/theshit alias shit)"

# Load mise if available
[[ -f $HOME/.local/bin/mise ]] && eval "$($HOME/.local/bin/mise activate zsh)"

# Optional: Carapace completions
if (( $+commands[carapace] )); then
  export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
  zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
  source <(carapace _carapace)
fi

# =========================================================
# SYSTEM SPECIFIC CONFIGURATION 
# =========================================================
# Termux-specific settings
if [[ "$OSTYPE" == linux-android ]]; then
  # Load Termux API integration
  if has termux-clipboard-set; then
    copy_to_clipboard() { termux-clipboard-set < "$1"; }
  else
    copy_to_clipboard() { echo "Clipboard not available"; }
  fi
  
  # Add Termux-specific tools
  alias reload='termux-reload-settings'
  alias battery='termux-battery-status'
  alias clipboard='termux-clipboard-get'
  alias copy='termux-clipboard-set'
  alias share='termux-share'
  alias notify='termux-notification'
  
  # Load Shizuku environment if available
  [ -f ~/.shizuku_env ] && source ~/.shizuku_env
fi

# Display system information on login
if [[ -o INTERACTIVE && -t 2 ]]; then
  if (( $+commands[fastfetch] )); then
    fastfetch
  fi
fi >&2

# =========================================================
# FINAL OPTIMIZATIONS
# =========================================================
# Recompile zsh files for faster startup if needed
autoload -Uz zrecompile
for file in ~/.zshrc ~/.zshenv ~/.p10k.zsh; do
  if [[ -f "$file" && ( ! -f "${file}.zwc" || "$file" -nt "${file}.zwc" ) ]]; then
    zrecompile -pq "$file" &>/dev/null
  fi
done
unset file

# Clean and optimize environment
typeset -gU cdpath fpath mailpath path
