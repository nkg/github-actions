# ci

Centralised reusable GitHub Actions workflows and composite actions.

## Layout

```
.github/
├── workflows/        # reusable workflows (callable via `uses:`)
│   ├── python-uv.yml
│   ├── node-bun.yml
│   ├── elixir.yml
│   ├── expo.yml
│   ├── opentofu.yml
│   ├── ansible.yml
│   ├── docker-build.yml
│   └── self-test.yml # runs on push to validate this repo
└── actions/          # composite actions (callable via `uses:` from steps)
    ├── setup-mise/
    └── setup-sops/
```

## Versioning

Workflows are consumed by tag. Tags follow `vMAJOR.MINOR.PATCH` and a
floating `vMAJOR` tag tracks the latest non-breaking release on that line.

- Pin to `@v1` for low-friction updates within a major version.
- Pin to `@v1.4.2` (or a SHA) when you need bit-for-bit reproducibility.

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
    uses: <org>/ci/.github/workflows/python-uv.yml@v1
    with:
      python-version: "3.12"
      working-directory: "."
    secrets: inherit
```

`secrets: inherit` is the quickest path; for tighter scoping, declare
secrets explicitly in the consumer and pass them through `secrets:`.

## Consuming a composite action

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: <org>/ci/.github/actions/setup-mise@v1
  - run: mise run build
```

## Available reusable workflows

| Workflow             | Purpose                                                        |
|----------------------|----------------------------------------------------------------|
| `python-uv.yml`      | uv-based Python: ruff, mypy, pytest with coverage              |
| `node-bun.yml`       | Bun-based Node/TS: install, lint, typecheck, test, build       |
| `elixir.yml`         | Mix: deps, format check, credo, test (matrix on otp/elixir)    |
| `expo.yml`           | Expo/RN: install, lint, typecheck, optional EAS build          |
| `opentofu.yml`       | OpenTofu: fmt, init, validate, plan (apply gated by env)       |
| `ansible.yml`        | ansible-lint + syntax check                                    |
| `docker-build.yml`   | buildx multi-arch build + push to GHCR                         |

## Available composite actions

| Action          | Purpose                                                            |
|-----------------|--------------------------------------------------------------------|
| `setup-mise`    | Installs mise and runs `mise install` (caches the tool dir)        |
| `setup-sops`    | Installs sops + age, optionally decrypts a file with a private key |

## Self-hosted runners

Every reusable workflow accepts a `runs-on` input (default `ubuntu-latest`).
Pass `runs-on: self-hosted` (or a label like `self-hosted,linux,x64`) to
route to your own runner pool.

## Updating actions

Renovate is configured (`renovate.json`) to bump pinned actions automatically.
Consumers should also enable Renovate to keep their pin to this repo
(`<org>/ci`) up to date.

## Releasing

Tag-based. From `main`:

```
git tag -a v1.2.0 -m "Release v1.2.0"
git tag -fa v1     -m "Track v1.2.0"
git push origin v1.2.0
git push origin v1 --force
```

The `release.yml` workflow handles the floating major-tag move automatically
when a `vMAJOR.MINOR.PATCH` tag is pushed.
# .github-actions
