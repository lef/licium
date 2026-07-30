#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-adapter-provider-neutrality.sh"
auth_source="$script_dir/adapters/oidc-provider-v1/authenticate.mjs"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

NODE="$node" "$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q ADAPTER_PROVIDER_NEUTRALITY_VALID "$tmp/baseline.out"
then
    echo PI_N15_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

{
    printf '%s\n' "import { appendFileSync } from 'node:fs';"
    awk '
        {
            print
            if ($0 == "  const provider = process.env.LICIUM_AUTH_BACKEND_PROVIDER;") {
                print "  appendFileSync(process.env.PI_N15_REACHABILITY_MARKER, `${provider}\\n`, { encoding: '\''utf8'\'' });"
                print "  contextRef = provider === '\''sqlite-provider-v1'\'' ? '\''context-claims-v1'\'' : '\''context-claims-v2'\'';"
                changed = 1
            }
        }
        END { exit !changed }
    ' "$auth_source"
} >"$tmp/mutant.mjs"

: >"$tmp/reached"
for provider in sqlite-provider-v1 flatfile-posix-provider-v1
do
    PI_N15_REACHABILITY_MARKER="$tmp/reached" \
    LICIUM_AUTH_BACKEND_COMMAND="$script_dir/auth-backend-v1.sh" \
    LICIUM_AUTH_BACKEND_PROVIDER="$provider" \
        "$node" "$script_dir/evaluate-adapter-semantics.mjs" \
        "$tmp/mutant.mjs" >"$tmp/$provider.tsv" 2>"$tmp/$provider.err"
    [ ! -s "$tmp/$provider.err" ] || {
        echo PI_N15_MUTANT_INVOCATION_FAILED >&2
        exit 1
    }
done
if [ "$(grep -F -x -c sqlite-provider-v1 "$tmp/reached")" -ne 1 ] ||
    [ "$(grep -F -x -c flatfile-posix-provider-v1 "$tmp/reached")" -ne 1 ] ||
    cmp -s "$tmp/sqlite-provider-v1.tsv" \
        "$tmp/flatfile-posix-provider-v1.tsv"
then
    echo PI_N15_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
NODE="$node" "$verifier" "$tmp/mutant.mjs" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N15_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c PROVIDER_SPECIFIC_ADAPTER_BRANCH \
    "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N15_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N15_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N15 class=static/runtime mutation=provider-id-context-branch inner_status=$inner_status marker=PROVIDER_SPECIFIC_ADAPTER_BRANCH marker_count=1 target_gate=yes reachability=dynamic-both-providers semantic_difference=yes provider_artifacts_unchanged=yes" \
    'ok PI-N15' \
    'PI_N15_SELF_TEST_VALID 1 baseline 1 control'
