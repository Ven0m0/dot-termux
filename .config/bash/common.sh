#!/usr/bin/env bash
# common.sh - Shared utilities for all shell scripts
# This library provides reusable functions for dependency checking,
# logging, file operations, path helpers, and tool detection.

set -euo pipefail
export LC_ALL=C

# ============================================================================
# TOOL DETECTION
# ============================================================================

# Check if a command exists
has(){
  command -v -- "$1" >/dev/null 2>&1
}

# Get best available string replacement tool (sd preferred over sed)
get_replace_tool(){
  local -n _tool=$1
  if has sd; then
    _tool="sd"
  else
    _tool="sed"
  fi
}

# Get best available find tool (fd preferred over find)
get_find_tool(){
  local -n _tool=$1
  if has fd; then
    _tool="fd"
  else
    _tool="find"
  fi
}

# Execute string replacement using best available tool
str_replace(){
  local pattern=$1
  local replacement=$2
  local file=${3:-}
  
  if has sd; then
    if [[ -n $file ]]; then
      sd "$pattern" "$replacement" "$file"
    else
      sd "$pattern" "$replacement"
    fi
  else
    if [[ -n $file ]]; then
      sed -E "s/$pattern/$replacement/g" "$file"
    else
      sed -E "s/$pattern/$replacement/g"
    fi
  fi
}

# Find files using best available tool
find_files(){
  local path=$1
  shift
  
  if has fd; then
    fd "$@" . "$path"
  else
    find "$path" "$@"
  fi
}

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

# Check if all required dependencies are installed
# Usage: check_deps dep1 dep2 dep3 ...
# Returns: 0 if all deps exist, 1 if any are missing
check_deps(){
  local missing=()
  local dep
  for dep in "$@"; do
    has "$dep" || missing+=("$dep")
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Require dependencies or exit with error
# Usage: require_deps dep1 dep2 dep3 ...
require_deps(){
  local missing=()
  local dep
  for dep in "$@"; do
    has "$dep" || missing+=("$dep")
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'Error: Missing dependencies: %s\n' "${missing[*]}" >&2
    printf 'Install with: pkg install %s\n' "${missing[*]}" >&2
    exit 127
  fi
}

# Check if package manager is available and suggest install command
suggest_install(){
  local -a pkgs=("$@")
  
  if has pkg; then
    printf 'pkg install %s\n' "${pkgs[*]}"
  elif has apt-get; then
    printf 'sudo apt-get install -y %s\n' "${pkgs[*]}"
  elif has pacman; then
    printf 'sudo pacman -S --needed %s\n' "${pkgs[*]}"
  elif has brew; then
    printf 'brew install %s\n' "${pkgs[*]}"
  else
    printf '%s\n' "${pkgs[*]}"
  fi
}

# ============================================================================
# LOGGING
# ============================================================================

# Log message with timestamp
log(){
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# Log to file with timestamp
log_file(){
  local file=$1
  shift
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$file"
}

# Print error message to stderr
err(){
  printf 'Error: %s\n' "$*" >&2
}

# Print warning message to stderr
warn(){
  printf 'Warning: %s\n' "$*" >&2
}

# Print info message
info(){
  printf 'Info: %s\n' "$*"
}

# Print debug message if DEBUG is set
debug(){
  [[ ${DEBUG:-0} -eq 1 ]] && printf 'Debug: %s\n' "$*" >&2
}

# Print step header
print_step(){
  printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$1"
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# Create directory if it doesn't exist
ensure_dir(){
  local dir=$1
  [[ -d $dir ]] || mkdir -p "$dir"
}

# Touch file and create parent directories
touchf(){
  local file=$1
  ensure_dir "$(dirname "$file")"
  touch "$file"
}

# Check if file exists and is readable
is_readable(){
  [[ -r $1 ]]
}

# Check if file exists and is writable
is_writable(){
  [[ -w $1 ]]
}

# Check if file exists and is executable
is_executable(){
  [[ -x $1 ]]
}

# Backup file with timestamp
backup_file(){
  local file=$1
  local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
  [[ -e $file ]] && cp -p "$file" "$backup"
}

# Create symlink with backup of existing file
safe_symlink(){
  local src=$1
  local dst=$2
  
  ensure_dir "$(dirname "$dst")"
  
  if [[ -e $dst || -L $dst ]]; then
    backup_file "$dst"
    rm -f "$dst"
  fi
  
  ln -sf "$src" "$dst"
}

# Read file content into variable using nameref
read_file(){
  local -n _content=$1
  local file=$2
  _content=$(<"$file")
}

# ============================================================================
# PATH HELPERS
# ============================================================================

# Get absolute path
abspath(){
  local -n _path=$1
  local rel_path=$2
  _path=$(cd "$(dirname "$rel_path")" && pwd)/$(basename "$rel_path")
}

# Get directory name
dirname_safe(){
  local -n _dir=$1
  local path=$2
  _dir=$(dirname "$path")
}

# Get base name without extension
basename_noext(){
  local -n _name=$1
  local path=$2
  local base
  base=$(basename "$path")
  _name="${base%.*}"
}

# Get file extension
get_extension(){
  local -n _ext=$1
  local path=$2
  _ext="${path##*.}"
}

# Add directory to PATH if not already present
add_to_path(){
  local dir=$1
  [[ -d $dir ]] || return 1
  [[ :$PATH: == *":$dir:"* ]] && return 0
  export PATH="$dir:$PATH"
}

# Prepend directory to PATH if not already present
prepend_path(){
  local dir=$1
  [[ -d $dir ]] || return 1
  [[ :$PATH: == *":$dir:"* ]] && return 0
  export PATH="$dir:$PATH"
}

# ============================================================================
# NETWORK HELPERS
# ============================================================================

# Check internet connectivity
check_internet(){
  if has curl; then
    curl -s --connect-timeout 3 -o /dev/null http://www.google.com >/dev/null 2>&1
  elif has wget; then
    wget -q --spider --timeout=3 http://www.google.com >/dev/null 2>&1
  elif has ping; then
    ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1
  else
    return 1
  fi
}

# Download file with progress
download(){
  local url=$1
  local dest=$2
  
  if has curl; then
    curl -fsSL --progress-bar "$url" -o "$dest"
  elif has wget; then
    wget -q --show-progress "$url" -O "$dest"
  else
    err "No download tool available (curl or wget)"
    return 1
  fi
}

# ============================================================================
# STRING HELPERS
# ============================================================================

# Trim whitespace from string
trim(){
  local -n _str=$1
  local input=$2
  _str="${input#"${input%%[![:space:]]*}"}"
  _str="${_str%"${_str##*[![:space:]]}"}"
}

# Convert string to lowercase
to_lower(){
  local -n _str=$1
  local input=$2
  _str="${input,,}"
}

# Convert string to uppercase
to_upper(){
  local -n _str=$1
  local input=$2
  _str="${input^^}"
}

# Check if string contains substring
contains(){
  [[ $1 == *"$2"* ]]
}

# ============================================================================
# PROCESS HELPERS
# ============================================================================

# Sleep with silent error handling
sleepy(){
  read -rt "${1:-1}" -- <> <(:) >/dev/null 2>&1 || :
}

# Run command with timeout
run_with_timeout(){
  local timeout=$1
  shift
  timeout "$timeout" "$@" >/dev/null 2>&1 || :
}

# ============================================================================
# CONFIRMATION HELPERS
# ============================================================================

# Ask for confirmation (returns 0 for yes, 1 for no)
confirm(){
  local prompt=${1:-"Continue?"}
  local response
  
  read -rp "$prompt [y/N] " response
  [[ ${response,,} =~ ^(y|yes)$ ]]
}

# Ask for confirmation with default yes
confirm_yes(){
  local prompt=${1:-"Continue?"}
  local response
  
  read -rp "$prompt [Y/n] " response
  [[ ! ${response,,} =~ ^(n|no)$ ]]
}

# ============================================================================
# CACHE HELPERS
# ============================================================================

# Get cache directory
get_cache_dir(){
  local -n _dir=$1
  _dir="${XDG_CACHE_HOME:-$HOME/.cache}"
}

# Clear cache directory
clear_cache(){
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  find "$cache_dir" -type f -delete >/dev/null 2>&1 || :
}

# ============================================================================
# EXPORTS
# ============================================================================

# Export all functions for subshells
export -f has get_replace_tool get_find_tool str_replace find_files
export -f check_deps require_deps suggest_install
export -f log log_file err warn info debug print_step
export -f ensure_dir touchf is_readable is_writable is_executable
export -f backup_file safe_symlink read_file
export -f abspath dirname_safe basename_noext get_extension add_to_path prepend_path
export -f check_internet download
export -f trim to_lower to_upper contains
export -f sleepy run_with_timeout
export -f confirm confirm_yes
export -f get_cache_dir clear_cache
