#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

# --- Helper function for batch processing ---
process_batch() {
  local src_dir="$1"
  local out_dir="$2"
  shift 2 # Remove src_dir and out_dir from arguments, leaving only file paths

  for file in "$@"; do
    # Correctly get the relative path, even for files in the root of src_dir
    local rel_path="${file#$src_dir/}"
    local out_file="$out_dir/$rel_path"
    gifsicle -O3 "$file" -o "$out_file"
  done
}

# --- Main script ---
main() {
  # 1. Dependency Check
  local deps=(fd oxipng jpegoptim gifsicle svgcleaner)
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      echo "Error: '$dep' is not installed. Please install it." >&2
      echo "On Termux: pkg install $dep" >&2
      exit 1
    fi
  done

  # 2. Select Source Directory
  # Use argument 1, or fall back to an fzf directory picker
  local src_dir
  src_dir="${1:-$(fd --type d --hidden . ~)}"

  # Exit if no directory was selected or is invalid
  [[ -z "$src_dir" ]] && {
    echo "No directory selected. Exiting."
    exit 0
  }
  [[ ! -d "$src_dir" ]] && {
    echo "Error: '$src_dir' is not a valid directory." >&2
    exit 1
  }

  # Resolve to an absolute path
  src_dir="$(realpath "$src_dir")"
  local out_dir="${src_dir}-opt"

  # 3. Find Files and Confirm
  local -a files
  mapfile -d '' files < <(fd -0 -t f -e jpg -e jpeg -e png -e gif -e svg -e webp -e avif . "$src_dir")

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No supported image files found in '$src_dir'."
    exit 0
  fi

  echo "Source:      $src_dir"
  echo "Output:      $out_dir"
  echo "Found ${#files[@]} images to process."
  read -p "Press Enter to begin, or Ctrl+C to cancel..."

  # 4. Create Output Directory and Replicate Structure
  echo "Preparing output directory..."
  mkdir -p "$out_dir"
  # This clever rsync command replicates the directory tree without copying files
  rsync -a -f"+ */" -f"- *" "$src_dir/" "$out_dir/"

  # 5. Process Images using the most efficient method for each tool
  local start_time
  start_time=$(date +%s)

  echo "Optimizing PNGs with oxipng..."
  # Use xargs to run oxipng in an efficient batch process.
  # The -q (quiet) flag is added to prevent verbose output for every file.
  fd -t f -e png . "$src_dir" -0 | xargs -0 oxipng -o max -Z --strip all --alpha -q --dir "$out_dir"

  echo "Optimizing JPEGs with jpegoptim..."
  # Use `fd --exec ... {} +` for jpegoptim. It's the fastest way as it
  # creates the minimum number of processes.
  fd --type f -ejpg -e jpeg . "$src_dir" -x jpegoptim --strip-all --all-progressive -d "$out_dir" {} +

  echo "Optimizing GIFs with gifsicle..."
  # Use fd's batch execution for better performance on many files.
  # We export the helper function so it's available to the subshell created by fd.
  export -f process_batch
  fd -t f -e gif . "$src_dir" -X bash -c 'process_batch "$1" "$2" "$@"' _ "$src_dir" "$out_dir"

  echo "Optimizing SVGs and copying other formats..."
  # A loop is still fine here as svgcleaner is fast and webp/avif are just copies.
  fd -t f -e svg -e webp -e avif . "$src_dir" | while IFS= read -r file; do
    local rel_path="${file#$src_dir/}"
    local out_file="$out_dir/$rel_path"

    if [[ "${file##*.}" == "svg" ]]; then
      svgcleaner "$file" "$out_file"
    else
      # webp & avif are already highly compressed; just copy them.
      cp "$file" "$out_file"
    fi
  done

  # 6. Final Report
  local end_time duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))

  echo -e "\n--- Optimization Complete ---"
  echo "Original size: $(du -sh "$src_dir" | cut -f1)"
  echo "Optimized size:  $(du -sh "$out_dir" | cut -f1)"
  echo "Time elapsed:    ${duration}s"
  echo "---------------------------"
}

main "$@"
