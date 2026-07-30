#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: classify-bc02-negative.sh NEGATIVE_ID EVIDENCE_DIR" >&2
    exit 2
}

negative_id=$1
directory=$2
action="$directory/action-receipts.tsv"

case "$negative_id" in
    neg-bc02-complete-available)
        awk -F '	' 'NF == 19 && $7 == "root-unavailable" &&
            $14 == "rolled-back" &&
            $19 == "mutant-complete-as-unavailable" { ok++ }
            END { if (ok != 1) exit 1 }' "$action"
        marker=BC02_COMPLETE_ROOT_REQUIRED
        ;;
    neg-bc02-healthy-retry)
        awk -F '	' '$5 == "attempt-retry" &&
            $7 == "root-unavailable" && $14 == "rolled-back" &&
            $19 == "mutant-retry-rejected" { ok++ }
            END { if (ok != 1) exit 1 }' "$action"
        marker=BC02_HEALTHY_RETRY_REQUIRED
        ;;
    neg-bc02-incomplete-as-complete)
        awk -F '	' 'NF == 19 && $7 == "complete" && $10 == 3 &&
            $11 == 2 && $12 == 2 && $14 == "committed" &&
            $18 == "object-c" &&
            $19 == "mutant-incomplete-as-complete" { ok++ }
            END { if (ok != 1) exit 1 }' "$action"
        marker=BC02_INCOMPLETE_ROOT_ACCEPTED
        ;;
    neg-bc02-partial-residue)
        evidence="$directory/inventory-rollback-after.tsv"
        awk -F '	' '$2 == "root" && $3 == "root-02" { root++ }
            $2 == "root-member" && $3 == "root-02/0001" { member++ }
            END { if (root < 1 || member < 1) exit 1 }' "$evidence"
        marker=BC02_PARTIAL_ROOT_RESIDUE
        ;;
    neg-bc02-poisoned-retry)
        awk -F '	' '$5 == "attempt-retry" &&
            $7 == "root-unavailable" && $14 == "rolled-back" &&
            $19 == "mutant-poisoned-retry" { ok++ }
            END { if (ok != 1) exit 1 }' "$action"
        marker=BC02_POISONED_RETRY_DETECTED
        ;;
    neg-bc02-rollback-complete)
        evidence="$directory/inventory-rollback-after.tsv"
        awk -F '	' '$2 == "root" && $3 == "root-02" { root++ }
            END { if (root < 1) exit 1 }' "$evidence"
        marker=BC02_ROLLBACK_INCOMPLETE
        ;;
    *)
        exit 2
        ;;
esac

printf '%s\n' "$marker"
