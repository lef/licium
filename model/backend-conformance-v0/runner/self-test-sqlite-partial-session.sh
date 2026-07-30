#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-sqlite-partial-session.sh"
verifier="$script_dir/verify-sqlite-partial-session.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baseline="$tmp/baseline"
"$runner" "$baseline" >/dev/null

controls=0

rewrite()
{
    expression=$1
    file=$2
    sed "$expression" "$file" >"$file.new"
    mv "$file.new" "$file"
}

expect_rejected()
{
    name=$1
    expected=$2
    mutation=$3
    dir="$tmp/$name"
    cp -R "$baseline" "$dir"
    "$mutation" "$dir"
    set +e
    output=$("$verifier" "$dir" sealed 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "SQLITE_PARTIAL_SESSION_CONTROL_ACCEPTED: $name" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        printf '%s\n' "$output" >&2
        echo "SQLITE_PARTIAL_SESSION_CONTROL_MARKER_INVALID: $name" >&2
        exit 1
    }
    controls=$((controls + 1))
}

mutate_layout()
{
    : >"$1/extra.tsv"
}

mutate_aggregate()
{
    rewrite '$d' "$1/aggregate-dispositions.tsv"
}

mutate_canonical()
{
    rewrite '1s/[0-9a-f][0-9a-f]*/0000/' \
        "$1/canonical-comparison.tsv"
}

mutate_controls()
{
    rewrite '1s/SQLITE_PARTIAL_/SQLITE_FORGED_/' \
        "$1/control-receipts.tsv"
}

mutate_session_binding()
{
    rewrite '2s/[0-9a-f][0-9a-f]*$/0/' "$1/run-metadata.tsv"
}

expect_rejected layout SQLITE_PARTIAL_SESSION_LAYOUT_INVALID mutate_layout
expect_rejected aggregate SQLITE_PARTIAL_SESSION_AGGREGATE_INVALID \
    mutate_aggregate
expect_rejected canonical SQLITE_PARTIAL_CANONICAL_INVALID mutate_canonical
expect_rejected control-receipt \
    SQLITE_PARTIAL_SESSION_CONTROL_RECEIPT_INVALID mutate_controls
expect_rejected session-binding \
    SQLITE_PARTIAL_SESSION_REPORT_BINDING_INVALID mutate_session_binding

set +e
fresh_output=$("$runner" "$baseline" 2>&1)
fresh_status=$?
set -e
[ "$fresh_status" -ne 0 ] &&
    [ "$fresh_output" = "SQLITE_PARTIAL_SESSION_NOT_FRESH" ] || {
    echo SQLITE_PARTIAL_SESSION_FRESHNESS_CONTROL_INVALID >&2
    exit 1
}
controls=$((controls + 1))

printf '1 SQLite partial session baseline\n'
printf '%s SQLite partial session controls detected\n' "$controls"
