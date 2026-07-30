#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
expected="$script_dir/cases/context-b/expected.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for provider in sqlite-provider-v1 flatfile-posix-provider-v1
do
    "$runner" "$provider" valid-context-b \
        >"$tmp/$provider.tsv" 2>"$tmp/$provider.err"
    [ ! -s "$tmp/$provider.err" ] || {
        echo "CONTEXT_B_UNEXPECTED_STDERR $provider" >&2
        exit 1
    }
    cmp -s "$expected" "$tmp/$provider.tsv" || {
        echo "CONTEXT_B_PROVIDER_MISMATCH $provider" >&2
        exit 1
    }
done
cmp -s "$tmp/sqlite-provider-v1.tsv" \
    "$tmp/flatfile-posix-provider-v1.tsv" || {
    echo CONTEXT_B_PROVIDER_DIFFERENCE >&2
    exit 1
}

echo 'CONTEXT_B_PROVIDER_PARITY_VALID'
