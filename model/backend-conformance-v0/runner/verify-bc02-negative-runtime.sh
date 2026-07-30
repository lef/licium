#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
registry="$base_dir/sqlite-partial-bc02-negative-execution.tsv"

[ "$#" -eq 4 ] || {
    echo "usage: verify-bc02-negative-runtime.sh WORK_DIR RECEIPT RUN NS_PREFIX" >&2
    exit 2
}

work_dir=$1
receipt=$2
run=$3
namespace_prefix=$4

fail()
{
    echo "$1" >&2
    exit 1
}

[ -f "$receipt" ] && [ ! -L "$receipt" ] ||
    fail BC02_NEGATIVE_RECEIPT_MISSING

awk -F '	' '
    NF != 8 || $1 !~ /^neg-bc02-/ || $2 !~ /^(sut-mutant|counterfactual|fault)$/ ||
        $3 !~ /^mutant-/ || $4 !~ /^BC02_/ || $5 !~ /^BC02_/ ||
        $6 != $5 || $7 !~ /^[1-9][0-9]*$/ ||
        $8 !~ /^[0-9a-f][0-9a-f]*$/ { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 6) exit 1 }
' "$receipt" || fail BC02_NEGATIVE_RECEIPT_SHAPE_INVALID

while IFS='	' read -r negative_id class mutation assertion expected_marker \
    scenario execution_mode evidence_name
do
    row=$(awk -F '	' -v id="$negative_id" '$1 == id' "$receipt")
    [ -n "$row" ] || fail BC02_NEGATIVE_RECEIPT_BINDING_INVALID
    [ "$(printf '%s\n' "$row" | wc -l | tr -d ' ')" -eq 1 ] ||
        fail BC02_NEGATIVE_RECEIPT_BINDING_INVALID
    printf '%s\n' "$row" | awk -F '	' \
        -v class="$class" -v mutation="$mutation" -v assertion="$assertion" \
        -v marker="$expected_marker" '
        $2 != class || $3 != mutation || $4 != assertion ||
            $5 != marker || $6 != marker { exit 1 }
    ' || fail BC02_NEGATIVE_RECEIPT_BINDING_INVALID

    negative_dir="$work_dir/$negative_id"
    result="$negative_dir/runtime-result.tsv"
    evidence="$negative_dir/$evidence_name"
    [ -f "$result" ] && [ ! -L "$result" ] &&
        [ -f "$evidence" ] && [ ! -L "$evidence" ] ||
        fail BC02_NEGATIVE_EVIDENCE_MISSING
    status=$(cut -f1 "$result")
    runtime_marker=$(cut -f2 "$result")
    classified_marker=$(cut -f3 "$result")
    [ "$status" -ne 0 ] 2>/dev/null &&
        [ "$runtime_marker" = "BC02_ORACLE_MISMATCH" ] &&
        [ "$classified_marker" = "$expected_marker" ] &&
        [ "$(printf '%s\n' "$row" | cut -f6)" = "$classified_marker" ] ||
        fail BC02_NEGATIVE_EXECUTION_RESULT_INVALID
    [ "$(printf '%s\n' "$row" | cut -f7)" = "$status" ] ||
        fail BC02_NEGATIVE_RECEIPT_BINDING_INVALID
    [ "$(printf '%s\n' "$row" | cut -f8)" = \
        "$(sha256sum "$evidence" | awk '{ print $1 }')" ] ||
        fail BC02_NEGATIVE_EVIDENCE_DIGEST_INVALID

    case "$evidence_name" in
        oracle-result.tsv)
            awk -F '	' 'NF == 8 && $7 == "FAIL" { ok++ }
                END { if (ok != 1) exit 1 }' "$evidence" ||
                fail BC02_NEGATIVE_SEMANTIC_EVIDENCE_INVALID
            ;;
    esac

    case "$negative_id" in
        neg-bc02-complete-available)
            awk -F '	' 'NF == 19 && $1 == "'"$run"'" &&
                $2 == "'"$namespace_prefix-$negative_id"'" &&
                $7 == "root-unavailable" && $14 == "rolled-back" &&
                $19 == "mutant-complete-as-unavailable" { ok++ }
                END { if (ok != 1) exit 1 }' \
                "$negative_dir/action-receipts.tsv"
            ;;
        neg-bc02-healthy-retry)
            awk -F '	' '$5 == "attempt-retry" &&
                $7 == "root-unavailable" && $14 == "rolled-back" &&
                $19 == "mutant-retry-rejected" { ok++ }
                END { if (ok != 1) exit 1 }' \
                "$negative_dir/action-receipts.tsv"
            ;;
        neg-bc02-incomplete-as-complete)
            awk -F '	' 'NF == 19 && $7 == "complete" && $10 == 3 &&
                $11 == 2 && $12 == 2 && $14 == "committed" &&
                $18 == "object-c" &&
                $19 == "mutant-incomplete-as-complete" { ok++ }
                END { if (ok != 1) exit 1 }' \
                "$negative_dir/action-receipts.tsv"
            ;;
        neg-bc02-partial-residue)
            awk -F '	' '$2 == "root" && $3 == "root-02" { root++ }
                $2 == "root-member" && $3 == "root-02/0001" { member++ }
                END { if (root < 1 || member < 1) exit 1 }' "$evidence"
            ;;
        neg-bc02-poisoned-retry)
            awk -F '	' '$5 == "attempt-retry" &&
                $7 == "root-unavailable" && $14 == "rolled-back" &&
                $19 == "mutant-poisoned-retry" { ok++ }
                END { if (ok != 1) exit 1 }' \
                "$negative_dir/action-receipts.tsv"
            ;;
        neg-bc02-rollback-complete)
            awk -F '	' '$2 == "root" && $3 == "root-02" { root++ }
                END { if (root < 1) exit 1 }' "$evidence"
            ;;
        *)
            exit 1
            ;;
    esac || fail BC02_NEGATIVE_SEMANTIC_EVIDENCE_INVALID
done <"$registry"

echo BC02_NEGATIVE_RUNTIME_VALID
