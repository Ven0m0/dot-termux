#!/bin/bash
set -euo pipefail

# In order to test functions, we source bin/clean.sh with -n so it sets DRY_RUN=1 and exits because $# > 0 and no valid command given
# Wait, actually if we source it with arguments like `source bin/clean.sh -n`, it will parse opts.
# But `source bin/clean.sh -n` runs usage if no positional arguments?
# Wait, clean.sh has:
# [[ $# -eq 0 ]] && usage
# while getopts ...

# Let's bypass the execution logic by stripping it before sourcing
source <(sed '/^\[\[ $# -eq 0 \]\] && usage/,$d' bin/clean.sh)
DRY_RUN=1

test_rm_files_find() {
  local tmpdir
  tmpdir=$(mktemp -d)
  touch "$tmpdir/a.txt" "$tmpdir/b.log" "$tmpdir/c.bak" "$tmpdir/Thumbs.db"
  mkdir "$tmpdir/sub"
  touch "$tmpdir/sub/d.txt"

  # Mock has to force find
  has() { return 1; }

  local out
  out=$(rm_files "$tmpdir" -e "bak" -g "*.txt" | sort)
  expected=$(printf "%s\n%s\n%s" "$tmpdir/a.txt" "$tmpdir/c.bak" "$tmpdir/sub/d.txt" | sort)
  if [[ "$out" != "$expected" ]]; then
    echo "Failed multiple test find. Got: $out, expected: $expected"
    return 1
  fi
  rm -rf "$tmpdir"
}

test_rm_files_fd() {
  local tmpdir
  tmpdir=$(mktemp -d)
  touch "$tmpdir/a.txt" "$tmpdir/b.log" "$tmpdir/c.bak" "$tmpdir/Thumbs.db"
  mkdir "$tmpdir/sub"
  touch "$tmpdir/sub/d.txt"

  has() { command -v "$1" &>/dev/null; }

  local out
  out=$(rm_files "$tmpdir" -e "bak" -g "*.txt" | sort)
  expected=$(printf "%s\n%s\n%s" "$tmpdir/a.txt" "$tmpdir/c.bak" "$tmpdir/sub/d.txt" | sort)
  if [[ "$out" != "$expected" ]]; then
    echo "Failed multiple test fd. Got: $out, expected: $expected"
    return 1
  fi
  rm -rf "$tmpdir"
}

test_rm_files_find
test_rm_files_fd
echo "All tests passed."
