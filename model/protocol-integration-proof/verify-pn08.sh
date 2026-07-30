#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-protocol-neutral.sh"
vectors="$script_dir/vectors"
case_dir="$script_dir/cases/pn08"
schema="$script_dir/providers/sqlite-provider-v1/schema.sql"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
surfaces="$tmp/surfaces"
mkdir "$surfaces"

[ "$(grep -F -c 'secret-never-project-v1' "$schema")" -eq 2 ] || {
    echo PN08_SENTINEL_SOURCE_PRECONDITION_INVALID >&2
    exit 1
}

PROTOCOL_SURFACE_DIR="$surfaces" \
    "$runner" sqlite-provider-v1 surface-bundle \
    >"$tmp/stdout" 2>"$tmp/stderr"

[ ! -s "$tmp/stderr" ] || {
    echo PN08_UNEXPECTED_STDERR >&2
    exit 1
}

{
    cat "$vectors/expected-accepted.tsv"
    cat "$vectors/expected-projection.tsv"
} | LC_ALL=C sort >"$tmp/expected-result.tsv"

cmp -s "$tmp/expected-result.tsv" "$tmp/stdout" || {
    echo PN08_STDOUT_MISMATCH >&2
    exit 1
}
cmp -s "$tmp/expected-result.tsv" "$surfaces/result.tsv" || {
    echo PN08_RESULT_MISMATCH >&2
    exit 1
}
cmp -s "$case_dir/expected-explanation.tsv" \
    "$surfaces/explanation.tsv" || {
    echo PN08_EXPLANATION_MISMATCH >&2
    exit 1
}
cmp -s "$case_dir/expected-log.txt" "$surfaces/provider.log" || {
    echo PN08_LOG_MISMATCH >&2
    exit 1
}

find "$surfaces" -type f -printf '%f\n' | LC_ALL=C sort \
    >"$tmp/actual-surface-names"
printf '%s\n' explanation.tsv provider.log result.tsv \
    >"$tmp/expected-surface-names"
cmp -s "$tmp/expected-surface-names" "$tmp/actual-surface-names" || {
    echo PN08_SURFACE_INVENTORY_MISMATCH >&2
    exit 1
}

cut -f2 "$vectors/forbidden-sentinels.tsv" >"$tmp/forbidden"
for surface in "$tmp/stdout" "$tmp/stderr" \
    "$surfaces/result.tsv" "$surfaces/explanation.tsv" \
    "$surfaces/provider.log"
do
    if grep -F -f "$tmp/forbidden" "$surface" >/dev/null
    then
        echo "PN08_SECRET_LEAK $(basename "$surface")" >&2
        exit 1
    fi
done

echo 'PN08 all-output-surfaces sqlite-provider-v1 PASS'
