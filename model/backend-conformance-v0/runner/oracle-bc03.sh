#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

[ "$#" -eq 6 ] || {
    echo "usage: oracle-bc03.sh ARTIFACT_DIR RUN NS ASSERTION CASE SCENARIO" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
scenario=$6

fail()
{
    echo "$1" >&2
    exit 1
}

case "$assertion" in
    BC03_ACCEPTED_HEAD)
        marker=BC03_ACCEPTED_HEAD_MISSING
        oracle=oracle-bc03-accepted-head
        ;;
    BC03_PUBLICATION_SEPARATE)
        marker=BC03_PUBLICATION_ROOT_COLLAPSE_DETECTED
        oracle=oracle-bc03-publication-separate
        ;;
    BC03_REJECTED_IS_HEAD)
        marker=BC03_REJECTED_HEAD_DETECTED
        oracle=oracle-bc03-rejected-is-head
        ;;
    BC03_STORED_IS_HEAD)
        marker=BC03_STORED_ROOT_HEAD_DETECTED
        oracle=oracle-bc03-stored-is-head
        ;;
    BC03_STORED_ROOT_SEPARATE)
        marker=BC03_STORED_ROOT_PUBLICATION_COLLAPSE_DETECTED
        oracle=oracle-bc03-stored-root-separate
        ;;
    BC03_WRONG_AUTHORITY_HEAD)
        marker=BC03_WRONG_AUTHORITY_HEAD_DETECTED
        oracle=oracle-bc03-wrong-authority-head
        ;;
    *)
        fail BC03_ASSERTION_INVALID
        ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

raw="$artifact_dir/raw-observations.tsv"
receipts="$artifact_dir/action-receipts.tsv"
seal="$artifact_dir/raw-seal.tsv"
normalized="$artifact_dir/normalized-observations.tsv"

[ -f "$raw" ] && [ -f "$receipts" ] && [ -f "$seal" ] &&
    [ -f "$normalized" ] || fail BC03_REQUIRED_ARTIFACT_MISSING

raw_sha=$(sha256sum "$raw" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$raw" | tr -d ' ')
receipt_sha=$(sha256sum "$receipts" | awk '{ print $1 }')
awk -F '	' -v raw_sha="$raw_sha" -v raw_bytes="$raw_bytes" \
    -v receipt_sha="$receipt_sha" -v run="$run" -v ns="$namespace" \
    -v scenario="$scenario" '
    NF != 9 || $1 != "raw-observations.tsv" || $2 != "100644" ||
        $3 != raw_sha || $4 != raw_bytes || $5 != run || $6 != ns ||
        $7 != scenario || $8 != receipt_sha ||
        $9 != "sealed-before-normalization" { exit 1 }
    { count++ }
    END { if (count != 1) exit 1 }
' "$seal" || fail BC03_RAW_SEAL_INVALID

for stage in before after reopened
do
    template="$base_dir/bc03-inventory-$stage.tsv"
    awk -F '	' -v scenario="$scenario" '$1 == scenario' "$template" |
        LC_ALL=C sort >"$tmp/inventory-$stage.expected"
    LC_ALL=C sort "$artifact_dir/inventory-$stage.tsv" \
        >"$tmp/inventory-$stage.actual"
    cmp -s "$tmp/inventory-$stage.expected" \
        "$tmp/inventory-$stage.actual" || fail "$marker"
done

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc03-raw-template.tsv" | LC_ALL=C sort >"$tmp/raw.expected"
LC_ALL=C sort "$raw" >"$tmp/raw.actual"
cmp -s "$tmp/raw.expected" "$tmp/raw.actual" || fail "$marker"

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc03-normalized-contract.tsv" |
    LC_ALL=C sort >"$tmp/normalized.expected"
LC_ALL=C sort "$normalized" >"$tmp/normalized.actual"
cmp -s "$tmp/normalized.expected" "$tmp/normalized.actual" ||
    fail "$marker"

awk -F '	' -v run="$run" -v ns="$namespace" -v scenario="$scenario" \
    -v case_id="$case_id" '
    NF != 13 || $1 != run || $2 != ns || $3 != scenario ||
        $4 != case_id { exit 1 }
    $5 == "sut-setup-bc03" { setup++; next }
    { action++ }
    END { if (setup != 1 || action != 1) exit 1 }
' "$receipts" || fail "$marker"

printf '%s\t%s\tPASS\tnorm-bc03-observation\tnormal\t-\n' \
    "$assertion" "$oracle"
