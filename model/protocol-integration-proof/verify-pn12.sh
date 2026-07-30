#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
expected="$script_dir/cases/pn12/expected.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$runner" sqlite-provider-v1 ephemeral-provenance \
    >"$tmp/actual-a.tsv" 2>"$tmp/stderr-a"
"$runner" sqlite-provider-v1 ephemeral-provenance \
    >"$tmp/actual-b.tsv" 2>"$tmp/stderr-b"

[ ! -s "$tmp/stderr-a" ] && [ ! -s "$tmp/stderr-b" ] || {
    echo PN12_UNEXPECTED_STDERR >&2
    exit 1
}
cmp -s "$tmp/actual-a.tsv" "$tmp/actual-b.tsv" || {
    echo PN12_NONDETERMINISTIC >&2
    exit 1
}
cmp -s "$expected" "$tmp/actual-a.tsv" || {
    echo PN12_EPHEMERAL_PROVENANCE_MISMATCH >&2
    exit 1
}
if grep -F 'persisted_result_ref' "$tmp/actual-a.tsv" >/dev/null
then
    echo PN12_PERSISTED_RESULT_REF_REQUIRED >&2
    exit 1
fi

echo 'PN12 ephemeral-outcome-provenance sqlite-provider-v1 PASS'
