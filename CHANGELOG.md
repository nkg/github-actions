# Changelog

All notable changes documented here. Format roughly follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [SemVer](https://semver.org/) for the `vMAJOR.MINOR.PATCH` tags.

## [Unreleased]

### Added

- `playwright-integration.yml` — new reusable that runs integration tests
  inside the official `mcr.microsoft.com/playwright` image (Chromium +
  deps preinstalled), so jobs drive a real headless browser without
  downloading browser binaries each run. Handles the image's quirks
  (no bun, no `unzip`) and optional private-registry npm auth via
  `npm-scope` + the `NODE_AUTH_TOKEN` secret. Generalised from
  `HordiaLabs/fetcher-playwright`'s bespoke integration job; intended for
  the browser-fetcher fleet (`fetcher-playwright`, `fetcher-camoufox`, …).

## [2.4.1] - 2026-06-10

### Changed

- Bumped pinned third-party action versions used by the composites and
  reusables: `actions/setup-go@v6` (in `setup-go`), `actions/cache@v5`
  (in `setup-mise`), and `pozil/auto-assign-issue@v4` (in `auto-assign`)
  (#31).

### Documentation

- Synced README/examples to the `nkg/github-actions` owner and `@v2`
  pins, corrected the `elixir.yml` description and added the missing
  `stale-run-cleanup.yml` row, and added examples for every reusable +
  composite action (#30).

## [2.4.0] - 2026-06-10

### Added

- `setup-token` — optional `permission-*` inputs for least-privilege
  scoping: `permission-contents`, `permission-pull-requests`,
  `permission-issues`, `permission-actions`, `permission-checks`,
  `permission-statuses`, `permission-deployments`, `permission-packages`,
  `permission-workflows` (each `read`/`write`, default empty). Setting any
  restricts the minted token to exactly those permissions (a subset of the
  App installation's); leaving them all empty keeps the existing
  full-installation behaviour. Passed straight through to
  `actions/create-github-app-token`. Additive — no change for current
  callers.

### Changed

- Dependabot `github-actions` group bump (2 updates) for pinned action
  versions used by the reusables.

## [2.3.0] - 2026-06-06

### Fixed

- `claude-code-review.yml` no longer uses the `code-review@claude-code-plugins`
  plugin by default — it is **broken on Claude Code 2.1.x**: the plugin spawns
  a `claude-haiku-4-5-20251001` subagent that doesn't exist (`Error: Agent type
  '...' not found`), so the review ran and billed but produced **zero comments**
  ("No buffered inline comments"). The default now uses a direct review prompt
  plus the inline-comment tool (verified posting 3 inline comments + a summary
  on a test PR). `plugins` / `plugin-marketplace` inputs default to empty;
  callers can still opt back into a plugin or pass a custom `prompt`. This was
  the real "Claude isn't reviewing" cause — combined with the v2.2.0
  `allowedTools` default, reviews now post.

## [2.2.0] - 2026-06-06

### Fixed

- `claude-code-review.yml` now defaults `claude_args` to Anthropic's
  documented PR-review tool set
  (`--allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"`).
  Previously `claude_args` was empty, so the inline-comment MCP tool was
  denied — the review ran (and billed) but posted nothing ("No buffered
  inline comments", `permission_denials_count` > 0). Callers passing their
  own `claude-args` still override it. This is the actual reason reviews
  weren't appearing; unrelated to the upstream tsconfig crash (#1205).

## [2.1.0] - 2026-06-06

### Changed

- `claude-code-review.yml` now marks the upstream `claude-code-action`
  step `continue-on-error: true`, making the automated review an
  **advisory** check that can never block a PR. This shields consumers
  from the upstream Claude Code 2.1.98 SDK crash ("directory mismatch
  for tsconfig.json", anthropics/claude-code-action#1205) — non-fatal
  log noise on `pull_request` triggers, but it can turn fatal on large
  checkouts. Findings are still posted as PR comments. The `@claude` bot
  (`claude.yml`) is intentionally left blocking so failed invocations
  stay visible.

## [2.0.0] - 2026-06-01

### Changed

- **BREAKING (consumers): every reusable workflow now parses its
  `runs-on` input with `fromJSON`, so the value must be a JSON array
  string** — e.g. `'["ubuntu-latest"]'` or
  `'["self-hosted", "linux", "x64"]'`. Previously most reusables took
  `runs-on` as a bare scalar string. A caller still passing
  `runs-on: ubuntu-latest` (or an unquoted `'[self-hosted, linux, x64]'`)
  will fail to schedule — the value is taken as a single literal label,
  no runner matches, and the job queues to the 24h timeout. Effective
  defaults are unchanged: `'["ubuntu-latest"]'` everywhere except the
  `claude*` bot workflows, which default to the self-hosted pool. This
  completes the migration started piecemeal in #17/#18/#21 by converting
  all 23 remaining reusables in one pass; `examples/README.md` callers
  are updated to the JSON form. Per SemVer this is a breaking input
  change for consumers.

## [1.3.0] - 2026-06-01

### Added

- `setup-token` — composite action that mints a short-lived GitHub App
  installation token via `actions/create-github-app-token@v3` and exposes
  it (plus `installation-id` and `app-slug`) as outputs. The generic
  token-minting building block for steps that need to act as the App (gh
  CLI, API calls, pushes that re-trigger workflows). Unlike
  `setup-deps-reader` it does **not** touch git config — use that one when
  you need private-deps fetches over git. Scope with `repositories`; empty
  grants installation-wide access under `owner`.

- `elixir.yml` — `run-deps-audit` input (default `false`) that runs
  `mix deps.audit` (the `mix_audit` package) to scan `mix.lock` for
  dependencies with known CVEs. Complements the existing `run-hex-audit`
  (retired-package check) and `run-sobelow` (Phoenix security scanner)
  inputs. Requires the consumer to depend on `{:mix_audit, "~> 2.1",
  only: [:dev, :test]}`. Additive and off by default, so no behaviour
  change for current callers.

- `stale-run-cleanup.yml` — scheduled reusable workflow that cancels
  **superseded** queued runs (older queued runs for a `(workflow,
  head_branch)` that already has a newer run) so re-pushes/rebases don't
  stack up on a shared self-hosted runner pool. Cancels by supersession,
  never by age alone — a run merely waiting on a busy runner is left to
  take its turn. A `min-age-minutes` grace period avoids racing rapid
  successive pushes (which a consumer's `concurrency:` block already
  handles at push time). `dry-run` input for safe trials. Caller wires
  the `schedule:` cron; see `examples/README.md`.

### Fixed

- `lint-workflows.yml` — parse `runs-on` with `fromJSON` so a self-hosted
  pool passed as a JSON array string is honoured instead of being taken
  as a single literal label; the `lint` jobs had been queuing to the 24h
  cancel. `self-test.yml` caller corrected to valid JSON. Also silenced
  an intentional `SC2086` word-split in `stale-run-cleanup.yml` that the
  now-running actionlint job surfaced (#21).
- `claude-code-review.yml` — skip Dependabot PRs so the review bot no
  longer runs on automated dependency PRs (#20).

## [1.2.2] - 2026-05-27

### Fixed

- `auto-assign.yml` and `claude.yml` — parse the `runs-on` input with
  `fromJSON` so a self-hosted pool default is honoured instead of
  stalling queued jobs (#18).

## [1.2.1] - 2026-05-27

### Fixed

- `claude-code-review.yml` — parse the `runs-on` input with `fromJSON`
  so multi-label self-hosted pools schedule correctly (#17).

## [1.2.0] - 2026-05-21

### Added

- `trivy-repo.yml` — reusable workflow that runs Trivy in `fs`
  (filesystem/lockfile CVE scan) or `config` (IaC misconfiguration:
  Terraform, Kubernetes, Dockerfile, Helm) mode against the
  checked-out repo. Complements the existing `container-security.yml`,
  which scans built images. tfsec is intentionally not used —
  Aqua merged tfsec into Trivy, and `scan-type: config` is the
  maintained successor with the same Terraform check coverage. SARIF
  upload is tagged with a per-scan-type category so `fs` and `config`
  findings don't overwrite each other in the Security tab.

- `auto-revert-on-main-failure.yml` — reusable workflow that opens a
  revert PR when CI on the default branch fails after a merge. For
  private repos on the GitHub free plan, branch-protection rules are
  unavailable, so there's no server-side gate against merging a red PR;
  this reacts after the fact. Caller declares the `workflow_run` trigger
  and an if-guard (the trigger has to live in the caller because GitHub
  only evaluates `workflow_run` events on the default-branch copy), then
  passes `bad-sha` and `failed-run-url` to the reusable. The reusable
  bails if main has moved past the failing commit, if the failing commit
  is itself a revert, or if a revert PR for that SHA already exists.
  Does **not** auto-merge — review the revert PR and decide whether to
  merge (revert) or close (fix-forward). Lifted from
  sproncy/ReactNativeApp#170.

- `examples/README.md` stub for `actions/labeler`. Not shipped as a
  reusable because every repo's label taxonomy is different — the
  per-repo `.github/labeler.yml` config carries the value and a
  wrapper would add nothing on top of the 5-line action invocation.

### Changed

- Claude reusables (`claude.yml`, `claude-code-review.yml`) now default
  `runs-on` to the self-hosted pool, with documented required
  permissions and a one-time validation note for adopters.

## [1.1.2] - 2026-05-18

### Fixed

- `claude-code-review.yml` declared `pull-requests: read` and
  `issues: read`, but `anthropics/claude-code-action@v1` needs `write`
  on both to post review comments back on the PR. The old defaults
  would have made every adopted review bot silently fail to comment.
  Bumped to `write`; mirrors the working local copy in sproncy-accord.

## [1.1.1] - 2026-05-18

### Fixed

- `setup-deps-reader` composite now purges any pre-existing
  `url.*.insteadOf` entries from `~/.gitconfig` before installing the
  credential helper. Persistent self-hosted runners that previously
  ran an inline `git config --global url.<token>@github.com/.insteadOf
  https://github.com/` pattern (which is what every HordiaLabs and
  Sproncy CI used before they adopted the credential.helper approach)
  carry the stale rewrite across jobs — git evaluates url.insteadOf
  before consulting credential helpers, so it silently substitutes
  the now-expired baked-in token into every github.com URL and the
  fresh token from the helper never gets used. GitHub then 401s with
  the misleading `Invalid username or token. Password authentication
  is not supported.` message. Diagnosed in
  sproncy/sproncy-distillery#128; same `--remove-section` cleanup
  mirrored here so the next adopter doesn't hit the same trap.

## [1.1.0] - 2026-05-16

### Added

- **Phase 4 — Cross-org workflows (lifted from HordiaLabs + Regularmusic):**
  - `dependabot-auto-merge.yml` — auto-merges Dependabot PRs once required
    checks pass. `merge-strategy` input (squash/merge/rebase) and
    `auto-merge-major` toggle (default false). Lift from
    HordiaLabs/store-clickhouse.
  - `molecule.yml` — matrix `molecule test` across a list of Ansible
    roles. Collapses the per-role-job repetition seen in
    Regularmusic/iac (14 near-identical jobs → 1 matrix). Inputs cover
    driver, scenario, requirements file.
  - `toml-lint.yml` — taplo `fmt --check` plus Python `tomllib` parse
    over every `*.toml`. Two independent jobs so consumers can disable
    either. Lift from Regularmusic/komodo.
  - `turbo.yml` — Bun + Turborepo with `.turbo` cache, configurable
    tasks + optional workspace `--filter`. Designed to compose with
    `dorny/paths-filter` in the caller stub. Lift from
    Regularmusic/web-platform.
  - `bats.yml` — bats-core test runner + companion shellcheck job.
    Both jobs opt-out. shellcheck-paths auto-detects scripts/, tests/,
    bin/ when blank. Pattern observed across sproncy-secrets,
    GitHub-runners, monitoring_stack, scraper-skills, and
    Regularmusic/iac.

### Changed

- Dependabot-driven action bumps (PR #3, grouped):
  - `actions/upload-artifact` v4 → v7
  - `actions/setup-python` v5 → v6
  - `actions/cache` v4 → v5
  - `astral-sh/setup-uv` v4 → v7
  - `docker/setup-qemu-action` v3 → v4
  - `docker/setup-buildx-action` v3 → v4
  - `docker/login-action` v3 → v4
  - `docker/metadata-action` v5 → v6
  - `docker/build-push-action` v6 → v7
- All bumps are major versions; none of them carry a breaking change
  observable from the workflow inputs this repo exposes.

## [1.0.0] - 2026-05-15

First usable release. Prior commits on `main` shipped only a placeholder
README; everything below is the actual content of this repo.

### Added

- **Phase 1 — Security & bot bundle:**
  - `claude.yml` — reusable wrapper around `anthropics/claude-code-action`
    for the `@claude` on-demand bot. Mention-detection condition is inside
    the reusable so consumers don't copy-paste it.
  - `claude-code-review.yml` — automated Claude PR review with optional
    author/contributor filters.
  - `auto-assign.yml` — assigns new issues and PRs to a configurable user
    list (default `nkg`).
  - `secret-scan.yml` — installs the OSS `gitleaks` binary (no license
    required) and scans PR diff or full history depending on event.
  - `container-security.yml` — Trivy scan of every image in a compose
    file or an explicit list. Uploads SARIF to GitHub Security on push,
    reclaims runner disk after scanning.
  - `sops-audit.yml` — verifies SOPS encryption, scans for plaintext
    secrets, optional shellcheck and `.sops.yaml` CHANGELOG enforcement.
  - `lint-workflows.yml` — actionlint + yamllint reusable, complementing
    this repo's own `self-test.yml`.
- `.github/actionlint.yaml` — declares the Sproncy custom self-hosted
  runner labels (`dind`, `fast`, `slow`) so actionlint doesn't false-positive.

- **Phase 2 — Stack coverage:**
  - `go.yml` — gofmt, go vet, optional staticcheck + govulncheck,
    test with race + coverage upload.
  - `scrapy.yml` — uv-managed Scrapy project: ruff + pytest +
    `scrapy list` + `scrapy check` (contract tests) + optional
    single-item smoke crawl via `CLOSESPIDER_ITEMCOUNT=1`.
  - `fastapi.yml` — python-uv set of checks plus app-import smoke,
    OpenAPI schema export to an artifact, optional schema-drift diff
    against a committed baseline.
  - `compose-validate.yml` — generalised from `monitoring_stack`. Uses
    `docker compose config --quiet` across profiles. Supports env-vars
    input and extra-validator scripts.
  - `komodo-deploy.yml` — POSTs to Komodo's `/api/execute` endpoint
    (DeployStack, RunBuild, ExecuteProcedure, …). Optional
    poll-until-complete via `/read GetUpdate`.
- **Phase 3a — Hardening existing workflows (all additions are opt-in,
  default off — no behaviour change for current consumers):**
  - `python-uv.yml`: `run-pip-audit`, `run-bandit` toggles
    (`uvx pip-audit`, `uvx bandit`).
  - `elixir.yml`: `run-hex-audit` (`mix hex.audit`),
    `run-sobelow` (Phoenix security scanner via `mix archive.install`).
  - `node-bun.yml`: `run-audit` toggle (`bun pm audit`).
  - `docker-build.yml`: `run-trivy-scan` (scans pushed image by digest,
    SARIF upload on non-PR), `sign-image` (cosign keyless OIDC, signs
    every tag at the same digest), `generate-sbom` (anchore/sbom-action,
    SPDX-JSON, 30-day artifact retention). All three short-circuit
    silently when `push: false`. `id-token: write` and
    `security-events: write` permissions are now always declared.

- **Phase 3b — New composite actions & housekeeping:**
  - `setup-go` — thin wrapper over `actions/setup-go@v5` for org-wide
    Go version pinning.
  - `setup-trivy` — pinned Trivy CLI install (linux/macOS × amd64/arm64).
    Uses GitHub release tarball + `sudo install` for predictable perms.
  - `setup-cosign` — wraps `sigstore/cosign-installer@v3`. Single
    point for pinning the cosign release across the org.
  - `setup-deps-reader` — generalised from `sproncy-distillery`'s
    `setup-sproncy`. Mints a scoped GitHub App installation token,
    configures git via a per-job `credential.helper store` file
    (not `--global insteadOf`, which uv/hex/go subprocess fetches
    didn't honour reliably).
  - `.github/dependabot.yml` — weekly `github-actions` bumps for this
    repo itself.
  - `self-test.yml` now dogfoods `lint-workflows.yml` (was three
    inline jobs).

### Fixed

- `setup-sops` composite hardcoded `linux.amd64` — broken for arm and
  macOS runners. Now detects `RUNNER_OS` + `uname -m`, supports
  linux/darwin × amd64/arm64. Uses `sudo install` instead of
  `chmod` so the binary lands with correct perms.

### Changed

- `README.md` rewritten: replaced `<org>/ci` placeholder with the real
  `nkg/github-actions` slug, regrouped workflow table by purpose
  (build/test, security, bot), documented the runner strategy.
- `examples/README.md` extended with consumer stubs for every new workflow.
- Bumped `actions/checkout` from `@v4` to `@v6` across all existing
  workflows for consistency with new files.

[Unreleased]: https://github.com/nkg/github-actions/compare/v2.4.1...HEAD
[2.4.1]: https://github.com/nkg/github-actions/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/nkg/github-actions/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/nkg/github-actions/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/nkg/github-actions/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/nkg/github-actions/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/nkg/github-actions/compare/v1.3.0...v2.0.0
[1.3.0]: https://github.com/nkg/github-actions/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/nkg/github-actions/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/nkg/github-actions/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/nkg/github-actions/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/nkg/github-actions/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/nkg/github-actions/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/nkg/github-actions/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/nkg/github-actions/releases/tag/v1.0.0
