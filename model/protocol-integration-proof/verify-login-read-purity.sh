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
    echo LOGIN_READ_PURITY_UNEXPECTED_STDERR >&2
    exit 1
}

delta_rows=$(awk -F '\t' '$3 == "delta" { count++ } END { print count + 0 }' \
    "$tmp/counters.tsv")
[ "$delta_rows" -eq 3 ] || {
    echo LOGIN_READ_PURITY_PRECONDITION_INVALID >&2
    exit 1
}
if awk -F '\t' '$3 == "delta" && $4 != "0" { found = 1 }
    END { exit !found }' "$tmp/counters.tsv"
then
    echo LOGIN_READ_WRITES_STATE >&2
    exit 1
fi
for counter in repository_transition persisted_result decision_observation
do
    grep -F -x -q "ordinary-read	$counter	delta	0" \
        "$tmp/counters.tsv" || {
        echo LOGIN_READ_PURITY_PRECONDITION_INVALID >&2
        exit 1
    }
done

echo LOGIN_READ_PURITY_VALID
