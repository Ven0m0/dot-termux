#!/usr/bin/env bash
#
# optimize - Unified media optimization script for Termux
#
# Comprehensive tool for optimizing images, videos, and audio files with
# modern codec support and intelligent format conversion priorities.
#
# Features:
# - Lossless and lossy image optimization (including JXL support)
# - Video re-encoding: AV1, VP9, H.265, H.264 with MKV cleaning
# - Format conversion with priority: WebP -> AVIF -> JXL -> JPG -> PNG
# - Audio optimization: Opus (priority), FLAC
# - Animated GIF to WebP conversion
# - Parallel processing with modern tool preferences
# - Flexible input: stdin, files, or directories
#

set -euo pipefail
IFS=$'\n\t'
export LC_ALL=C

# --- Configuration Defaults ---
QUALITY=85        # Image quality (1-100)
VIDEO_CRF=27      # Video CRF (0-51, lower is better quality)
VIDEO_CODEC="vp9" # Default video codec (vp9, av1, h265, h264)
AUDIO_BITRATE=128 # Audio bitrate for Opus (kbps)
JOBS=0            # Parallel jobs (0 = auto-detect)
SUFFIX="_opt"     # Suffix for optimized files

# Mode flags
KEEP_ORIGINAL=0   # Keep original files
INPLACE=0         # Replace originals in-place
RECURSIVE=0       # Process directories recursively
CONVERT_FORMAT="" # Convert to specific format (webp, avif, jxl, png, jpg)
LOSSLESS=1        # Default to lossless mode
OUTPUT_DIR=""     # Output directory
MEDIA_TYPE="all"  # all, image, video, audio
MKV_TO_MP4=0      # Convert MKV to MP4
GIF_TO_WEBP=1     # Convert GIFs to animated WebP (default enabled)

# Codec priority for image conversion (best compression/compatibility balance)
# Priority: webp (best compatibility) -> avif -> jxl -> jpg -> png
IMAGE_CODEC_PRIORITY=("webp" "avif" "jxl" "jpg" "png")

# --- Helper Functions ---
has() {
  command -v "$1" >/dev/null 2>&1
}

# Tool availability cache
declare -A TOOL_CACHE
cache_tool() {
  local tool=$1
  if [[ -z ${TOOL_CACHE[$tool]:-} ]]; then
    if has "$tool"; then
      TOOL_CACHE[$tool]=1
    else
      TOOL_CACHE[$tool]=0
    fi
  fi
  return $((1 - TOOL_CACHE[$tool]))
}

# Cached nproc
NPROC_CACHED=""
get_nproc() {
  if [[ -z $NPROC_CACHED ]]; then
    NPROC_CACHED=$(nproc 2>/dev/null || echo 4)
  fi
  echo "$NPROC_CACHED"
}

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

err() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

get_size() {
  stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo 0
}

format_bytes() {
  local bytes=$1
  if has numfmt; then
    numfmt --to=iec-i --suffix=B --format="%.2f" "$bytes"
  else
    if ((bytes < 1024)); then
      printf '%dB' "$bytes"
    elif ((bytes < 1048576)); then
      printf '%.1fKB' "$(awk "BEGIN {print $bytes/1024}")"
    else
      printf '%.2fMB' "$(awk "BEGIN {print $bytes/1048576}")"
    fi
  fi
}

get_output_path() {
  local src=$1
  local fmt=$2
  local base_name ext name

  base_name=$(basename "$src")
  name="${base_name%.*}"
  ext="${base_name##*.}"

  # Handle MKV to MP4 conversion
  if [[ $MKV_TO_MP4 -eq 1 && ${ext,,} == "mkv" ]]; then
    fmt="mp4"
  fi

  if [[ -n $OUTPUT_DIR ]]; then
    if [[ -n $fmt && $fmt != "${ext,,}" ]]; then
      echo "$OUTPUT_DIR/${name}.${fmt}"
    elif [[ $INPLACE -eq 1 ]]; then
      echo "$OUTPUT_DIR/${base_name}"
    else
      echo "$OUTPUT_DIR/${name}${SUFFIX}.${ext}"
    fi
  else
    if [[ -n $fmt && $fmt != "${ext,,}" ]]; then
      echo "$(dirname "$src")/${name}.${fmt}"
    elif [[ $INPLACE -eq 1 ]]; then
      echo "$src"
    else
      echo "$(dirname "$src")/${name}${SUFFIX}.${ext}"
    fi
  fi
}

# Get preferred image manipulation tool: gm (GraphicsMagick) > convert (ImageMagick)
get_convert_tool() {
  if has gm; then
    echo "gm convert"
  elif has convert; then
    echo "convert"
  else
    return 1
  fi
}

# --- Image Optimization Functions ---
optimize_png() {
  local src=$1 out=$2
  local orig_sz tmp success=0

  orig_sz=$(get_size "$src")
  tmp="${out}.tmp"

  # Tool preference: oxipng > optipng > pngcrush
  if cache_tool oxipng; then
    cp "$src" "$tmp"
    if [[ $LOSSLESS -eq 1 ]]; then
      oxipng -o6 --strip safe -q "$tmp" 2>/dev/null && success=1
    else
      oxipng -o6 --strip safe -q "$tmp" 2>/dev/null || :
      if cache_tool pngquant; then
        pngquant --quality=65-"$QUALITY" --strip --speed 1 -f "$tmp" -o "${tmp}.2" 2>/dev/null && mv "${tmp}.2" "$tmp" && success=1 || success=1
      else
        success=1
      fi
    fi
  elif cache_tool optipng; then
    cp "$src" "$tmp"
    if [[ $LOSSLESS -eq 1 ]]; then
      optipng -o7 -strip all -quiet "$tmp" 2>/dev/null && success=1
    else
      if cache_tool pngquant; then
        pngquant --quality=65-"$QUALITY" --strip --speed 1 -f "$src" -o "$tmp" 2>/dev/null || cp "$src" "$tmp"
        optipng -o2 -strip all -quiet "$tmp" 2>/dev/null || :
      else
        optipng -o7 -strip all -quiet "$tmp" 2>/dev/null || :
      fi
      success=1
    fi
  elif cache_tool pngcrush; then
    pngcrush -rem alla -reduce "$src" "$tmp" 2>/dev/null && success=1 || cp "$src" "$tmp"
  else
    cp "$src" "$tmp"
    success=1
  fi

  if [[ $success -eq 1 ]]; then
    mv "$tmp" "$out"
    echo "$((orig_sz - $(get_size "$out")))"
  else
    rm -f "$tmp"
    return 1
  fi
}

optimize_jpeg() {
  local src=$1 out=$2
  local orig_sz tmp success=0

  orig_sz=$(get_size "$src")
  tmp="${out}.tmp"

  # Tool preference: jpegoptim > mozjpeg
  if cache_tool jpegoptim; then
    if [[ $LOSSLESS -eq 1 ]]; then
      jpegoptim --strip-all --stdout "$src" >"$tmp" 2>/dev/null && success=1
    else
      jpegoptim --max="$QUALITY" --strip-all --stdout "$src" >"$tmp" 2>/dev/null && success=1
    fi
  elif cache_tool mozjpeg || cache_tool cjpeg; then
    local jpeg_tool=$(has cjpeg && echo "cjpeg" || echo "convert")
    "$jpeg_tool" -quality "$QUALITY" -optimize "$src" >"$tmp" 2>/dev/null && success=1
  else
    local convert_tool=$(get_convert_tool)
    if [[ -n $convert_tool ]]; then
      "$convert_tool" "$src" -quality "$QUALITY" -strip "$tmp" 2>/dev/null && success=1
    else
      cp "$src" "$tmp"
      success=1
    fi
  fi

  if [[ $success -eq 1 ]]; then
    mv "$tmp" "$out"
    echo "$((orig_sz - $(get_size "$out")))"
  else
    rm -f "$tmp"
    return 1
  fi
}

optimize_jxl() {
  local src=$1 out=$2
  local orig_sz tmp success=0

  orig_sz=$(get_size "$src")
  tmp="${out}.tmp"

  # Tool: cjxl (JPEG XL encoder)
  if has cjxl; then
    if [[ $LOSSLESS -eq 1 ]]; then
      cjxl "$src" "$tmp" -d 0 -e 7 2>/dev/null && success=1
    else
      cjxl "$src" "$tmp" -q "$QUALITY" -e 7 2>/dev/null && success=1
    fi
  else
    warn "cjxl not found, cannot optimize JXL"
    return 1
  fi

  if [[ $success -eq 1 ]]; then
    mv "$tmp" "$out"
    echo "$((orig_sz - $(get_size "$out")))"
  else
    rm -f "$tmp"
    return 1
  fi
}

optimize_image() {
  local src=$1
  local ext="${src##*.}"
  ext="${ext,,}"
  local out fmt

  # Determine output format
  if [[ -n $CONVERT_FORMAT ]]; then
    fmt="$CONVERT_FORMAT"
  else
    fmt="$ext"
  fi

  out=$(get_output_path "$src" "$fmt")

  # Skip if output exists and we're keeping originals
  if [[ -f $out && $KEEP_ORIGINAL -eq 1 && $INPLACE -eq 0 ]]; then
    return 0
  fi

  local orig_sz new_sz saved pct
  orig_sz=$(get_size "$src")

  log "Processing image: $(basename "$src")"

  # Special case: GIF to animated WebP conversion
  if [[ $ext == "gif" && $GIF_TO_WEBP -eq 1 && ($CONVERT_FORMAT == "" || $CONVERT_FORMAT == "webp") ]]; then
    local tmp="${out%.gif}.webp"
    out="$tmp"
    if has gif2webp; then
      gif2webp -q "$QUALITY" -m 6 -mt "$src" -o "$tmp" 2>/dev/null
      if [[ -f $tmp ]]; then
        new_sz=$(get_size "$tmp")
        if ((new_sz > 0 && new_sz < orig_sz)); then
          saved=$((orig_sz - new_sz))
          pct=$((saved * 100 / orig_sz))
          printf '%s → %s | %s → %s (%d%%) [animated]\n' \
            "$(basename "$src")" "$(basename "$out")" \
            "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"

          if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then
            rm -f "$src"
          fi
          return 0
        fi
      fi
    fi
  fi

  # Format conversion using specialized tools
  if [[ $CONVERT_FORMAT != "" && $CONVERT_FORMAT != "$ext" ]]; then
    local tmp="${out}.tmp"
    local success=0
    local convert_tool=$(get_convert_tool)

    case "$CONVERT_FORMAT" in
    webp)
      if cache_tool cwebp; then
        cwebp -q "$QUALITY" -m 6 -mt -af "$src" -o "$tmp" 2>/dev/null && success=1
      elif [[ -n $convert_tool ]]; then
        "$convert_tool" "$src" -quality "$QUALITY" "$tmp" 2>/dev/null && success=1
      fi
      ;;
    avif)
      if cache_tool avifenc; then
        avifenc -s 6 -j "$(get_nproc)" --min 0 --max "$QUALITY" "$src" "$tmp" 2>/dev/null && success=1
      fi
      ;;
    jxl)
      if cache_tool cjxl; then
        if [[ $LOSSLESS -eq 1 ]]; then
          cjxl "$src" "$tmp" -d 0 -e 7 2>/dev/null && success=1
        else
          cjxl "$src" "$tmp" -q "$QUALITY" -e 7 2>/dev/null && success=1
        fi
      fi
      ;;
    jpg | jpeg)
      if [[ -n $convert_tool ]]; then
        "$convert_tool" "$src" -quality "$QUALITY" -strip "$tmp" 2>/dev/null && success=1
      fi
      ;;
    png)
      if [[ -n $convert_tool ]]; then
        "$convert_tool" "$src" PNG:"$tmp" 2>/dev/null && success=1
      fi
      ;;
    esac

    if [[ $success -eq 1 ]]; then
      mv "$tmp" "$out"
    else
      warn "Format conversion failed for $(basename "$src")"
      rm -f "$tmp"
      return 1
    fi
  else
    # Optimize in native format
    case "$ext" in
    png)
      optimize_png "$src" "$out" >/dev/null || return 1
      ;;
    jpg | jpeg)
      optimize_jpeg "$src" "$out" >/dev/null || return 1
      ;;
    jxl)
      optimize_jxl "$src" "$out" >/dev/null || return 1
      ;;
    gif)
      if has gifsicle; then
        gifsicle -O3 "$src" -o "$out" 2>/dev/null || return 1
      else
        cp "$src" "$out"
      fi
      ;;
    svg)
      if has svgcleaner; then
        svgcleaner "$src" "$out" 2>/dev/null || return 1
      elif has svgo; then
        svgo -i "$src" -o "$out" 2>/dev/null || return 1
      else
        cp "$src" "$out"
      fi
      ;;
    webp)
      if has cwebp; then
        cwebp -q "$QUALITY" -m 6 -mt "$src" -o "$out" 2>/dev/null || return 1
      else
        cp "$src" "$out"
      fi
      ;;
    avif)
      if cache_tool avifenc; then
        avifenc -s 6 -j "$(get_nproc)" --min 0 --max "$QUALITY" "$src" "$out" 2>/dev/null || return 1
      else
        cp "$src" "$out"
      fi
      ;;
    tiff | tif | bmp)
      # Use image-optimizer or rimage if available
      if has image-optimizer; then
        image-optimizer -i "$src" -o "$(dirname "$out")" -q "$QUALITY" 2>/dev/null || cp "$src" "$out"
      elif has imgc; then
        imgc "$src" "$ext" -q "$QUALITY" -o "$(dirname "$out")" 2>/dev/null || cp "$src" "$out"
      elif has rimage; then
        rimage -q "$QUALITY" "$src" -o "$out" 2>/dev/null || cp "$src" "$out"
      else
        cp "$src" "$out"
      fi
      ;;
    *)
      warn "Unsupported image format: $ext"
      return 1
      ;;
    esac
  fi

  # Report savings
  new_sz=$(get_size "$out")
  if ((new_sz > 0 && new_sz < orig_sz)); then
    saved=$((orig_sz - new_sz))
    pct=$((saved * 100 / orig_sz))
    printf '%s → %s | %s → %s (%d%%)\n' \
      "$(basename "$src")" "$(basename "$out")" \
      "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"

    # Remove original if inplace or not keeping
    if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then
      [[ $src != "$out" ]] && rm -f "$src"
    fi
  elif ((new_sz >= orig_sz)); then
    if [[ $CONVERT_FORMAT == "" ]]; then
      warn "No savings for $(basename "$src"), keeping original"
      rm -f "$out"
      return 1
    else
      log "Converted $(basename "$src") to $CONVERT_FORMAT"
    fi
  fi
}

# --- Video Optimization Functions ---
optimize_video() {
  local src=$1
  local ext="${src##*.}"
  local out

  out=$(get_output_path "$src" "$ext")

  # Skip if output exists
  if [[ -f $out && $KEEP_ORIGINAL -eq 1 && $INPLACE -eq 0 ]]; then
    return 0
  fi

  local orig_sz new_sz saved pct
  orig_sz=$(get_size "$src")

  log "Processing video: $(basename "$src")"

  local success=0
  local video_tool=""
  local enc_cmd=()
  local tmp_out="$out"

  # Tool preference: ffzap > ffmpeg
  if has ffzap; then
    video_tool="ffzap"
    case "$VIDEO_CODEC" in
    vp9)
      enc_cmd=(-c:v libvpx-vp9 -crf "$VIDEO_CRF" -b:v 0 -row-mt 1 -c:a libopus -b:a "${AUDIO_BITRATE}k")
      ;;
    av1)
      enc_cmd=(-c:v libsvtav1 -preset 8 -crf "$VIDEO_CRF" -g 240 -c:a libopus -b:a "${AUDIO_BITRATE}k")
      ;;
    h265 | hevc)
      enc_cmd=(-c:v libx265 -preset medium -crf "$VIDEO_CRF" -tag:v hvc1 -c:a libopus -b:a "${AUDIO_BITRATE}k")
      ;;
    h264)
      enc_cmd=(-c:v libx264 -preset medium -crf "$VIDEO_CRF" -c:a libopus -b:a "${AUDIO_BITRATE}k")
      ;;
    esac
    ffzap -i "$src" -f "${enc_cmd[*]}" -o "$tmp_out" -t 1 2>/dev/null && success=1
  elif has ffmpeg; then
    video_tool="ffmpeg"
    case "$VIDEO_CODEC" in
    vp9)
      # VP9 with Opus audio (WebM default, can output to MP4/MKV)
      enc_cmd=(-c:v libvpx-vp9 -crf "$VIDEO_CRF" -b:v 0 -row-mt 1 -c:a libopus -b:a "${AUDIO_BITRATE}k")
      ;;
    av1)
      # Tool preference for grep: rg -> grep
      local grep_cmd="grep"
      has rg && grep_cmd="rg"

      if ffmpeg -encoders 2>/dev/null | "$grep_cmd" -q libsvtav1; then
        enc_cmd=(-c:v libsvtav1 -preset 8 -crf "$VIDEO_CRF" -g 240)
      elif ffmpeg -encoders 2>/dev/null | "$grep_cmd" -q libaom-av1; then
        enc_cmd=(-c:v libaom-av1 -cpu-used 6 -crf "$VIDEO_CRF" -g 240)
      else
        warn "AV1 encoder not found, falling back to VP9"
        enc_cmd=(-c:v libvpx-vp9 -crf "$VIDEO_CRF" -b:v 0 -row-mt 1)
      fi
      enc_cmd+=(-c:a libopus -b:a "${AUDIO_BITRATE}k")
      ;;
    h265 | hevc)
      enc_cmd=(-c:v libx265 -preset medium -crf "$VIDEO_CRF" -tag:v hvc1 -c:a libopus -b:a "${AUDIO_BITRATE}k")
      ;;
    h264)
      enc_cmd=(-c:v libx264 -preset medium -crf "$VIDEO_CRF" -c:a libopus -b:a "${AUDIO_BITRATE}k")
      ;;
    esac

    ffmpeg -i "$src" "${enc_cmd[@]}" -y "$tmp_out" -loglevel error 2>&1 && success=1
  else
    err "No video encoding tool found (ffzap or ffmpeg required)"
  fi

  # Apply mkvclean if output is MKV
  if [[ $success -eq 1 && ${tmp_out##*.} == "mkv" && -f $tmp_out ]]; then
    if has mkvclean; then
      local cleaned="${tmp_out}.clean"
      mkvclean "$tmp_out" "$cleaned" 2>/dev/null && mv "$cleaned" "$tmp_out"
      log "Applied mkvclean to $(basename "$tmp_out")"
    fi
  fi

  if [[ $success -eq 1 ]]; then
    new_sz=$(get_size "$tmp_out")
    if ((new_sz > 0 && new_sz < orig_sz)); then
      saved=$((orig_sz - new_sz))
      pct=$((saved * 100 / orig_sz))
      printf '%s → %s | %s → %s (%d%%) [%s/%s]\n' \
        "$(basename "$src")" "$(basename "$tmp_out")" \
        "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct" "$video_tool" "$VIDEO_CODEC"

      # Remove original if inplace or not keeping
      if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then
        [[ $src != "$tmp_out" ]] && rm -f "$src"
      fi
    else
      warn "No savings for $(basename "$src")"
      rm -f "$tmp_out"
      return 1
    fi
  else
    warn "Video optimization failed for $(basename "$src")"
    rm -f "$tmp_out"
    return 1
  fi
}

# --- Audio Optimization Functions ---
optimize_audio() {
  local src=$1
  local ext="${src##*.}"
  local out

  out=$(get_output_path "$src" "$ext")

  # Skip if output exists
  if [[ -f $out && $KEEP_ORIGINAL -eq 1 && $INPLACE -eq 0 ]]; then
    return 0
  fi

  local orig_sz new_sz saved pct
  orig_sz=$(get_size "$src")

  log "Processing audio: $(basename "$src")"

  case "${ext,,}" in
  opus)
    # Opus optimization with opusenc
    if has opusenc; then
      local tmp="${out}.tmp"
      # Re-encode with optimal settings
      opusenc --bitrate "$AUDIO_BITRATE" --vbr "$src" "$tmp" 2>/dev/null || return 1
      if [[ -f $tmp ]]; then
        mv "$tmp" "$out"
        new_sz=$(get_size "$out")
        if ((new_sz < orig_sz)); then
          saved=$((orig_sz - new_sz))
          pct=$((saved * 100 / orig_sz))
          printf '%s → %s | %s → %s (%d%%)\n' \
            "$(basename "$src")" "$(basename "$out")" \
            "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"

          if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then
            [[ $src != "$out" ]] && rm -f "$src"
          fi
        fi
      fi
    else
      warn "opusenc not found, skipping Opus optimization"
      return 1
    fi
    ;;
  flac)
    if has flaca; then
      cp "$src" "$out" || return 1
      flaca --best "$out" 2>/dev/null || return 1
      new_sz=$(get_size "$out")
      if ((new_sz < orig_sz)); then
        saved=$((orig_sz - new_sz))
        pct=$((saved * 100 / orig_sz))
        printf '%s → %s | %s → %s (%d%%)\n' \
          "$(basename "$src")" "$(basename "$out")" \
          "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"

        if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then
          [[ $src != "$out" ]] && rm -f "$src"
        fi
      fi
    else
      warn "flaca not found, skipping FLAC optimization"
      return 1
    fi
    ;;
  mp3 | m4a | aac | ogg | wav)
    # Convert other audio formats to Opus for better compression
    if has ffmpeg && [[ -n $CONVERT_FORMAT && $CONVERT_FORMAT == "opus" ]]; then
      local opus_out="${out%.*}.opus"
      ffmpeg -i "$src" -c:a libopus -b:a "${AUDIO_BITRATE}k" -vbr on "$opus_out" -loglevel error 2>&1
      if [[ -f $opus_out ]]; then
        out="$opus_out"
        new_sz=$(get_size "$out")
        saved=$((orig_sz - new_sz))
        pct=$((saved * 100 / orig_sz))
        printf '%s → %s | %s → %s (%d%%) [opus]\n' \
          "$(basename "$src")" "$(basename "$out")" \
          "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"

        if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then
          rm -f "$src"
        fi
      fi
    else
      warn "Unsupported audio format for optimization: $ext (try -f opus for conversion)"
      return 1
    fi
    ;;
  *)
    warn "Unsupported audio format: $ext"
    return 1
    ;;
  esac
}

# --- File Processing ---
process_file() {
  local file=$1
  local ext="${file##*.}"
  ext="${ext,,}"

  # Skip already processed files
  if [[ $INPLACE -eq 0 && $file == *"$SUFFIX"* ]]; then
    return 0
  fi

  case "$ext" in
  jpg | jpeg | png | gif | svg | webp | avif | jxl | tiff | tif | bmp)
    [[ $MEDIA_TYPE == "all" || $MEDIA_TYPE == "image" ]] && optimize_image "$file"
    ;;
  mp4 | mkv | mov | webm | avi | flv)
    [[ $MEDIA_TYPE == "all" || $MEDIA_TYPE == "video" ]] && optimize_video "$file"
    ;;
  opus | flac | mp3 | m4a | aac | ogg | wav)
    [[ $MEDIA_TYPE == "all" || $MEDIA_TYPE == "audio" ]] && optimize_audio "$file"
    ;;
  *)
    warn "Skipping unsupported file: $file"
    ;;
  esac
}

# --- File Collection ---
collect_files() {
  local -a files=()
  local items=("$@")

  if [[ ${#items[@]} -eq 0 ]]; then
    # Read from stdin
    while IFS= read -r file; do
      [[ -f $file ]] && files+=("$file")
    done
  else
    # Collect from arguments
    for item in "${items[@]}"; do
      if [[ -f $item ]]; then
        files+=("$(realpath "$item")")
      elif [[ -d $item ]]; then
        local search_path
        search_path=$(realpath "$item")

        local -a found_files=()
        local exts=("jpg" "jpeg" "png" "gif" "svg" "webp" "avif" "jxl" "tiff" "tif" "bmp" "mp4" "mkv" "mov" "webm" "avi" "flv" "opus" "flac" "mp3" "m4a" "aac" "ogg" "wav")

        # Tool preference: fdf -> fd -> find
        if cache_tool fdf; then
          local fd_args=(-t f)
          for e in "${exts[@]}"; do fd_args+=(-e "$e"); done
          [[ $RECURSIVE -eq 0 ]] && fd_args+=(-d 1)
          mapfile -t -d '' found_files < <(fdf "${fd_args[@]}" . "$search_path" -0 2>/dev/null || :)
        elif cache_tool fd; then
          local fd_args=(-t f)
          for e in "${exts[@]}"; do fd_args+=(-e "$e"); done
          [[ $RECURSIVE -eq 0 ]] && fd_args+=(-d 1)
          mapfile -t -d '' found_files < <(fd "${fd_args[@]}" . "$search_path" -0 2>/dev/null || :)
        else
          local find_args=(-type f)
          [[ $RECURSIVE -eq 0 ]] && find_args+=(-maxdepth 1)
          local patterns=()
          for e in "${exts[@]}"; do patterns+=(-o -iname "*.$e"); done
          patterns=("${patterns[@]:1}") # Remove first -o
          mapfile -t found_files < <(find "$search_path" "${find_args[@]}" \( "${patterns[@]}" \) 2>/dev/null || :)
        fi

        files+=("${found_files[@]}")
      fi
    done
  fi

  printf '%s\n' "${files[@]}"
}

# --- Usage ---
show_help() {
  cat <<EOF
optimize - Unified media optimization tool for Termux

USAGE:
  $(basename "$0") [OPTIONS] <files or directories...>
  <command> | $(basename "$0") [OPTIONS]

OPTIONS:
  -h, --help              Show this help message
  -t, --type TYPE         Media type: all, image, video, audio (default: all)
  -q, --quality N         Quality for lossy compression (1-100, default: $QUALITY)
  -c, --crf N             Video CRF value (0-51, default: $VIDEO_CRF)
  -C, --codec CODEC       Video codec: vp9, av1, h265, h264 (default: $VIDEO_CODEC)
  -b, --bitrate N         Audio bitrate in kbps (default: $AUDIO_BITRATE)
  -f, --format FMT        Convert to format: webp, avif, jxl, png, jpg, opus
  -o, --output DIR        Output directory (default: same as input)
  -k, --keep              Keep original files
  -i, --inplace           Replace originals in-place
  -r, --recursive         Process directories recursively
  -j, --jobs N            Number of parallel jobs (default: auto)
  -l, --lossy             Enable lossy compression (default: lossless)
  -m, --mkv-to-mp4        Convert MKV files to MP4
  --no-gif-webp           Disable GIF to animated WebP conversion

EXAMPLES:
  # Lossless optimization of all media in current directory
  $(basename "$0") .

  # Convert all images to WebP with quality 90
  $(basename "$0") -f webp -q 90 -r ~/Pictures

  # Re-encode video with VP9 codec (MKV container with Opus audio)
  $(basename "$0") -t video -C vp9 -c 28 movie.mp4

  # Convert audio to Opus
  $(basename "$0") -t audio -f opus -b 128 music.mp3

  # Process files from find command
  find . -name "*.jpg" | $(basename "$0") -q 85

  # Recursive optimization with MKV to MP4 conversion
  $(basename "$0") -r -m -o ./optimized ~/Videos

SUPPORTED FORMATS:
  Images: JPG, PNG, GIF, SVG, WebP, AVIF, JXL, TIFF, BMP
  Video:  MP4, MKV, MOV, WebM, AVI, FLV
  Audio:  Opus (priority), FLAC, MP3, M4A, AAC, OGG, WAV

CODEC PRIORITY (for automatic conversion):
  Images: WebP (compatibility) -> AVIF -> JXL -> JPG -> PNG
  Audio:  Opus (best compression/quality ratio)
  Video:  VP9 (default, excellent balance)

TOOLS (in preference order):
  File finding:  fdf -> fd -> find
  Parallel:      rust-parallel -> parallel -> xargs
  PNG:           oxipng -> optipng -> pngcrush
  JPEG:          jpegoptim -> mozjpeg
  JXL:           cjxl (libjxl)
  Video:         ffzap -> ffmpeg (with VP9/Opus support)
  Image conv:    gm (GraphicsMagick) -> convert (ImageMagick)
  Pattern match: rg -> grep
  Download:      aria2c -> curl (if needed)

FEATURES:
  - GIF to animated WebP conversion (enabled by default)
  - MKV cleaning with mkvclean (automatic for MKV outputs)
  - Opus audio encoding in videos (better than AAC)
  - JXL support for next-gen image compression

EOF
}

# --- Main ---
main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      show_help
      exit 0
      ;;
    -t | --type)
      MEDIA_TYPE="$2"
      shift 2
      ;;
    -q | --quality)
      QUALITY="$2"
      shift 2
      ;;
    -c | --crf)
      VIDEO_CRF="$2"
      shift 2
      ;;
    -C | --codec)
      VIDEO_CODEC="$2"
      shift 2
      ;;
    -b | --bitrate)
      AUDIO_BITRATE="$2"
      shift 2
      ;;
    -f | --format)
      CONVERT_FORMAT="$2"
      LOSSLESS=0
      shift 2
      ;;
    -o | --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -k | --keep)
      KEEP_ORIGINAL=1
      shift
      ;;
    -i | --inplace)
      INPLACE=1
      KEEP_ORIGINAL=0
      shift
      ;;
    -r | --recursive)
      RECURSIVE=1
      shift
      ;;
    -j | --jobs)
      JOBS="$2"
      shift 2
      ;;
    -l | --lossy)
      LOSSLESS=0
      shift
      ;;
    -m | --mkv-to-mp4)
      MKV_TO_MP4=1
      shift
      ;;
    --no-gif-webp)
      GIF_TO_WEBP=0
      shift
      ;;
    -*)
      err "Unknown option: $1 (use -h for help)"
      ;;
    *)
      break
      ;;
    esac
  done

  # Validate
  ((QUALITY >= 1 && QUALITY <= 100)) || err "Quality must be 1-100"
  ((VIDEO_CRF >= 0 && VIDEO_CRF <= 51)) || err "CRF must be 0-51"
  ((AUDIO_BITRATE >= 6 && AUDIO_BITRATE <= 510)) || err "Audio bitrate must be 6-510 kbps"

  # Create output directory if specified
  if [[ -n $OUTPUT_DIR ]]; then
    mkdir -p "$OUTPUT_DIR" || err "Could not create output directory: $OUTPUT_DIR"
    OUTPUT_DIR=$(realpath "$OUTPUT_DIR")
  fi

  # Auto-detect jobs
  if [[ $JOBS -eq 0 ]]; then
    JOBS=$(get_nproc)
  fi

  # Collect files
  local -a all_files=()
  mapfile -t all_files < <(collect_files "$@")

  [[ ${#all_files[@]} -eq 0 ]] && err "No files found to process"

  log "Processing ${#all_files[@]} file(s) with $JOBS parallel jobs"
  [[ $LOSSLESS -eq 1 ]] && log "Mode: Lossless" || log "Mode: Lossy (Q=$QUALITY)"
  [[ -n $CONVERT_FORMAT ]] && log "Convert to: $CONVERT_FORMAT"
  [[ -n $VIDEO_CODEC ]] && log "Video codec: $VIDEO_CODEC (Opus audio @ ${AUDIO_BITRATE}kbps)"

  # Export functions for parallel processing
  export -f process_file optimize_image optimize_video optimize_audio
  export -f optimize_png optimize_jpeg optimize_jxl get_output_path get_convert_tool
  export -f has log warn get_size format_bytes
  export QUALITY VIDEO_CRF VIDEO_CODEC AUDIO_BITRATE SUFFIX KEEP_ORIGINAL INPLACE
  export OUTPUT_DIR CONVERT_FORMAT LOSSLESS MEDIA_TYPE MKV_TO_MP4 GIF_TO_WEBP

  # Parallel processing with tool preference: rust-parallel -> parallel -> xargs
  if has rust-parallel; then
    printf '%s\0' "${all_files[@]}" | rust-parallel -0 -j "$JOBS" bash -c 'process_file "$0"'
  elif has parallel; then
    printf '%s\0' "${all_files[@]}" | parallel -0 -j "$JOBS" bash -c 'process_file "$0"'
  else
    printf '%s\0' "${all_files[@]}" | xargs -0 -P "$JOBS" -I {} bash -c 'process_file "$0"' {}
  fi

  log "Optimization complete"
}

# Run main if executed directly
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
