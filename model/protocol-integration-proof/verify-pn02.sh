#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
vectors="$script_dir/vectors"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
cut -f2 "$vectors/forbidden-sentinels.tsv" >"$tmp/forbidden"

for case_id in wrong-proof unknown-login malformed-request
do
    "$runner" sqlite-provider-v1 "$case_id" \
        >"$tmp/$case_id-a.tsv" 2>"$tmp/$case_id-a.err"
    "$runner" sqlite-provider-v1 "$case_id" \
        >"$tmp/$case_id-b.tsv" 2>"$tmp/$case_id-b.err"
    [ ! -s "$tmp/$case_id-a.err" ] &&
        [ ! -s "$tmp/$case_id-b.err" ] || {
        echo "PN02_UNEXPECTED_STDERR $case_id" >&2
        exit 1
    }
    cmp -s "$tmp/$case_id-a.tsv" "$tmp/$case_id-b.tsv" || {
        echo "PN02_NONDETERMINISTIC $case_id" >&2
        exit 1
    }
    awk -F '	' -v case_id="$case_id" '$1 == case_id' \
        "$vectors/expected-rejected.tsv" >"$tmp/$case_id-expected.tsv"
    cmp -s "$tmp/$case_id-expected.tsv" "$tmp/$case_id-a.tsv" || {
        echo "PN02_OUTCOME_MISMATCH $case_id" >&2
        exit 1
    }
    if grep -F -f "$tmp/forbidden" "$tmp/$case_id-a.tsv" >/dev/null
    then
        echo "PN02_FORBIDDEN_SENTINEL $case_id" >&2
        exit 1
    fi
    printf 'PN02 %s sqlite-provider-v1 PASS\n' "$case_id"
done
