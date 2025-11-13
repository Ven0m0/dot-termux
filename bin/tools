#!/data/data/com.termux/files/usr/bin/env bash
# tools.sh - Consolidated helper functions
# Source: source /path/tools.sh
set -euo pipefail
export LC_ALL=C LANG=C

readonly G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' D=$'\e[0m'
has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '[%(%H:%M:%S)T] %s\n' -1 "$*"; }
info(){ printf '%b[*]%b %s\n' "$G" "$D" "$*"; }
warn(){ printf '%b[!]%b %s\n' "$Y" "$D" "$*" >&2; }
err(){ printf '%b[x]%b %s\n' "$R" "$D" "$*" >&2; }
die(){ err "$1"; exit "${2:-1}"; }
_shell=${BASH_VERSION:+bash}
[[ -n ${ZSH_VERSION:-} ]] && _shell=zsh

# List executables on PATH
# list_execs [-p] [-a]
#  -p: show full paths
#  -a: include duplicates
list_execs() {
  local show_path=0 allow_dupe=0
  while getopts ":pa" o; do
    case $o in
    p) show_path=1 ;;
    a) allow_dupe=1 ;;
    *) die "Bad flag: -$OPTARG" ;;
    esac
  done
  shift $((OPTIND - 1))

  local IFS=: d f base
  local -a path_arr out=()
  local -A seen
  read -ra path_arr <<<"$PATH"

  for d in "${path_arr[@]}"; do
    [[ -z $d ]] && d=.
    # Use more efficient globbing with nullglob enabled
    shopt -s nullglob
    for f in "$d"/* "$d"/..?*; do
      [[ -f $f && -x $f ]] || continue
      base=${f##*/}

      # Skip based on duplication settings
      if [[ $allow_dupe -eq 0 ]]; then
        if [[ $show_path -eq 1 ]]; then
          [[ -n ${seen["$f"]:-} ]] && continue
          seen["$f"]=1
          out+=("$f")
        else
          [[ -n ${seen["$base"]:-} ]] && continue
          seen["$base"]=1
          out+=("$base")
        fi
      else
        if [[ $show_path -eq 1 ]]; then
          out+=("$f")
        else
          out+=("$base")
        fi
      fi
    done
    shopt -u nullglob
  done

  printf '%s\n' "${out[@]}"
}

# cht.sh integration
# cht [--update|--list] [topic] [query...]
CHT_SH_LIST_CACHE=${CHT_SH_LIST_CACHE:-"$HOME/.cache/cht_sh_cached_list"}
_cht_dl() {
  mkdir -p "${CHT_SH_LIST_CACHE%/*}"
  curl -fsSL cht.sh/:list -o "$CHT_SH_LIST_CACHE" || die "Failed cache"
}
cht() {
  local update=0 list_only=0
  while [[ $# -gt 0 ]]; do
    case $1 in
    --update)
      update=1
      shift
      ;;
    --list)
      list_only=1
      shift
      ;;
    -h)
      cat <<E
cht [--update|--list] [topic] [query...]
E
      return 0
      ;;
    *) break ;;
    esac
  done

  if ((update)) || [[ ! -f $CHT_SH_LIST_CACHE ]]; then
    log "Updating cache..."
    _cht_dl || return 1
  fi
  ((list_only)) && {
    cat "$CHT_SH_LIST_CACHE"
    return 0
  }

  local topic=$1
  [[ -n ${topic:-} ]] && shift || :
  if [[ -z $topic ]]; then
    has fzf || return 1
    topic=$(fzf --reverse --height 75% --border -m --ansi --nth 2..,.. \
      --prompt='CHT.SH> ' --preview='curl -fsSL cht.sh/{-1}' \
      --preview-window=right:60% <"$CHT_SH_LIST_CACHE") || :
    [[ -z $topic ]] && return 0
  fi

  local query="$*"
  if [[ -z $query ]]; then
    log "curl cht.sh/$topic"
    curl -fsSL "https://cht.sh/$topic" || die "Fail"
  else
    query=${query// /+}
    log "curl cht.sh/$topic/$query"
    curl -fsSL "https://cht.sh/$topic/$query" || die "Fail"
  fi
}

# ln2 - intuitive ln syntax
# ln2 [opts...] LINK_NAME > TARGET
# ln2 [opts...] TARGET < LINK_NAME
_ln2_usage() {
  cat <<E
ln2 [opts...] LINK_NAME > TARGET
ln2 [opts...] TARGET < LINK_NAME
E
}
ln2() {
  local -a all=("$@")
  [[ " ${all[*]} " =~ \ -(h|-help)\  ]] && {
    _ln2_usage
    return 0
  }
  ((${#all[@]} >= 3)) || {
    _ln2_usage
    return 1
  }
  local operand2=${all[-1]} op=${all[-2]} operand1=${all[-3]}
  local -a opts=("${all[@]:0:${#all[@]}-3}")
  [[ $operand1 == -* ]] && {
    _ln2_usage
    return 1
  }
  local target link
  case $op in
  '>')
    target=$operand2
    link=$operand1
    ;;
  '<')
    target=$operand1
    link=$operand2
    ;;
  *)
    _ln2_usage
    return 1
    ;;
  esac
  ln "${opts[@]}" "$target" "$link"
}

# netlist - network summary
# netlist [-q] [--no-speed] [--size MB] [--region R]
netlist() {
  local quiet=0 do_speed=1 size_mb=10 region=""
  while [[ $# -gt 0 ]]; do
    case $1 in
    -q)
      quiet=1
      shift
      ;;
    --no-speed)
      do_speed=0
      shift
      ;;
    --size)
      size_mb=$2
      shift 2
      ;;
    --region)
      region=$2
      shift 2
      ;;
    -h)
      cat <<E
netlist [-q] [--no-speed] [--size MB] [--region R]
E
      return 0
      ;;
    *)
      warn "Unused: $1"
      shift
      ;;
    esac
  done

  has curl || {
    die "curl required"
    return 1
  }

  local ip
  ip=$(curl -fsSL https://api.ipify.org/ || echo "?")
  ((quiet)) || printf 'Global IP: %s\n' "$ip"

  local loc
  if [[ -n $region ]]; then
    loc=$region
  else
    loc=$(curl -fsSL https://ipinfo.io/region 2>/dev/null || :)
    [[ -z $loc || $loc == Bielefeld ]] && loc="Bielefeld"
  fi
  ((quiet)) || printf 'Weather (%s):\n' "$loc"
  curl -fsSL "https://wttr.in/${loc}?0" || warn "Weather fail"

  if ((do_speed)); then
    local rawd
    rawd=$(curl -fsSL -o /dev/null -w "%{speed_download}" "https://speed.cloudflare.com/__down?bytes=100000000" 2>/dev/null || echo 0)
    awk -v s="$rawd" 'BEGIN{printf "Download: %.2f Mbps\n",(s*8)/(1024*1024)}'

    local rawu
    rawu=$(dd if=/dev/zero bs=1M count="$size_mb" 2>/dev/null \
      | curl -fsSL -o /dev/null -w "%{speed_upload}" --data-binary @- "https://speed.cloudflare.com/__up" 2>/dev/null || echo 0)
    awk -v s="$rawu" 'BEGIN{printf "Upload: %.2f Mbps\n",(s*8)/(1024*1024)}'
  fi
}

tools_help() {
  cat <<E
Available functions:
  list_execs : List executables on PATH
  cht        : Query cht.sh cheat sheets
  ln2        : Intuitive ln (LINK > TARGET / TARGET < LINK)
  netlist    : Network/IP/Weather/Speed summary
  tools_help : This help
E
}

# Show help if executed directly (not sourced)
if [[ -n ${BASH_SOURCE[0]:-} && ${BASH_SOURCE[0]} == "${0}" ]]; then
  tools_help
fi
