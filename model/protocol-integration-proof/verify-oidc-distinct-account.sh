#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-oidc-integration.sh"
expected_alice="$script_dir/cases/oidc-integration/expected-sqlite.tsv"
expected_bob="$script_dir/cases/oidc-subject/distinct-account.tsv"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

NODE="$node" "$runner" sqlite-provider-v1 \
    >"$tmp/alice.tsv" 2>"$tmp/alice.err"
if [ -s "$tmp/alice.err" ] ||
    ! cmp -s "$expected_alice" "$tmp/alice.tsv"
then
    echo OI12_ALICE_BASELINE_INVALID >&2
    exit 1
fi

for run in a b
do
    NODE="$node" "$runner" sqlite-provider-v1 distinct-account \
        >"$tmp/bob-$run.tsv" 2>"$tmp/bob-$run.err"
    [ ! -s "$tmp/bob-$run.err" ] || {
        echo OI12_BOB_UNEXPECTED_STDERR >&2
        exit 1
    }
    cmp -s "$expected_bob" "$tmp/bob-$run.tsv" || {
        echo OI12_BOB_OUTCOME_MISMATCH >&2
        exit 1
    }
done
cmp -s "$tmp/bob-a.tsv" "$tmp/bob-b.tsv" || {
    echo OI12_BOB_NONDETERMINISTIC >&2
    exit 1
}

alice=$(awk -F '	' '$1 == "subject" { print $2 }' \
    "$script_dir/cases/oidc-subject/context-b.tsv")
bob=$(awk -F '	' '$1 == "subject" { print $2 }' "$tmp/bob-a.tsv")
[ -n "$alice" ] && [ -n "$bob" ] && [ "$alice" != "$bob" ] || {
    echo OI12_DISTINCT_ACCOUNT_COLLISION >&2
    exit 1
}

NODE="$node" "$script_dir/verify-oidc-subject-policy.sh" \
    >"$tmp/subject-policy.out" 2>"$tmp/subject-policy.err"
if [ -s "$tmp/subject-policy.err" ] ||
    ! grep -F -x -q OIDC_SUBJECT_POLICY_SCENARIOS_VALID \
        "$tmp/subject-policy.out"
then
    echo OI12_PAIRWISE_OR_MIGRATION_REGRESSION >&2
    exit 1
fi

NODE="$node" "$script_dir/self-test-pi-n16.sh" \
    >"$tmp/reassignment-control.out" \
    2>"$tmp/reassignment-control.err"
if [ -s "$tmp/reassignment-control.err" ] ||
    ! grep -F -x -q \
        'PI_N16_SELF_TEST_VALID 1 baseline 1 control' \
        "$tmp/reassignment-control.out"
then
    echo OI12_REASSIGNMENT_CONTROL_INVALID >&2
    exit 1
fi

echo 'OI12_DISTINCT_ACCOUNT_AND_PAIRWISE_VALID'
