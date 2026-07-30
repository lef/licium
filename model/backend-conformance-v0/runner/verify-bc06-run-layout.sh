#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases="$base_dir/bc06-cases.tsv"
artifacts="$base_dir/bc06-runtime-artifacts.tsv"

[ "$#" -eq 2 ] || {
    echo "usage: verify-bc06-run-layout.sh RUN_DIR preseal|sealed" >&2
    exit 2
}

run_dir=$1
stage=$2
case "$stage" in preseal|sealed) ;; *) exit 2 ;; esac

fail()
{
    echo "$1" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

find "$run_dir" -type l -print | awk 'NR == 1 { exit 1 }' ||
    fail BC06_RUN_LAYOUT_INVALID

{
    for root_file in \
        action-receipts.tsv \
        assertions.tsv \
        command-receipts.tsv \
        control-receipts.tsv \
        coverage.tsv \
        exclusions.tsv \
        fault-markers.tsv \
        inventory-after.tsv \
        inventory-before.tsv \
        namespace-inventory.tsv \
        normalized-observations.tsv \
        oracle-result.tsv \
        pragma.tsv \
        raw-observations.tsv \
        run-metadata.tsv \
        runtime-status.tsv
    do
        printf '%s\n' "$root_file"
    done
    [ "$stage" != "sealed" ] || printf '%s\n' \
        outer-receipt.tsv payload-manifest.tsv report.tsv
    while IFS='	' read -r assertion kind normal_mode control_mode count disposition
    do
        name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
        while IFS='	' read -r artifact fields rows relation_kind source
        do
            printf '%s/%s\n' "$name" "$artifact"
        done <"$artifacts"
    done <"$cases"
} | LC_ALL=C sort >"$tmp/expected-files"

find "$run_dir" -type f -print |
    while IFS= read -r file
    do
        printf '%s\n' "${file#"$run_dir"/}"
    done |
    LC_ALL=C sort >"$tmp/actual-files"
cmp -s "$tmp/expected-files" "$tmp/actual-files" ||
    fail BC06_RUN_LAYOUT_INVALID

{
    printf '.\n'
    while IFS='	' read -r assertion kind normal_mode control_mode count disposition
    do
        printf '%s' "$assertion" | tr 'A-Z_' 'a-z-'
        printf '\n'
    done <"$cases"
} | LC_ALL=C sort >"$tmp/expected-dirs"
find "$run_dir" -type d -print |
    while IFS= read -r directory
    do
        relative=${directory#"$run_dir"}
        [ -n "$relative" ] || relative=.
        relative=${relative#/}
        printf '%s\n' "$relative"
    done |
    LC_ALL=C sort >"$tmp/actual-dirs"
cmp -s "$tmp/expected-dirs" "$tmp/actual-dirs" ||
    fail BC06_RUN_LAYOUT_INVALID

echo BC06_RUN_LAYOUT_VALID
