# Copilot Instructions for dot-termux

## Repository Overview

**dot-termux** is a Termux (Android terminal emulator) dotfiles and toolkit repository.
It provides:

- Shell configuration (Zsh + Bash) with Zinit/Zimfw plugin manager and Powerlevel10k theme
- A suite of `bin/` utility scripts for media optimization, system cleaning, APK patching, and ADB operations
- A `setup.sh` bootstrap script for fresh Termux + Debian proot environments
- Tests under `tests/` validating script behaviour (no Termux required to run them)

The target runtime is **Termux on Android** (`/data/data/com.termux/files/usr/bin/bash`).
Scripts are not intended to run on standard Linux without Termux.

---

## Repository Structure

```
.
├── .github/
│   ├── copilot-instructions.md           # This file
│   ├── dependabot.yml
│   └── workflows/
│       ├── shell.yml                     # shellcheck + shfmt linting (runs on push/PR)
│       ├── mega-linter.yml               # MegaLinter (manual trigger only)
│       ├── img-opt.yml                   # Image optimization workflow
│       ├── jules-cleanup.yml
│       └── jules-performance-improver.yml
├── bin/                                  # Executable utility scripts (symlinked to ~/bin)
│   ├── antisplit.sh                      # Merge & sign split APKs
│   ├── audio-opt.sh                      # Audio → Opus converter
│   ├── clean.sh                          # Unified system/cache cleaner
│   ├── cls.sh                            # Clear cache and temporary files
│   ├── img-opt.sh                        # Image optimizer (image-optimizer)
│   ├── img-webp.sh                       # Convert images to WebP
│   ├── media-opt.sh                      # Unified image/video optimizer
│   ├── termux-adb-helper.sh              # ADB device utilities
│   ├── termux-ai.sh                      # AI tool helpers
│   ├── termux-change-repo                # Mirror selector (no .sh extension)
│   ├── termux-fix-shebang.sh             # Fix shebangs for Termux
│   ├── termux-install-tools.sh           # Third-party tool installers
│   ├── termux-proot-helper.sh            # proot-distro utilities
│   ├── termux-setup-storage              # Storage access helper (no .sh extension)
│   ├── termux-ssh-helper.sh              # SSH key management
│   └── vid-min.sh                        # Video minimizer (AV1/VP9 encoding)
├── docs/                                 # Documentation
│   ├── ADB.md
│   ├── setup.md
│   └── utilities.md
├── tests/
│   ├── test_antisplit_health.sh          # Tests for antisplit.sh
│   ├── test_install_tools_logic.sh       # Tests for termux-install-tools.sh
│   └── test_termux_change_repo.sh        # Tests for termux-change-repo
├── .bashrc                               # Interactive Bash config
├── .zshrc                                # Interactive Zsh config (Zinit + Powerlevel10k)
├── .zshenv                               # Zsh environment (PATH, XDG_*, tool paths)
├── .profile                              # POSIX sh profile for login shells
├── .shellcheckrc                         # ShellCheck project-wide config
├── .editorconfig                         # Editor formatting rules
├── setup.sh                              # Bootstrap script (Termux + Debian proot)
├── AGENTS.md                             # AI agent execution guidelines (symlinked as CLAUDE.md)
└── renovate.json                         # Dependency update config
```

---

## File Discovery

Prefer `rg` (ripgrep) for searching — it respects `.gitignore` and is significantly faster than `grep`.

```bash
# Search file contents
rg 'pattern' bin/
rg -l 'set -euo pipefail' --type sh

# List shell scripts
rg --files bin/ | grep '\.sh$'

# Prefer fd for file listing when available
fd -e sh bin/
fd -tf . tests/
```

---

## Bash Coding Standards

Every `bin/*.sh` script and setup script **must** follow these standards exactly.

### Shebang

```bash
#!/data/data/com.termux/files/usr/bin/bash
```

Use the Termux-specific path. Never use `/bin/bash` or `/usr/bin/bash`.

### ShellCheck Directive

Place this immediately after the shebang (before the preamble):

```bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
```

### Standard Preamble

```bash
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
```

**Critical notes:**
- Use `set -euo pipefail` — **not** `set -Eeuo pipefail` (no capital E)
- Use `export LC_ALL=C` — **not** `LC_ALL=C LANG=C`
- The self-location line (`s=${BASH_SOURCE[0]}...`) makes scripts runnable from any directory
- Preamble components are on the **same line**, separated by `;`

### Function Style

```bash
# Correct: compact brace, no space before {
has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '[INFO] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
warn(){ printf '[WARN] %s\n' "$*"; }
```

Not `func() {` — use `func(){` (no space before `{`).

### Error Handling

```bash
# Silent error suppression
some_command &>/dev/null || :
some_command >/dev/null 2>&1 || :

# Use || : instead of || true
pkg clean || :
```

### Tool Preferences

| Prefer | Over | Notes |
|--------|------|-------|
| `rg` / ripgrep | `grep` | Check availability with `has rg` first |
| `fd` | `find` | Check availability with `has fd` first |
| `sd` | `sed` | Only when available |
| `[[ ]]` | `[ ]` | Always in Bash |
| `(( ))` | `let` / `expr` | For arithmetic |
| `mapfile -t` | `read` loops | For reading into arrays |
| `command -v` | `which` / `type` | For command existence checks |

Always provide a fallback when using optional tools:

```bash
if has fd; then
  fd -tf -e mp3 "$dir"
else
  find "$dir" -type f -name "*.mp3"
fi
```

### Indentation & Formatting

- **2-space** indentation (enforced by `.editorconfig`)
- Max line length: 120 characters
- LF line endings only
- Final newline required

### Disabled ShellCheck Rules

See `.shellcheckrc` for the authoritative list. Currently disabled:
`SC1079, SC1078, SC1073, SC1072, SC1083, SC1090, SC1091, SC2002, SC2016, SC2034, SC2154, SC2155, SC2236, SC2250, SC2312`

---

## Linting & Testing

### ShellCheck

```bash
# Lint a single script
shellcheck bin/clean.sh

# Lint all scripts (respects .shellcheckrc)
shellcheck bin/*.sh setup.sh
```

### shfmt

```bash
# Check formatting
shfmt -d -i 2 -ci -sr bin/clean.sh

# Apply formatting
shfmt -w -i 2 -ci -sr bin/clean.sh
```

Flags: `-i 2` (2-space indent), `-ci` (indent switch cases), `-sr` (space after redirect operators).

### Running Tests

```bash
bash tests/test_antisplit_health.sh
bash tests/test_termux_change_repo.sh
bash tests/test_install_tools_logic.sh
```

Tests use mock executables in a temp directory; they do not require Termux.

### CI Workflows

- **`shell.yml`** — Runs on push/PR for `*.sh`, `*.bash`, `*.bashrc`, `*.profile` files.
  Calls the shared `Ven0m0/.github` `shell-lint.yml` workflow (shellcheck + shfmt).
  Excludes `.git/` and `Linux-Settings/`.
- **`mega-linter.yml`** — Manual trigger only (`workflow_dispatch`).
  Excludes `.github,.git,.cache,go,node_modules,.var,.rustup,.wine,.zim,.void-editor,.vscode,.claude`.
- **`img-opt.yml`** — Image optimization automation.
- **`jules-cleanup.yml`** / **`jules-performance-improver.yml`** — Automated maintenance workflows.

---

## Setup Script (`setup.sh`)

Environment variable toggles (default: `0` / disabled):

| Variable | Default | Effect |
|----------|---------|--------|
| `INSTALL_FONTS` | `0` | Download JetBrains Mono Nerd Font |
| `INSTALL_DEVTOOLS` | `0` | Install mise, Rust, bun in Debian |
| `INSTALL_MEDIA_TOOLS` | `0` | Install ffmpeg, graphicsmagick, etc. |
| `INSTALL_HELPERS` | `0` | Symlink helper scripts to `~/bin` |
| `PATCH_AM` | `1` | Patch activity manager for performance |
| `MIRROR_REGION` | `europe` | Termux mirror region |

Usage:

```bash
INSTALL_DEVTOOLS=1 INSTALL_MEDIA_TOOLS=1 ./setup.sh
```

---

## Shell Configuration Files

- **`.zshrc`** — Zsh interactive config. Shebang: `#!/data/data/com.termux/files/usr/bin/env zsh`.
  Uses `setopt`, Zinit/Zimfw plugin manager, Powerlevel10k prompt.
- **`.bashrc`** — Bash interactive config. Has inline helper functions (`has`, `bname`, `dname`).
  Sources fragments lazily. Requires `# shellcheck enable=all shell=bash` at top.
- **`.zshenv`** — Zsh environment (always sourced). Sets `PATH`, `XDG_*`, tool paths.
- **`.profile`** — POSIX sh profile for login shells.

---

## Key Patterns

### Command Existence Check

```bash
has(){ command -v -- "$1" &>/dev/null; }
has ffmpeg || die "ffmpeg is required"
```

### Parallel Processing with fd

```bash
if has fd; then
  fd -tf -e jpg "$dir" -x bash -c 'encode_one "$@"' _ {}
else
  find "$dir" -type f -name "*.jpg" | while IFS= read -r f; do
    encode_one "$f"
  done
fi
```

### Version Constant

```bash
readonly VERSION="2.1.0"
```

### Self-Location (for scripts that source relative files)

```bash
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
```

---

## Common Errors & Workarounds

- **`set -Eeuo pipefail` vs `set -euo pipefail`**: This repo uses the latter. Capital `E` (`errtrace`)
  is intentionally omitted to avoid issues with subshell traps in Termux.
- **`LANG=C` vs `LC_ALL=C`**: Only `LC_ALL=C` is set. Adding `LANG=C` can override user locale
  settings unexpectedly in the Termux environment.
- **`|| true` vs `|| :`**: Always use `|| :` (POSIX built-in, no subprocess overhead).
- **shellcheck SC1091**: Source files can't be followed statically in Termux paths — disabled
  globally in `.shellcheckrc`.
- **ShellCheck SC2154**: Variables set in sourced files are unknown to shellcheck — disabled globally.

---

## Quick Reference

```bash
# Lint all shell scripts
shellcheck bin/*.sh setup.sh

# Format check
shfmt -d -i 2 -ci -sr bin/*.sh

# Run all tests
bash tests/test_antisplit_health.sh
bash tests/test_termux_change_repo.sh
bash tests/test_install_tools_logic.sh

# Install (minimal)
./setup.sh

# Install with all options
INSTALL_FONTS=1 INSTALL_DEVTOOLS=1 INSTALL_MEDIA_TOOLS=1 INSTALL_HELPERS=1 ./setup.sh
```
