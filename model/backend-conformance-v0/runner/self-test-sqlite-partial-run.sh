#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
runner="$script_dir/run-sqlite-partial-run.sh"
verifier="$script_dir/verify-sqlite-partial-run.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

lifecycle="$tmp/lifecycle"
mkdir -p "$lifecycle/run-a" "$lifecycle/run-b"
"$adapter" lifecycle-sentinel "$lifecycle" put run-a sentinel-a >/dev/null

baseline="$tmp/baseline"
"$runner" "$baseline" run-a a "$lifecycle" >/dev/null

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
    output=$(
        "$verifier" "$dir" run-a a "$lifecycle" sealed 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "SQLITE_PARTIAL_RUN_CONTROL_ACCEPTED: $name" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        printf '%s\n' "$output" >&2
        echo "SQLITE_PARTIAL_RUN_CONTROL_MARKER_INVALID: $name" >&2
        exit 1
    }
    controls=$((controls + 1))
}

mutate_layout()
{
    : >"$1/extra.tsv"
}

mutate_runtime_status()
{
    rewrite '1s/BC02_RUNTIME_VALID/BC02_RUNTIME_FORGED/' \
        "$1/runtime-status.tsv"
}

mutate_assertions()
{
    rewrite 's/	PASS	ok	/	UNTESTED	not-executed	/' \
        "$1/assertions.tsv"
}

mutate_bc02_receipt()
{
    rewrite '1s/BC02_COMPLETE_ROOT_REQUIRED/BC02_FORGED_MARKER/' \
        "$1/bc02-negative-receipts.tsv"
}

mutate_bc03_receipt()
{
    rewrite '1s/BC03_/BC03_FORGED_/' "$1/bc03-control-receipts.tsv"
}

mutate_bc04_receipt()
{
    rewrite '1s/BC04_/BC04_FORGED_/' "$1/bc04-control-receipts.tsv"
}

mutate_bc05_receipt()
{
    rewrite '1s/BC05_/BC05_FORGED_/' "$1/bc05-control-receipts.tsv"
}

mutate_bc01_receipt()
{
    rewrite '1s/BC01_/BC01_FORGED_/' "$1/bc01-control-receipts.tsv"
}

mutate_bc06_receipt()
{
    rewrite '1s/BC06_/BC06_FORGED_/' "$1/bc06-control-receipts.tsv"
}

mutate_bc07_receipt()
{
    rewrite '1s/BC07_/BC07_FORGED_/' "$1/bc07-control-receipts.tsv"
}

mutate_bc08_receipt()
{
    rewrite '1s/BC08_/BC08_FORGED_/' "$1/bc08-control-receipts.tsv"
}

mutate_bc09_receipt()
{
    rewrite '1s/BC09_/BC09_FORGED_/' "$1/bc09-control-receipts.tsv"
}

mutate_bc10_receipt()
{
    rewrite '1s/BC10_/BC10_FORGED_/' "$1/bc10-control-receipts.tsv"
}

mutate_bc11_receipt()
{
    rewrite '1s/BC11_/BC11_FORGED_/' "$1/bc11-control-receipts.tsv"
}

mutate_bc12_receipt()
{
    rewrite '1s/BC12_/BC12_FORGED_/' "$1/bc12-control-receipts.tsv"
}

mutate_namespace()
{
    rewrite 's/	present$/	absent/' "$1/namespace-inventory.tsv"
}

mutate_manifest()
{
    rewrite '1s/[0-9a-f][0-9a-f]*$/0/' "$1/payload-manifest.tsv"
}

expect_rejected layout SQLITE_PARTIAL_RUN_LAYOUT_INVALID mutate_layout
expect_rejected runtime-status SQLITE_PARTIAL_RUNTIME_STATUS_INVALID \
    mutate_runtime_status
expect_rejected assertions SQLITE_PARTIAL_ASSERTIONS_INVALID mutate_assertions
expect_rejected bc01-receipt \
    SQLITE_PARTIAL_BC01_CONTROL_RECEIPTS_INVALID mutate_bc01_receipt
expect_rejected bc02-receipt \
    SQLITE_PARTIAL_BC02_NEGATIVE_RECEIPTS_INVALID mutate_bc02_receipt
expect_rejected bc03-receipt \
    SQLITE_PARTIAL_BC03_CONTROL_RECEIPTS_INVALID mutate_bc03_receipt
expect_rejected bc04-receipt \
    SQLITE_PARTIAL_BC04_CONTROL_RECEIPTS_INVALID mutate_bc04_receipt
expect_rejected bc05-receipt \
    SQLITE_PARTIAL_BC05_CONTROL_RECEIPTS_INVALID mutate_bc05_receipt
expect_rejected bc06-receipt \
    SQLITE_PARTIAL_BC06_CONTROL_RECEIPTS_INVALID mutate_bc06_receipt
expect_rejected bc07-receipt \
    SQLITE_PARTIAL_BC07_CONTROL_RECEIPTS_INVALID mutate_bc07_receipt
expect_rejected bc08-receipt \
    SQLITE_PARTIAL_BC08_CONTROL_RECEIPTS_INVALID mutate_bc08_receipt
expect_rejected bc09-receipt \
    SQLITE_PARTIAL_BC09_CONTROL_RECEIPTS_INVALID mutate_bc09_receipt
expect_rejected bc10-receipt \
    SQLITE_PARTIAL_BC10_CONTROL_RECEIPTS_INVALID mutate_bc10_receipt
expect_rejected bc11-receipt \
    SQLITE_PARTIAL_BC11_CONTROL_RECEIPTS_INVALID mutate_bc11_receipt
expect_rejected bc12-receipt \
    SQLITE_PARTIAL_BC12_CONTROL_RECEIPTS_INVALID mutate_bc12_receipt
expect_rejected namespace \
    SQLITE_PARTIAL_NAMESPACE_INVENTORY_INVALID mutate_namespace
expect_rejected manifest PAYLOAD_MANIFEST_INVALID mutate_manifest

source_b="$tmp/source-b"
cp -R "$base_dir" "$source_b"
printf '\n' >>"$source_b/sqlite-partial-canonical.tsv"
set +e
closure_output=$(
    "$source_b/runner/verify-sqlite-partial-run.sh" \
        "$baseline" run-a a "$lifecycle" sealed 2>&1
)
closure_status=$?
set -e
[ "$closure_status" -ne 0 ] &&
    [ "$closure_output" = "SQLITE_PARTIAL_RUN_METADATA_CLOSURE_INVALID" ] || {
    printf '%s\n' "$closure_output" >&2
    echo SQLITE_PARTIAL_RUN_CLOSURE_DRIFT_CONTROL_INVALID >&2
    exit 1
}
controls=$((controls + 1))

set +e
fresh_output=$(
    "$runner" "$baseline" run-a a "$lifecycle" 2>&1
)
fresh_status=$?
set -e
[ "$fresh_status" -ne 0 ] &&
    [ "$fresh_output" = "SQLITE_PARTIAL_RUN_NOT_FRESH" ] || {
    echo SQLITE_PARTIAL_RUN_FRESHNESS_CONTROL_INVALID >&2
    exit 1
}
controls=$((controls + 1))

printf '1 SQLite partial run baseline\n'
printf '%s SQLite partial run controls detected\n' "$controls"
