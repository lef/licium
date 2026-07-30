#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-adapter-ownership.sh"
auth_source="$script_dir/adapters/oidc-provider-v1/authenticate.mjs"
map_source="$script_dir/adapters/oidc-provider-v1/map-request.mjs"
subject_source="$script_dir/adapters/oidc-provider-v1/subject-policy.mjs"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q ADAPTER_TOKEN_OWNERSHIP_BOUNDARY_VALID "$tmp/baseline.out"
then
    echo PI_N02_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

{
    printf '%s\n' \
        "import { createHmac } from 'node:crypto';" \
        "import { writeFileSync } from 'node:fs';"
    awk '
        {
            print
            if ($0 ~ /PI_N01_REACHABLE_INSERTION_POINT/) {
                print "  const mutantSignature = createHmac('\''sha256'\'', '\''mutant-token-signing-key'\'').update('\''mutant-header.mutant-payload'\'').digest('\''base64url'\'');"
                print "  writeFileSync(process.env.PI_N02_REACHABILITY_MARKER, `mutant-header.mutant-payload.${mutantSignature}\\n`, { encoding: '\''utf8'\'' });"
            }
        }
    ' "$auth_source"
} >"$tmp/mutant.mjs"

set +e
PI_N02_REACHABILITY_MARKER="$tmp/reached.jwt" \
LICIUM_AUTH_BACKEND_COMMAND="$script_dir/auth-backend-v1.sh" \
LICIUM_AUTH_BACKEND_PROVIDER=sqlite-provider-v1 \
    "$node" "$script_dir/invoke-adapter-pi-n02.mjs" "$tmp/mutant.mjs" \
    >"$tmp/invoke.out" 2>"$tmp/invoke.err"
invoke_status=$?
set -e
[ "$invoke_status" -eq 0 ] || {
    cat "$tmp/invoke.err" >&2
    echo PI_N02_MUTANT_INVOCATION_FAILED >&2
    exit 1
}
[ -s "$tmp/reached.jwt" ] &&
    awk -F. 'NF == 3 { found = 1 } END { exit !found }' "$tmp/reached.jwt" &&
    grep -F -x -q PI_N02_MUTANT_REACHED "$tmp/invoke.out" &&
    [ ! -s "$tmp/invoke.err" ] || {
    echo PI_N02_MUTANT_NOT_REACHED >&2
    exit 1
}

set +e
"$verifier" "$tmp/mutant.mjs" "$map_source" "$subject_source" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N02_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c ADAPTER_OWNS_TOKEN "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N02_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N02_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N02 class=static/runtime mutation=reachable-hmac-token-signing inner_status=$inner_status marker=ADAPTER_OWNS_TOKEN marker_count=1 target_gate=yes reachability=dynamic-valid-authentication" \
    'ok PI-N02' \
    'PI_N02_SELF_TEST_VALID 1 baseline 1 control'
