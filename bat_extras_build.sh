#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob globstar extglob dotglob
IFS=$'\n\t'

git_cmd=$(command -v gix || command -v git || { echo "git or gix required" >&2; exit 1; })
repo=https://github.com/eth-p/bat-extras.git
dest=bat-extras

if [[ -d "$dest/.git" ]]; then
  "$git_cmd" -C "$dest" pull -q --ff-only >/dev/null 2>&1 || :
else
  "$git_cmd" clone -q --depth=1 "$repo" "$dest"
fi

cd "$dest"

chmod +x build.sh
./build.sh --minify=all

# Compute install dir and ensure it exists
inst_dir=${XDG_BIN_HOME:-$HOME/.local/bin}
mkdir -p "$inst_dir"

# Symlink executables
count=0
while IFS= read -r -d '' file; do
  ln -sf "$PWD/$file" "$inst_dir/"
  ((count++))
done < <(find . -maxdepth 2 -type f -executable -print0)

((count == 0)) && { echo "no executables found to symlink" >&2; exit 1; }

printf 'symlinked %d executables to %s\n' "$count" "$inst_dir"
printf 'ensure %s is on your PATH\n' "$inst_dir"
