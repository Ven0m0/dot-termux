#!/data/data/com.termux/files/usr/bin/env bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR external-sources=true
set -eo pipefail; shopt -s nullglob globstar; IFS=$'\n\t'; export LC_ALL=C; DEBIAN_FRONTEND=noninteractive
pkg update -ym && pkg i -y wget curl gpg
install -dm 755 /data/data/com.termux/files/usr/etc/apt/keyrings
wget -qO - https://mise.jdx.dev/gpg-key.pub | gpg --dearmor | tee /data/data/com.termux/files/usr/etc/apt/keyrings/mise-archive-keyring.gpg 1>/dev/null
echo "deb [signed-by=/data/data/com.termux/files/usr/etc/apt/keyrings/mise-archive-keyring.gpg arch=arm64] https://mise.jdx.dev/deb stable main" | tee /data/data/com.termux/files/usr/etc/apt/sources.list.d/mise.list
pkg update -y && pkg install -y mise
