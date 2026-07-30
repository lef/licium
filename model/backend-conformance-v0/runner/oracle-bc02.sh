#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

[ "$#" -eq 2 ] || {
    echo "usage: oracle-bc02.sh ARTIFACT_DIR SCENARIO" >&2
    exit 2
}

artifact_dir=$1
scenario=$2
actual="$artifact_dir/normalized-observations.tsv"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

oracle_kind=exact
oracle_relation=norm-bc02-observation
case "$scenario" in
    bc02-complete-available--case-bc02-complete)
        oracle_id=oracle-bc02-complete-available
        ;;
    bc02-incomplete-as-complete--case-bc02-incomplete-missing|\
    bc02-incomplete-as-complete--case-bc02-incomplete-substitution)
        oracle_id=oracle-bc02-incomplete-as-complete
        ;;
    bc02-healthy-retry--case-bc02-incomplete-corrected)
        oracle_id=oracle-bc02-healthy-retry
        oracle_kind=exact
        oracle_relation=norm-bc02-observation
        ;;
    bc02-partial-residue--case-bc02-after-root-header|\
    bc02-partial-residue--case-bc02-after-root-member)
        oracle_id=oracle-bc02-partial-residue
        oracle_kind=exact
        oracle_relation=norm-bc02-observation
        ;;
    bc02-poisoned-retry--case-bc02-after-root-header|\
    bc02-poisoned-retry--case-bc02-after-root-member)
        oracle_id=oracle-bc02-poisoned-retry
        oracle_kind=exact
        oracle_relation=norm-bc02-observation
        ;;
    bc02-rollback-complete--case-bc02-after-root-header|\
    bc02-rollback-complete--case-bc02-after-root-member)
        oracle_id=oracle-bc02-rollback-complete
        oracle_kind=equality
        oracle_relation=inventory-repository
        ;;
    *)
        exit 2
        ;;
esac

case "$oracle_kind" in
    exact)
        awk -F '	' -v scenario="$scenario" '$1 == scenario' \
            "$base_dir/bc02-normalized-contract.tsv" > "$tmp/expected.tsv"
        LC_ALL=C sort "$actual" > "$tmp/actual.tsv"
        ;;
    equality)
        cp "$artifact_dir/inventory-setup-before.tsv" "$tmp/expected.tsv"
        cp "$artifact_dir/inventory-rollback-after.tsv" "$tmp/actual.tsv"
        ;;
esac

expected_sha=$(sha256sum "$tmp/expected.tsv" | awk '{ print $1 }')
actual_sha=$(sha256sum "$tmp/actual.tsv" | awk '{ print $1 }')
revision=$(sha256sum "$0" | awk '{ print $1 }')

cmp -s "$tmp/expected.tsv" "$tmp/actual.tsv" || {
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$scenario" "$oracle_id" "$oracle_kind" \
        "$oracle_relation" "$expected_sha" "$actual_sha" FAIL "$revision"
    echo BC02_ORACLE_MISMATCH >&2
    exit 1
}

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$scenario" "$oracle_id" "$oracle_kind" \
    "$oracle_relation" "$expected_sha" "$actual_sha" PASS "$revision"
