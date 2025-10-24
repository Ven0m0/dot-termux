#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
shopt -s nullglob globstar
export LC_ALL=C LANG=C LANGUAGE=C

# --- Config ---
QUALITY=90
JOBS=0
KEEP_ORIG=0
OUT_DIR=""
RECURSIVE=0
INPLACE=0
CONVERT=0
VIDEO_CRF=23
VIDEO_CODEC="av1"

# --- Helpers ---
has(){ command -v -- "$1" >/dev/null 2>&1; }
die(){ printf '%s\n' "$*" >&2; exit 1; }
log(){ printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

trap 'rc=$?; trap - EXIT; exit "$rc"' EXIT
trap 'trap - INT; exit 130' INT
trap 'trap - TERM; exit 143' TERM

usage(){
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] <files/dirs...>

Losslessly compress images/video (no format change by default)

OPTIONS
  -h        Help
  -q N      Quality 1-100 (default: 90, for lossy/convert)
  -j N      Parallel jobs (default: nproc)
  -k        Keep originals
  -i        In-place (replace originals)
  -o DIR    Output directory
  -r        Recursive
  -f FMT    Convert to format (webp, avif, png, jpg)
  -c CRF    Video CRF 0-51 (default: 23)
  -C CODE   Video codec (av1, h265, h264, default: av1)

EXAMPLES
  $(basename "$0") photo.jpg           # Lossless JPEG optimize
  $(basename "$0") image.png           # Lossless PNG optimize
  $(basename "$0") -f webp *.jpg       # Convert JPG→WebP Q90
  $(basename "$0") -r -o out/ pics/    # Recursive optimize

DEFAULT BEHAVIOR
  No format conversion - only lossless compression
  Use -f flag to convert formats

TOOLS (priority order)
  Images: nixuuu/image-optimizer > imgc > rimage
  PNG: oxipng > pngquant > optipng > pngcrush
  JPEG: jpegoptim > mozjpeg
  Video: ffzap > compresscli > ffmpeg
EOF
}

get_size(){ stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo 0; }

fmt_bytes(){
  local b=$1
  if ((b<1024)); then printf '%dB' "$b"
  elif ((b<1048576)); then printf '%.1fKB' "$(awk "BEGIN {print $b/1024}")"
  else printf '%.2fMB' "$(awk "BEGIN {print $b/1048576}")"; fi
}

get_out(){
  local src=$1 fmt=$2
  local name="${src%.*}"
  [[ -n $OUT_DIR ]] && echo "$OUT_DIR/$(basename "$name").${fmt}" || echo "${name}.${fmt}"
}

opt_png(){
  local src=$1 out=$2 lossy=${3:-0}
  local orig_sz tmp
  
  orig_sz=$(get_size "$src")
  tmp="${out}.tmp"
  
  if has oxipng; then
    cp "$src" "$tmp"
    oxipng -o6 --strip safe -q "$tmp" >/dev/null 2>&1 || :
    if ((lossy)) && has pngquant; then
      pngquant --quality=65-"$QUALITY" --strip --speed 1 -f "$tmp" -o "${tmp}.2" >/dev/null 2>&1 && mv "${tmp}.2" "$tmp" || :
    fi
  elif ((lossy)) && has pngquant; then
    pngquant --quality=65-"$QUALITY" --strip --speed 1 -f "$src" -o "$tmp" >/dev/null 2>&1 || cp "$src" "$tmp"
    if has optipng; then
      optipng -o2 -strip all -quiet "$tmp" >/dev/null 2>&1 || :
    elif has pngcrush; then
      pngcrush -rem alla -reduce "$tmp" "${tmp}.2" >/dev/null 2>&1 && mv "${tmp}.2" "$tmp" || :
    fi
  elif has optipng; then
    cp "$src" "$tmp"
    optipng -o7 -strip all -quiet "$tmp" >/dev/null 2>&1 || :
  elif has pngcrush; then
    pngcrush -rem alla -reduce "$src" "$tmp" >/dev/null 2>&1 || cp "$src" "$tmp"
  else
    cp "$src" "$tmp"
  fi
  
  mv "$tmp" "$out"
  echo "$((orig_sz - $(get_size "$out")))"
}

opt_img(){
  local src=$1 fmt=$2
  local out orig_sz new_sz saved pct ext="${src##*.}"
  ext="${ext,,}"
  
  [[ -z $fmt ]] && fmt="$ext"
  out=$(get_out "$src" "$fmt")
  [[ -f $out && $KEEP_ORIG -eq 0 ]] && return 0
  
  orig_sz=$(get_size "$src")
  
  if [[ $CONVERT -eq 1 ]] && has image-optimizer && [[ $fmt != "$ext" ]]; then
    local opt_fmt="--webp"
    [[ $fmt == "avif" ]] && opt_fmt="--avif"
    [[ $fmt == "jpeg" || $fmt == "jpg" ]] && opt_fmt="--jpeg-quality $QUALITY"
    image-optimizer -i "$src" -o "$(dirname "$out")" $opt_fmt -q "$QUALITY" >/dev/null 2>&1 && {
      new_sz=$(get_size "$out")
      saved=$((orig_sz - new_sz))
      pct=$((saved * 100 / orig_sz))
      printf '%s → %s | %s → %s (%d%%)\n' "$(basename "$src")" "$(basename "$out")" "$(fmt_bytes "$orig_sz")" "$(fmt_bytes "$new_sz")" "$pct"
      [[ $KEEP_ORIG -eq 0 && $INPLACE -eq 1 && "$src" != "$out" ]] && rm -f "$src"
      return 0
    }
  fi
  
  if [[ $CONVERT -eq 1 ]] && has imgc && [[ $fmt != "$ext" ]]; then
    imgc "$src" "$fmt" -q "$QUALITY" -o "$(dirname "$out")" >/dev/null 2>&1 && {
      new_sz=$(get_size "$out")
      saved=$((orig_sz - new_sz))
      pct=$((saved * 100 / orig_sz))
      printf '%s → %s | %s → %s (%d%%)\n' "$(basename "$src")" "$(basename "$out")" "$(fmt_bytes "$orig_sz")" "$(fmt_bytes "$new_sz")" "$pct"
      [[ $KEEP_ORIG -eq 0 && $INPLACE -eq 1 && "$src" != "$out" ]] && rm -f "$src"
      return 0
    }
  fi
  
  if [[ $CONVERT -eq 1 ]] && has rimage && [[ $fmt != "$ext" ]]; then
    rimage -q "$QUALITY" "$src" -o "$out" >/dev/null 2>&1 && {
      new_sz=$(get_size "$out")
      saved=$((orig_sz - new_sz))
      pct=$((saved * 100 / orig_sz))
      printf '%s → %s | %s → %s (%d%%)\n' "$(basename "$src")" "$(basename "$out")" "$(fmt_bytes "$orig_sz")" "$(fmt_bytes "$new_sz")" "$pct"
      [[ $KEEP_ORIG -eq 0 && $INPLACE -eq 1 && "$src" != "$out" ]] && rm -f "$src"
      return 0
    }
  fi
  
  case "$fmt" in
    png)
      saved=$(opt_png "$src" "$out" "$CONVERT")
      ;;
    jpg|jpeg)
      if [[ $CONVERT -eq 1 && $fmt != "$ext" ]]; then
        has cwebp || die "cwebp required for conversion (pkg install libwebp)"
        cwebp -q "$QUALITY" -m 6 -mt "$src" -o "$out" >/dev/null 2>&1 || return 1
      else
        has jpegoptim || die "jpegoptim required (pkg install jpegoptim)"
        cp "$src" "$out"
        jpegoptim --strip-all -q "$out" >/dev/null 2>&1 || return 1
      fi
      ;;
    webp)
      if [[ $CONVERT -eq 1 && $fmt != "$ext" ]]; then
        has cwebp || die "cwebp required (pkg install libwebp)"
        cwebp -q "$QUALITY" -m 6 -mt -af "$src" -o "$out" >/dev/null 2>&1 || return 1
      else
        cp "$src" "$out"
      fi
      ;;
    avif)
      has avifenc || die "avifenc required (pkg install libavif)"
      avifenc -s 6 -j "$(nproc 2>/dev/null || echo 4)" --min 0 --max "$QUALITY" "$src" "$out" >/dev/null 2>&1 || return 1
      ;;
    *)
      log "Unknown format: $fmt"
      return 1
      ;;
  esac
  
  new_sz=$(get_size "$out")
  saved=$((orig_sz - new_sz))
  pct=$((saved * 100 / orig_sz))
  
  printf '%s → %s | %s → %s (%d%%)\n' \
    "$(basename "$src")" "$(basename "$out")" \
    "$(fmt_bytes "$orig_sz")" "$(fmt_bytes "$new_sz")" "$pct"
  
  [[ $KEEP_ORIG -eq 0 && $INPLACE -eq 1 && "$src" != "$out" ]] && rm -f "$src"
}

opt_gif(){
  local src=$1
  local out orig_sz new_sz saved pct
  
  out=$(get_out "$src" "gif")
  [[ -f $out && $KEEP_ORIG -eq 0 ]] && return 0
  
  orig_sz=$(get_size "$src")
  
  if has gifsicle; then
    gifsicle -O3 "$src" -o "$out" >/dev/null 2>&1 || return 1
  else
    die "gifsicle required (pkg install gifsicle)"
  fi
  
  new_sz=$(get_size "$out")
  saved=$((orig_sz - new_sz))
  pct=$((saved * 100 / orig_sz))
  
  printf '%s → %s | %s → %s (%d%%)\n' \
    "$(basename "$src")" "$(basename "$out")" \
    "$(fmt_bytes "$orig_sz")" "$(fmt_bytes "$new_sz")" "$pct"
  
  [[ $KEEP_ORIG -eq 0 && $INPLACE -eq 1 && "$src" != "$out" ]] && rm -f "$src"
}

opt_vid(){
  local src=$1 crf=$2 codec=$3
  local out orig_sz new_sz saved pct
  
  out=$(get_out "$src" "${src##*.}")
  [[ -f $out && $KEEP_ORIG -eq 0 ]] && return 0
  
  orig_sz=$(get_size "$src")
  
  if has ffzap; then
    local ffzap_opts="-c:v libsvtav1 -preset 8 -crf $crf -g 240 -c:a copy"
    [[ $codec == "h265" || $codec == "hevc" ]] && ffzap_opts="-c:v libx265 -preset medium -crf $crf -tag:v hvc1 -c:a copy"
    [[ $codec == "h264" ]] && ffzap_opts="-c:v libx264 -preset medium -crf $crf -c:a copy"
    
    ffzap -i "$src" -f "$ffzap_opts" -o "$out" -t 1 >/dev/null 2>&1 || return 1
  elif has compresscli; then
    compresscli --input "$src" --output "$out" --quality "$((100 - crf * 2))" >/dev/null 2>&1 || return 1
  elif has ffmpeg; then
    local enc_cmd
    case "$codec" in
      av1)
        if ffmpeg -encoders 2>/dev/null | grep -q libsvtav1; then
          enc_cmd=(-c:v libsvtav1 -preset 8 -crf "$crf" -g 240)
        elif ffmpeg -encoders 2>/dev/null | grep -q libaom-av1; then
          enc_cmd=(-c:v libaom-av1 -cpu-used 6 -crf "$crf" -g 240)
        else
          enc_cmd=(-c:v libx265 -preset medium -crf "$crf")
        fi
        ;;
      h265|hevc)
        enc_cmd=(-c:v libx265 -preset medium -crf "$crf" -tag:v hvc1)
        ;;
      h264)
        enc_cmd=(-c:v libx264 -preset medium -crf "$crf")
        ;;
    esac
    
    ffmpeg -i "$src" "${enc_cmd[@]}" -c:a copy -y "$out" >/dev/null 2>&1 || return 1
  else
    die "ffzap, compresscli, or ffmpeg required"
  fi
  
  new_sz=$(get_size "$out")
  saved=$((orig_sz - new_sz))
  pct=$((saved * 100 / orig_sz))
  
  printf '%s → %s | %s → %s (%d%%)\n' \
    "$(basename "$src")" "$(basename "$out")" \
    "$(fmt_bytes "$orig_sz")" "$(fmt_bytes "$new_sz")" "$pct"
  
  [[ $KEEP_ORIG -eq 0 && $INPLACE -eq 1 && "$src" != "$out" ]] && rm -f "$src"
}

process(){
  local f=$1 fmt=${2:-}
  local ext="${f##*.}"
  ext="${ext,,}"
  
  [[ -z $fmt ]] && fmt="$ext"
  
  case "$ext" in
    jpg|jpeg|png|tiff|tif|bmp|webp|avif)
      opt_img "$f" "$fmt"
      ;;
    gif)
      opt_gif "$f"
      ;;
    mp4|mkv|mov|webm|avi)
      opt_vid "$f" "$VIDEO_CRF" "$VIDEO_CODEC"
      ;;
    *)
      log "Skip: $f (unsupported)"
      ;;
  esac
}

collect(){
  local -n _files=$1
  shift
  
  for item in "$@"; do
    if [[ -f $item ]]; then
      _files+=("$item")
    elif [[ -d $item ]]; then
      if [[ $RECURSIVE -eq 1 ]]; then
        if has fd; then
          while IFS= read -r -d '' f; do _files+=("$f"); done < <(
            fd -t f -e jpg -e jpeg -e png -e gif -e webp -e avif -e mp4 -e mkv -e mov -e webm -e avi . "$item" -0
          )
        else
          while IFS= read -r -d '' f; do _files+=("$f"); done < <(
            find "$item" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.avif" -o -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" -o -iname "*.avi" \) -print0
          )
        fi
      else
        for f in "$item"/*.{jpg,jpeg,png,gif,webp,avif,mp4,mkv,mov,webm,avi}; do
          [[ -f $f ]] && _files+=("$f")
        done
      fi
    fi
  done
}

main(){
  local opt fmt=""
  while getopts ":hq:j:kio:rf:c:C:" opt; do
    case "$opt" in
      h) usage; exit 0;;
      q) QUALITY="$OPTARG";;
      j) JOBS="$OPTARG";;
      k) KEEP_ORIG=1;;
      i) INPLACE=1;;
      o) OUT_DIR="$OPTARG";;
      r) RECURSIVE=1;;
      f) fmt="$OPTARG"; CONVERT=1;;
      c) VIDEO_CRF="$OPTARG";;
      C) VIDEO_CODEC="$OPTARG";;
      \?|:) usage; exit 64;;
    esac
  done
  shift $((OPTIND-1))
  
  [[ $# -eq 0 ]] && { usage; exit 1; }
  [[ $JOBS -eq 0 ]] && JOBS=$(nproc 2>/dev/null || echo 1)
  ((QUALITY >= 1 && QUALITY <= 100)) || die "Quality must be 1-100"
  ((VIDEO_CRF >= 0 && VIDEO_CRF <= 51)) || die "CRF must be 0-51"
  [[ -n $OUT_DIR ]] && mkdir -p "$OUT_DIR"
  
  local -a files=()
  collect files "$@"
  [[ ${#files[@]} -eq 0 ]] && die "No files found"
  
  log "Processing ${#files[@]} file(s), jobs: $JOBS"
  [[ $CONVERT -eq 1 ]] && log "Convert mode: $fmt" || log "Lossless mode"
  
  export -f process opt_img opt_gif opt_vid opt_png get_out get_size fmt_bytes log has die
  export QUALITY VIDEO_CRF VIDEO_CODEC OUT_DIR KEEP_ORIG INPLACE CONVERT
  
  printf '%s\0' "${files[@]}" | xargs -0 -n1 -P"$JOBS" bash -c "process \"\$0\" \"$fmt\""
  
  log "Complete"
}

main "$@"
