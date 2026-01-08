- https://github.com/Graywizard888/Custom-Enhancify-aapt2-binary
- https://github.com/Graywizard888/Enhancify
- https://github.com/nozwock/yanu/blob/main/scripts/yanu-bootstrap-termux.sh


```bash
err(){ printf >&2 "\e[;91m%s\n\e[0m" "Error: $(if [[ -n "$*" ]]; then echo -e "$*"; else echo 'an error occurred'; fi)"; exit 1; }

# Runs passed command in proot
# $1 - command string
proot(){
  printf >&2 "\e[1;97m%s\n%s\n\e[0m" "Running in PROOT:" "$1"
  proot-distro login debian -- bash -c "$1"
}
# Patch activity manager for performance improvements
# https://github.com/termux/termux-api/issues/552#issuecomment-1382722639
patch_am(){
  local am_path="$PREFIX/bin/am" pat="app_process" patch="-Xnoimage-dex2oat"
  sed -i "/$pat/!b; /$patch/b; s/$pat/& $patch/" "$am_path" || return $?
}
termux-setup-storage <<<"Y" || err "Failed to get permission to Internal storage"
USR_DIR='/data/data/com.termux/files/usr'

proot-distro install debian || :

sh -c 'yes Y | pkg update' || termux-change-repo && sh -c 'yes Y | pkg update' || err "Failed to sync package repos; Changing mirror should help 'termux-change-repo'"
sh -c 'yes Y | pkg upgrade' || err "Failed to update packages"
sh -c 'yes Y | pkg in proot-distro termux-api' || err "Failed to install essential packages"
proot 'yes Y | apt update && apt upgrade' || err "Failed to update packages in proot"
proot 'apt install git gcc binutils make -y' || err "Failed to install required deps in proot"
patch_am || err "Failed to patch AM"

```
