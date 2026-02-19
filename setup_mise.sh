#!/usr/bin/env bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
set -euo pipefail; shopt -s nullglob globstar
IFS=$'\n\t' LC_ALL=C DEBIAN_FRONTEND=noninteractive
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"

readonly TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '[INFO] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
fetch_key(){
  local keyring="${TERMUX_PREFIX}/etc/apt/keyrings/mise-archive-keyring.gpg"
  install -dm 755 "${keyring%/*}"
  if has curl; then
    curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor >"$keyring"
  elif has wget; then
    wget -qO- https://mise.jdx.dev/gpg-key.pub | gpg --dearmor >"$keyring"
  else
    die "Need curl or wget to fetch key"
  fi
}
write_sources(){
  local list="${TERMUX_PREFIX}/etc/apt/sources.list.d/mise.list"
  install -dm 755 "${list%/*}"
  cat >"$list" <<INNEREOF
deb [signed-by=${TERMUX_PREFIX}/etc/apt/keyrings/mise-archive-keyring.gpg arch=arm64] https://mise.jdx.dev/deb stable main
INNEREOF
}
main(){
  pkg update -y; pkg install -y wget curl gpg
  fetch_key; write_sources
  pkg update -y; pkg install -y mise
  log "mise installed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
