#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-adapter-boundary.sh"
auth_source="$script_dir/adapters/oidc-provider-v1/authenticate.mjs"
map_source="$script_dir/adapters/oidc-provider-v1/map-request.mjs"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/bin"

"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q ADAPTER_BOUNDARY_VALID "$tmp/baseline.out"
then
    echo PI_N01_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

awk '
    {
        print
        if ($0 ~ /PI_N01_REACHABLE_INSERTION_POINT/) {
            print "  await execFileAsync(process.env.PI_N01_SQLITE3, ['\'':memory:'\'', '\''select 1'\'']);"
        }
    }
' "$auth_source" >"$tmp/mutant.mjs"

cat >"$tmp/bin/sqlite3" <<'WRAPPER'
#!/bin/sh
: >"$PI_N01_REACHABILITY_MARKER"
exit 0
WRAPPER
chmod +x "$tmp/bin/sqlite3"

set +e
PI_N01_REACHABILITY_MARKER="$tmp/reached" \
PI_N01_SQLITE3="$tmp/bin/sqlite3" \
LICIUM_AUTH_BACKEND_COMMAND="$script_dir/auth-backend-v1.sh" \
LICIUM_AUTH_BACKEND_PROVIDER=sqlite-provider-v1 \
    "$node" "$script_dir/invoke-adapter.mjs" "$tmp/mutant.mjs" \
    >"$tmp/invoke.out" 2>"$tmp/invoke.err"
invoke_status=$?
set -e
[ "$invoke_status" -eq 0 ] || {
    cat "$tmp/invoke.err" >&2
    echo PI_N01_MUTANT_INVOCATION_FAILED >&2
    exit 1
}
[ -f "$tmp/reached" ] &&
    grep -F -x -q PI_N01_MUTANT_REACHED "$tmp/invoke.out" &&
    [ ! -s "$tmp/invoke.err" ] || {
    echo PI_N01_MUTANT_NOT_REACHED >&2
    exit 1
}

set +e
"$verifier" "$tmp/mutant.mjs" "$map_source" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N01_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c ADAPTER_BACKEND_SCHEMA_COUPLING \
    "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N01_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N01_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N01 class=static/runtime mutation=reachable-sqlite3-call inner_status=$inner_status marker=ADAPTER_BACKEND_SCHEMA_COUPLING marker_count=1 target_gate=yes reachability=dynamic-valid-authentication" \
    'ok PI-N01' \
    'PI_N01_SELF_TEST_VALID 1 baseline 1 control'
