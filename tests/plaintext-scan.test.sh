#!/usr/bin/env bash
#
# Test the plaintext-secret scan in .github/workflows/sops-audit.yml.
#
# This workflow is consumed by every repo in the org through a floating @v2
# tag, so a change here reaches all of them at once. The allowlist added for
# issue #74 can only ever make the scan LESS sensitive, which is exactly the
# direction that fails silently — a scan that stops detecting reports success.
#
# So: the fixtures below are half true-positives that must still fail. If the
# allowlist is ever widened carelessly, those go green and this test goes red.
#
# The patterns are extracted FROM the workflow rather than restated here.
# A copy would drift, and a drifted test proves nothing about what runs.
# SC2153/SC2154: KEY/SEP/Q/ENUMS come from the eval below, which shellcheck
#   cannot follow — that indirection is the point, so the test cannot drift
#   from the workflow it is testing.
# SC2016: the fixtures deliberately contain literal $VAR and ${VAR}. Single
#   quotes are correct; expanding them would destroy the case under test.
# shellcheck disable=SC2153,SC2154,SC2016

set -uo pipefail

WF=".github/workflows/sops-audit.yml"
[ -f "$WF" ] || { echo "run from the repo root" >&2; exit 1; }

# Pull the four assignments out of the run: block verbatim.
eval "$(grep -E "^ +(KEY|SEP|Q|ENUMS)=" "$WF" | sed 's/^ *//')"

pattern="${KEY}${SEP}${Q}[A-Za-z0-9/_+.=-]{8,}"
IND="${KEY}${SEP}${Q}([{][{]|[$][{]|[$][A-Za-z_]|ENC[[]|!vault|lookup[(])"
ENUM="${KEY}${SEP}${Q}(${ENUMS})${Q}[[:space:]]*(#.*)?$"

scan() {  # 0 = flagged, 1 = clean
  printf '%s\n' "$1" \
    | grep -E -i "$pattern" \
    | grep -v -E -i "$IND" \
    | grep -v -E -i "$ENUM" \
    | grep -q .
}

pass=0; fail=0
check() { # <expect flag|clean> <label> <line>
  if [ "$1" = flag ]; then scan "$3" && r=flag || r=clean
  else scan "$3" && r=flag || r=clean; fi
  if [ "$r" = "$1" ]; then pass=$((pass+1)); printf '  ok    %-9s %s\n' "$1" "$2"
  else fail=$((fail+1)); printf '  FAIL  want=%-5s got=%-5s %s\n' "$1" "$r" "$2" >&2; fi
}

echo "── must still be caught (real secrets) ──"
check flag "plain password"        'password: hunter2hunter2'
check flag "aws access key"        'api_key: "AKIAIOSFODNN7EXAMPLE"'
check flag "aws secret w/ slashes" 'secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
check flag "github token"          'token: ghp_abcdefghijklmnopqr'
check flag "base64 private key"    'private_key: "MIIEowIBAAKCAQEA+xyz/abc=="'
check flag "equals form"           'password=SuperSecret12345'
check flag "changeme NOT allowed"  'password: changeme'
check flag "placeholder NOT allowed" 'password: placeholder'
check flag "enum-ish but longer"    'password: alwaysontop123'

echo "── must now be allowed (cannot be a secret) ──"
check clean "ansible enum"         'update_password: on_create'
check clean "jinja template"       'password: "{{ vault_db_password }}"'
check clean "env expansion"        'api_key: ${API_KEY}'
check clean "bare env var"         'token: $GITHUB_TOKEN'
check clean "ansible vault ref"    'password: !vault |'
check clean "lookup"               'password: lookup(''env'', ''PW'')'
check clean "sops ciphertext"      'password: ENC[AES256_GCM,data:Rk2UTxoS4vuLpZ]'
check clean "boolean"              'token: true'
check clean "enum with comment"    'password: never   # policy'
check clean "quoted enum"          'secret: "disabled"'

echo "── unrelated prose must stay clean ──"
check clean "prose"                '# this is a token for the API'
check clean "short value"          'password: abc'

echo
if [ "$fail" -eq 0 ]; then echo "plaintext-scan.test.sh: $pass passed"; exit 0; fi
echo "plaintext-scan.test.sh: $fail FAILED, $pass passed" >&2; exit 1
