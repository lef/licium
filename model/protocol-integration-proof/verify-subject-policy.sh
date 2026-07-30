#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
input="$script_dir/cases/subject-policy/input.tsv"
expected="$script_dir/cases/subject-policy/expected.tsv"
evaluator="$script_dir/adapters/oidc-provider-v1/evaluate-subject-policy.mjs"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$node" "$evaluator" "$input" >"$tmp/actual-a.tsv" 2>"$tmp/stderr-a"
"$node" "$evaluator" "$input" >"$tmp/actual-b.tsv" 2>"$tmp/stderr-b"

[ ! -s "$tmp/stderr-a" ] && [ ! -s "$tmp/stderr-b" ] || {
    echo SUBJECT_POLICY_UNEXPECTED_STDERR >&2
    exit 1
}
cmp -s "$tmp/actual-a.tsv" "$tmp/actual-b.tsv" || {
    echo SUBJECT_POLICY_NONDETERMINISTIC >&2
    exit 1
}
cmp -s "$expected" "$tmp/actual-a.tsv" || {
    echo SUBJECT_POLICY_OUTCOME_MISMATCH >&2
    exit 1
}

context_a=$(awk -F '	' '$1 == "context-a" { print $3 }' "$tmp/actual-a.tsv")
context_b=$(awk -F '	' '$1 == "context-b" { print $3 }' "$tmp/actual-a.tsv")
[ "$context_a" = "$context_b" ] || {
    echo SUBJECT_POLICY_CONTEXT_INSTABILITY >&2
    exit 1
}
pairwise_a=$(awk -F '	' '$1 == "pairwise-a" { print $3 }' "$tmp/actual-a.tsv")
pairwise_b=$(awk -F '	' '$1 == "pairwise-b" { print $3 }' "$tmp/actual-a.tsv")
[ "$pairwise_a" != "$pairwise_b" ] || {
    echo SUBJECT_POLICY_SECTOR_COLLISION >&2
    exit 1
}
[ "$context_a" != "$(awk -F '	' \
    '$1 == "distinct-account" { print $3 }' "$tmp/actual-a.tsv")" ] || {
    echo SUBJECT_POLICY_ACCOUNT_COLLISION >&2
    exit 1
}

echo 'SUBJECT_POLICY_V1_VALID'
