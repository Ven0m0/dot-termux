#!/data/data/com.termux/files/usr/bin/env bash
# DESCRIPTION: Unified media optimizer for Termux with aggressive codec routing
# FEATURES:
# - Lossless by default with optional lossy conversions
# - Automatic codec detection and format prioritization for minimal output size
# - Parallel-capable workflow with smart CPU-aware job scaling

# -- Strict Mode & Globals --
set -euo pipefail
shopt -s nullglob globstar
IFS=$'\n\t'
export LC_ALL=C LANG=C

# Source common library
readonly SCRIPT_DIR="$(builtin cd -P -- "$(dirname -- "${BASH_SOURCE[0]:-}")" && pwd)"
readonly LIB_DIR="${SCRIPT_DIR%/*}/lib"
if [[ -f "${LIB_DIR}/common.sh" ]]; then
  # shellcheck source=../lib/common.sh
  source "${LIB_DIR}/common.sh"
else
  echo "ERROR: common.sh library not found at ${LIB_DIR}/common.sh" >&2
  exit 1
fi

# abs_path is now provided by common.sh
# Preserve ORIGIN_PWD for backwards compatibility
readonly ORIGIN_PWD="${PWD}"

FFMPEG_ENCODERS=""
ffmpeg_has_encoder() {
  local encoder=$1
  has ffmpeg || return 1
  if [[ -z $FFMPEG_ENCODERS ]]; then
    FFMPEG_ENCODERS=$(ffmpeg -hide_banner -encoders 2>/dev/null || printf '')
  fi
  [[ $FFMPEG_ENCODERS == *"$encoder"* ]]
}

detect_video_codec() {
  local requested=${VIDEO_CODEC,,}
  if [[ -n $requested && $requested != "auto" ]]; then
    VIDEO_CODEC=$requested
    return
  fi
  if ffmpeg_has_encoder "libsvtav1"; then
    VIDEO_CODEC="av1"
    return
  fi
  if ffmpeg_has_encoder "libaom-av1"; then
    VIDEO_CODEC="av1"
    return
  fi
  if ffmpeg_has_encoder "libvpx-vp9"; then
    VIDEO_CODEC="vp9"
    return
  fi
  if ffmpeg_has_encoder "libx265"; then
    VIDEO_CODEC="h265"
    return
  fi
  if ffmpeg_has_encoder "libx264"; then
    VIDEO_CODEC="h264"
    return
  fi
  if has ffzap; then VIDEO_CODEC="av1"; else VIDEO_CODEC="vp9"; fi
}

# --- Cache System Capabilities ---
NPROC=$(get_nproc)

# Detect and cache stat variant
if stat -c%s /dev/null &>/dev/null; then
  _STAT_FMT="-c%s"
elif stat -f%z /dev/null &>/dev/null; then
  _STAT_FMT="-f%z"
else
  _STAT_FMT=""
fi

# Detect and cache convert tool
if has gm; then
  _CONVERT_TOOL="gm convert"
elif has convert; then
  _CONVERT_TOOL="convert"
else
  _CONVERT_TOOL=""
fi

# --- Configuration Defaults ---
QUALITY=85         # Image quality (1-100)
VIDEO_CRF=27       # Video CRF (0-51, lower is better quality)
VIDEO_CODEC="auto" # Default video codec (auto-detect best available)
AUDIO_BITRATE=128  # Audio bitrate (kbps)
JOBS=0             # Parallel jobs (0 = auto-detect)
SUFFIX="_opt"      # Suffix for optimized files

# Mode flags
KEEP_ORIGINAL=0
INPLACE=0
RECURSIVE=0
CONVERT_FORMAT=""
LOSSLESS=1
OUTPUT_DIR=""
MEDIA_TYPE="all" # all, image, video, audio
MKV_TO_MP4=0
GIF_TO_WEBP=1
DRY_RUN=0          # Preview mode without actual processing
SKIP_EXISTING=0    # Skip files that appear already optimized
PROGRESS=0         # Show progress indicators
MIN_SAVINGS=0      # Minimum % savings to keep optimized file (0 = keep all)

# Codec priority for image conversion
IMAGE_CODEC_PRIORITY=("webp" "avif" "jxl" "jpg" "png")
IMAGE_CODEC_PRIORITY_STR="${IMAGE_CODEC_PRIORITY[*]}"

# Processing statistics
declare -g STATS_TOTAL=0 STATS_PROCESSED=0 STATS_SKIPPED=0 STATS_FAILED=0
declare -g STATS_BYTES_BEFORE=0 STATS_BYTES_AFTER=0

# Temporary directory for processing
TEMP_DIR=""
create_temp_dir() {
  TEMP_DIR=$(mktemp -d -t "optimize.XXXXXX" 2>/dev/null || mktemp -d)
  export TEMP_DIR
}

# Cleanup handler
cleanup() {
  local exit_code=$?
  # Remove temporary directory
  [[ -n $TEMP_DIR && -d $TEMP_DIR ]] && rm -rf "$TEMP_DIR" 2>/dev/null || :
  # Clean up any orphaned temp files
  find /tmp -maxdepth 1 -name "optimize.*.tmp" -user "$(id -u)" -mmin +60 -delete 2>/dev/null || :
  return $exit_code
}
trap cleanup EXIT INT TERM

# Create temp dir at startup
create_temp_dir

# --- Additional Helper Functions ---
# cache_tool is now provided by common.sh

resolve_job_count() {
  local requested=$1 total=$2
  local max_cpu=${3:-$NPROC}
  ((requested <= 0)) && requested=$max_cpu
  if ((total > 0 && requested > total)); then requested=$total; fi
  ((requested < 1)) && requested=1
  printf '%s\n' "$requested"
}

# get_size and format_bytes are now provided by common.sh
# Note: get_size in common.sh doesn't use _STAT_FMT cache, but it's equivalent

# Check if file appears already optimized
is_already_optimized() {
  local file=$1
  local ext="${file##*.}"
  ext="${ext,,}"

  # Skip if already has optimization suffix
  [[ $file == *"$SUFFIX"* ]] && return 0

  # For images, check if already in optimal format
  case "$ext" in
    webp|avif|jxl)
      # Already in modern format
      return 0
      ;;
    jpg|jpeg)
      # Check if file size is suspiciously small (likely already optimized)
      local size=$(get_size "$file")
      if has identify && ((size > 10240)); then
        local quality=$(identify -format '%Q' "$file" 2>/dev/null || echo 100)
        # If quality < 90, likely already compressed
        ((quality < 90)) && return 0
      fi
      ;;
  esac

  return 1
}

# Progress indicator
show_progress() {
  [[ $PROGRESS -eq 0 ]] && return
  local current=$1 total=$2 msg=${3:-}
  local pct=$((current * 100 / total))
  local bar_len=40
  local filled=$((pct * bar_len / 100))
  local empty=$((bar_len - filled))

  printf '\r['
  printf '%*s' "$filled" '' | tr ' ' '='
  printf '%*s' "$empty" ''
  printf '] %3d%% (%d/%d) %s' "$pct" "$current" "$total" "$msg"
}

# Print final statistics
print_stats() {
  log ""
  log "=== Optimization Statistics ==="
  log "Total files: $STATS_TOTAL"
  log "Processed: $STATS_PROCESSED"
  log "Skipped: $STATS_SKIPPED"
  log "Failed: $STATS_FAILED"

  if ((STATS_PROCESSED > 0)); then
    local saved=$((STATS_BYTES_BEFORE - STATS_BYTES_AFTER))
    if ((saved > 0)); then
      local pct=$((saved * 100 / STATS_BYTES_BEFORE))
      log "Original size: $(format_bytes "$STATS_BYTES_BEFORE")"
      log "Final size: $(format_bytes "$STATS_BYTES_AFTER")"
      log "Saved: $(format_bytes "$saved") (${pct}%)"
    fi
  fi
}

get_output_path() {
  local src=$1 fmt=$2
  local base_name="${src##*/}" name="${base_name%.*}" ext="${base_name##*.}"
  if [[ $MKV_TO_MP4 -eq 1 && ${ext,,} == "mkv" ]]; then fmt="mp4"; fi
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
      echo "${src%/*}/${name}.${fmt}"
    elif [[ $INPLACE -eq 1 ]]; then
      echo "$src"
    else
      echo "${src%/*}/${name}${SUFFIX}.${ext}"
    fi
  fi
}

# Get preferred image manipulation tool: gm (GraphicsMagick) > convert (ImageMagick)
get_convert_tool() {
  echo "$_CONVERT_TOOL"
  [[ -n $_CONVERT_TOOL ]]
}

# --- Image Optimization Functions ---
optimize_png() {
  local src=$1 out=$2
  local orig_sz tmp success=0
  orig_sz=$(get_size "$src")
  tmp="${TEMP_DIR}/$(basename "$out").tmp"

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
  tmp="${TEMP_DIR}/$(basename "$out").tmp"

  if cache_tool jpegoptim; then
    if [[ $LOSSLESS -eq 1 ]]; then
      jpegoptim --strip-all --stdout "$src" >"$tmp" 2>/dev/null && success=1
    else
      jpegoptim --max="$QUALITY" --strip-all --stdout "$src" >"$tmp" 2>/dev/null && success=1
    fi
  elif cache_tool mozjpeg || cache_tool cjpeg; then
    local jpeg_tool
    if cache_tool cjpeg; then jpeg_tool="cjpeg"; else jpeg_tool="convert"; fi
    "$jpeg_tool" -quality "$QUALITY" -optimize "$src" >"$tmp" 2>/dev/null && success=1
  else
    local convert_tool
    convert_tool=$(get_convert_tool)
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
  tmp="${TEMP_DIR}/$(basename "$out").tmp"

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

select_image_target_format() {
  local src_ext=${1,,}
  if [[ -n $CONVERT_FORMAT ]]; then
    printf '%s\n' "$CONVERT_FORMAT"
    return
  fi
  if ((LOSSLESS == 1)); then
    printf '%s\n' "$src_ext"
    return
  fi

  local -a priority=("${IMAGE_CODEC_PRIORITY[@]}")
  if ((${#priority[@]} == 0)) && [[ -n ${IMAGE_CODEC_PRIORITY_STR:-} ]]; then
    local IFS=' '
    read -r -a priority <<<"$IMAGE_CODEC_PRIORITY_STR"
  fi

  local candidate
  for candidate in "${priority[@]}"; do
    case "$candidate" in
    webp) cache_tool cwebp && {
      printf 'webp\n'
      return
    } ;;
    avif) has avifenc && {
      printf 'avif\n'
      return
    } ;;
    jxl) cache_tool cjxl && {
      printf 'jxl\n'
      return
    } ;;
    jpg) get_convert_tool >/dev/null && {
      printf 'jpg\n'
      return
    } ;;
    png) get_convert_tool >/dev/null && {
      printf 'png\n'
      return
    } ;;
    esac
  done
  printf '%s\n' "$src_ext"
}

optimize_image() {
  local src=$1
  local ext="${src##*.}"
  ext="${ext,,}"
  local out fmt

  # Check if already optimized
  if [[ $SKIP_EXISTING -eq 1 ]] && is_already_optimized "$src"; then
    ((STATS_SKIPPED++))
    log "Skipping already optimized: $(basename "$src")"
    return 0
  fi

  fmt=$(select_image_target_format "$ext")
  out=$(get_output_path "$src" "$fmt")

  if [[ -f $out && $KEEP_ORIGINAL -eq 1 && $INPLACE -eq 0 ]]; then
    ((STATS_SKIPPED++))
    return 0
  fi

  local orig_sz new_sz saved pct
  orig_sz=$(get_size "$src")
  ((STATS_BYTES_BEFORE += orig_sz))

  # Dry run mode
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] Would process: $(basename "$src") -> $fmt"
    return 0
  fi

  log "Processing image: $(basename "$src")"

  # GIF → animated WebP
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
          printf '%s -> %s | %s -> %s (%d%%) [animated]\n' \
            "$(basename "$src")" "$(basename "$out")" "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"
          if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then rm -f "$src"; fi
          return 0
        fi
      fi
    fi
  fi

  if [[ $fmt != "$ext" ]]; then
    local tmp="${out}.tmp" success=0
    local convert_tool
    convert_tool=$(get_convert_tool)
    case "$fmt" in
    webp)
      if cache_tool cwebp; then
        cwebp -q "$QUALITY" -m 6 -mt -af "$src" -o "$tmp" 2>/dev/null && success=1
      elif [[ -n $convert_tool ]]; then
        "$convert_tool" "$src" -quality "$QUALITY" "$tmp" 2>/dev/null && success=1
      fi
      ;;
    avif)
      if has avifenc; then avifenc -s 6 -j "$NPROC" --min 0 --max "$QUALITY" "$src" "$tmp" 2>/dev/null && success=1; fi
      ;;
    jxl)
      if cache_tool cjxl; then
        if [[ $LOSSLESS -eq 1 ]]; then
          cjxl "$src" "$tmp" -d 0 -e 7 2>/dev/null && success=1
        else cjxl "$src" "$tmp" -q "$QUALITY" -e 7 2>/dev/null && success=1; fi
      fi
      ;;
    jpg | jpeg)
      if [[ -n $convert_tool ]]; then "$convert_tool" "$src" -quality "$QUALITY" -strip "$tmp" 2>/dev/null && success=1; fi
      ;;
    png)
      if [[ -n $convert_tool ]]; then "$convert_tool" "$src" PNG:"$tmp" 2>/dev/null && success=1; fi
      ;;
    esac
    if [[ $success -eq 1 ]]; then
      mv "$tmp" "$out"
    else
      warn "Format conversion to $fmt failed for $(basename "$src")"
      rm -f "$tmp"
      return 1
    fi
  else
    case "$ext" in
    png) optimize_png "$src" "$out" >/dev/null || return 1 ;;
    jpg | jpeg) optimize_jpeg "$src" "$out" >/dev/null || return 1 ;;
    jxl) optimize_jxl "$src" "$out" >/dev/null || return 1 ;;
    gif) if has gifsicle; then gifsicle -O3 "$src" -o "$out" 2>/dev/null || return 1; else cp "$src" "$out"; fi ;;
    svg) if has svgcleaner; then
      svgcleaner "$src" "$out" 2>/dev/null || return 1
    elif has svgo; then
      svgo -i "$src" -o "$out" 2>/dev/null || return 1
    else cp "$src" "$out"; fi ;;
    webp) if has cwebp; then cwebp -q "$QUALITY" -m 6 -mt "$src" -o "$out" 2>/dev/null || return 1; else cp "$src" "$out"; fi ;;
    avif) if has avifenc; then avifenc -s 6 -j "$NPROC" --min 0 --max "$QUALITY" "$src" "$out" 2>/dev/null || return 1; else cp "$src" "$out"; fi ;;
    tiff | tif | bmp)
      if has image-optimizer; then
        image-optimizer -i "$src" -o "$(dirname "$out")" -q "$QUALITY" 2>/dev/null || cp "$src" "$out"
      elif has imgc; then
        imgc "$src" "$ext" -q "$QUALITY" -o "$(dirname "$out")" 2>/dev/null || cp "$src" "$out"
      elif has rimage; then
        rimage -q "$QUALITY" "$src" -o "$out" 2>/dev/null || cp "$src" "$out"
      else cp "$src" "$out"; fi
      ;;
    *)
      warn "Unsupported image format: $ext"
      return 1
      ;;
    esac
  fi

  new_sz=$(get_size "$out")
  if ((new_sz > 0 && new_sz < orig_sz)); then
    saved=$((orig_sz - new_sz))
    pct=$((saved * 100 / orig_sz))

    # Check minimum savings threshold
    if ((MIN_SAVINGS > 0 && pct < MIN_SAVINGS)); then
      warn "Savings ${pct}% below threshold ${MIN_SAVINGS}%, keeping original: $(basename "$src")"
      rm -f "$out"
      ((STATS_SKIPPED++))
      return 1
    fi

    ((STATS_BYTES_AFTER += new_sz))
    ((STATS_PROCESSED++))
    printf '%s -> %s | %s -> %s (%d%%)\n' \
      "$(basename "$src")" "$(basename "$out")" "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"
    if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then [[ $src != "$out" ]] && rm -f "$src"; fi
  elif ((new_sz >= orig_sz)); then
    if [[ $fmt == "$ext" ]]; then
      warn "No savings for $(basename "$src"), keeping original"
      rm -f "$out"
      ((STATS_BYTES_AFTER += orig_sz))
      ((STATS_FAILED++))
      return 1
    else
      log "Converted $(basename "$src") to $fmt"
      ((STATS_BYTES_AFTER += new_sz))
      ((STATS_PROCESSED++))
    fi
  fi
}

# --- Video Optimization Functions ---
optimize_video() {
  local src=$1
  local ext="${src##*.}"
  local out dest_ext
  out=$(get_output_path "$src" "$ext")
  dest_ext="${out##*.}"
  dest_ext="${dest_ext,,}"

  if [[ -f $out && $KEEP_ORIGINAL -eq 1 && $INPLACE -eq 0 ]]; then return 0; fi

  local orig_sz new_sz saved pct
  orig_sz=$(get_size "$src")
  log "Processing video: $(basename "$src")"

  local success=0 video_tool="" tmp_out="$out"
  local enc_cmd=()

  # Choose audio codec per container (MP4 => AAC; else Opus)
  local -a ac_flags
  if [[ $dest_ext == "mp4" ]]; then
    ac_flags=(-c:a aac -b:a "${AUDIO_BITRATE}k")
  else
    ac_flags=(-c:a libopus -b:a "${AUDIO_BITRATE}k")
  fi

  if has ffzap; then
    video_tool="ffzap"
    case "$VIDEO_CODEC" in
    vp9) enc_cmd=(-c:v libvpx-vp9 -crf "$VIDEO_CRF" -b:v 0 -row-mt 1) ;;
    av1) enc_cmd=(-c:v libsvtav1 -preset 8 -crf "$VIDEO_CRF" -g 240) ;;
    h265 | hevc) enc_cmd=(-c:v libx265 -preset medium -crf "$VIDEO_CRF" -tag:v hvc1) ;;
    h264) enc_cmd=(-c:v libx264 -preset medium -crf "$VIDEO_CRF") ;;
    *) enc_cmd=(-c:v libvpx-vp9 -crf "$VIDEO_CRF" -b:v 0 -row-mt 1) ;;
    esac
    enc_cmd+=("${ac_flags[@]}")
    ffzap -i "$src" -f "${enc_cmd[*]}" -o "$tmp_out" -t 1 2>/dev/null && success=1
  elif has ffmpeg; then
    video_tool="ffmpeg"
    case "$VIDEO_CODEC" in
    vp9)
      enc_cmd=(-c:v libvpx-vp9 -crf "$VIDEO_CRF" -b:v 0 -row-mt 1)
      ;;
    av1)
      if ffmpeg_has_encoder "libsvtav1"; then
        enc_cmd=(-c:v libsvtav1 -preset 8 -crf "$VIDEO_CRF" -g 240)
      elif ffmpeg_has_encoder "libaom-av1"; then
        enc_cmd=(-c:v libaom-av1 -cpu-used 6 -crf "$VIDEO_CRF" -g 240)
      else
        warn "AV1 encoder not found, falling back to VP9"
        enc_cmd=(-c:v libvpx-vp9 -crf "$VIDEO_CRF" -b:v 0 -row-mt 1)
      fi
      ;;
    h265 | hevc)
      enc_cmd=(-c:v libx265 -preset medium -crf "$VIDEO_CRF" -tag:v hvc1)
      ;;
    h264)
      enc_cmd=(-c:v libx264 -preset medium -crf "$VIDEO_CRF")
      ;;
    *)
      enc_cmd=(-c:v libvpx-vp9 -crf "$VIDEO_CRF" -b:v 0 -row-mt 1)
      ;;
    esac
    enc_cmd+=("${ac_flags[@]}")
    ffmpeg -i "$src" "${enc_cmd[@]}" -y "$tmp_out" -loglevel error && success=1
  else
    err "No video encoding tool found (ffzap or ffmpeg required)"
  fi

  # mkvclean for MKV outputs
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
      printf '%s -> %s | %s -> %s (%d%%) [%s/%s]\n' \
        "$(basename "$src")" "$(basename "$tmp_out")" \
        "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct" "$video_tool" "$VIDEO_CODEC"
      if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then [[ $src != "$tmp_out" ]] && rm -f "$src"; fi
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
  local src=$1 ext="${src##*.}" out
  out=$(get_output_path "$src" "$ext")
  if [[ -f $out && $KEEP_ORIGINAL -eq 1 && $INPLACE -eq 0 ]]; then return 0; fi

  local orig_sz new_sz saved pct
  orig_sz=$(get_size "$src")
  log "Processing audio: $(basename "$src")"

  case "${ext,,}" in
  opus)
    if has opusenc; then
      local tmp="${out}.tmp"
      opusenc --bitrate "$AUDIO_BITRATE" --vbr "$src" "$tmp" 2>/dev/null || return 1
      if [[ -f $tmp ]]; then
        mv "$tmp" "$out"
        new_sz=$(get_size "$out")
        if ((new_sz < orig_sz)); then
          saved=$((orig_sz - new_sz))
          pct=$((saved * 100 / orig_sz))
          printf '%s -> %s | %s -> %s (%d%%)\n' \
            "$(basename "$src")" "$(basename "$out")" "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"
          if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then [[ $src != "$out" ]] && rm -f "$src"; fi
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
        printf '%s -> %s | %s -> %s (%d%%)\n' \
          "$(basename "$src")" "$(basename "$out")" "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"
        if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then [[ $src != "$out" ]] && rm -f "$src"; fi
      fi
    else
      warn "flaca not found, skipping FLAC optimization"
      return 1
    fi
    ;;
  mp3 | m4a | aac | ogg | wav)
    if has ffmpeg && [[ -n $CONVERT_FORMAT && $CONVERT_FORMAT == "opus" ]]; then
      local opus_out="${out%.*}.opus"
      ffmpeg -i "$src" -c:a libopus -b:a "${AUDIO_BITRATE}k" -vbr on -y "$opus_out" -loglevel error
      if [[ -f $opus_out ]]; then
        out="$opus_out"
        new_sz=$(get_size "$out")
        saved=$((orig_sz - new_sz))
        pct=$((saved * 100 / orig_sz))
        printf '%s -> %s | %s -> %s (%d%%) [opus]\n' \
          "$(basename "$src")" "$(basename "$out")" "$(format_bytes "$orig_sz")" "$(format_bytes "$new_sz")" "$pct"
        if [[ $INPLACE -eq 1 || $KEEP_ORIGINAL -eq 0 ]]; then rm -f "$src"; fi
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

  ((STATS_TOTAL++))

  if [[ $INPLACE -eq 0 && $file == *"$SUFFIX"* ]]; then
    ((STATS_SKIPPED++))
    return 0
  fi

  # Progress indicator
  show_progress "$STATS_TOTAL" "${TOTAL_FILES:-$STATS_TOTAL}" "$(basename "$file")"

  # Wrap in error handler
  local result=0
  case "$ext" in
    jpg | jpeg | png | gif | svg | webp | avif | jxl | tiff | tif | bmp)
      if [[ $MEDIA_TYPE == "all" || $MEDIA_TYPE == "image" ]]; then
        optimize_image "$file" || result=$?
      fi
      ;;
    mp4 | mkv | mov | webm | avi | flv)
      if [[ $MEDIA_TYPE == "all" || $MEDIA_TYPE == "video" ]]; then
        optimize_video "$file" || result=$?
      fi
      ;;
    opus | flac | mp3 | m4a | aac | ogg | wav)
      if [[ $MEDIA_TYPE == "all" || $MEDIA_TYPE == "audio" ]]; then
        optimize_audio "$file" || result=$?
      fi
      ;;
    *)
      warn "Skipping unsupported file: $file"
      ((STATS_SKIPPED++))
      ;;
  esac

  return $result
}

# --- File Collection ---
collect_files() {
  local -a files=()
  local items=("$@")

  if [[ ${#items[@]} -eq 0 ]]; then
    while IFS= read -r file; do
      [[ -f $file ]] && files+=("$(abs_path "$file")")
    done
  else
    for item in "${items[@]}"; do
      if [[ -f $item ]]; then
        files+=("$(abs_path "$item")")
      elif [[ -d $item ]]; then
        local search_path
        search_path=$(abs_path "$item")
        local -a found_files=()
        local exts=("jpg" "jpeg" "png" "gif" "svg" "webp" "avif" "jxl" "tiff" "tif" "bmp" "mp4" "mkv" "mov" "webm" "avi" "flv" "opus" "flac" "mp3" "m4a" "aac" "ogg" "wav")
        if cache_tool fd; then
          local fd_args=(-t f)
          for e in "${exts[@]}"; do fd_args+=(-e "$e"); done
          [[ $RECURSIVE -eq 0 ]] && fd_args+=(-d 1)
          mapfile -t -d '' found_files < <(fd "${fd_args[@]}" . "$search_path" -0 2>/dev/null || :)
        elif cache_tool fdfind; then
          local fd_args=(-t f)
          for e in "${exts[@]}"; do fd_args+=(-e "$e"); done
          [[ $RECURSIVE -eq 0 ]] && fd_args+=(-d 1)
          mapfile -t -d '' found_files < <(fdfind "${fd_args[@]}" . "$search_path" -0 2>/dev/null || :)
        else
          local find_args=(-type f)
          [[ $RECURSIVE -eq 0 ]] && find_args+=(-maxdepth 1)
          local patterns=()
          for e in "${exts[@]}"; do patterns+=(-o -iname "*.$e"); done
          patterns=("${patterns[@]:1}")
          mapfile -t found_files < <(find "$search_path" "${find_args[@]}" \( "${patterns[@]}" \) 2>/dev/null || :)
        fi
        local f
        for f in "${found_files[@]}"; do
          [[ -z $f ]] && continue
          if [[ $f == /* ]]; then files+=("$(abs_path "$f")"); else files+=("$(abs_path "$search_path/$f")"); fi
        done
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
  -C, --codec CODEC       Video codec: auto, vp9, av1, h265, h264 (default: auto)
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
  -n, --dry-run           Preview what would be done without processing
  -s, --skip-existing     Skip files that appear already optimized
  -p, --progress          Show progress bar during processing
  --min-savings N         Minimum % savings to keep optimized file (default: 0)

EXAMPLES:
  $(basename "$0") .
  $(basename "$0") -f webp -q 90 -r ~/Pictures
  $(basename "$0") -t video -C vp9 -c 28 movie.mp4
  $(basename "$0") -t audio -f opus -b 128 music.mp3
  $(basename "$0") -n -s ~/Pictures          # Dry-run, skip already optimized
  $(basename "$0") -p --min-savings 10 .     # Progress bar, only if 10%+ savings
  find . -name "*.jpg" | $(basename "$0") -q 85
  $(basename "$0") -r -m -o ./optimized ~/Videos

SUPPORTED FORMATS:
  Images: JPG, PNG, GIF, SVG, WebP, AVIF, JXL, TIFF, BMP
  Video:  MP4, MKV, MOV, WebM, AVI, FLV
  Audio:  Opus, FLAC, MP3, M4A, AAC, OGG, WAV
EOF
}

# --- Main ---
main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      show_help
      exit 0
      ;;
    -t | --type)
      MEDIA_TYPE="${2,,}"
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
      VIDEO_CODEC="${2,,}"
      shift 2
      ;;
    -b | --bitrate)
      AUDIO_BITRATE="$2"
      shift 2
      ;;
    -f | --format)
      CONVERT_FORMAT="${2,,}"
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
    -n | --dry-run)
      DRY_RUN=1
      shift
      ;;
    -s | --skip-existing)
      SKIP_EXISTING=1
      shift
      ;;
    -p | --progress)
      PROGRESS=1
      shift
      ;;
    --min-savings)
      MIN_SAVINGS="$2"
      shift 2
      ;;
    -*) err "Unknown option: $1 (use -h for help)" ;;
    *) break ;;
    esac
  done

  ((QUALITY >= 1 && QUALITY <= 100)) || err "Quality must be 1-100"
  ((VIDEO_CRF >= 0 && VIDEO_CRF <= 51)) || err "CRF must be 0-51"
  ((AUDIO_BITRATE >= 6 && AUDIO_BITRATE <= 510)) || err "Audio bitrate must be 6-510 kbps"

  if [[ -n $OUTPUT_DIR ]]; then
    mkdir -p "$OUTPUT_DIR" || err "Could not create output directory: $OUTPUT_DIR"
    OUTPUT_DIR=$(abs_path "$OUTPUT_DIR")
  fi

  local -a all_files=()
  mapfile -t all_files < <(collect_files "$@")
  [[ ${#all_files[@]} -eq 0 ]] && err "No files found to process"

  # Export total files for progress tracking
  export TOTAL_FILES=${#all_files[@]}

  JOBS=$(resolve_job_count "$JOBS" "${#all_files[@]}")
  local need_video=0
  [[ $MEDIA_TYPE == "all" || $MEDIA_TYPE == "video" ]] && need_video=1
  ((need_video)) && detect_video_codec

  log "Processing ${#all_files[@]} file(s) with $JOBS worker(s)"
  [[ $DRY_RUN -eq 1 ]] && log "Mode: DRY RUN (no files will be modified)"
  [[ $SKIP_EXISTING -eq 1 ]] && log "Skipping files that appear already optimized"
  [[ $MIN_SAVINGS -gt 0 ]] && log "Minimum savings threshold: ${MIN_SAVINGS}%"

  if ((LOSSLESS == 1)); then
    log "Mode: Lossless"
  else
    log "Mode: Lossy (Q=$QUALITY)"
    [[ -z $CONVERT_FORMAT ]] && log "Image conversion priority: ${IMAGE_CODEC_PRIORITY_STR}"
  fi
  [[ -n $CONVERT_FORMAT ]] && log "Convert to: $CONVERT_FORMAT"
  ((need_video)) && log "Video codec: ${VIDEO_CODEC^^} (audio @ ${AUDIO_BITRATE}kbps)"

  if ((JOBS == 1)); then
    local f
    for f in "${all_files[@]}"; do
      process_file "$f" || :  # Continue on errors
    done
    [[ $PROGRESS -eq 1 ]] && echo ""  # New line after progress bar
  else
    # Export common library functions
    export_common_functions

    # Export script-specific functions
    export -f process_file optimize_image optimize_video optimize_audio
    export -f optimize_png optimize_jpeg optimize_jxl get_output_path get_convert_tool
    export -f select_image_target_format ffmpeg_has_encoder

    # Export configuration variables
    export QUALITY VIDEO_CRF VIDEO_CODEC AUDIO_BITRATE SUFFIX KEEP_ORIGINAL INPLACE
    export OUTPUT_DIR CONVERT_FORMAT LOSSLESS MEDIA_TYPE MKV_TO_MP4 GIF_TO_WEBP IMAGE_CODEC_PRIORITY_STR NPROC

    # Note: Progress bar and statistics don't work well with parallel processing
    # because each subprocess has its own copy of the variables
    if has parallel; then
      printf '%s\0' "${all_files[@]}" | parallel -0 -j "$JOBS" bash -c 'process_file "$1" || :' _ {}
    else
      printf '%s\0' "${all_files[@]}" | xargs -0 -P "$JOBS" -n 1 bash -c 'process_file "$1" || :' _
    fi
    log "Note: Statistics not available in parallel mode"
  fi

  log "Optimization complete"

  # Print statistics (only accurate in single-job mode)
  if ((JOBS == 1)); then
    print_stats
  fi
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
