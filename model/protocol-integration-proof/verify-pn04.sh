#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
expected="$script_dir/cases/pn04/expected.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$runner" sqlite-provider-v1 pinned-closure \
    >"$tmp/actual-a.tsv" 2>"$tmp/stderr-a"
"$runner" sqlite-provider-v1 pinned-closure \
    >"$tmp/actual-b.tsv" 2>"$tmp/stderr-b"

[ ! -s "$tmp/stderr-a" ] && [ ! -s "$tmp/stderr-b" ] || {
    echo PN04_UNEXPECTED_STDERR >&2
    exit 1
}
cmp -s "$tmp/actual-a.tsv" "$tmp/actual-b.tsv" || {
    echo PN04_NONDETERMINISTIC >&2
    exit 1
}
cmp -s "$expected" "$tmp/actual-a.tsv" || {
    echo PN04_PINNED_CLOSURE_MISMATCH >&2
    exit 1
}

[ "$(wc -l <"$tmp/actual-a.tsv" | tr -d ' ')" -eq 6 ] || {
    echo PN04_CLOSURE_CARDINALITY_INVALID >&2
    exit 1
}

echo 'PN04 pinned-closure sqlite-provider-v1 PASS'
