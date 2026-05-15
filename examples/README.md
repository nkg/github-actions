# Consumer examples

Drop these into `.github/workflows/*.yml` of a consumer repo. Replace
`sproncy/.github-actions@v1` with a SHA when you need bit-for-bit pinning.

## Python (uv)

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
jobs:
  test:
    uses: sproncy/.github-actions/.github/workflows/python-uv.yml@v1
    with:
      python-version: "3.12"
    secrets: inherit
```

## Node (Bun) monorepo package

```yaml
name: CI
on: [push, pull_request]
jobs:
  web:
    uses: sproncy/.github-actions/.github/workflows/node-bun.yml@v1
    with:
      working-directory: apps/web
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
    uses: sproncy/.github-actions/.github/workflows/elixir.yml@v1
    with:
      otp-version: ${{ matrix.otp }}
      elixir-version: ${{ matrix.elixir }}
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
    uses: sproncy/.github-actions/.github/workflows/opentofu.yml@v1
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
    uses: sproncy/.github-actions/.github/workflows/docker-build.yml@v1
    with:
      image-name: ${{ github.repository }}
      platforms: linux/amd64,linux/arm64
      push: ${{ github.event_name != 'pull_request' }}
```

## Ansible

```yaml
name: CI
on: [push, pull_request]
jobs:
  ansible:
    uses: sproncy/.github-actions/.github/workflows/ansible.yml@v1
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
    uses: sproncy/.github-actions/.github/workflows/go.yml@v1
    with:
      go-version: "1.23"
      run-staticcheck: true
      run-govulncheck: true
```

## Scrapy

```yaml
name: CI
on: [push, pull_request]
jobs:
  scrapy:
    uses: sproncy/.github-actions/.github/workflows/scrapy.yml@v1
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
    uses: sproncy/.github-actions/.github/workflows/fastapi.yml@v1
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
    uses: sproncy/.github-actions/.github/workflows/compose-validate.yml@v1
    with:
      compose-file: docker-compose.yml
      profiles: |
        logs
        alerts
        tracing
      env-vars: |
        GRAFANA_ADMIN_PASSWORD=ci-validate
      runs-on: '[self-hosted, linux, x64]'
```

## Komodo deploy

```yaml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  komodo:
    uses: sproncy/.github-actions/.github/workflows/komodo-deploy.yml@v1
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
    uses: sproncy/.github-actions/.github/workflows/secret-scan.yml@v1
    with:
      runs-on: '[self-hosted, linux, x64]'
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
    uses: sproncy/.github-actions/.github/workflows/container-security.yml@v1
    with:
      compose-file: docker-compose.yml
      runs-on: '[self-hosted, linux, x64]'
```

Or scan an explicit list:

```yaml
jobs:
  trivy:
    uses: sproncy/.github-actions/.github/workflows/container-security.yml@v1
    with:
      image-list: |
        ghcr.io/sproncy/api:latest
        ghcr.io/sproncy/web:latest
```

### SOPS audit

```yaml
name: SOPS audit
on: [push, pull_request]
jobs:
  audit:
    uses: sproncy/.github-actions/.github/workflows/sops-audit.yml@v1
    with:
      encrypted-glob: '*.encrypted'
      shellcheck: true
      sops-config-changelog: true
      runs-on: '[self-hosted, linux, x64]'
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
    uses: sproncy/.github-actions/.github/workflows/lint-workflows.yml@v1
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
action runs against your token:

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
jobs:
  claude:
    uses: sproncy/.github-actions/.github/workflows/claude.yml@v1
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### Claude code review on every PR

```yaml
name: Claude code review
on:
  pull_request:
    types: [opened, synchronize, ready_for_review, reopened]
jobs:
  review:
    uses: sproncy/.github-actions/.github/workflows/claude-code-review.yml@v1
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

Filter to first-time contributors only:

```yaml
jobs:
  review:
    uses: sproncy/.github-actions/.github/workflows/claude-code-review.yml@v1
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
    uses: sproncy/.github-actions/.github/workflows/auto-assign.yml@v1
    with:
      assignees: nkg
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
      - uses: actions/checkout@v4
      - uses: sproncy/.github-actions/.github/actions/setup-sops@v1
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
      - uses: actions/checkout@v4
      - uses: sproncy/.github-actions/.github/actions/setup-deps-reader@v1
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
      - uses: actions/checkout@v4
      - uses: sproncy/.github-actions/.github/actions/setup-trivy@v1
      - run: trivy fs --severity HIGH,CRITICAL .

  sign:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: sproncy/.github-actions/.github/actions/setup-cosign@v1
      - run: cosign sign --yes ghcr.io/sproncy/api@sha256:...
```
