#!/data/data/com.termux/files/usr/bin/env bash

# Install JetBrains Mono font with proper error handling and progress feedback
setup_font() {
  print_step "Installing JetBrains Mono font"
  local font_dir="${HOME}/.termux/font"
  local temp_file temp_dir tag_name release_url
  
  # Create font directory
  mkdir -p "$font_dir"
  
  # Get latest release information using GitHub API
  log "Fetching latest JetBrains Mono release info"
  temp_file=$(mktemp)
  
  if ! curl -sL "https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest" -o "$temp_file"; then
    log "Failed to fetch release info. Using fallback version."
    release_url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
  else
    # Extract release URL using awk for better performance
    tag_name=$(awk -F '"' '/tag_name/ {print $4; exit}' "$temp_file")
    release_url=$(awk -F '"' '/browser_download_url/ {print $4; exit}' "$temp_file")
    log "Found latest version: $tag_name"
  fi
  
  # Download and extract the font
  log "Downloading font archive: $release_url"
  temp_dir=$(mktemp -d)
  local zip_file="${temp_dir}/jetbrains-mono.zip"
  
  if curl -sL "$release_url" -o "$zip_file"; then
    log "Extracting regular font file"
    unzip -j "$zip_file" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$temp_dir" >/dev/null 2>&1
    
    if [[ -f "${temp_dir}/JetBrainsMono-Regular.ttf" ]]; then
      cp "${temp_dir}/JetBrainsMono-Regular.ttf" "${font_dir}/font.ttf"
      log "JetBrains Mono installed successfully"
      termux-reload-settings >/dev/null 2>&1 || true
    else
      log "Font extraction failed"
    fi
  else
    log "Font download failed"
  fi
  
  # Cleanup temp files
  rm -rf "$temp_file" "$temp_dir"
}
