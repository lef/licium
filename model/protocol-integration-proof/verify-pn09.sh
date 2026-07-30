#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
expected="$script_dir/cases/pn09/expected.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$runner" sqlite-provider-v1 ordinary-read-counters \
    >"$tmp/actual-a.tsv" 2>"$tmp/stderr-a"
"$runner" sqlite-provider-v1 ordinary-read-counters \
    >"$tmp/actual-b.tsv" 2>"$tmp/stderr-b"

[ ! -s "$tmp/stderr-a" ] && [ ! -s "$tmp/stderr-b" ] || {
    echo PN09_UNEXPECTED_STDERR >&2
    exit 1
}
cmp -s "$tmp/actual-a.tsv" "$tmp/actual-b.tsv" || {
    echo PN09_NONDETERMINISTIC >&2
    exit 1
}
cmp -s "$expected" "$tmp/actual-a.tsv" || {
    echo PN09_READ_COUNTER_MISMATCH >&2
    exit 1
}

[ "$(awk -F '	' '$3 == "delta" { total += $4 } END { print total + 0 }' \
    "$tmp/actual-a.tsv")" -eq 0 ] || {
    echo PN09_ORDINARY_READ_WRITES >&2
    exit 1
}

echo 'PN09 ordinary-read-no-write sqlite-provider-v1 PASS'
