#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# pick git (gix preferred)
if [[ -x "$(command -v gix)" ]]; then
  git_cmd=(gix)
elif [[ -x "$(command -v git)" ]]; then
  git_cmd=(git)
else
  echo "git or gix required" >&2
  exit 1
fi

repo=https://github.com/eth-p/bat-extras.git
dest=bat-extras

# clone or update in-place
if [[ -d "$dest/.git" ]]; then
  "${git_cmd[@]}" -C "$dest" pull -q --ff-only >/dev/null 2>&1 || true
else
  "${git_cmd[@]}" clone -q --depth=1 "$repo" "$dest"
fi

cd "$dest"

chmod +x build.sh
./build.sh --minify=all

# compute install dir (using nameref, preferred idiom)
compute_install_dir() {
  local -n out=$1
  if [[ -d "${HOME}/.local/bin" ]]; then
    out="${HOME}/.local/bin"
  else
    out="${HOME}/bin"
  fi
  mkdir -p "$out"
  printf '%s' "$out"
}

ret=$(compute_install_dir inst_dir)

# symlink executables (using while read -r, preferred idiom)
count=0
while IFS= read -r -d '' file; do
  name="$(basename "$file")"
  ln -sf -- "$PWD/$file" "$ret/$name"
  ((count++))
done < <(find . -maxdepth 2 -type f -perm /111 -print0)

if [[ $count -eq 0 ]]; then
  echo "no executables found to symlink" >&2
  exit 1
fi

printf 'symlinked %d executables to %s\n' "$count" "$ret"
printf 'ensure %s is on your PATH\n' "$ret"
