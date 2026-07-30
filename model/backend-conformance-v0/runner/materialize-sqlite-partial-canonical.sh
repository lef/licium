#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
scenarios="$base_dir/sqlite-partial-scenarios.tsv"
inventory_map="$base_dir/bc02-inventory-map.tsv"

[ "$#" -eq 2 ] || {
    echo "usage: materialize-sqlite-partial-canonical.sh RUN_DIR OUTPUT" >&2
    exit 2
}

run_dir=$1
output=$2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: >"$tmp/relations.tsv"

while IFS='	' read -r ordinal suite assertion case_id scenario \
    runner_path verifier_path evidence_policy
do
    case "$suite" in
        BC01)
            for relation in \
                coverage.tsv inventory-after.tsv inventory-before.tsv \
                inventory-reopened.tsv normalized-observations.tsv \
                oracle-result.tsv raw-observations.tsv
            do
                printf '%s\t%s\t%s\n' "$suite" "$scenario" "$relation" \
                    >>"$tmp/relations.tsv"
            done
            ;;
        BC02)
            for relation in \
                coverage.tsv normalized-observations.tsv oracle-result.tsv
            do
                printf '%s\t%s\t%s\n' "$suite" "$scenario" "$relation" \
                    >>"$tmp/relations.tsv"
            done
            awk -F '	' -v OFS='	' -v suite="$suite" \
                -v scenario="$scenario" -v assertion="$assertion" \
                -v case_id="$case_id" '
                $1 == assertion && $2 == case_id {
                    print suite,scenario,$4
                }
            ' "$inventory_map" >>"$tmp/relations.tsv"
            ;;
        BC03|BC04|BC05|BC07)
            for relation in \
                coverage.tsv inventory-after.tsv inventory-before.tsv \
                inventory-reopened.tsv normalized-observations.tsv \
                oracle-result.tsv raw-observations.tsv
            do
                printf '%s\t%s\t%s\n' "$suite" "$scenario" "$relation" \
                    >>"$tmp/relations.tsv"
            done
            ;;
        BC06)
            for relation in \
                coverage.tsv inventory-after.tsv inventory-before.tsv \
                normalized-observations.tsv oracle-result.tsv \
                raw-observations.tsv
            do
                printf '%s\t%s\t%s\n' "$suite" "$scenario" "$relation" \
                    >>"$tmp/relations.tsv"
            done
            ;;
        BC08|BC09)
            for relation in \
                coverage.tsv fault-activation-receipts.tsv \
                fault-configuration-receipts.tsv \
                fault-inventory-healthy.tsv fault-inventory-reopened.tsv \
                fault-inventory-rollback.tsv fault-inventory-setup.tsv \
                fault-markers.tsv fault-trigger-receipts.tsv \
                inventory-after.tsv inventory-before.tsv \
                inventory-reopened.tsv normalized-observations.tsv \
                oracle-result.tsv raw-observations.tsv
            do
                printf '%s\t%s\t%s\n' "$suite" "$scenario" "$relation" \
                    >>"$tmp/relations.tsv"
            done
            ;;
        BC10|BC11|BC12)
            for relation in \
                coverage.tsv normalized-observations.tsv \
                oracle-result.tsv raw-observations.tsv
            do
                printf '%s\t%s\t%s\n' "$suite" "$scenario" "$relation" \
                    >>"$tmp/relations.tsv"
            done
            ;;
        *)
            exit 1
            ;;
    esac
done <"$scenarios"

LC_ALL=C sort -u "$tmp/relations.tsv" |
while IFS='	' read -r suite scenario relation
do
    file="$run_dir/$scenario/$relation"
    [ -f "$file" ] && [ ! -L "$file" ] || exit 1
    projected=$file
    if [ "$suite" = BC08 ] || [ "$suite" = BC09 ]; then
        projected="$tmp/projected.tsv"
        case "$relation" in
            fault-activation-receipts.tsv)
                awk -F '	' 'BEGIN { OFS=FS }
                    {$1="{run}"; $2="{namespace}"; $9="{nonce}"; print}
                ' "$file" >"$projected" ;;
            fault-configuration-receipts.tsv)
                awk -F '	' 'BEGIN { OFS=FS }
                    {$1="{run}"; $2="{namespace}"; $7="{nonce}";
                     $9="{activation-sha256}"; print}
                ' "$file" >"$projected" ;;
            fault-trigger-receipts.tsv)
                awk -F '	' 'BEGIN { OFS=FS }
                    {$1="{run}"; $2="{namespace}"; $9="{nonce}";
                     $11="{activation-sha256}"; print}
                ' "$file" >"$projected" ;;
            fault-markers.tsv)
                awk -F '	' 'BEGIN { OFS=FS }
                    {$2="{run}"; $4="{namespace}"; $5="{nonce}"; print}
                ' "$file" >"$projected" ;;
            *) projected=$file ;;
        esac
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$suite" "$scenario" "$relation" \
        "$(sha256sum "$projected" | awk '{ print $1 }')" \
        "$(wc -c <"$projected" | tr -d ' ')"
done >"$output"

chmod 0644 "$output"
