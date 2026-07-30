#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mapper=${1:-"$script_dir/adapters/oidc-provider-v1/subject-policy.mjs"}
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$node" "$script_dir/evaluate-subject-stability.mjs" "$mapper" \
    >"$tmp/decisions.tsv" 2>"$tmp/stderr"
[ ! -s "$tmp/stderr" ] || {
    echo SUBJECT_STABILITY_UNEXPECTED_STDERR >&2
    exit 1
}
a_disposition=$(awk -F '\t' '$1 == "context-a" { print $2 }' \
    "$tmp/decisions.tsv")
b_disposition=$(awk -F '\t' '$1 == "context-b" { print $2 }' \
    "$tmp/decisions.tsv")
a_subject=$(awk -F '\t' '$1 == "context-a" { print $3 }' \
    "$tmp/decisions.tsv")
b_subject=$(awk -F '\t' '$1 == "context-b" { print $3 }' \
    "$tmp/decisions.tsv")

[ "$a_disposition" = issued ] && [ "$b_disposition" = issued ] || {
    echo SUBJECT_STABILITY_PRECONDITION_INVALID >&2
    exit 1
}
[ "$a_subject" = sub-public-alice-v1 ] || {
    echo SUBJECT_STABILITY_PRECONDITION_INVALID >&2
    exit 1
}
[ "$a_subject" = "$b_subject" ] || {
    echo SUBJECT_INSTABILITY >&2
    exit 1
}

echo SUBJECT_STABILITY_VALID
