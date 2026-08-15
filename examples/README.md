# Consumer examples

Drop these into `.github/workflows/*.yml` of a consumer repo. Replace
`nkg/github-actions@v2` with a SHA when you need bit-for-bit pinning.

## Python (uv)

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
      python-version: "3.14"
    secrets: inherit
```

## Node monorepo package

Defaults to Bun. Pass `package-manager: npm` (or `yarn`/`pnpm`), or
`use-mise: true` to install the toolchain from your `mise.toml`. Per-step
commands auto-derive from the package manager — override any with the
`*-command` inputs.

```yaml
name: CI
on: [push, pull_request]
jobs:
  web:
    uses: nkg/github-actions/.github/workflows/node-bun.yml@v2
    with:
      working-directory: apps/web
      # package-manager: npm      # bun (default) | npm | yarn | pnpm
      # use-mise: true            # install Node/Bun from mise.toml instead
```

## Playwright integration tests

Drives a real headless Chromium inside the Playwright runtime image —
no browser download per run. Pin `playwright-image` to the same tag as
your `package.json` playwright version + Dockerfile base. Pass an
`npm-scope` (and `NODE_AUTH_TOKEN`) when the integration deps live in a
private org registry:

```yaml
name: Integration
on: [push, pull_request]
jobs:
  integration:
    uses: nkg/github-actions/.github/workflows/playwright-integration.yml@v2
    with:
      playwright-image: "mcr.microsoft.com/playwright:v1.60.0-noble"
      npm-scope: "@hordialabs"
      bun-version: "1.3.9"           # pin to your mise.toml
      test-command: "npm run test:integration"
    secrets:
      NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Expo / React Native

Defaults to Bun (`bun install` / `bun test`). install + lint + typecheck +
tests run by default; the EAS build is opt-in.

```yaml
name: CI
on: [push, pull_request]
jobs:
  app:
    uses: nkg/github-actions/.github/workflows/expo.yml@v2
    with:
      bun-version: "1.1"
    # Opt into an EAS build (off by default; needs EXPO_TOKEN):
    #   run-eas-build: true
    #   eas-platform: android   # ios | android | all
    #   eas-profile: preview
    # secrets: inherit
```

For an **npm + mise-pinned Node** Expo app (e.g. one whose tests are a
`node:test`/`tsx` runner rather than `bun test`), select the package manager
and install the toolchain from `mise.toml`, then point the `*-command` inputs
at the repo's own scripts:

```yaml
jobs:
  app:
    uses: nkg/github-actions/.github/workflows/expo.yml@v2
    with:
      package-manager: npm
      use-mise: true                       # Node comes from mise.toml
      typecheck-command: "npm run typecheck"
      test-command: "npm test"             # node:test runner, not bun test
      runs-on: '["self-hosted", "linux", "x64"]'
```

## Elixir/Phoenix with matrix

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    strategy:
      matrix:
        otp: ["26", "27"]
        elixir: ["1.16", "1.17"]
    uses: nkg/github-actions/.github/workflows/elixir.yml@v2
    with:
      otp-version: ${{ matrix.otp }}
      elixir-version: ${{ matrix.elixir }}
```

Phoenix app with Ecto tests (Postgres + Valkey services) and a private hex/git
dep — the DB test job runs `mix test` against the service containers; the main
job covers format/credo/dialyzer:

```yaml
name: CI
on: [push, pull_request]
jobs:
  ci:
    uses: nkg/github-actions/.github/workflows/elixir.yml@v2
    with:
      elixir-version: "1.18"
      otp-version: "27"
      run-dialyzer: true
      run-db-tests: true            # spins up Postgres + Valkey, runs mix test there
      postgres-image: "postgres:16-alpine"
      # private scraper-core dep:
      deps-reader-client-id: ${{ vars.DEPS_READER_CLIENT_ID }}
      deps-reader-repositories: scraper-core
    secrets:
      DEPS_READER_PRIVATE_KEY: ${{ secrets.DEPS_READER_PRIVATE_KEY }}
```

## OpenTofu (per-stack)

```yaml
name: CI
on:
  push:
    branches: [main]
    paths: ["stacks/cloudflare/**"]
  pull_request:
    paths: ["stacks/cloudflare/**"]
jobs:
  cloudflare:
    uses: nkg/github-actions/.github/workflows/opentofu.yml@v2
    with:
      working-directory: stacks/cloudflare
      tofu-version: "1.8.0"
```

## Docker → GHCR

```yaml
name: Build
on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:
jobs:
  image:
    uses: nkg/github-actions/.github/workflows/docker-build.yml@v2
    with:
      image-name: ${{ github.repository }}
      platforms: linux/amd64,linux/arm64
      push: ${{ github.event_name != 'pull_request' }}
```

Build a Dockerfile that pulls **private modules**. The workflow mints a scoped
deps-reader token and injects it as the `github_token` BuildKit secret, so the
build can fetch private repos without the caller minting the token itself.
Consume it in the Dockerfile with
`RUN --mount=type=secret,id=github_token …`:

```yaml
jobs:
  image:
    uses: nkg/github-actions/.github/workflows/docker-build.yml@v2
    with:
      image-name: ${{ github.repository }}
      push: ${{ github.event_name != 'pull_request' }}
      deps-reader-client-id: ${{ vars.DEPS_READER_CLIENT_ID }}
      deps-reader-repositories: scraper-core
      # build-secrets: |          # merged with the minted github_token
      #   npm_token=${{ secrets.NPM_TOKEN }}
    secrets:
      DEPS_READER_PRIVATE_KEY: ${{ secrets.DEPS_READER_PRIVATE_KEY }}
```

## Ansible

```yaml
name: CI
on: [push, pull_request]
jobs:
  ansible:
    uses: nkg/github-actions/.github/workflows/ansible.yml@v2
    with:
      working-directory: ansible
      playbooks: |
        playbooks/site.yml
        playbooks/proxmox.yml
      requirements-file: ansible/requirements.yml
```

## Go

```yaml
name: CI
on: [push, pull_request]
jobs:
  go:
    uses: nkg/github-actions/.github/workflows/go.yml@v2
    with:
      go-version: "1.23"
      run-staticcheck: true
      run-govulncheck: true
```

Go with private modules (mints a deps-reader token before `go mod download`)
and a fuzz smoke pass:

```yaml
name: CI
on: [push, pull_request]
jobs:
  go:
    uses: nkg/github-actions/.github/workflows/go.yml@v2
    with:
      go-version: "1.26"
      # goprivate is required for private modules — it makes `go` resolve them
      # over git (where the minted token applies) instead of the public proxy.
      goprivate: github.com/HordiaLabs/*
      deps-reader-client-id: ${{ vars.DEPS_READER_CLIENT_ID }}
      deps-reader-repositories: scraper-core
      run-fuzz: true
      fuzz-target: FuzzExtract
      fuzz-time: 30s
      fuzz-package: ./internal/...
      # govulncheck-soft: true   # report CVEs without failing the build
    secrets:
      DEPS_READER_PRIVATE_KEY: ${{ secrets.DEPS_READER_PRIVATE_KEY }}
```

Go with `golangci-lint` and `gowork-off`. Pin `golangci-lint-version` to the
same version as your local mise/`.tool-versions` entry so CI and dev agree.
`gowork-off: true` exports `GOWORK=off` for every step, so a parent `go.work`
`replace` can't mask a stale `go.mod` pin — the module resolves exactly as a
fresh single-module checkout would:

```yaml
name: CI
on: [push, pull_request]
jobs:
  go:
    uses: nkg/github-actions/.github/workflows/go.yml@v2
    with:
      go-version: "1.26"
      run-golangci-lint: true
      golangci-lint-version: "2.11.4"   # match your .tool-versions
      gowork-off: true
```

Go with a throwaway Postgres for DB-gated integration tests. The workflow
starts the container before the test step and exports `DATABASE_URL` into the
job env, so tests that skip when `DATABASE_URL` is unset actually run:

```yaml
name: CI
on: [push, pull_request]
jobs:
  go:
    uses: nkg/github-actions/.github/workflows/go.yml@v2
    with:
      go-version: "1.26"
      postgres-enabled: true
      # postgres-image: "postgres:16-alpine"   # default
      # postgres-user / postgres-password / postgres-db also configurable
```

## Scrapy

```yaml
name: CI
on: [push, pull_request]
jobs:
  scrapy:
    uses: nkg/github-actions/.github/workflows/scrapy.yml@v2
    with:
      run-spider-smoke: true
      spider-name: products
```

## FastAPI

```yaml
name: CI
on: [push, pull_request]
jobs:
  api:
    uses: nkg/github-actions/.github/workflows/fastapi.yml@v2
    with:
      app-module: myapi.main:app
      run-openapi-diff: true
      openapi-baseline: docs/openapi.json
```

## Compose validate (DinD-safe)

```yaml
name: Validate compose
on: [push, pull_request]
jobs:
  validate:
    uses: nkg/github-actions/.github/workflows/compose-validate.yml@v2
    with:
      compose-file: docker-compose.yml
      profiles: |
        logs
        alerts
        tracing
      env-vars: |
        GRAFANA_ADMIN_PASSWORD=ci-validate
      runs-on: '["self-hosted", "linux", "x64"]'
```

## Komodo deploy

```yaml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  komodo:
    uses: nkg/github-actions/.github/workflows/komodo-deploy.yml@v2
    with:
      komodo-url: https://komodo.example.com
      operation: DeployStack
      target: monitoring
      wait-for-completion: true
    secrets:
      KOMODO_API_KEY: ${{ secrets.KOMODO_API_KEY }}
      KOMODO_API_SECRET: ${{ secrets.KOMODO_API_SECRET }}
```

---

## Security

### Secret scan (gitleaks)

```yaml
name: Secret scan
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 6 * * 1'   # weekly full-history sweep
jobs:
  gitleaks:
    uses: nkg/github-actions/.github/workflows/secret-scan.yml@v2
    with:
      runs-on: '["self-hosted", "linux", "x64"]'
```

### Container security (Trivy on compose images)

```yaml
name: Container security
on:
  push:
    branches: [main]
    paths: ['docker-compose.yml']
  pull_request:
    paths: ['docker-compose.yml']
  schedule:
    - cron: '0 6 * * 1'
jobs:
  trivy:
    uses: nkg/github-actions/.github/workflows/container-security.yml@v2
    with:
      compose-file: docker-compose.yml
      runs-on: '["self-hosted", "linux", "x64"]'
```

Or scan an explicit list:

```yaml
jobs:
  trivy:
    uses: nkg/github-actions/.github/workflows/container-security.yml@v2
    with:
      image-list: |
        ghcr.io/nkg/api:latest
        ghcr.io/nkg/web:latest
```

### Trivy repo scan (filesystem + IaC)

Complement to `container-security.yml`. Scans the checked-out repo for lockfile CVEs (`scan-type: fs`) or IaC misconfigurations in Terraform/Kubernetes/Dockerfile/Helm (`scan-type: config`). Aqua merged `tfsec` into Trivy — `scan-type: config` is the maintained successor and covers the same Terraform checks.

```yaml
name: Repo security
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 6 * * 1'
jobs:
  fs:
    uses: nkg/github-actions/.github/workflows/trivy-repo.yml@v2
    permissions:
      contents: read
      actions: read          # }- only needed while upload-sarif is true
      security-events: write # }
    with:
      scan-type: fs
  config:
    uses: nkg/github-actions/.github/workflows/trivy-repo.yml@v2
    permissions:
      contents: read
      actions: read
      security-events: write
    with:
      scan-type: config
      skip-dirs: |
        node_modules
        .terraform
```

**Private repo without Advanced Security?** The SARIF upload 403s there, so pass `upload-sarif: false` — and then `contents: read` is the *only* permission you need. The upload lives in its own `sarif-upload` job which declares no permissions of its own and is skipped outright when you opt out, so you're never asked to grant `security-events: write` for a run that won't use it:

```yaml
jobs:
  fs:
    uses: nkg/github-actions/.github/workflows/trivy-repo.yml@v2
    permissions:
      contents: read
    with:
      scan-type: fs
      upload-sarif: false
```

> Grant the two extra scopes whenever `upload-sarif` is `true`. Because the reusable no longer declares them itself, forgetting them no longer fails the run at startup — the scan runs and gates as normal and only the upload step 403s, which is easy to miss.

### SOPS audit

```yaml
name: SOPS audit
on: [push, pull_request]
jobs:
  audit:
    uses: nkg/github-actions/.github/workflows/sops-audit.yml@v2
    with:
      encrypted-glob: '*.encrypted'
      shellcheck: true
      sops-config-changelog: true
      runs-on: '["self-hosted", "linux", "x64"]'
```

### Lint workflows

```yaml
name: Lint workflows
on:
  push:
    paths: ['.github/workflows/**', '.github/actions/**']
  pull_request:
    paths: ['.github/workflows/**', '.github/actions/**']
jobs:
  lint:
    uses: nkg/github-actions/.github/workflows/lint-workflows.yml@v2
    with:
      # actionlint's bundled action metadata trails behind upstream.
      # See sproncy-distillery/.github/workflows/lint-workflows.yml for context.
      actionlint-ignore: |
        input "client-id" is not defined in action "actions/create-github-app-token
        missing input "app-id" which is required by action "actions/create-github-app-token
```

---

## Bot / automation

### Claude on-demand (`@claude` bot)

Consumer stub — secrets must be declared explicitly because the upstream
action runs against your token. The top-level `permissions:` block is
**required** because the called workflow can't widen permissions beyond
what the caller granted (and the org default is read-only on contents):

```yaml
name: Claude
on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned]
  pull_request_review:
    types: [submitted]
permissions:
  contents: read
  pull-requests: read
  issues: read
  id-token: write
  actions: read
jobs:
  claude:
    uses: nkg/github-actions/.github/workflows/claude.yml@v2
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### Claude code review on every PR

Note: `claude-code-action@v2` self-validates that the workflow file on
the PR matches the version on the default branch. On the PR that first
introduces this wrapper, expect one "Workflow validation failed"
failure — it's safe to ignore (the action's own message says so) and
subsequent PRs will be green. Add a `paths-ignore` on the wrapper file
so benign edits to it don't fail the same check.

```yaml
name: Claude code review
on:
  pull_request:
    types: [opened, synchronize, ready_for_review, reopened]
    paths-ignore:
      - ".github/workflows/claude-code-review.yml"
permissions:
  contents: read
  pull-requests: write   # required to post review comments
  issues: write          # required if reviewer ever opens issues
  id-token: write
jobs:
  review:
    uses: nkg/github-actions/.github/workflows/claude-code-review.yml@v2
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Pass a repo-specific prompt + restricted gh-tools allow-list:

```yaml
jobs:
  review:
    uses: nkg/github-actions/.github/workflows/claude-code-review.yml@v2
    with:
      prompt: |
        REPO: ${{ github.repository }}
        PR NUMBER: ${{ github.event.pull_request.number }}

        Please review this pull request and provide feedback on …
      claude-args: '--allowed-tools "Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"'
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Filter to first-time contributors only:

```yaml
jobs:
  review:
    uses: nkg/github-actions/.github/workflows/claude-code-review.yml@v2
    with:
      filter-first-time-only: true
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### Auto-assign new issues + PRs

```yaml
name: Auto-assign
on:
  issues:
    types: [opened]
  pull_request:
    types: [opened]
jobs:
  assign:
    uses: nkg/github-actions/.github/workflows/auto-assign.yml@v2
    with:
      assignees: nkg
```

### Dependabot auto-merge

Pairs with a `dependabot.yml` config — merges patch/minor bumps automatically once required checks pass. Major bumps are gated.

There are two trigger styles; pick by plan.

**Team / Enterprise (native auto-merge):** the default. Triggers on `pull_request` and uses `gh pr merge --auto`, which queues the merge until required checks pass.

```yaml
name: Dependabot auto-merge
on:
  pull_request:
jobs:
  merge:
    uses: nkg/github-actions/.github/workflows/dependabot-auto-merge.yml@v2
    # Defaults: squash strategy, skip major bumps, use-auto-merge: true.
    # with:
    #   merge-strategy: rebase
    #   auto-merge-major: true
```

**Free plan (`workflow_run` immediate-merge):** GitHub restricts native auto-merge to Team/Enterprise on **private** repos, so `--auto` can't work there. Instead, trigger *after* your CI workflow completes and set `use-auto-merge: false` — the workflow finds the Dependabot PR for that run and merges it immediately (CI already passed). Replace `CI` with the exact `name:` of your CI workflow.

```yaml
name: Dependabot auto-merge
on:
  workflow_run:
    workflows: [CI]
    types: [completed]
jobs:
  merge:
    # workflow_run runs with the repo default token; if that's read-only
    # (the safe org default), grant write here so the reusable can merge.
    permissions:
      contents: write
      pull-requests: write
    uses: nkg/github-actions/.github/workflows/dependabot-auto-merge.yml@v2
    with:
      use-auto-merge: false
```

The `if:` guard (Dependabot actor + successful run) lives inside the reusable, so the stub stays this small. Major-bump gating on this path is best-effort from the PR title: **grouped** updates can't be classified from the title and are treated as non-major. Keep majors manual where that matters, or set `auto-merge-major: true` to merge them too.

### Dependabot uv lockfile

When Dependabot bumps a `uv` dependency, regenerate `uv.lock` on the PR branch so the resolved graph stays in sync. The actor guard lives in the reusable; the stub just supplies the trigger and `contents: write` (Dependabot runs get a read-only token by default). Pass `directories` for a monorepo with one lockfile per subproject.

```yaml
name: Update uv lockfiles for Dependabot
on:
  pull_request:
    types: [opened, synchronize]
permissions:
  contents: write
jobs:
  update-lockfile:
    uses: nkg/github-actions/.github/workflows/dependabot-uv-lockfile.yml@v2
    with:
      directories: |
        sproncy-api
        sproncy-blend
        sproncy-ml
```

A push made with `GITHUB_TOKEN` does not re-trigger workflows, so this keeps the lockfile correct without looping. For a single-package repo, omit `directories` (defaults to the repo root).

### Auto-revert when main CI fails

For repos that can't use branch protection (private repos on the free plan). When CI on `main` fails after a merge, opens a revert PR so `main` can be restored quickly. Does **not** auto-merge — review the revert PR and either merge it (revert) or close it (fix-forward).

The `workflow_run` trigger and the if-guard live in the caller because GitHub only evaluates `workflow_run` events on the default-branch copy of the workflow file. Replace `CI` below with the exact `name:` of your repo's main CI workflow.

```yaml
name: Auto-revert when main CI fails
on:
  workflow_run:
    workflows: [CI]
    types: [completed]
jobs:
  revert:
    if: |
      github.event.workflow_run.conclusion == 'failure' &&
      github.event.workflow_run.head_branch == 'main' &&
      github.event.workflow_run.event == 'push'
    permissions:
      contents: write
      pull-requests: write
    uses: nkg/github-actions/.github/workflows/auto-revert-on-main-failure.yml@v2
    with:
      bad-sha: ${{ github.event.workflow_run.head_sha }}
      failed-run-url: ${{ github.event.workflow_run.html_url }}
```

**Client-side complement:** `auto-revert` reacts *after* bad code lands. Pair
it with a `pre-push` git hook that runs the same checks CI runs, so broken
code never reaches `origin` in the first place. See
[`pre-push-hook.md`](pre-push-hook.md) for the portable pattern (lefthook +
per-stack command table).

### Stale run cleanup

Cancels **superseded** queued runs — older queued runs for a `(workflow, branch)` that already has a newer run — so re-pushes/rebases don't stack up on a shared (self-hosted) runner pool. A `concurrency:` block on each workflow is the first line of defence (cancels at push time); this scheduled sweep is the safety net for runs that slipped through (e.g. created before the block existed, or across different workflows).

It cancels by **supersession, never by age alone** — a run that's merely waiting on a busy runner is left to run its turn.

```yaml
name: Stale run cleanup
on:
  schedule:
    - cron: '*/20 * * * *'   # every 20 min
  workflow_dispatch:
jobs:
  cleanup:
    uses: nkg/github-actions/.github/workflows/stale-run-cleanup.yml@v2
    # with:
    #   min-age-minutes: 5     # grace period before a superseded run is cancelled
    #   dry-run: true          # log only
    #   runs-on: '["ubuntu-latest"]' # if your self-hosted pool is saturated, keep
    #                                # this on a hosted/maintenance runner or the
    #                                # cleanup job queues behind the backlog it clears.
```

### PR labeler (`actions/labeler`)

Not shipped as a reusable — every repo's label taxonomy is different, so the per-repo `.github/labeler.yml` config is the whole point and a wrapper would add nothing. Drop this stub into the consumer and adjust the config below.

`.github/workflows/labeler.yml`:

```yaml
name: Pull request labeler
on:
  # pull_request_target is required if you want to label PRs from forks.
  # Public Sproncy repos with external contributors should use it; for
  # internal-only repos, pull_request is fine and safer.
  pull_request:
permissions:
  contents: read
  pull-requests: write
jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/labeler@v5
```

`.github/labeler.yml` (the per-repo config the action consumes):

```yaml
frontend:
  - changed-files:
      - any-glob-to-any-file:
          - 'web/**'
          - 'apps/web/**'
backend:
  - changed-files:
      - any-glob-to-any-file:
          - 'api/**'
          - 'lib/**'
ci:
  - changed-files:
      - any-glob-to-any-file:
          - '.github/**'
docs:
  - changed-files:
      - any-glob-to-any-file:
          - 'docs/**'
          - '**/*.md'
```

---

## Monorepo / specialty

### Turborepo (Bun)

```yaml
name: CI
on: [push, pull_request]
jobs:
  build:
    uses: nkg/github-actions/.github/workflows/turbo.yml@v2
    with:
      turbo-tasks: "lint type-check test build"
      turbo-filter: "@my-org/web @my-org/api"
```

Combine with `dorny/paths-filter` in your stub for per-app change detection:

```yaml
on: [push, pull_request]
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      web: ${{ steps.f.outputs.web }}
      api: ${{ steps.f.outputs.api }}
    steps:
      - uses: actions/checkout@v6
      - id: f
        uses: dorny/paths-filter@v4
        with:
          filters: |
            web: ['apps/web/**', 'packages/**']
            api: ['apps/api/**', 'packages/**']
  web:
    needs: changes
    if: needs.changes.outputs.web == 'true'
    uses: nkg/github-actions/.github/workflows/turbo.yml@v2
    with:
      turbo-tasks: "lint type-check test build"
      turbo-filter: "@my-org/web"
```

### Molecule (Ansible role tests)

Collapses the per-role-job pattern into one matrix:

```yaml
name: Molecule
on: [push, pull_request]
jobs:
  molecule:
    uses: nkg/github-actions/.github/workflows/molecule.yml@v2
    with:
      roles: |
        common
        docker
        crowdsec
        restic
        trivy
      roles-dir: ansible/roles
```

### TOML lint

```yaml
name: TOML lint
on: [push, pull_request]
jobs:
  toml:
    uses: nkg/github-actions/.github/workflows/toml-lint.yml@v2
```

### Bats + shellcheck

```yaml
name: Bash tests
on: [push, pull_request]
jobs:
  bash:
    uses: nkg/github-actions/.github/workflows/bats.yml@v2
    with:
      test-paths: tests/
      # Auto-detects scripts/ + tests/ + bin/ when shellcheck-paths is empty
```

Pinning bats and customising shellcheck scope:

```yaml
jobs:
  bash:
    uses: nkg/github-actions/.github/workflows/bats.yml@v2
    with:
      bats-version: "1.11.0"
      test-paths: "tests/sops tests/restore"
      shellcheck-paths: "scripts lib"
      shellcheck-args: "-x --source-path=SCRIPTDIR -e SC2034"
```

---

## Composite actions

### SOPS-decrypt during a custom job

```yaml
name: Deploy
on: [workflow_dispatch]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: nkg/github-actions/.github/actions/setup-sops@v2
        with:
          age-key: ${{ secrets.SOPS_AGE_KEY }}
          decrypt-file: secrets.enc.yaml
      - run: ./scripts/deploy.sh
```

### Private-deps fetch via GitHub App

For repos that depend on private Sproncy modules (uv `git+`, hex from a
private repo, go modules behind a proxy):

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: nkg/github-actions/.github/actions/setup-deps-reader@v2
        with:
          app-client-id: ${{ vars.DEPS_READER_CLIENT_ID }}
          app-private-key: ${{ secrets.DEPS_READER_PRIVATE_KEY }}
          repositories: sproncy-schemas,sproncy-secrets-core
      - uses: astral-sh/setup-uv@v7
      - run: uv sync --frozen
```

### Pinned Trivy / cosign for custom steps

```yaml
jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: nkg/github-actions/.github/actions/setup-trivy@v2
      - run: trivy fs --severity HIGH,CRITICAL .

  sign:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: nkg/github-actions/.github/actions/setup-cosign@v2
      - run: cosign sign --yes ghcr.io/nkg/api@sha256:...
```

### mise (pinned dev toolchain) for a custom job

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: nkg/github-actions/.github/actions/setup-mise@v2   # runs `mise install` from .mise.toml
      - run: mise run build
```

### Go toolchain for a custom job

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: nkg/github-actions/.github/actions/setup-go@v2
        with:
          go-version: "1.23"
      - run: go build ./...
```

### Mint a GitHub App token

`setup-token` mints a short-lived App installation token (e.g. to push
commits that re-trigger workflows, or call the API as the App). Scope it
to least privilege with the optional `permission-*` inputs:

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: nkg/github-actions/.github/actions/setup-token@v2
        id: token
        with:
          app-client-id: ${{ vars.APP_CLIENT_ID }}
          app-private-key: ${{ secrets.APP_PRIVATE_KEY }}
          permission-contents: write          # omit all permission-* for the installation's full set
      - uses: actions/checkout@v6
        with:
          token: ${{ steps.token.outputs.token }}
      - run: git push
```
