#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
expected="$script_dir/cases/forced-reauth/expected.tsv"
node=${NODE:-node}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
for run in a b
do
    NODE="$node" "$script_dir/run-oidc-integration.sh" \
        sqlite-provider-v1 forced-reauth \
        >"$tmp/$run.tsv" 2>"$tmp/$run.err"
    [ ! -s "$tmp/$run.err" ] || {
        echo PN14_FORCED_REAUTH_UNEXPECTED_STDERR >&2
        exit 1
    }
    cmp -s "$expected" "$tmp/$run.tsv" || {
        echo PN14_FORCED_REAUTH_OUTCOME_MISMATCH >&2
        exit 1
    }
done
cmp -s "$tmp/a.tsv" "$tmp/b.tsv" || {
    echo PN14_FORCED_REAUTH_NONDETERMINISTIC >&2
    exit 1
}

echo PN14_FORCED_REAUTHENTICATION_VALID
