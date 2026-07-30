#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
vectors="$script_dir/vectors"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

{
    cat "$vectors/expected-accepted.tsv"
    cat "$vectors/expected-projection.tsv"
} | LC_ALL=C sort >"$tmp/expected.tsv"

"$runner" sqlite-provider-v1 valid \
    >"$tmp/actual-a.tsv" 2>"$tmp/stderr-a"
"$runner" sqlite-provider-v1 valid \
    >"$tmp/actual-b.tsv" 2>"$tmp/stderr-b"

[ ! -s "$tmp/stderr-a" ] && [ ! -s "$tmp/stderr-b" ] || {
    echo PN01_UNEXPECTED_STDERR >&2
    exit 1
}
cmp -s "$tmp/actual-a.tsv" "$tmp/actual-b.tsv" || {
    echo PN01_NONDETERMINISTIC >&2
    exit 1
}
cmp -s "$tmp/expected.tsv" "$tmp/actual-a.tsv" || {
    echo PN01_OUTCOME_MISMATCH >&2
    exit 1
}
cut -f2 "$vectors/forbidden-sentinels.tsv" >"$tmp/forbidden"
if grep -F -f "$tmp/forbidden" "$tmp/actual-a.tsv" >/dev/null
then
    echo PN01_FORBIDDEN_SENTINEL >&2
    exit 1
fi

echo 'PN01 VALID sqlite-provider-v1 PASS'
