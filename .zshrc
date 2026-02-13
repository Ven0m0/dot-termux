#!/data/data/com.termux/files/usr/bin/env zsh
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
[[ $- != *i* ]] && return

# Instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ===== CORE =====
setopt EXTENDED_GLOB NULL_GLOB GLOB_DOTS NO_BEEP
export LANG=C.UTF-8 LANGUAGE=C LC_COLLATE=C LC_CTYPE=C LC_MESSAGES=C
stty stop undef 2>/dev/null

has(){ command -v -- "$1" &>/dev/null; }
fe(){ local -a files; local q="${*:-}" preview; if (( $+commands[bat] )); then preview='bat -n --style=plain --color=always --line-range=:500 {}'; else preview='head -n 500 {}'; fi
  if (( $+commands[fzf] )); then files=("${(@f)$(fzf --multi --select-1 --exit-0 ${q:+--query="$q"} --preview "$preview")}"); else print -r -- "fzf not found" >&2; return 127; fi
  [[ ${#files} -gt 0 ]] && "${EDITOR:-micro}" "${files[@]}"
}
h(){ curl -s "cheat.sh/${@:-}"; }

# Zsh-specific helpers (keep these as they may differ from bash equivalents)
ifsource(){ [[ -r "$1" ]] && source "$1"; }
ensure_dir(){ [[ -d "$1" ]] || mkdir -p -- "$1"; }

export EDITOR="${EDITOR:-micro}" VISUAL="$EDITOR" PAGER="${PAGER:-bat}" TERM="${TERM:-xterm-256color}"
export CLICOLOR=1 MICRO_TRUECOLOR=1 KEYTIMEOUT=1 TZ='Europe/Berlin' TIME_STYLE='+%d-%m %H:%M'
export LESS='-g -i -M -R -S -w -z-4' LESSHISTFILE=- LESSCHARSET=utf-8
export MANPAGER="sh -c 'col -bx | ${PAGER:-bat} -lman -ps --squeeze-limit 0'"
export FZF_DEFAULT_OPTS="--height=40% --layout=reverse --border --info=inline --cycle --bind=ctrl-y:preview-up,ctrl-e:preview-down"
export FZF_DEFAULT_COMMAND='fd -tf -H --strip-cwd-prefix -E ".git"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND" FZF_ALT_C_COMMAND='fd -td -H'
typeset -gU cdpath fpath mailpath path
path=("$HOME"/{,s}bin(N) "$HOME"/.local/{,s}bin(N) "$HOME"/.cargo/bin(N) "$HOME"/go/bin(N) "$path")

HISTFILE="${HOME}/.zsh_history"; HISTSIZE=50000; SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY
ifsource ~/.shizuku_env

# ===== Antidote =====
antidote_dir=${XDG_DATA_HOME:-$HOME/.local/share}/antidote
[[ -d $antidote_dir ]] || git clone --depth 1 https://github.com/mattmc3/antidote "$antidote_dir" &>/dev/null || :
antidote_bin="$antidote_dir/bin/antidote"
bundle=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zsh_plugins.zsh
list=${XDG_CONFIG_HOME:-$HOME/.config}/zsh/config/plugins.txt
if [[ -f $list ]]; then
  [[ -f $bundle && $list -ot $bundle ]] || "$antidote_bin" bundle <"$list" >"$bundle"
else
  print -l \
    zsh-users/zsh-completions \
    zdharma-continuum/fast-syntax-highlighting \
    zsh-users/zsh-autosuggestions \
    romkatv/powerlevel10k \
  | "$antidote_bin" bundle >"$bundle"
fi
source "$bundle"

# ===== Completion =====
(){ emulate -L zsh; setopt extendedglob local_options
  local zdump="${XDG_CACHE_HOME:-$HOME/.cache}/.zcompdump"
  if [[ -f $zdump ]] && [[ $(find "$zdump" -mtime -1 2>/dev/null) ]]; then compinit -C -d "$zdump"
  else compinit -d "$zdump"; { zcompile "$zdump" } &!; fi
}
zstyle ':completion:*' menu select
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*' squeeze-slashes false special-dirs true insert-unambiguous true
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:approximate:*' max-errors 1 numeric
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:matches' group yes
zstyle ':completion:*:options' description yes auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{red}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{purple}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{green} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{yellow}-- no matches found --%f'
zstyle ':completion:*' format ' %F{blue}-- %d --%f'
if has vivid; then export LS_COLORS="$(vivid generate molokai)"; elif has dircolors; then eval "$(dircolors -b)" &>/dev/null; fi
LS_COLORS=${LS_COLORS:-'di=34:ln=35:so=32:pi=33:ex=31:'}
zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"

# fzf-tab if present in bundle
(( $+functions[fzf_completion] )) && bindkey '^I' fzf_completion

# ===== Keybindings =====
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
dot-expansion(){ if [[ $LBUFFER = *.. ]]; then LBUFFER+='/..'; else LBUFFER+='.'; fi; }
zle -N dot-expansion
bindkey '.' dot-expansion

# ===== Aliases =====
alias ls='eza --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale'
alias ll='eza --all --header --long --git --icons --classify --group-directories-first --time-style=long-iso --group --color-scale'
alias llm='ll --sort=modified'
alias la='eza -lbhHigUmuSa'
alias tree='eza -T'
alias grep='grep --color=auto'
alias python='python3'; alias pip='python3 -m pip'
alias make="make -j$(nproc)"; alias ninja="ninja -j$(nproc)"; alias mkdir='mkdir -p'
alias e='$EDITOR'; alias r='bat -p'; alias dirs='dirs -v'; alias which='command -v'
alias open='termux-open'; alias reload='termux-reload-settings'
alias battery='termux-battery-status'; alias clipboard='termux-clipboard-get'
alias copy='termux-clipboard-set'; alias share='termux-share'; alias notify='termux-notification'
alias -s {css,gradle,html,js,json,md,patch,properties,txt,xml,yml}="$PAGER"
alias -s gz='gzip -l'; alias -s {log,out}='tail -F'
alias -g -- -h='-h 2>&1 | bat -plhelp'; alias -g -- --help='--help 2>&1 | bat -plhelp'
alias -g L="| ${PAGER:-less}" G="| rg -i" NE="2>/dev/null" NUL=">/dev/null 2>&1"

# ===== Functions =====
mkcd(){ mkdir -p -- "$1" && cd -- "$1" || return 1; }
extract(){ [[ -f $1 ]] || { printf 'File not found: %s\n' "$1" >&2; return 1; }
  case "${1##*.}" in tar|tgz) tar -xf "$1" ;; tar.gz) tar -xzf "$1" ;; tar.bz2|tbz2) tar -xjf "$1" ;;
    tar.xz|txz) tar -xJf "$1" ;; zip) unzip -q "$1" ;; rar) unrar x "$1" ;;
    gz) gunzip "$1" ;; bz2) bunzip2 "$1" ;; 7z) 7z x "$1" ;; *) printf 'Unsupported archive: %s\n' "$1" >&2; return 2 ;; esac
}
fcd(){ local root="." q sel preview; [[ $# -gt 0 && -d $1 ]] && { root="$1"; shift; }; q="${*:-}"
  preview=$(( $+commands[eza] )) && preview='eza -T -L2 --color=always {}' || preview='ls -la --color=always {}'
  if (( $+commands[fd] )); then sel="$(fd -HI -t d . "$root" 2>/dev/null | fzf --ansi --height "${FZF_HEIGHT:-60%}" --layout=reverse --border --select-1 --exit-0 --preview "$preview" "${q:+--query "$q"}")"
  else sel="$(find "$root" -type d -not -path '*/.git/*' -print 2>/dev/null | fzf --ansi --height "${FZF_HEIGHT:-60%}" --layout=reverse --border --select-1 --exit-0 --preview "$preview" "${q:+--query "$q"}")"; fi
  [[ -n $sel ]] && cd -- "$sel"
}
fe(){ local -a files; local q="${*:-}" preview; if (( $+commands[bat] )); then preview='bat -n --style=plain --color=always --line-range=:500 {}'; else preview='head -n 500 {}'; fi
  if (( $+commands[fzf] )); then files=("${(@f)$(fzf --multi --select-1 --exit-0 ${q:+--query="$q"} --preview "$preview")}"); else print -r -- "fzf not found" >&2; return 127; fi
  [[ ${#files} -gt 0 ]] && "${EDITOR:-micro}" "${files[@]}"
}
h(){ curl -s "cheat.sh/${@:-}"; }

# Quick clean utility
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

# Revancify bootstrapper
revancify() {
  if [[ -f $HOME/revancify-xisr/revancify.sh ]]; then
    bash "$HOME/revancify-xisr/revancify.sh"
  else
    curl -sL https://github.com/Xisrr1/Revancify-Xisr/raw/main/install.sh | bash
  fi
}

# Simplify bootstrapper
simplify() {
  [[ -f $HOME/.Simplify.sh ]] || curl -sL -o "$HOME/.Simplify.sh" "https://raw.githubusercontent.com/arghya339/Simplify/main/Termux/Simplify.sh"
  bash "$HOME/.Simplify.sh"
}

# ===== Integrations & finalize =====
ifsource ~/.p10k.zsh
has zoxide && eval "$(zoxide init zsh --cmd cd)"
has thefuck && eval "$(thefuck --alias)"
has mise && eval "$(mise activate zsh)"

# Smart precompile
(){ local zcompdir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcomp"; ensure_dir "$zcompdir"
  local compile_if_needed(){ local src=$1 dst="$zcompdir/${src:t}.zwc"
    if [[ -f $src && (! -f $dst || $src -nt $dst) ]]; then zcompile -U "$dst" "$src" &>/dev/null && ln -sf "$dst" "${src}.zwc" &>/dev/null; fi
  }
  { for f in ~/.zsh{rc,env} ~/.p10k.zsh ~/.config/zsh/*.zsh(N); do compile_if_needed "$f"; done; } &!
}

alias debon="proot-distro login --user $USER debian"
