#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
expected="$script_dir/cases/oidc-integration/expected-sqlite.tsv"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
for run in a b
do
    OIDC_REPORT_SURFACE_SCAN=yes NODE="$node" \
        "$script_dir/run-oidc-integration.sh" sqlite-provider-v1 \
        >"$tmp/$run.tsv" 2>"$tmp/$run.err"
    [ ! -s "$tmp/$run.err" ] || {
        echo OI10_UNEXPECTED_STDERR >&2
        exit 1
    }
    [ "$(grep -F -x -c \
        'oidc-all-surfaces-nonleakage	PASS' "$tmp/$run.tsv")" -eq 1 ] || {
        echo OI10_SCAN_RECEIPT_MISSING >&2
        exit 1
    }
    grep -F -x -v 'oidc-all-surfaces-nonleakage	PASS' \
        "$tmp/$run.tsv" >"$tmp/$run-semantic.tsv"
    cmp -s "$expected" "$tmp/$run-semantic.tsv" || {
        echo OI10_SEMANTIC_REGRESSION >&2
        exit 1
    }
done
cmp -s "$tmp/a.tsv" "$tmp/b.tsv" || {
    echo OI10_NONDETERMINISTIC_RECEIPT >&2
    exit 1
}

echo OI10_ALL_RUNTIME_SURFACES_NONLEAKAGE_VALID
