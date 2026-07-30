#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

[ "$#" -eq 6 ] || {
    echo "usage: oracle-bc01.sh ARTIFACT_DIR RUN NS ASSERTION CASE SCENARIO" >&2
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
    BC01_ASSOCIATION_IDEMPOTENT)
        marker=BC01_ASSOCIATION_DUPLICATION_DETECTED
        oracle=oracle-bc01-association-idempotent
        evidence=norm-bc01-observation
        ;;
    BC01_DISTINCT_OCCURRENCE)
        marker=BC01_DISTINCT_OCCURRENCE_COLLAPSE_DETECTED
        oracle=oracle-bc01-distinct-occurrence
        evidence=norm-bc01-observation
        ;;
    BC01_OCCURRENCE_COLLAPSE)
        marker=BC01_OCCURRENCE_COLLAPSE_DETECTED
        oracle=oracle-bc01-occurrence-collapse
        evidence=norm-bc01-observation
        ;;
    BC01_PAYLOAD_COLLISION)
        marker=BC01_PAYLOAD_COLLISION_ACCEPTED
        oracle=oracle-bc01-payload-collision
        evidence=norm-bc01-observation
        ;;
    BC01_RETRY_DUPLICATION)
        marker=BC01_RETRY_DUPLICATION_DETECTED
        oracle=oracle-bc01-retry-duplication
        evidence=norm-bc01-observation
        ;;
    *)
        fail BC01_ASSERTION_INVALID
        ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

raw="$artifact_dir/raw-observations.tsv"
seal="$artifact_dir/raw-seal.tsv"
receipts="$artifact_dir/action-receipts.tsv"
normalized="$artifact_dir/normalized-observations.tsv"

[ -f "$raw" ] && [ -f "$seal" ] && [ -f "$receipts" ] ||
    fail BC01_REQUIRED_ARTIFACT_MISSING

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
' "$seal" || fail BC01_RAW_SEAL_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" -v scenario="$scenario" \
    -v case_id="$case_id" '
    NF != 13 || $1 != run || $2 != ns || $3 != scenario ||
        $4 != case_id { exit 1 }
    $5 == "sut-setup-bc01" {
        if ($6 != "accepted" || $7 != "-" || $8 != "delivery-a" ||
            $9 != "occurrence-a" || $10 != "alice" ||
            $11 != "public-a" || $12 != "inserted") exit 1
        setup++
        next
    }
    { action++ }
    END { if (setup != 1 || action != 1) exit 1 }
' "$receipts" || fail "$marker"

for stage in before after reopened
do
    template="$base_dir/bc01-inventory-after.tsv"
    [ "$stage" = before ] &&
        template="$base_dir/bc01-inventory-before.tsv"
    awk -F '	' -v scenario="$scenario" '$1 == scenario' "$template" |
        LC_ALL=C sort >"$tmp/inventory-$stage.expected"
    LC_ALL=C sort "$artifact_dir/inventory-$stage.tsv" \
        >"$tmp/inventory-$stage.actual"
done

cmp -s "$tmp/inventory-before.expected" "$tmp/inventory-before.actual" ||
    fail BC01_BEFORE_INVENTORY_INVALID
cmp -s "$tmp/inventory-after.expected" "$tmp/inventory-after.actual" ||
    fail "$marker"
cmp -s "$tmp/inventory-reopened.expected" "$tmp/inventory-reopened.actual" ||
    fail "$marker"

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc01-raw-template.tsv" | LC_ALL=C sort >"$tmp/raw.expected"
LC_ALL=C sort "$raw" >"$tmp/raw.actual"
cmp -s "$tmp/raw.expected" "$tmp/raw.actual" || fail "$marker"

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc01-normalized-contract.tsv" |
    LC_ALL=C sort >"$tmp/normalized.expected"
LC_ALL=C sort "$normalized" >"$tmp/normalized.actual"
cmp -s "$tmp/normalized.expected" "$tmp/normalized.actual" || fail "$marker"

printf '%s\t%s\tPASS\t%s\tnormal\t-\n' \
    "$assertion" "$oracle" "$evidence"
