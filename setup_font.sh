#!/data/data/com.termux/files/usr/bin/env bash

# Install JetBrains Mono font with proper error handling and progress feedback
setup_font() {
  print_step "Installing JetBrains Mono font"
  local font_dir="$HOME/.termux/font"
  local temp_json temp_zip tag_name browser_url
  
  mkdir -p "$font_dir"
  
  temp_json=$(mktemp)
  # Use expr/grep instead of jq dependency
  if curl -sL "https://api.github.com/repos/JetBrains/JetBrainsMono/releases/latest" -o "$temp_json"; then
    tag_name=$(grep -o '"tag_name": *"[^"]*"' "$temp_json" | cut -d'"' -f4)
    browser_url=$(grep -o '"browser_download_url": *"[^"]*"' "$temp_json" | head -1 | cut -d'"' -f4)
    log "Found JetBrains Mono version: $tag_name"
  else
    # Fallback to known version
    browser_url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
    log "Using fallback version v2.304"
  fi
  
  temp_zip=$(mktemp)
  if curl -sL "$browser_url" -o "$temp_zip"; then
    unzip -j "$temp_zip" "fonts/ttf/JetBrainsMono-Regular.ttf" -d "$font_dir" >/dev/null 2>&1 &&
      mv "$font_dir/JetBrainsMono-Regular.ttf" "$font_dir/font.ttf" &&
      log "JetBrains Mono installed successfully"
    termux-reload-settings >/dev/null 2>&1 || true
  else
    log "Failed to download JetBrains Mono"
  fi
  
  # Clean up temps
  rm -f "$temp_json" "$temp_zip"
}
