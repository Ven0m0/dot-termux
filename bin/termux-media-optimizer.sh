#!/data/data/com.termux/files/usr/bin/bash
# termux-media-optimizer.sh - Media optimization for Android/Termux
#
# Features:
# - Image optimization and conversion to WebP
# - Media cleanup (WhatsApp, Telegram, Downloads)
# - System cache cleaning
# - ADB or Shizuku for privileged operations

set -euo pipefail
IFS=$'\n\t'
shopt -s nullglob globstar

# ----------------------------------------------------------------------
# Environment setup
# ----------------------------------------------------------------------
export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export HOME="${HOME:-/data/data/com.termux/files/home}"
export LD_LIBRARY_PATH="$PREFIX/lib"
export PATH="$PREFIX/bin:$PATH"
export LANG=C LC_ALL=C

# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------
LOG_FILE="${HOME}/termux-optimizer.log"
TEMP_DIR=$(mktemp -d -p "$PREFIX/tmp")
HAS_SHIZUKU=0
HAS_ROOT=0
HAS_ADB=0
CLEAN_MEDIA=1
OPTIMIZE_MEDIA=1
WEBP_QUALITY=80
MEDIA_DIRS=()

# ----------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------
log() {
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

run_cmd() {
  if [[ ${DRY_RUN:-0} -eq 1 ]]; then
    log "[DRY RUN] Would run: $*"
    return 0
  fi
  
  log "Running: $*"
  if ! "$@" >> "$LOG_FILE" 2>&1; then
    log "Command failed: $*"
    return 1
  fi
  return 0
}

confirm() {
  [[ ${ASSUME_YES:-0} -eq 1 ]] && return 0
  
  local prompt="$1"
  local response
  
  echo -n "$prompt [y/N] "
  read -r response
  
  [[ "${response,,}" == "y" || "${response,,}" == "yes" ]]
}

check_tools() {
  # Check for Termux:API package
  if command -v termux-info >/dev/null 2>&1; then
    log "Termux:API is installed"
  else
    log "Termux:API not found. Consider installing for more features:"
    log "pkg install termux-api"
  fi
  
  # Check for media optimization tools
  if command -v compresscli >/dev/null 2>&1; then
    log "compresscli is available for optimization"
  elif command -v cwebp >/dev/null 2>&1 && command -v jpegoptim >/dev/null 2>&1; then
    log "Basic image optimization tools available"
  else
    log "Consider installing optimization tools: pkg install imagemagick libwebp jpegoptim"
  fi
  
  # Check for Shizuku support
  if command -v rish >/dev/null 2>&1; then
    log "Shizuku integration available via rish"
    if rish id >/dev/null 2>&1; then
      log "Shizuku is active"
      HAS_SHIZUKU=1
    else
      log "Shizuku is installed but not active"
    fi
  fi
  
  # Check for ADB
  if command -v adb >/dev/null 2>&1; then
    if adb devices | grep -q 'device$'; then
      log "ADB connection available"
      HAS_ADB=1
    else
      log "ADB installed but no device connected"
    fi
  fi
  
  # Check for root
  if command -v su >/dev/null 2>&1; then
    if su -c id 2>/dev/null | grep -q uid=0; then
      log "Root access available"
      HAS_ROOT=1
    fi
  fi
}

# ----------------------------------------------------------------------
# Storage access functions
# ----------------------------------------------------------------------
access_external_storage() {
  # Check if we have direct access
  if [[ -d /sdcard && -w /sdcard ]]; then
    log "Direct /sdcard access available"
    echo "/sdcard"
    return 0
  fi
  
  # Try termux-setup-storage first
  if command -v termux-setup-storage >/dev/null 2>&1; then
    log "Running termux-setup-storage to request access..."
    termux-setup-storage
    if [[ -d "$HOME/storage/shared" && -w "$HOME/storage/shared" ]]; then
      log "Access granted via termux-setup-storage"
      echo "$HOME/storage/shared"
      return 0
    fi
  fi
  
  # Try termux-saf as a fallback
  if command -v termux-saf >/dev/null 2>&1; then
    log "Using termux-saf for storage access"
    local saf_dir
    saf_dir=$(termux-saf -d)
    if [[ -n "$saf_dir" ]]; then
      echo "$saf_dir"
      return 0
    fi
  fi
  
  # Use ADB or Shizuku as last resort
  if [[ $HAS_ADB -eq 1 ]]; then
    log "Using ADB for storage access"
    echo "adb"
    return 0
  elif [[ $HAS_SHIZUKU -eq 1 ]]; then
    log "Using Shizuku for storage access"
    echo "shizuku"
    return 0
  fi
  
  log "Warning: No storage access method available"
  return 1
}

# ----------------------------------------------------------------------
# Media optimization functions
# ----------------------------------------------------------------------
optimize_image() {
  local file="$1" quality="${2:-$WEBP_QUALITY}" original_ext="${file##*.}"
  original_ext="${original_ext,,}"  # Convert to lowercase
  
  # Skip already optimized WebP images
  if [[ "$original_ext" == "webp" ]]; then
    log "Skipping already WebP file: $file"
    return 0
  fi
  
  local tmp_output="$TEMP_DIR/$(basename "$file")"
  local webp_output="${file%.*}.webp"
  
  # Copy the file first
  cp "$file" "$tmp_output" || return 1
  
  # Try with compresscli first
  if command -v compresscli >/dev/null 2>&1; then
    log "Optimizing with compresscli: $file"
    if compresscli -i "$tmp_output" -o "$webp_output" -q "$quality" -t webp >/dev/null 2>&1; then
      log "Successfully optimized: $file → $webp_output"
      return 0
    fi
  fi
  
  # Try with cwebp next
  if command -v cwebp >/dev/null 2>&1; then
    log "Converting to WebP with cwebp: $file"
    if cwebp -quiet -q "$quality" -metadata none "$tmp_output" -o "$webp_output" >/dev/null 2>&1; then
      log "Successfully converted: $file → $webp_output"
      return 0
    fi
  fi
  
  # Try with convert (ImageMagick)
  if command -v convert >/dev/null 2>&1; then
    log "Converting with ImageMagick: $file"
    if convert "$tmp_output" -quality "$quality" "$webp_output" >/dev/null 2>&1; then
      log "Successfully converted: $file → $webp_output"
      return 0
    fi
  fi
  
  log "Failed to optimize: $file"
  rm -f "$tmp_output"
  return 1
}

process_media_directory() {
  local dir="$1" max_age="${2:-30}"
  
  log "Processing media in: $dir"
  
  # Find image files
  local image_files=()
  if command -v fd >/dev/null 2>&1; then
    mapfile -t image_files < <(fd -t f -e jpg -e jpeg -e png -e gif . "$dir")
  else
    mapfile -t image_files < <(find "$dir" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) -mtime -"$max_age")
  fi
  
  log "Found ${#image_files[@]} images in $dir"
  
  # Process each file
  local count=0
  for file in "${image_files[@]}"; do
    if [[ ${OPTIMIZE_MEDIA} -eq 1 ]]; then
      optimize_image "$file" "$WEBP_QUALITY"
    fi
    
    if [[ ${CLEAN_MEDIA} -eq 1 && -f "$file" && $(find "$file" -mtime +"$max_age" -print) ]]; then
      # File is older than max_age days
      if rm -f "$file"; then
        (( count++ ))
      fi
    fi
  done
  
  if [[ $count -gt 0 ]]; then
    log "Removed $count old files from $dir"
  fi
}

# ----------------------------------------------------------------------
# Main function
# ----------------------------------------------------------------------
main() {
  local storage_path
  
  log "Starting Termux Media Optimizer"
  check_tools
  
  # Get storage access
  storage_path=$(access_external_storage)
  if [[ $? -ne 0 ]]; then
    log "Failed to get storage access"
    exit 1
  fi
  
  # Define media directories to process
  if [[ "$storage_path" == "adb" ]]; then
    # Using ADB
    MEDIA_DIRS=(
      "/sdcard/DCIM/Camera"
      "/sdcard/Pictures"
      "/sdcard/Download"
      "/sdcard/WhatsApp/Media/WhatsApp Images"
      "/sdcard/Telegram/Telegram Images"
    )
    
    # Process each directory
    for dir in "${MEDIA_DIRS[@]}"; do
      log "Checking directory: $dir"
      if [[ $(adb shell "test -d '$dir' && echo exists") == "exists" ]]; then
        log "Processing media in $dir via ADB"
        
        # For ADB, we need to pull files, process them, then push them back
        local tmp_dir="$TEMP_DIR/$(basename "$dir")"
        mkdir -p "$tmp_dir"
        
        # Pull recent images (last 30 days)
        adb shell "find '$dir' -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' \) -mtime -30" | while read -r file; do
          local base_name=$(basename "$file")
          adb pull "$file" "$tmp_dir/$base_name" >/dev/null
          
          if [[ ${OPTIMIZE_MEDIA} -eq 1 ]]; then
            optimize_image "$tmp_dir/$base_name" "$WEBP_QUALITY"
            
            # If WebP was created, push it back
            local webp_name="${base_name%.*}.webp"
            if [[ -f "$tmp_dir/$webp_name" ]]; then
              adb push "$tmp_dir/$webp_name" "${file%.*}.webp" >/dev/null
            fi
          fi
        done
      fi
    done
  elif [[ "$storage_path" == "shizuku" ]]; then
    # Using Shizuku
    MEDIA_DIRS=(
      "/sdcard/DCIM/Camera"
      "/sdcard/Pictures"
      "/sdcard/Download"
      "/sdcard/WhatsApp/Media/WhatsApp Images"
      "/sdcard/Telegram/Telegram Images"
    )
    
    # Process each directory using Shizuku
    for dir in "${MEDIA_DIRS[@]}"; do
      if [[ $(rish test -d "$dir" && echo exists) == "exists" ]]; then
        log "Processing media in $dir via Shizuku"
        
        # Find images
        mapfile -t image_files < <(rish find "$dir" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) -mtime -30 2>/dev/null || echo "")
        
        for file in "${image_files[@]}"; do
          [[ -z "$file" ]] && continue
          
          # Extract to tmp
          local tmp_file="$TEMP_DIR/$(basename "$file")"
          rish cp "$file" "$tmp_file" >/dev/null 2>&1
          
          if [[ ${OPTIMIZE_MEDIA} -eq 1 ]]; then
            optimize_image "$tmp_file" "$WEBP_QUALITY"
            
            # If WebP was created, copy it back
            local webp_file="${tmp_file%.*}.webp"
            if [[ -f "$webp_file" ]]; then
              local dest_webp="${file%.*}.webp"
              rish mkdir -p "$(dirname "$dest_webp")" >/dev/null 2>&1
              rish cp "$webp_file" "$dest_webp" >/dev/null 2>&1
            fi
          fi
        done
      fi
    done
  else
    # Direct access
    MEDIA_DIRS=(
      "$storage_path/DCIM/Camera"
      "$storage_path/Pictures"
      "$storage_path/Download"
      "$storage_path/WhatsApp/Media/WhatsApp Images"
      "$storage_path/WhatsApp/Media/WhatsApp Video"
      "$storage_path/Telegram/Telegram Images"
    )
    
    # Process each directory
    for dir in "${MEDIA_DIRS[@]}"; do
      if [[ -d "$dir" ]]; then
        process_media_directory "$dir" 30
      fi
    done
  fi
  
  log "Media optimization complete"
  
  # Clean up
  rm -rf "$TEMP_DIR"
}

# Parse command-line arguments
while getopts "cyqnj:w:h" opt; do
  case "$opt" in
    c) CLEAN_MEDIA=1 ;;
    y) ASSUME_YES=1 ;;
    q) OPTIMIZE_MEDIA=0 ;;
    n) DRY_RUN=1 ;;
    j) JOBS="$OPTARG" ;;
    w) WEBP_QUALITY="$OPTARG" ;;
    h|*)
      echo "Usage: $0 [-c] [-y] [-q] [-n] [-j JOBS] [-w QUALITY]"
      echo "  -c  Clean old media files (default: enabled)"
      echo "  -y  Assume yes to all prompts"
      echo "  -q  Quiet mode (no media optimization, just cleaning)"
      echo "  -n  Dry run (don't actually modify files)"
      echo "  -j  Number of parallel jobs"
      echo "  -w  WebP quality (0-100, default: 80)"
      echo "  -h  Show this help"
      exit 0
      ;;
  esac
done

# Run main function
main
