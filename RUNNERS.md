# Runner selection

Which machine a job runs on, how to change it, and what must not move.

Two conventions exist, they default in **opposite directions**, and that is
deliberate. There is also one default that lives in this repo rather than in
the consumers.

---

## Why any of this exists

The self-hosted pool is small and shared across every org. Jobs that need
nothing from it — reading a diff, calling an API, linting — were queueing
behind jobs that genuinely need a real machine.

Measured on the `sproncy` pool before any of this landed:

| run created | job started | finished | queued | actually ran |
| ----------- | ----------- | -------- | ------ | ------------ |
| 19:37:04    | 20:54:07    | 20:59:14 | 77 min | 5m 07s       |
| 22:18:25    | 23:02:23    | 23:05:28 | 44 min | 3m 05s       |
| 17:25:19    | 18:26:13    | 18:29:42 | 61 min | 3m 29s       |

Long queues are the visible cost. The invisible ones were worse: reviews
posting *after* the PR had merged, where nothing surfaces the findings, and
jobs failing outright at runner assignment (`steps_run=0`) in roughly one run
in six.

---

## The three mechanisms

### 1. `runs-on` input on the reusables — see the README

Defaults and the JSON-array calling convention are documented in
[README.md](README.md#runner-strategy). The one thing to know here: as of
v3.4.0 `claude-code-review.yml` defaults to a GitHub-hosted image, while
`claude.yml` still defaults to the self-hosted pool.

The rest of this file covers the two **consumer-side** variables, which the
README does not describe because they live in the consuming repos rather than
in this one.

### 2. `RUNNER_POOL` — ordinary CI, defaults to **self-hosted**

```yaml
runs-on: ${{ fromJSON(vars.RUNNER_POOL || '["self-hosted","linux","x64"]') }}
```

Unset means today's behaviour. Setting the variable moves the repo.

**Why this way round:** the safe default is the status quo. A deleted or
mistyped variable degrades to self-hosted rather than somewhere surprising.

### 3. `DIND_POOL` — service-container jobs, defaults to **hosted**

```yaml
runs-on: ${{ fromJSON(vars.DIND_POOL || '["ubuntu-24.04"]') }}
```

**Why the other way round:** here hosted *is* the fix. Service containers are
native on hosted runners — the runner is itself a container on the same
network, so `services.<name>` resolves without DinD. The org has a single
`dind` runner shared across every repo, so the self-hosted path queues behind
whatever else wants it. Defaulting to self-hosted would preserve the fault.

The move is worth the asymmetry:

| job                                | before (self-hosted)  | after (hosted) |
| ---------------------------------- | --------------------- | -------------- |
| distillery `integration-test`      | 18m 36s               | 59s            |
| transcription `Integration tests`  | queued / cancelled    | 70s            |
| scrapers `Integration Tests`       | cancelled after 25m   | 6m 27s         |

---

## Flipping and reverting

Repo scope (preferred — narrow blast radius):

```bash
gh variable set    RUNNER_POOL --repo <owner>/<repo> --body '["ubuntu-24.04"]'
gh variable delete RUNNER_POOL --repo <owner>/<repo>     # back to self-hosted
```

Org scope (every repo in the org at once):

```bash
gh variable set RUNNER_POOL --org <owner> --visibility all --body '["ubuntu-24.04"]'
```

Repo variables take precedence over org variables, so a repo-level value wins.

**The value must be a valid JSON array.** `fromJSON` throws on anything else,
and because the expression repeats across jobs, one malformed variable fails
them all at runner assignment with an error that names no cause:

```
["ubuntu-24.04"]     correct
ubuntu-24.04         breaks every job using the variable
```

---

## Current state

Deliberately not tabulated here. A hand-maintained inventory of state that
lives in another system goes stale — in this fleet a version-pin table drifted
three times in two days, twice while the PR carrying it was open.

Read it instead:

```bash
# which repos consume a toggle. `gh search code` does NOT work here -- it does
# not index these private repos and returns an empty result rather than an
# error, which reads as "nothing uses it". Walk the workflows instead:
for repo in $(gh repo list <owner> --limit 100 --json nameWithOwner --jq '.[].nameWithOwner'); do
  for f in $(gh api "repos/$repo/contents/.github/workflows" --jq '.[].name' 2>/dev/null); do
    gh api "repos/$repo/contents/.github/workflows/$f" --jq '.content' 2>/dev/null \
      | base64 -d 2>/dev/null | grep -q "vars.RUNNER_POOL" && echo "$repo  $f"
  done
done

# what a repo or org is currently set to
gh api repos/<owner>/<repo>/actions/variables --jq '.variables[]|"\(.name)=\(.value)"'
gh api /orgs/<owner>/actions/variables        --jq '.variables[]|"\(.name)=\(.value)"'

# what a job actually ran on
gh api repos/<owner>/<repo>/actions/runs/<id>/jobs \
  --jq '.jobs[]|"\(.name)  \(.runner_name)"'
```

That last one is the only real answer. Everything else is intent.

---

## Deliberate exceptions — do not "fix" these

Four jobs are pinned to self-hosted on purpose. Flipping a toggle must not
drag them along, which is why each is hardcoded rather than parameterised.

| where                                                    | why                                                                                                                             |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `Regularmusic/web-platform` `deploy.yml`                 | Reaches Komodo on the home-lab network. A hosted runner cannot route there.                                                       |
| `sproncy/sproncy-secrets` `infisical-rotate.yml`         | Decrypts live secret material. On self-hosted that plaintext exists only on hardware we control.                                  |
| `sproncy/sproncy-secrets` `key-rotation.yml`             | Same. Both are scheduled or dispatched rather than per-push, so pinning costs almost no capacity — which is why it is worth spending here. |
| `sproncy/monitoring_stack` `claude-code-review.yml`      | Passes `runs-on` explicitly. An existing opt-out, not an oversight.                                                               |

---

## Gotchas found the hard way

**Pin the image, not the alias.** `ubuntu-latest` is floating — GitHub moves it
(24.04 today, 26.04 eventually). A dated label makes an image bump an
intentional, reviewable change instead of a silent environment shift mid-run.

**Not every ubuntu image is equivalent.** `ubuntu-22.04` ships Python 3.10,
which predates `tomllib`. A job relying on a system interpreter can pass on
`ubuntu-24.04` and fail on `ubuntu-22.04`. Check before pointing a variable at
an older image.

**Dependabot PRs get no repo secrets.** A job needing a secret fails at the
token step on a Dependabot PR regardless of runner. Scope the guard to the
event, not the actor:

```yaml
if: github.event_name != 'pull_request' || github.actor != 'dependabot[bot]'
```

Testing `github.actor` alone looks equivalent and is not: on a `schedule` run
the actor is `github-actions[bot]`, so a bare actor test silently changes
meaning between triggers.

**A concurrency guard written for shared hardware may outlive its reason.**
`web-platform`'s E2E jobs serialise on fixed ports 3001–3003 because
self-hosted jobs share a box. Hosted runners get an ephemeral VM each, so the
collision cannot happen — but the group is qualified by neither pool nor ref,
so it keeps serialising anyway. Drop or qualify it when flipping that repo.

**Hosted minutes are metered on private repos**, and each org has its own
allowance that cannot be pooled without an Enterprise plan. Check headroom
before moving a heavy suite:

```bash
gh api "/organizations/<owner>/settings/billing/usage?year=<y>&month=<m>" \
  --jq '[.usageItems[]|select(.product=="actions" and (.unitType|test("Minutes")))|.quantity]|add'
```

Note the `year`/`month` arguments. Without them the endpoint returns a
truncated page that looks like a complete per-repo breakdown and is not.
