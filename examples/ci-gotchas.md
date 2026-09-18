# CI gotchas that cost real time

> Five platform behaviours that look like misconfiguration and are not. Each
> one was found the expensive way — by shipping a fix, watching it not work,
> and finding out why. They are written down here because the reasoning lives
> in scattered inline comments otherwise, and the next person re-derives it.

Each section is: **what you see**, **why**, **what to do**.

---

## 1. `cancel-in-progress: false` does not protect queued runs

**What you see.** You want every commit on `main` to get its own CI run, so you
write the idiom everyone writes:

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
```

Bursts of two merges behave. Bursts of three or more silently lose the middle
commits — no run, no failure, nothing to notice.

**Why.** `cancel-in-progress` governs only the run that is *already executing*.
A run that is **pending** is cancelled whenever a newer run joins the group,
regardless of what the flag says. From the workflow-syntax docs on
`concurrency.queue`:

> at most one job or workflow run can be `pending` in the concurrency group…
> any existing `pending` job or workflow run in the same group is canceled and
> replaced

So run A executes, B queues behind it, C arrives and evicts B. B never runs.

**What to do.** Do not try to protect the branch *inside* a shared group — keep
it out of one. Key the group on the SHA for the branch that matters, so every
commit gets a group of one that nothing can evict:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event_name }}-${{ github.ref }}-${{ github.ref == 'refs/heads/main' && github.sha || 'shared' }}
  cancel-in-progress: true
```

`queue: max` is the other documented answer (up to 100 pending, FIFO), but it
**cannot** be combined with `cancel-in-progress: true`, which PR runs still
want — that combination is a validation error.

Two related traps in the same area:

- `github.event_name` belongs in the group key whenever a workflow has both a
  `push` and a `schedule` (or `workflow_dispatch`) trigger. `github.ref` is
  `refs/heads/main` for all three, so without it the weekly sweep and a push to
  `main` evict each other.
- **Never** put `cancel-in-progress` on a workflow triggered by `workflow_run`,
  `issue_comment`, `issues` or `pull_request_review`. `github.ref` is the
  *default branch* for those events, so a shared group makes runs for unrelated
  PRs cancel each other. `pull_request` is safe — there `github.ref` is the PR
  merge ref.

**Decide per workflow whether cancelling is safe at all.** A HEAD-state check
(lint, a Trivy filesystem scan) loses nothing when a superseded run is dropped.
A workflow that publishes an artefact per commit, or whose *conclusion* something
downstream reads, does.

---

## 2. `GITHUB_TOKEN` can never write `.github/workflows/`

**What you see.** A job that pushes a branch fails with:

```
refusing to allow a GitHub App to create or update workflow
.github/workflows/ci.yml without `workflows` permission
```

You go looking for the `permissions:` key to add. There isn't one.

**Why.** `GITHUB_TOKEN` is issued by GitHub's own built-in Actions App, and it
is categorically forbidden from creating or updating anything under
`.github/workflows/`. `workflows` is **not** among the grantable
`permissions:` scopes, so no amount of configuration fixes it. This is a
platform rule, not a setting you missed.

**What to do.** Either avoid pushing workflow files from Actions, or push with a
different credential — a GitHub App installation token whose installation has
**Workflows: read and write** (see `setup-token`'s `permission-workflows`
input), or a fine-grained PAT with the same.

Use a **dedicated** App if you go that way. A credential that can rewrite
workflow files can rewrite CI itself, so it wants its own key, its own
installation, and only the repos that need it — not a shared one like a
read-only deps-reader whose private key already sits in every repo's secrets.

And handle the case gracefully rather than failing: detect it up front and open
an issue, so the underlying problem is still surfaced instead of being buried
under a second red check that reads like a setup error. See
`auto-revert-on-main-failure.yml` for the pattern.

---

## 3. Actions cannot open a pull request until you tick a box

**What you see.**

```
pull request create failed: GraphQL: GitHub Actions is not permitted
to create or approve pull requests (createPullRequest)
```

Confusingly, this can differ *per repository* inside one organisation, so the
same workflow works in one repo and not its neighbour.

**Why.** Settings → Actions → General → Workflow permissions → *Allow GitHub
Actions to create and approve pull requests*. It is off by default, and the
repo-level value overrides the org-level one.

**What to do.**

```bash
gh api repos/OWNER/REPO/actions/permissions/workflow \
  -q '.can_approve_pull_request_reviews'          # check

gh api -X PUT repos/OWNER/REPO/actions/permissions/workflow \
  -F can_approve_pull_request_reviews=true \
  -f default_workflow_permissions=read            # enable
```

Enable it only on repos that actually run a workflow which opens a PR —
granting it elsewhere is dead privilege. The same flag also permits Actions to
*approve* PRs, which matters if you rely on review approval as a gate; on the
Free plan, where branch protection is unavailable anyway, it is not gating
anything.

---

## 4. `git diff-tree -r <sha>` lists nothing for a merge commit

**What you see.** A path check over a commit's changed files that works when you
test it by hand and never fires in CI.

**Why.** `git diff-tree --no-commit-id --name-only -r <sha>` returns **zero
paths** for a merge commit, because a merge is diffed against multiple parents
and the default output suppresses it. Anything reacting to merges into `main` is
looking at merge commits almost every time.

**What to do.** Diff against the first parent, which is correct for both merge
and ordinary commits:

```bash
changed=$(git diff --name-only "${SHA}^1" "$SHA")
```

Verify against a real merge before trusting it:

```bash
m=$(git rev-list --merges -n1 origin/main)
git diff-tree --no-commit-id --name-only -r "$m" | wc -l   # 0
git diff --name-only "${m}^1" "$m" | wc -l                 # the real answer
```

---

## 5. What the Free plan quietly withholds

Private repos on the GitHub **Free** plan lack several things CI commonly
assumes. None of these produce a message that names the plan.

| Missing | How it shows up | What to do |
|---|---|---|
| Branch protection / rulesets | Nothing stops a red merge to `main` | `auto-revert-on-main-failure.yml` plus the `pre-push-hook.md` pattern |
| Organisation secrets for private repos | Secret resolves to empty string; e.g. `create-github-app-token` fails with *"The 'private-key' input must be set to a non-empty string"* | Add the secret at **repository** level |
| A separate Dependabot secret store | Same empty-string failure, but **only** on `dependabot/**` branches | Add it again with `gh secret set NAME --app dependabot` |
| GitHub Advanced Security | `Advanced Security must be enabled for this repository to use code scanning` on SARIF upload, while the scan itself passes | Pass `upload-sarif: false` (`trivy-repo.yml`, `container-security.yml`, `docker-build.yml`) |

The Dependabot one is worth restating because it surprises people twice: a
Dependabot-triggered run reads a **different secret store** from Actions. A
repository secret that works perfectly for every other workflow is invisible to
Dependabot's, and the failure looks identical to having no secret at all.

---

## 6. Higher scanner recall looks like a regression

**What you see.** A repo that has scanned clean for months starts failing its
secret scan, with no relevant change to the code.

**Why.** `secret-scan.yml` moved from gitleaks to betterleaks in v3.
betterleaks reports roughly 98.6% against CredData where gitleaks reported
roughly 70.4%. Higher recall means a repo that scanned clean can stop scanning
clean — that is the swap working, not a regression. It surfaces one repo at a
time, as each repo's next push to `main` runs the scan.

Typically what it finds is placeholders: `user:pass@host` in docs,
`change_me_*` in `.env.example`, fixtures deliberately shaped to look real so a
test can exercise the "operator replaced the placeholder" branch.

**What to do.** Add a repo-root `.gitleaks.toml` — betterleaks auto-detects it,
no workflow change needed:

```toml
[extend]
useDefault = true

[allowlist]
description = "Placeholder and fixture credentials, matched by exact value"
regexTarget = "secret"
regexes = [
  '''^change_me_[a-z]+$''',
  '''^pass$''',
]
```

Match **exact values, anchored**, via `regexTarget = "secret"`. Do **not**
allowlist the files or directories they live in, which is the usual shortcut —
that permanently hides a real credential committed to the same test file or the
same `.env.example`. Do not reach for `fail-on-finding: false` either.

Verify before pushing, rather than pushing and hoping:

```bash
betterleaks git .        # must print "no leaks found"
```

Then prove the allowlist is not over-broad, by planting a freshly generated
random credential in one of the allowlisted files and confirming it is **still**
caught. A value-scoped allowlist passes that test; a path-scoped one does not.

Finally, check each finding at **its own commit** — the scan covers history, so
the line numbers in the report refer to the commit that introduced it, not to
`HEAD`:

```bash
betterleaks git . --report-format json --report-path /tmp/leaks.json
```

Group by distinct secret value before judging: 25 findings are often five
placeholders repeated.
