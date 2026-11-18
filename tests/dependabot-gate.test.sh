#!/usr/bin/env bash
#
# Test the merge gate in .github/workflows/dependabot-auto-merge.yml.
#
# The gate decides whether a Dependabot PR may merge, for every caller that
# passes `required-workflows`. A gate that wrongly says "proceed" merges a PR
# whose CI failed or hasn't finished, which is exactly what this input exists
# to prevent, and nothing else would catch it.
#
# The gate's `run:` block is extracted FROM the workflow and run verbatim
# against a fake `gh`, so this test cannot drift from what runs.
#
# Run from the repo root: ./tests/dependabot-gate.test.sh

set -uo pipefail

WF=".github/workflows/dependabot-auto-merge.yml"
[ -f "$WF" ] || { echo "run from the repo root" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The block under `id: check`'s `run: |`, up to and including its last line,
# with the step's indentation removed.
awk '
  /id: check/ { in_step = 1 }
  in_step && /^ *run: \|/ { in_run = 1; next }
  in_run {
    print
    if ($0 ~ /proceed=\$proceed/) exit
  }
' "$WF" | sed 's/^          //' > "$work/gate.sh"
# shellcheck disable=SC2016  # a literal $proceed, as written in the workflow
grep -q 'proceed=\$proceed' "$work/gate.sh" || { echo "could not extract the gate script" >&2; exit 1; }

# Fake gh: `gh api repos/R/actions/workflows/<wf>/runs?... --jq ...`.
# RUN_<wf with . and - as _> is what the query returns ("status conclusion",
# or empty for no run); the value FAIL makes the query itself fail.
mkdir -p "$work/bin"
cat > "$work/bin/gh" <<'GH'
#!/usr/bin/env bash
url="$2"
wf="${url#*/actions/workflows/}"; wf="${wf%%/runs*}"
var="RUN_$(printf '%s' "$wf" | tr '.-' '__')"
val="${!var-}"
[ "$val" = "FAIL" ] && { echo "HTTP 403" >&2; exit 1; }
[ -n "$val" ] && printf '%s\n' "$val"
exit 0
GH
chmod +x "$work/bin/gh"

pass=0 fail=0
# check <name> <expected proceed> <REQUIRED> <OPTIONAL> [VAR=value ...]
check() {
  local name="$1" want="$2" req="$3" opt="$4"; shift 4
  : > "$work/out"
  env -i PATH="$work/bin:/usr/bin:/bin" GITHUB_OUTPUT="$work/out" \
    REPO=o/r SHA=abc REQUIRED="$req" OPTIONAL="$opt" "$@" \
    bash "$work/gate.sh" > "$work/log" 2>&1
  local got
  got=$(sed -n 's/^proceed=//p' "$work/out")
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $name: proceed=${got:-<unset>}, want $want"
    sed 's/^/    /' "$work/log"
  fi
}

ok="completed success"

check "all required passed"            true  "ci.yml secret-scan.yml" "" RUN_ci_yml="$ok" RUN_secret_scan_yml="$ok"
check "newline-separated input"        true  $'ci.yml\n  secret-scan.yml\n' "" RUN_ci_yml="$ok" RUN_secret_scan_yml="$ok"
check "a required one failed"          false "ci.yml secret-scan.yml" "" RUN_ci_yml="completed failure" RUN_secret_scan_yml="$ok"
check "a required one still running"   false "ci.yml secret-scan.yml" "" RUN_ci_yml="in_progress -" RUN_secret_scan_yml="$ok"
check "a required one has no run yet"  false "ci.yml secret-scan.yml" "" RUN_ci_yml="$ok"
check "a required one was skipped"     false "ci.yml"                 "" RUN_ci_yml="completed skipped"
check "a required one was cancelled"   false "ci.yml"                 "" RUN_ci_yml="completed cancelled"
check "the query failed (fail closed)" false "ci.yml secret-scan.yml" "" RUN_ci_yml="$ok" RUN_secret_scan_yml=FAIL
check "an optional one has no run"     true  "ci.yml" "lint.yml"         RUN_ci_yml="$ok"
check "an optional one was skipped"    true  "ci.yml" "lint.yml"         RUN_ci_yml="$ok" RUN_lint_yml="completed skipped"
check "an optional one failed"         false "ci.yml" "lint.yml"         RUN_ci_yml="$ok" RUN_lint_yml="completed failure"
check "an optional one still running"  false "ci.yml" "lint.yml"         RUN_ci_yml="$ok" RUN_lint_yml="queued -"
check "a name that only prefixes one"  false "ci.yml" "ci.yml.bak"       RUN_ci_yml_bak="$ok"

echo "dependabot-gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
