#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for scenario in exact-root published-head
do
    NODE="$node" "$script_dir/run-oidc-integration.sh" \
        sqlite-provider-v1 "$scenario" \
        >"$tmp/$scenario.tsv" 2>"$tmp/$scenario.err"
    [ ! -s "$tmp/$scenario.err" ] || {
        echo "OI09_UNEXPECTED_STDERR $scenario" >&2
        exit 1
    }
    cmp -s "$script_dir/cases/oidc-source/$scenario.tsv" \
        "$tmp/$scenario.tsv" || {
        echo "OI09_SOURCE_MODE_MISMATCH $scenario" >&2
        exit 1
    }
done

exact_root=$(awk -F '\t' '$1 == "root-ref" { print $2 }' \
    "$tmp/exact-root.tsv")
published_root=$(awk -F '\t' '$1 == "root-ref" { print $2 }' \
    "$tmp/published-head.tsv")
[ "$exact_root" = root-auth-v1 ] &&
    [ "$published_root" = root-auth-v2 ] &&
    [ "$exact_root" != "$published_root" ] || {
    echo OI09_SOURCE_MODES_COLLAPSED >&2
    exit 1
}

echo OI09_EXACT_AND_PUBLISHED_LOGIN_VALID
