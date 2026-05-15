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
    test with race + coverage upload. `go-version: "mise"` reads the
    pin from `.mise.toml`.
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

### Changed

- `README.md` rewritten: replaced `<org>/ci` placeholder with the real
  `sproncy/github-actions` slug, regrouped workflow table by purpose
  (build/test, security, bot), documented the runner strategy.
- `examples/README.md` extended with consumer stubs for every new workflow.

### Pre-1.1.0 baseline

Earlier additions, currently shipped under `v1.0.x`:

- Reusable workflows: `python-uv`, `node-bun`, `elixir`, `expo`,
  `opentofu`, `ansible`, `docker-build`.
- Composite actions: `setup-mise`, `setup-sops`.
- `release.yml` to maintain the floating `vMAJOR` tag.
- `self-test.yml` running actionlint and yamllint on every PR.
- Renovate config.

[Unreleased]: https://github.com/sproncy/github-actions/compare/v1.0.0...HEAD
