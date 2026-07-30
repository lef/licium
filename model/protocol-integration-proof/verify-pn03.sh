#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
expected="$script_dir/cases/pn03/expected.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for case_id in exact-root published-head
do
    "$runner" sqlite-provider-v1 "$case_id" \
        >"$tmp/$case_id-a.tsv" 2>"$tmp/$case_id-a.err"
    "$runner" sqlite-provider-v1 "$case_id" \
        >"$tmp/$case_id-b.tsv" 2>"$tmp/$case_id-b.err"
    [ ! -s "$tmp/$case_id-a.err" ] &&
        [ ! -s "$tmp/$case_id-b.err" ] || {
        echo "PN03_UNEXPECTED_STDERR $case_id" >&2
        exit 1
    }
    cmp -s "$tmp/$case_id-a.tsv" "$tmp/$case_id-b.tsv" || {
        echo "PN03_NONDETERMINISTIC $case_id" >&2
        exit 1
    }
    awk -F '	' -v case_id="$case_id" '$1 == case_id' \
        "$expected" >"$tmp/$case_id-expected.tsv"
    cmp -s "$tmp/$case_id-expected.tsv" "$tmp/$case_id-a.tsv" || {
        echo "PN03_ROOT_MODE_MISMATCH $case_id" >&2
        exit 1
    }
    printf 'PN03 %s sqlite-provider-v1 PASS\n' "$case_id"
done

exact_root=$(awk -F '	' \
    '$1 == "exact-root" && $3 == "root_ref" { print $4 }' \
    "$tmp/exact-root-a.tsv")
published_root=$(awk -F '	' \
    '$1 == "published-head" && $3 == "root_ref" { print $4 }' \
    "$tmp/published-head-a.tsv")
[ "$exact_root" != "$published_root" ] || {
    echo PN03_ROOT_MODES_COLLAPSED >&2
    exit 1
}
