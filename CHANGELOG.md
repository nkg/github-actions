# Changelog

All notable changes documented here. Format roughly follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [SemVer](https://semver.org/) for the `vMAJOR.MINOR.PATCH` tags.

## [Unreleased]

## [2.10.0] - 2026-06-12

### Added

- `expo.yml` + `node-bun.yml` — cache the package-manager download dir on the
  `use-mise` path. The bun/node setup actions already cache their store, but
  `use-mise: true` skips them, so mise-path runs re-downloaded every build.
  Adds an `actions/cache` step (gated on `use-mise`) keyed on whichever
  lockfile exists, caching the resolved PM's dir (`~/.npm`, `~/.bun/install/cache`,
  `~/.cache/yarn`, `~/.local/share/pnpm/store`). No-op for the non-mise paths;
  additive. Follow-up to the v2.8.0 package-manager-agnostic work — biggest win
  on ephemeral GitHub-hosted runners (self-hosted already persists the dir).
- `dependabot-uv-lockfile.yml` — regenerates `uv.lock` on Dependabot PRs and
  pushes the result back onto the PR branch, keeping the resolved graph in sync
  when a bump (especially grouped/transitive) leaves the lockfile stale. The
  actor guard (`dependabot[bot]`) lives in the reusable; the caller stub only
  supplies the `pull_request` trigger and `contents: write`. Multi-dir aware
  via `directories` (newline/comma-separated), so a monorepo regenerates every
  subproject's lockfile in one job. Generalised from sproncy-distillery's
  `dependabot-lockfile.yml`.

## [2.9.0] - 2026-06-11

### Added

- `elixir.yml` — optional private-deps access (mirrors `go.yml`): set
  `deps-reader-client-id` + `deps-reader-repositories` (and pass the
  `DEPS_READER_PRIVATE_KEY` secret) and a scoped GitHub App token is minted
  via `setup-deps-reader` with git's credential helper wired before
  `mix deps.get`, so private hex/git deps resolve. Empty = no change for
  current callers.
- `elixir.yml` — optional DB-backed test job (`run-db-tests`, default false):
  runs `mix test` in a separate job with parameterized Postgres
  (`postgres-image`/`-user`/`-password`/`-db`) + Valkey (`valkey-image`)
  service containers, optional `mix ecto.create && ecto.migrate`
  (`run-ecto-setup`), and a derived `DATABASE_URL`/`VALKEY_URL` (override via
  `database-url`). When enabled, the main job's `mix test` step is skipped so
  the suite isn't run twice. Unblocks the DB-backed Elixir services
  (scraper-control, elixir_web_app, reddit_streamer, NamingThingsIsHardAPI)
  that previously had to hand-roll their CI for service containers.

### Fixed

- `lint-workflows.yml` — install yamllint via `uv` instead of
  `actions/setup-python@v6` + `pip`. setup-python can't provision Python on
  newer runners (Debian 13 self-hosted: "version '3.12' ... not found"), which
  failed the yamllint job for self-hosted consumers; uv is self-contained.
  Behaviour-preserving — still runs `yamllint <paths>` (honouring a consumer
  `.yamllint` config). Surfaced by HordiaLabs/NamingThingsIsHardExpoApp CI.

## [2.8.0] - 2026-06-10

### Added

- `expo.yml` + `node-bun.yml` — **package-manager-agnostic** toolchain.
  New `package-manager` input (`bun` default, or `npm`/`yarn`/`pnpm`) swaps
  the setup action (`setup-bun` vs `setup-node` + corepack) and derives the
  per-step commands; a `use-mise` input installs the toolchain from the
  repo's `mise.toml` instead (Node, and Bun if pinned), for mise-pinned apps.
  Added `node-version` to pair with the non-bun path.
- `expo.yml` — command-override escape hatch: `install-command`,
  `lint-command`, `typecheck-command`, `test-command` (empty = derive from
  the package manager). Brings it in line with `node-bun.yml`, and lets
  npm/`node:test`-style Expo apps point each step at their own scripts.

  Both changes are additive and behaviour-preserving for current callers:
  the defaults still resolve to the previous Bun commands
  (`bun install --frozen-lockfile`, `bun test`, `bunx tsc --noEmit`). The
  `*-command` defaults on `node-bun.yml` changed from literal Bun strings to
  empty (derive-from-PM), which is identical for the default `package-manager: bun`.
  Generalises the hand-rolled npm + mise CI in
  HordiaLabs/NamingThingsIsHardExpoApp so that repo can migrate onto the reusable.

## [2.7.0] - 2026-06-10

### Added

- `go.yml` — optional `gowork-off`. Set `gowork-off: true` to export
  `GOWORK=off` for every Go step, so a parent `go.work` (a workspace
  `replace` pointing a dependency at a local tree) can't mask a stale
  `go.mod` pin — the module resolves exactly as declared, matching a fresh
  single-module CI checkout. Default off — additive. Generalises the
  `GOWORK=off` dep-drift guard in `HordiaLabs/store-clickhouse`'s
  `make test-ci` / pre-push hook so any private-module consumer gets it.
- `go.yml` — optional `golangci-lint`. Set `run-golangci-lint: true` (with
  `golangci-lint-version` pinned to match a mise/`.tool-versions` entry, e.g.
  `"2.11.4"`) and the workflow installs the pinned binary and runs
  `golangci-lint run ./...` after `go mod download`. Pins via the official
  install script rather than `golangci-lint-action` so the version isn't
  coupled to the action's v1/v2 support matrix. Default off — additive, no
  change for current callers. Lets repos that lint via golangci-lint (e.g.
  `HordiaLabs/store-clickhouse`) drop their hand-rolled lint job and migrate
  onto `go.yml`.
- `go.yml` — optional throwaway Postgres for DB-gated integration tests.
  Set `postgres-enabled: true` (with optional `postgres-image` / `-user` /
  `-password` / `-db`) and the workflow starts a Postgres container before
  the test step and exports `DATABASE_URL` into the job env, so tests that
  skip when `DATABASE_URL` is unset actually run in CI. Implemented as a
  conditional `docker run` step rather than a `services:` block on purpose —
  a `services:` map can't be gated by an input, so this keeps Postgres fully
  opt-in and zero-cost for non-DB consumers. Default off — additive, no
  change for current callers. Generalises the hand-rolled Postgres service
  in `HordiaLabs/store-postgres`'s CI so that repo can migrate onto `go.yml`.
- `docker-build.yml` — optional private-deps access *inside the build*.
  Set `deps-reader-client-id` + `deps-reader-repositories` (and pass the
  `DEPS_READER_PRIVATE_KEY` secret) and the workflow mints a scoped App
  token via `setup-token` and injects it as the `github_token` BuildKit
  secret, merged with any `build-secrets`. Lets a Dockerfile that pulls
  private modules build through the reusable without the caller minting the
  token itself (which a reusable can't accept from a step output). Empty
  `deps-reader-client-id` keeps existing behaviour — additive.
- `dependabot-auto-merge.yml` — `use-auto-merge` input (default `true`) plus a
  `workflow_run` trigger path, so the workflow works on **Free-plan private
  repos**. GitHub gates native auto-merge (`gh pr merge --auto`) to
  Team/Enterprise on private repos; setting `use-auto-merge: false` and
  triggering on `workflow_run` (after CI succeeds) resolves the Dependabot PR
  for that run and merges it immediately instead. The default `pull_request`
  path is unchanged — fully backwards-compatible for current callers. Major
  bumps are gated accurately via `fetch-metadata` on the `pull_request` path
  and best-effort from the PR title on the `workflow_run` path (grouped
  updates are treated as non-major). Generalises the inert
  `dependabot-auto-merge.yml` that HordiaLabs/extractor-llm hit on the Free
  plan. See examples/README.md for both stubs.

## [2.6.0] - 2026-06-10

### Added

- `go.yml` — optional private-deps access. Set `deps-reader-client-id` +
  `deps-reader-repositories` (and pass the `DEPS_READER_PRIVATE_KEY` secret)
  and the workflow mints a scoped GitHub App token via `setup-deps-reader`
  and wires git's credential helper before `go mod download`, so GOPRIVATE
  modules behind private repos resolve. Empty `deps-reader-client-id` keeps
  the existing public-only behaviour — additive, no change for current callers.
- `go.yml` — optional `go test -fuzz` smoke pass: `run-fuzz` (default false)
  with `fuzz-target` (anchored `^NAME$`), `fuzz-time` (default `30s`), and
  `fuzz-package` (default `./...`). Runs after the test step; corpus
  additions are discarded.
- `docker-build.yml` — `build-secrets` input, forwarded to BuildKit as
  `--mount=type=secret` id=value pairs. Lets a Dockerfile consume a
  private-deps token (e.g. `github_token`) minted in the caller without
  baking it into image layers. Empty default — no change for current callers.

  These generalise the hand-rolled pattern in
  HordiaLabs/extractor-jsonpath (private `scraper-core` module + a 30s
  FuzzExtract smoke pass), so that repo's CI can migrate onto the reusables.
  Code merged in #35; this entry restores the changelog note dropped in that
  squash-merge.

## [2.5.0] - 2026-06-10

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

[Unreleased]: https://github.com/nkg/github-actions/compare/v2.10.0...HEAD
[2.10.0]: https://github.com/nkg/github-actions/compare/v2.9.0...v2.10.0
[2.9.0]: https://github.com/nkg/github-actions/compare/v2.8.0...v2.9.0
[2.8.0]: https://github.com/nkg/github-actions/compare/v2.7.0...v2.8.0
[2.7.0]: https://github.com/nkg/github-actions/compare/v2.6.0...v2.7.0
[2.6.0]: https://github.com/nkg/github-actions/compare/v2.5.0...v2.6.0
[2.5.0]: https://github.com/nkg/github-actions/compare/v2.4.1...v2.5.0
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
