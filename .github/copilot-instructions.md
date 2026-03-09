# AI Agent Instructions

## TL;DR — Critical Rules

> Read this first. These are the highest-priority, non-obvious rules.

1. **Execute immediately** — edit existing files without asking. Confirm only for destructive or large-scale changes.
2. **One source of truth** — prefer editing existing files over creating new ones. Never duplicate logic.
3. **Separate structural from behavioral** — never mix formatting changes with logic changes in the same commit.
4. **Verify, don't speculate** — look up facts before stating them. Silence is better than a confident wrong answer.
5. **Completion password** — when ALL tasks are done with zero errors, output exactly: `May the Force be with you.`

---

## Core Principles

| Principle | Rule |
|---|---|
| Autonomy | Start tasks immediately. Minimize confirmation prompts. |
| Quality | Run formatters, linters, and tests automatically. Zero warnings. |
| Conciseness | Prefer short, precise output. No padding or filler. |
| Debt elimination | Remove unused code, dead dependencies, and complexity aggressively. |
| Safety | Never skip hooks (`--no-verify`). Never force-push without explicit permission. |

---

## Execution Rules

### Immediate — No Confirmation Needed

- Bug fixes, refactoring, performance improvements
- Editing existing files (code, config, docs)
- Adding/updating/removing packages
- Writing or updating tests (follow TDD cycle)
- Applying formatters or linters

### Requires Confirmation

- **Creating new files** — explain necessity first
- **Deleting important files** — state what will be lost
- **Structural/architectural changes** — large-scale reorganization
- **External integrations** — new APIs or third-party libraries
- **Security features** — auth, authorization, secrets handling
- **Database changes** — schema changes, migrations
- **Production/CI changes** — deployment config, environment variables

---

## Development Practices

### TDD Cycle

1. **Red** — write the simplest failing test; failure message must be readable
2. **Green** — implement minimal code to pass; skip elegance at this stage
3. **Refactor** — clean up only after tests pass; run tests after each step

### Commit Discipline

A commit is ready only when all are true:
- All tests pass
- Linters produce zero warnings
- It is a single logical unit of work
- The commit message is clear and explains *why*, not *what*

### Change Hygiene

| Type | Definition | Rule |
|---|---|---|
| Structural | Formatting, renaming, reorganizing | Never changes behavior |
| Behavioral | Logic, new features, bug fixes | Always has a test |

> Never put structural and behavioral changes in the same commit.

---

## Language Guidelines

### Bash

```bash
# Required preamble
set -Eeuo pipefail
shopt -s nullglob globstar
IFS=$'\n\t'
export LC_ALL=C LANG=C
```

- Prefer native bashisms: `[[ ]]`, arrays, `mapfile -t`, parameter expansion
- Prefer modern Rust-based tools: `fd`, `rg`, `bat`, `sd`, `zoxide`
  - Fallbacks: `find`, `grep`, `cat`, `sed`, `cd`
- Avoid: `eval`, backticks, parsing `ls`
- Lint: `shfmt -i 2 -ci -sr`, `shellcheck` (zero warnings), `shellharden`
- Template: see `prompts/bash-script.prompt.md` if present

### Rust

- Errors: `Result<T, E>` + `?` operator; use `thiserror`/`anyhow`; no `unwrap()`/`expect()` in lib code
- Style: `rustfmt` + `cargo clippy -- -D warnings`
- Patterns: builder pattern, `serde`, `rayon`; iterators over indexing; borrow over `clone()`
- APIs: implement standard traits; use newtypes for type safety; document public APIs

### Python

- Style: PEP 8; format with `ruff format` or `black`; lint with `ruff`/`flake8`
- Typing: type hints on all functions and variables
- Docstrings: PEP 257
- Structure: small, single-purpose functions

### Markdown

- Use `##` for H2, `###` for H3; limit nesting depth
- Fenced code blocks with language identifiers
- Soft wrap at 80–100 characters

---

## Performance & Infrastructure

### Optimization Strategy

1. Measure first — profile and benchmark before changing anything
2. Focus on hot paths — optimize what runs most often
3. Use caching — in-memory, DB query, and frontend layers; invalidate correctly
4. Use concurrency — async I/O, worker pools, batch processing
5. Optimize DB access — indexes, `EXPLAIN` plans, no N+1 queries

### GitHub Actions

- **Security**: OIDC for cloud auth; least-privilege `permissions` for `GITHUB_TOKEN`; scan for secrets
- **Performance**: cache dependencies and build outputs; matrix strategies for parallel jobs
- **Structure**: modular workflows; composite actions or reusable workflows to reduce duplication
- **Testing**: unit + integration + E2E; clear result reporting

---

> For full Claude-specific rules (context management, completion reporting, refactoring patterns), see `CLAUDE.md` / `AGENTS.md`.
