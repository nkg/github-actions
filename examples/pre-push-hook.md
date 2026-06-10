# Pre-push hook pattern (free-plan stand-in for branch protection)

> **Client-side complement to `auto-revert-on-main-failure.yml`.** That
> reusable reacts *after* bad code lands on `main` (opens a revert PR); this
> hook stops it reaching `origin` in the first place. Use both: the hook is
> the gate, auto-revert is the safety net for pushes that bypass it.

GitHub branch-protection rules — "require CI to pass before merge" — need a
**Team or Enterprise plan** for private repos. On the Free plan, anyone with
push access can push directly to `main` and break it. CI catches the breakage
after the fact, but by then `main` is already broken: cloning the repo,
pulling on another machine, or running the test suite locally all hit the
same broken code.

A `pre-push` git hook closes that gap. It runs the **same checks CI runs**
against your local working tree before the push goes out. If they fail, the
push aborts and `origin/main` stays clean.

This is not as strong as branch protection (`--no-verify` bypasses it, and
collaborators have to install the hooks), but for solo work or trusted-team
work it's the cheapest way to get the same practical guarantee.

The examples below use [lefthook](https://lefthook.dev/) as the hook runner,
but the pattern works with any (`pre-commit`, husky, a hand-written
`.git/hooks/pre-push`). The only rule that matters: **the hook runs exactly
what CI runs.**

---

## The pattern

`lefthook.yml` defines a `pre-push:` block that mirrors your CI workflow.
Here it mirrors a Python (uv) repo that consumes `python-uv.yml`:

```yaml
# lefthook.yml
pre-push:
  parallel: true
  commands:
    lint:
      run: |
        uv run ruff format --check .
        uv run ruff check .
    typecheck:
      run: uv run mypy .
    test:
      run: uv run pytest --cov --cov-fail-under=85 -q
```

Notable choices:
- **No `glob:` filter.** Pre-*commit* hooks gate on changed-file globs (skip
  the linter if no `*.py` changed). Pre-*push* runs *every* check on *every*
  push — that's the point. A merge or rebase can produce a broken tree even
  when each individual commit looked fine.
- **Same commands as CI, byte-for-byte.** If CI runs `mypy .`, the hook runs
  `mypy .` — not `mypy src/`. If CI gates coverage at 85%, so does the hook.
  If it passes locally it passes on Actions, and vice-versa.
- **`parallel: true`** so all checks run concurrently.

---

## Porting to another repo

Three steps, ~5 minutes:

### 1. Install lefthook

If the repo doesn't already use it:

```bash
# via mise (recommended — version pinned in .mise.toml / mise.toml)
mise use lefthook@latest

# or brew / npm / go install — see https://lefthook.dev/installation/
brew install lefthook
```

Then add `lefthook.yml` to the repo root and run:

```bash
lefthook install
```

`lefthook install` writes `.git/hooks/pre-commit` and `.git/hooks/pre-push`
shims that call `lefthook run`. **Each clone needs to run this once** — add it
to a `make setup` / `mise run setup` task so it isn't forgotten.

### 2. Mirror your CI in `lefthook.yml`

Open your `.github/workflows/<ci>.yml` (or the reusable it calls) and copy
each check's command verbatim into a `pre-push.commands` block. The goal is
**identical behaviour** — if mypy is invoked with extra paths in CI, do the
same locally.

| Stack            | Lint                          | Typecheck           | Test                       |
| ---------------- | ----------------------------- | ------------------- | -------------------------- |
| Python (uv)      | `uv run ruff format --check . && uv run ruff check .` | `uv run mypy .` | `uv run pytest -q` |
| Python (poetry)  | `poetry run ruff check .`     | `poetry run mypy .` | `poetry run pytest -q`    |
| Node (bun)       | `bun run lint`                | `bun run typecheck` | `bun test`                |
| Node (pnpm)      | `pnpm lint`                   | `pnpm tsc --noEmit` | `pnpm test`               |
| Go               | `golangci-lint run`           | `go vet ./...`      | `go test ./...`           |
| Rust             | `cargo clippy -- -D warnings` | (lint covers it)    | `cargo test`              |
| Elixir (mix)     | `mix credo --strict`          | `mix dialyzer`      | `mix test`                |

When the matching reusable from this repo runs a specific command (e.g.
`python-uv.yml` runs `ruff format --check .` and `mypy .`), copy *that* exact
command so local and CI never drift.

### 3. Document the bypass

Add a one-liner to the repo's `CLAUDE.md` / `AGENTS.md` / contributor docs:

> Never use `git push --no-verify` unless you've manually run the CI suite
> first. The pre-push hook is our stand-in for branch protection; bypassing
> it puts broken code on `origin/main`.

---

## When the hook fires (and when it doesn't)

| Action                      | pre-push runs?                              |
| --------------------------- | ------------------------------------------- |
| `git push`                  | Yes                                         |
| `git push origin <branch>`  | Yes                                         |
| `git push --force`          | Yes                                         |
| `git push --no-verify`      | **No** (hook bypassed)                      |
| `git push --dry-run`        | No (no actual push)                         |
| Pushing zero new commits    | No (empty diff)                             |
| `lefthook run pre-push`     | No, unless `--all-files` (no push context)  |

To smoke-test the hook without pushing:

```bash
lefthook run pre-push --all-files
```

This forces all commands to run regardless of git state — handy after editing
the config.

---

## Limits and known caveats

1. **`--no-verify` bypasses it.** This is git by design, not lefthook's. For a
   solo dev, discipline is enough; otherwise pair it with
   `auto-revert-on-main-failure.yml` so a bypassed bad push still gets a revert
   PR opened automatically.

2. **Each clone has to run `lefthook install`.** A fresh clone has no hooks in
   `.git/hooks/`. Until `lefthook install` runs, pre-push is silent.
   Mitigations:
   - Add `lefthook install` to a `make setup` / `mise run setup` task.
   - Use `lefthook install -f` in a CI smoke-check that runs on PRs.
   - Personal: a `~/.config/git/templates` hook that auto-installs lefthook.

3. **Coverage thresholds drift.** If CI's `--cov-fail-under` changes, the hook
   silently passes a stricter CI. Either read both from a shared config (e.g.
   `pyproject.toml`'s `[tool.coverage]`) or bump them together.

4. **Slow test suites = slow pushes.** If your suite takes >30s, split
   pre-push into "fast checks always, slow tests opt-in via env var":
   ```yaml
   pre-push:
     commands:
       test:
         skip:
           - run: test "$SKIP_PUSH_TESTS" = "1"
         run: <test command>
   ```
   Then `SKIP_PUSH_TESTS=1 git push` for emergencies — documents the bypass
   without making it the silent default.

---

## Why this beats just trusting CI

CI catches breakage *after* it lands on `origin/main`. With this hook, broken
code never reaches `origin` in the first place — same end-state as
required-status-checks branch protection, just enforced client-side instead
of server-side. It's the gate; `auto-revert-on-main-failure.yml` is the net
for whatever slips past it.
