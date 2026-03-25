# AI Agent Guidelines — dot-termux

## Project Context

**dot-termux** is a Termux (Android terminal emulator) dotfiles and toolkit repository.
Target runtime: **Termux on Android** (`/data/data/com.termux/files/usr/bin/bash`).
Scripts are not intended to run on standard Linux without Termux.

### Key Entry Points

- `setup.sh` — Bootstrap script (Termux + Debian proot)
- `bin/` — Executable utility scripts (symlinked to `~/bin` on install)
- `tests/` — Bash test suites (no Termux required)
- `docs/` — Documentation (ADB, setup, utilities)

---

## Repository Structure

```
.
├── .github/
│   ├── copilot-instructions.md
│   ├── dependabot.yml
│   └── workflows/
│       ├── shell.yml                   # shellcheck + shfmt (runs on push/PR)
│       ├── mega-linter.yml             # MegaLinter (manual trigger only)
│       ├── img-opt.yml                 # Image optimization workflow
│       ├── jules-cleanup.yml
│       └── jules-performance-improver.yml
├── bin/
│   ├── antisplit.sh                    # Merge & sign split APKs
│   ├── audio-opt.sh                    # Audio → Opus converter
│   ├── clean.sh                        # Unified system/cache cleaner
│   ├── cls.sh                          # Clear cache and temporary files
│   ├── img-opt.sh                      # Image optimizer
│   ├── img-webp.sh                     # Image → WebP converter
│   ├── media-opt.sh                    # Unified image/video optimizer
│   ├── termux-adb-helper.sh            # ADB device utilities
│   ├── termux-ai.sh                    # AI tool helpers
│   ├── termux-change-repo              # Mirror selector (no .sh extension)
│   ├── termux-fix-shebang.sh           # Fix shebangs for Termux
│   ├── termux-install-tools.sh         # Third-party tool installers
│   ├── termux-proot-helper.sh          # proot-distro utilities
│   ├── termux-setup-storage            # Storage access helper (no .sh extension)
│   ├── termux-ssh-helper.sh            # SSH key management
│   └── vid-min.sh                      # Video minimizer (AV1/VP9)
├── docs/
│   ├── ADB.md
│   ├── setup.md
│   └── utilities.md
├── tests/
│   ├── test_antisplit_health.sh
│   ├── test_install_tools_logic.sh
│   └── test_termux_change_repo.sh
├── .bashrc                             # Interactive Bash config
├── .zshrc                              # Interactive Zsh config (Zinit + Powerlevel10k)
├── .zshenv                             # Zsh environment (PATH, XDG_*, tool paths)
├── .profile                            # POSIX sh profile for login shells
├── .shellcheckrc                       # ShellCheck project-wide config
├── .editorconfig                       # Editor formatting rules
├── setup.sh                            # Bootstrap script
└── renovate.json                       # Dependency update config
```

---

## File Discovery

Use `rg` (ripgrep) for all searches — it respects `.gitignore` and is faster than `grep`/`find`.

```bash
# Find files containing a pattern
rg 'pattern' bin/
rg -l 'set -euo pipefail' --type sh

# List all shell scripts
rg --files bin/ | grep '\.sh$'
rg --files --glob '*.sh'

# Search with context lines
rg -C3 'die(' bin/clean.sh

# Find TODO/FIXME across repo
rg 'TODO|FIXME' --type sh

# Prefer fd for file listing when available
fd -e sh bin/
fd -tf . tests/
```

---

## Bash Coding Standards

Every `bin/*.sh` script and `setup.sh` must follow these standards exactly.

### Shebang

```bash
#!/data/data/com.termux/files/usr/bin/bash
```

Never use `/bin/bash` or `/usr/bin/bash`.

### ShellCheck Directive

Place immediately after the shebang:

```bash
# shellcheck enable=all shell=bash source-path=SCRIPTDIR
```

### Standard Preamble

```bash
set -euo pipefail; shopt -s nullglob globstar
export LC_ALL=C; IFS=$'\n\t'
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
```

### Function Style

```bash
has(){ command -v -- "$1" &>/dev/null; }
log(){ printf '[INFO] %s\n' "$*"; }
die(){ printf '[ERROR] %s\n' "$*" >&2; exit 1; }
warn(){ printf '[WARN] %s\n' "$*"; }
```

Use `func(){` — no space before `{`.

### Error Handling

```bash
some_command &>/dev/null || :   # || : not || true
```

### Tool Preferences

| Prefer | Over | Notes |
|--------|------|-------|
| `rg` / ripgrep | `grep` | Check with `has rg` first; fallback to `grep` |
| `fd` | `find` | Check with `has fd` first; fallback to `find` |
| `sd` | `sed` | Only when available |
| `[[ ]]` | `[ ]` | Always in Bash |
| `(( ))` | `let` / `expr` | Arithmetic |
| `mapfile -t` | `read` loops | Reading into arrays |
| `command -v` | `which` / `type` | Command existence checks |

Always provide a fallback when using optional tools:

```bash
if has rg; then
  rg -l 'pattern' "$dir"
else
  grep -rl 'pattern' "$dir"
fi
```

### Formatting

- **2-space** indentation (enforced by `.editorconfig`)
- Max line length: 120 characters
- LF line endings, final newline required

### Disabled ShellCheck Rules

See `.shellcheckrc` for the authoritative list. Currently disabled:
`SC1079, SC1078, SC1073, SC1072, SC1083, SC1090, SC1091, SC2002, SC2016, SC2034, SC2154, SC2155, SC2236, SC2250, SC2312`

---

## Linting & Testing

```bash
# Lint
shellcheck bin/*.sh setup.sh
shfmt -d -i 2 -ci -sr bin/*.sh        # check formatting
shfmt -w -i 2 -ci -sr bin/*.sh        # apply formatting

# Run all tests
bash tests/test_antisplit_health.sh
bash tests/test_termux_change_repo.sh
bash tests/test_install_tools_logic.sh
```

Tests use mock executables in a temp directory and do not require Termux.

---

## Common Pitfalls

| Wrong | Correct | Reason |
|-------|---------|--------|
| `set -Eeuo pipefail` | `set -euo pipefail` | Capital `E` (errtrace) causes subshell trap issues in Termux |
| `LC_ALL=C LANG=C` | `export LC_ALL=C` | `LANG=C` can override user locale unexpectedly |
| `\|\| true` | `\|\| :` | `true` spawns a subprocess; `:` is a POSIX built-in |
| `#!/bin/bash` | `#!/data/data/com.termux/files/usr/bin/bash` | Termux uses non-standard paths |
| `func() {` | `func(){` | shfmt enforces no-space style in this repo |

---

## Agent Execution Rules

### Autonomous (No Confirmation Needed)

- Bug fixes, refactoring, performance improvements
- Editing existing files
- Documentation updates (README, specs)
- Dependency addition/update/removal
- Unit/integration tests (follow TDD cycle)
- Configuration changes

### Require Confirmation

- **New file creation** — explain necessity first
- **File deletion** — especially important files
- **Architecture changes** — large-scale restructuring
- **New external dependencies** — new APIs or libraries
- **Security features** — auth/authorization implementation
- **Production changes** — deployment config, environment variables

### Commit Discipline

Only commit when all conditions are met:

- All tests pass
- Zero shellcheck/shfmt warnings
- Single logical unit of work
- Commit message explains the "why"

Keep structural changes (renaming, formatting, reordering) separate from behavioral changes (logic, bug fixes, new features).

### TDD Cycle

1. **Red** — Write the simplest failing test; name it to describe the behavior
2. **Green** — Implement minimal code to pass; no optimization yet
3. **Refactor** — Clean up after tests pass; run tests after each step

### Context Management

For complex tasks, break work into isolated subtasks where only the result matters. Use `/compact` when the context grows large during extended sessions.

### Error Handling

- Cannot execute: Present 3 concrete alternatives
- Partial execution possible: Execute what is possible; clearly report what remains

---

## Common Patterns

```bash
# Command existence check
has(){ command -v -- "$1" &>/dev/null; }
has ffmpeg || die "ffmpeg is required"

# File discovery with rg
rg --files bin/ | sort
rg -l 'TODO' --type sh

# Parallel processing (fd preferred, find as fallback)
if has fd; then
  fd -tf -e jpg "$dir" -x bash -c 'encode_one "$@"' _ {}
else
  find "$dir" -type f -name "*.jpg" | while IFS= read -r f; do
    encode_one "$f"
  done
fi

# Version constant
readonly VERSION="2.1.0"

# Self-location (makes scripts runnable from any directory)
s=${BASH_SOURCE[0]}; [[ $s != /* ]] && s=$PWD/$s; cd -P -- "${s%/*}"
```

---

## Completion Signal

When all tasks are 100% complete (zero errors, empty TODO list, no continuation possible without new instructions), report exactly:

```
May the Force be with you.
```

Do not use this phrase if any tasks remain or if you plan to continue work.

For partial completion, use:

```markdown
## Execution Complete

### Changes
- [specific changes made]

### Next Steps
- [recommended next actions]
```
