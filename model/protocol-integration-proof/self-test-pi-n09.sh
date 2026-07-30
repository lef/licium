#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
engine="$script_dir/engine-selection/oidc-provider"
integration="$engine/integration"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

NODE="$node" "$script_dir/verify-forced-reauth.sh" \
    >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q \
        PN14_FORCED_REAUTHENTICATION_VALID "$tmp/baseline.out"
then
    echo PI_N09_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

mkdir -p "$tmp/proof/engine-selection/oidc-provider/integration"
cp -R "$script_dir/adapters" "$tmp/proof/adapters"
cp "$integration/server.mjs" \
    "$tmp/proof/engine-selection/oidc-provider/integration/server.mjs"
ln -s "$engine/node_modules" \
    "$tmp/proof/engine-selection/oidc-provider/node_modules"
selector="$tmp/proof/engine-selection/oidc-provider/integration/select-login-subject.mjs"
awk '
    $0 == "  return credentialBoundSubject;" {
        print "  return _engineSessionSubject ?? credentialBoundSubject;"
        changed = 1
        next
    }
    { print }
    END { exit !changed }
' "$integration/select-login-subject.mjs" >"$selector"

set +e
LICIUM_OIDC_SERVER_SOURCE="$tmp/proof/engine-selection/oidc-provider/integration/server.mjs" \
NODE="$node" \
    "$script_dir/run-oidc-integration.sh" \
    sqlite-provider-v1 forced-reauth \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N09_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c ENGINE_USER_OVERRIDE "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N09_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N09_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N09 class=runtime mutation=engine-decoy-overrides-credential-subject inner_status=$inner_status marker=ENGINE_USER_OVERRIDE marker_count=1 target_gate=yes reachability=actual-same-session-prompt-login guard=http-409 reauth_token_issued=no" \
    'ok PI-N09' \
    'PI_N09_SELF_TEST_VALID 1 baseline 1 control'
