#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
evaluator=${1:-"$script_dir/adapters/oidc-provider-v1/evaluate-subject-policy.mjs"}
input="$script_dir/cases/subject-policy/input.tsv"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$node" "$evaluator" "$input" >"$tmp/decisions.tsv" 2>"$tmp/stderr"
[ ! -s "$tmp/stderr" ] || {
    echo SUBJECT_UNIQUENESS_UNEXPECTED_STDERR >&2
    exit 1
}
for scenario in context-a distinct-account pairwise-a pairwise-b
do
    grep -F -q "$scenario	issued	" "$tmp/decisions.tsv" || {
        echo SUBJECT_UNIQUENESS_PRECONDITION_INVALID >&2
        exit 1
    }
done
alice=$(awk -F '\t' '$1 == "context-a" { print $3 }' "$tmp/decisions.tsv")
bob=$(awk -F '\t' '$1 == "distinct-account" { print $3 }' \
    "$tmp/decisions.tsv")
sector_a=$(awk -F '\t' '$1 == "pairwise-a" { print $3 }' \
    "$tmp/decisions.tsv")
sector_b=$(awk -F '\t' '$1 == "pairwise-b" { print $3 }' \
    "$tmp/decisions.tsv")
[ "$alice" != "$bob" ] && [ "$sector_a" != "$sector_b" ] || {
    echo SUBJECT_COLLISION_OR_REASSIGNMENT >&2
    exit 1
}

echo SUBJECT_UNIQUENESS_VALID
