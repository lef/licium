#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-oidc-integration.sh"
expected="$script_dir/cases/oidc-integration/expected-sqlite.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$runner" sqlite-provider-v1 \
    >"$tmp/actual.tsv" 2>"$tmp/stderr"

[ ! -s "$tmp/stderr" ] || {
    echo OIDC_INTEGRATION_UNEXPECTED_STDERR >&2
    exit 1
}
cmp -s "$expected" "$tmp/actual.tsv" || {
    echo OIDC_INTEGRATION_SEMANTIC_MISMATCH >&2
    exit 1
}

cat "$tmp/actual.tsv"
