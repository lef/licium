#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-path-equivalence.sh"
auth_source="$script_dir/adapters/oidc-provider-v1/authenticate.mjs"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

NODE="$node" "$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q \
        DIRECT_ADAPTER_PATH_EQUIVALENCE_VALID "$tmp/baseline.out"
then
    echo PI_N13_BASELINE_INVALID >&2
    exit 1
fi
"$script_dir/run-protocol-neutral.sh" sqlite-provider-v1 valid \
    >"$tmp/direct-before.tsv"
direct_before=$(sha256sum "$tmp/direct-before.tsv" | cut -d' ' -f1)
echo 'ok BASELINE'

awk '
    /backend returned an invalid accepted envelope/ {
        after_validation = 1
    }
    after_validation && $0 == "  return {" && !changed {
        print "  values.set('\''display-name'\'', '\''Mutant Protocol Value'\'');"
        changed = 1
    }
    { print }
    END { exit !changed }
' "$auth_source" >"$tmp/mutant.mjs"

LICIUM_AUTH_BACKEND_COMMAND="$script_dir/auth-backend-v1.sh" \
LICIUM_AUTH_BACKEND_PROVIDER=sqlite-provider-v1 \
    "$node" "$script_dir/evaluate-adapter-semantics.mjs" "$tmp/mutant.mjs" \
    >"$tmp/reached.tsv" 2>"$tmp/reached.err"
if [ -s "$tmp/reached.err" ] ||
    ! grep -F -x -q \
        'envelope	disposition	accepted' "$tmp/reached.tsv" ||
    ! grep -F -x -q \
        'value	display-name	Mutant Protocol Value' "$tmp/reached.tsv"
then
    echo PI_N13_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
NODE="$node" "$verifier" "$tmp/mutant.mjs" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N13_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c PROTOCOL_PATH_SEMANTIC_DRIFT \
    "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N13_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N13_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

"$script_dir/run-protocol-neutral.sh" sqlite-provider-v1 valid \
    >"$tmp/direct-after.tsv"
direct_after=$(sha256sum "$tmp/direct-after.tsv" | cut -d' ' -f1)
[ "$direct_before" = "$direct_after" ] || {
    echo PI_N13_DIRECT_RESULT_CHANGED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N13 class=runtime mutation=adapter-only-display-value inner_status=$inner_status marker=PROTOCOL_PATH_SEMANTIC_DRIFT marker_count=1 target_gate=yes reachability=dynamic-accepted-changed-value direct_result_unchanged=yes" \
    'ok PI-N13' \
    'PI_N13_SELF_TEST_VALID 1 baseline 1 control'
