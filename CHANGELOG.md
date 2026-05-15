# Changelog

All notable changes documented here. Format roughly follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [SemVer](https://semver.org/) for the `vMAJOR.MINOR.PATCH` tags.

## [Unreleased]

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
  `sproncy/github-actions` slug, regrouped workflow table by purpose
  (build/test, security, bot), documented the runner strategy.
- `examples/README.md` extended with consumer stubs for every new workflow.
- Bumped `actions/checkout` from `@v4` to `@v6` across all existing
  workflows for consistency with new files.

### Pre-1.1.0 baseline

Earlier additions, currently shipped under `v1.0.x`:

- Reusable workflows: `python-uv`, `node-bun`, `elixir`, `expo`,
  `opentofu`, `ansible`, `docker-build`.
- Composite actions: `setup-mise`, `setup-sops`.
- `release.yml` to maintain the floating `vMAJOR` tag.
- `self-test.yml` running actionlint and yamllint on every PR.
- Renovate config.

[Unreleased]: https://github.com/sproncy/github-actions/compare/v1.0.0...HEAD
