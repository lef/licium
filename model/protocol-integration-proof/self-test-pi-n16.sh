#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verifier="$script_dir/verify-subject-uniqueness.sh"
adapter="$script_dir/adapters/oidc-provider-v1"
input="$script_dir/cases/subject-policy/input.tsv"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

NODE="$node" "$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q SUBJECT_UNIQUENESS_VALID "$tmp/baseline.out"
then
    echo PI_N16_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

cp -R "$adapter" "$tmp/adapter"
policy="$tmp/adapter/subject-policy.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" }
    $1 == "account-bob" {
        $7 = "sub-public-alice-v1"
        changed = 1
    }
    { print }
    END { exit !changed }
' "$adapter/subject-policy.tsv" >"$policy.new"
mv "$policy.new" "$policy"

"$node" "$tmp/adapter/evaluate-subject-policy.mjs" "$input" \
    >"$tmp/reached.tsv" 2>"$tmp/reached.err"
if [ -s "$tmp/reached.err" ] ||
    ! grep -F -x -q \
        'distinct-account	issued	sub-public-alice-v1' "$tmp/reached.tsv"
then
    echo PI_N16_MUTANT_NOT_REACHED >&2
    exit 1
fi

set +e
NODE="$node" "$verifier" "$tmp/adapter/evaluate-subject-policy.mjs" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N16_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c SUBJECT_COLLISION_OR_REASSIGNMENT \
    "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N16_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N16_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}
[ ! -e "$tmp/token.json" ] && [ ! -e "$tmp/id-token.jwt" ] || {
    echo PI_N16_MUTANT_TOKEN_ISSUED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N16 class=runtime mutation=bob-subject-reassigned-to-alice inner_status=$inner_status marker=SUBJECT_COLLISION_OR_REASSIGNMENT marker_count=1 target_gate=yes reachability=dynamic-distinct-account-decision token_issued=no" \
    'ok PI-N16' \
    'PI_N16_SELF_TEST_VALID 1 baseline 1 control'
