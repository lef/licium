#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner=${1:-"$script_dir/run-protocol-neutral.sh"}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$runner" sqlite-provider-v1 exact-root \
    >"$tmp/exact.tsv" 2>"$tmp/exact.err"
"$runner" sqlite-provider-v1 published-head \
    >"$tmp/published.tsv" 2>"$tmp/published.err"
[ ! -s "$tmp/exact.err" ] && [ ! -s "$tmp/published.err" ] || {
    echo ROOT_PINNING_UNEXPECTED_STDERR >&2
    exit 1
}

exact_root=$(awk -F '\t' \
    '$1 == "exact-root" && $3 == "root_ref" { print $4 }' \
    "$tmp/exact.tsv")
exact_value=$(awk -F '\t' \
    '$1 == "exact-root" && $3 == "display-name" { print $4 }' \
    "$tmp/exact.tsv")
published_root=$(awk -F '\t' \
    '$1 == "published-head" && $3 == "root_ref" { print $4 }' \
    "$tmp/published.tsv")
published_value=$(awk -F '\t' \
    '$1 == "published-head" && $3 == "display-name" { print $4 }' \
    "$tmp/published.tsv")

[ "$published_root" = root-auth-v2 ] &&
    [ "$published_value" = 'Alice Updated' ] || {
    echo ROOT_PINNING_PRECONDITION_INVALID >&2
    exit 1
}
[ "$exact_root" = root-auth-v1 ] &&
    [ "$exact_value" = 'Alice Example' ] || {
    echo AMBIENT_ROOT_SUBSTITUTION >&2
    exit 1
}
[ "$exact_root" != "$published_root" ] || {
    echo AMBIENT_ROOT_SUBSTITUTION >&2
    exit 1
}

echo ROOT_PINNING_VALID
