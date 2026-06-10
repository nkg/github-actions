# nkg/github-actions

Centralised reusable GitHub Actions workflows and composite actions for the
Sproncy org. Consumed by ~20 sibling repos via `uses:` pinned tags.

## Layout

```
.github/
├── workflows/             # reusable workflows (callable via `uses:`)
│   ├── ansible.yml
│   ├── auto-assign.yml
│   ├── auto-revert-on-main-failure.yml
│   ├── bats.yml
│   ├── claude.yml
│   ├── claude-code-review.yml
│   ├── compose-validate.yml
│   ├── container-security.yml
│   ├── dependabot-auto-merge.yml
│   ├── docker-build.yml
│   ├── elixir.yml
│   ├── expo.yml
│   ├── fastapi.yml
│   ├── go.yml
│   ├── komodo-deploy.yml
│   ├── lint-workflows.yml
│   ├── molecule.yml
│   ├── node-bun.yml
│   ├── opentofu.yml
│   ├── playwright-integration.yml
│   ├── python-uv.yml
│   ├── release.yml          # auto-moves the floating vMAJOR tag
│   ├── scrapy.yml
│   ├── secret-scan.yml
│   ├── self-test.yml        # this repo's own CI
│   ├── sops-audit.yml
│   ├── toml-lint.yml
│   ├── trivy-repo.yml
│   └── turbo.yml
├── actions/               # composite actions (callable via `uses:` from steps)
│   ├── setup-cosign/
│   ├── setup-deps-reader/
│   ├── setup-go/
│   ├── setup-mise/
│   ├── setup-sops/
│   ├── setup-token/
│   └── setup-trivy/
├── actionlint.yaml          # declares Sproncy custom self-hosted labels
└── dependabot.yml           # weekly bumps for this repo's own actions
```

## Runner strategy

Most reusable workflows default to `'["ubuntu-latest"]'` and expose a
`runs-on` input (a JSON array string parsed with `fromJSON`). Consumers
route to self-hosted by passing a label array:

```yaml
with:
  runs-on: '["self-hosted", "linux", "x64"]'
```

**Exception:** `claude.yml` and `claude-code-review.yml` default to the
self-hosted pool (`'["self-hosted", "linux", "x64"]'`) since Claude jobs
run on private repos. Public/open-source consumers opt out with
`runs-on: '["ubuntu-latest"]'`.

The Sproncy self-hosted fleet uses capability labels (`dind`, `fast`, `slow`
for AI workloads). `.github/actionlint.yaml` declares them so `actionlint`
doesn't false-positive.

## Versioning

Workflows are consumed by tag. Tags follow `vMAJOR.MINOR.PATCH` and a
floating `vMAJOR` tag tracks the latest non-breaking release on that line.

- Pin to `@v2` for low-friction updates within a major version.
- Pin to `@v2.4.0` (or a SHA) when you need bit-for-bit reproducibility.

Breaking changes bump the major. See `CHANGELOG.md`.

## Consuming a workflow

Drop a stub into the consumer repo at `.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    uses: nkg/github-actions/.github/workflows/python-uv.yml@v2
    with:
      python-version: "3.12"
    secrets: inherit
```

`secrets: inherit` is the quickest path; for security-sensitive workflows
(`claude`, `claude-code-review`, `sops-audit`) prefer declaring secrets
explicitly so it's obvious what the workflow can see.

### Choosing a runner

Every reusable takes a `runs-on` input that is a **JSON array string**, parsed
with `fromJSON`. Pass a quoted JSON array — not a bare label:

```yaml
    with:
      runs-on: '["ubuntu-latest"]'              # GitHub-hosted (the default)
      # runs-on: '["self-hosted", "linux", "x64"]'   # self-hosted pool
```

A bare string like `runs-on: ubuntu-latest` (or unquoted `'[self-hosted, ...]'`)
will not parse and the job will fail to schedule. The default is
`'["ubuntu-latest"]'` for every reusable except the `claude*` bot workflows,
which default to the self-hosted pool.

## Consuming a composite action

```yaml
steps:
  - uses: actions/checkout@v6
  - uses: nkg/github-actions/.github/actions/setup-mise@v2
  - run: mise run build
```

## Available reusable workflows

### Build & test

| Workflow              | Purpose                                                          |
|-----------------------|------------------------------------------------------------------|
| `python-uv.yml`       | uv-based Python: ruff, mypy, pytest with coverage                |
| `fastapi.yml`         | python-uv + import smoke + OpenAPI export/diff                   |
| `scrapy.yml`          | python-uv + `scrapy list` + `scrapy check` (+ optional smoke)    |
| `node-bun.yml`        | Bun-based Node/TS: install, lint, typecheck, test, build         |
| `playwright-integration.yml`| Integration tests inside the Playwright image (real Chromium; bun + private-registry aware) |
| `turbo.yml`           | Bun + Turborepo monorepo (cache, tasks, optional filters)        |
| `elixir.yml`          | Mix: deps, format check, credo, test; opt-in dialyzer/sobelow/audits |
| `go.yml`              | Go: gofmt, vet, optional golangci-lint/staticcheck/govulncheck/fuzz, test+coverage, optional Postgres + private-deps |
| `expo.yml`            | Expo/RN: install, lint, typecheck, optional EAS build            |
| `opentofu.yml`        | OpenTofu: fmt, init, validate, plan (apply gated by env)         |
| `ansible.yml`         | ansible-lint + syntax check                                      |
| `molecule.yml`        | Matrix `molecule test` across Ansible roles                      |
| `toml-lint.yml`       | taplo fmt --check + Python tomllib parse over all `.toml` files  |
| `docker-build.yml`    | buildx multi-arch build + push to GHCR, optional build-secrets + private-deps |
| `compose-validate.yml`| `docker compose config` across profiles (DinD-safe pattern)      |
| `komodo-deploy.yml`   | POST to Komodo's /api/execute; optional poll-until-complete      |

### Security

| Workflow                | Purpose                                                          |
|-------------------------|------------------------------------------------------------------|
| `secret-scan.yml`       | OSS gitleaks; PR-diff or full-history scan, SARIF artifact       |
| `container-security.yml`| Trivy scan of every image in a compose file or explicit list     |
| `trivy-repo.yml`        | Trivy filesystem (lockfiles) or config (IaC) scan of the repo    |
| `sops-audit.yml`        | Verify SOPS encryption + plaintext-secret scan + shellcheck      |
| `lint-workflows.yml`    | actionlint + yamllint for the consumer's `.github/` tree         |
| `bats.yml`              | bats-core test runner + companion shellcheck job (both opt-out)  |

### Bot / automation

| Workflow                  | Purpose                                                        |
|---------------------------|----------------------------------------------------------------|
| `claude.yml`              | `@claude` on-demand bot (issues, PRs, review comments)         |
| `claude-code-review.yml`  | Automated Claude code review on PR open/sync                   |
| `auto-assign.yml`         | Auto-assign new issues and PRs to a user list                  |
| `dependabot-auto-merge.yml`| Auto-merges Dependabot PRs (major bumps gated; native auto-merge or Free-plan `workflow_run` path) |
| `auto-revert-on-main-failure.yml`| Opens a revert PR when main CI fails (free-plan branch-protection workaround) |
| `stale-run-cleanup.yml`   | Cancels superseded queued runs on a shared runner pool (min-age guard, dry-run) |

## Available composite actions

| Action               | Purpose                                                            |
|----------------------|--------------------------------------------------------------------|
| `setup-mise`         | Installs mise and runs `mise install` (caches the tool dir)        |
| `setup-sops`         | Installs sops + age (cross-arch), optionally decrypts a file       |
| `setup-go`           | Thin wrapper over `actions/setup-go@v6` for org-wide version pin   |
| `setup-trivy`        | Installs Trivy CLI at a pinned version (linux/macOS × amd64/arm64) |
| `setup-cosign`       | Wraps `sigstore/cosign-installer@v3` so the version is pinned once |
| `setup-deps-reader`  | Mints a scoped GitHub App token for private-deps access via git    |
| `setup-token`        | Mints a GitHub App installation token as an output (no git wiring); optional `permission-*` inputs scope it to least privilege |

## Self-hosted runners

Every reusable workflow accepts a `runs-on` input. Most default to
`'["ubuntu-latest"]'`; the Claude workflows (`claude.yml`,
`claude-code-review.yml`) default to `'["self-hosted", "linux", "x64"]'`.
Pass `runs-on: '["self-hosted", "linux", "x64"]'` (or a longer label array
like `'["self-hosted", "linux", "x64", "dind"]'`) to route to your own
runner pool, or `runs-on: '["ubuntu-latest"]'` to opt back onto
GitHub-hosted runners.

The input is a JSON array string parsed with `fromJSON`, so it must be
quoted. Per-job matrix splits stay in the caller — this repo's workflows
are single-job.

## Updating actions

Renovate is configured (`renovate.json`) to bump pinned actions automatically.
Consumers should also enable Renovate to keep their pin to this repo
(`nkg/github-actions`) up to date.

## Releasing

Tag-based. From `main`:

```
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

The `release.yml` workflow handles the floating major-tag move automatically
when a `vMAJOR.MINOR.PATCH` tag is pushed.
