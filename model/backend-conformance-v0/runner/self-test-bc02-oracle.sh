#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
oracle="$script_dir/oracle-bc02.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

partial=bc02-partial-residue--case-bc02-after-root-header
partial_dir="$tmp/partial"
mkdir "$partial_dir"
awk -F '	' -v scenario="$partial" '$1 == scenario' \
    "$base_dir/bc02-normalized-contract.tsv" \
    > "$partial_dir/normalized-observations.tsv"
: > "$partial_dir/inventory-setup-before.tsv"
: > "$partial_dir/inventory-rollback-after.tsv"
"$oracle" "$partial_dir" "$partial" > "$partial_dir/oracle.tsv"

printf 'tamper\n' >> "$partial_dir/normalized-observations.tsv"
set +e
partial_output=$("$oracle" "$partial_dir" "$partial" 2>&1)
partial_status=$?
set -e
[ "$partial_status" -ne 0 ] &&
    [ "$partial_output" = "BC02_ORACLE_MISMATCH" ] || {
    echo BC02_EXACT_ORACLE_CONTROL_INVALID >&2
    exit 1
}

rollback=bc02-rollback-complete--case-bc02-after-root-header
rollback_dir="$tmp/rollback"
mkdir "$rollback_dir"
awk -F '	' -v scenario="$rollback" '$1 == scenario' \
    "$base_dir/bc02-normalized-contract.tsv" \
    > "$rollback_dir/normalized-observations.tsv"
printf 'same\n' > "$rollback_dir/inventory-setup-before.tsv"
printf 'same\n' > "$rollback_dir/inventory-rollback-after.tsv"
"$oracle" "$rollback_dir" "$rollback" > "$rollback_dir/oracle.tsv"

printf 'drift\n' >> "$rollback_dir/inventory-rollback-after.tsv"
set +e
rollback_output=$("$oracle" "$rollback_dir" "$rollback" 2>&1)
rollback_status=$?
set -e
[ "$rollback_status" -ne 0 ] &&
    [ "$rollback_output" = "BC02_ORACLE_MISMATCH" ] || {
    echo BC02_EQUALITY_ORACLE_CONTROL_INVALID >&2
    exit 1
}

echo "2 BC02 oracle baselines"
echo "2 BC02 oracle controls detected"
