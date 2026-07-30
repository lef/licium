#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
expected="$script_dir/cases/pn11/expected.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$runner" sqlite-provider-v1 record-only \
    >"$tmp/actual-a.tsv" 2>"$tmp/stderr-a"
"$runner" sqlite-provider-v1 record-only \
    >"$tmp/actual-b.tsv" 2>"$tmp/stderr-b"

[ ! -s "$tmp/stderr-a" ] && [ ! -s "$tmp/stderr-b" ] || {
    echo PN11_UNEXPECTED_STDERR >&2
    exit 1
}
cmp -s "$tmp/actual-a.tsv" "$tmp/actual-b.tsv" || {
    echo PN11_NONDETERMINISTIC >&2
    exit 1
}
cmp -s "$expected" "$tmp/actual-a.tsv" || {
    echo PN11_RECORD_ONLY_MISMATCH >&2
    exit 1
}

echo 'PN11 explicit-record-only sqlite-provider-v1 PASS'
