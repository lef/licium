#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
engine="$script_dir/engine-selection/oidc-provider"
server="$engine/integration/server.mjs"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

NODE="$node" "$script_dir/verify-oi10.sh" \
    >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q \
        OI10_ALL_RUNTIME_SURFACES_NONLEAKAGE_VALID "$tmp/baseline.out"
then
    echo OI10_SELF_TEST_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

mkdir -p "$tmp/proof/engine-selection/oidc-provider/integration"
cp -R "$script_dir/adapters" "$tmp/proof/adapters"
ln -s "$engine/node_modules" \
    "$tmp/proof/engine-selection/oidc-provider/node_modules"
cp "$engine/integration/select-login-subject.mjs" \
    "$tmp/proof/engine-selection/oidc-provider/integration/select-login-subject.mjs"
mutant="$tmp/proof/engine-selection/oidc-provider/integration/server.mjs"
awk '
    {
        print
        if ($0 == "const ephemeralOutcomes = new Map();") {
            print "process.stderr.write('\''secret-never-project-v1\\n'\'');"
            changed = 1
        }
    }
    END { exit !changed }
' "$server" >"$mutant"

set +e
LICIUM_OIDC_SERVER_SOURCE="$mutant" \
OIDC_REPORT_SURFACE_SCAN=yes \
NODE="$node" \
    "$script_dir/run-oidc-integration.sh" sqlite-provider-v1 \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo OI10_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c OIDC_SECRET_LEAK "$tmp/mutant.err")" -eq 1 ] || {
    echo OI10_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo OI10_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

printf '%s\n' \
    "receipt observation=OI10 mutation=engine-log-secret inner_status=$inner_status marker=OIDC_SECRET_LEAK marker_count=1 target_gate=yes reachability=actual-engine-stderr full-flow-before-scan=yes" \
    'ok OI10-control' \
    'OI10_SELF_TEST_VALID 1 baseline 1 control'
