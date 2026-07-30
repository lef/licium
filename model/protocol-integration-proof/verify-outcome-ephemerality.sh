#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner=${1:-"$script_dir/run-protocol-neutral.sh"}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$runner" sqlite-provider-v1 ordinary-read-counters \
    >"$tmp/counters.tsv" 2>"$tmp/stderr"
[ ! -s "$tmp/stderr" ] || {
    echo OUTCOME_EPHEMERALITY_UNEXPECTED_STDERR >&2
    exit 1
}

persisted_delta=$(awk -F '\t' \
    '$2 == "persisted_result" && $3 == "delta" { print $4 }' \
    "$tmp/counters.tsv")
[ -n "$persisted_delta" ] || {
    echo OUTCOME_EPHEMERALITY_PRECONDITION_INVALID >&2
    exit 1
}
[ "$persisted_delta" = 0 ] || {
    echo OUTCOME_RESULT_COLLAPSE >&2
    exit 1
}
for counter in repository_transition decision_observation
do
    grep -F -x -q "ordinary-read	$counter	delta	0" \
        "$tmp/counters.tsv" || {
        echo OUTCOME_EPHEMERALITY_POSTCONDITION_INVALID >&2
        exit 1
    }
done

echo OUTCOME_EPHEMERALITY_VALID
