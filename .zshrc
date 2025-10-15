# =============================================================================
# ~/.zshrc - Optimized for Termux with Zinit
# =============================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}"
fi

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
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

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
zinit wait'0' lucid as'program' from'gh-r' for ajeetdsouza/zoxide

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


# --- Help functions ---
h(){ curl cheat.sh/${@:-cheat}; }
cht(){
  local query="${*// /\/}"
  if ! LC_ALL=C curl -sfZ4 --compressed -m 5 --connect-timeout 3 "cht.sh/${query}"; then
    LC_ALL=C curl -sfZ4 --compressed -m 5 --connect-timeout 3 "cht.sh/:help"
  fi
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
    cd "$HOME/revancify-xisr" && ./revancify.sh
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
add-zsh-hook precmd precmd

# =============================================================================
# POWERLEVEL10K CONFIGURATION
# =============================================================================
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Additional beneficial additions for optimization and usability
# Enable command correction for common typos
setopt CORRECT
setopt CORRECT_ALL

# Add more efficient history search
bindkey '^R' history-incremental-pattern-search-backward

# Enhanced PATH additions (ensure no duplicates)
export PATH="$HOME/.cargo/bin:$HOME/go/bin:$PATH"

# Optional: Add support for additional tools if available
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Integrate atuin for better history if installed
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# Export additional environment variables for better tool integration
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgreprc"
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

export PATH="$PATH:/data/data/com.termux/files/home/.local/bin:/data/data/com.termux/files/home/.local/share/soar/bin"

[ ! -f "$HOME/.x-cmd.root/X" ] || . "$HOME/.x-cmd.root/X" # boot up x-cmd.

# Shizuku environment
[ -f ~/.shizuku_env ] && source ~/.shizuku_env
export PATH=$PATH:~/bin

alias dtlx="python DTL-X/dtlx.py"
