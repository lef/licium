#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc08-mutants.tsv"
runtime="$script_dir/run-bc08-runtime.sh"
verifier="$script_dir/verify-bc08-runtime.sh"

[ "$#" -eq 3 ] || exit 2
run_dir=$1
run_id=$2
output=$3
side=${run_id#run-}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: >"$output"

record()
{
    id=$1
    class=$2
    mutation=$3
    assertion=$4
    target=$5
    observed=$6
    status=$7
    evidence=$8
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC08_CONTROL_EXECUTION_INVALID >&2
        exit 1
    }
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$class" "$mutation" "$assertion" "$target" "$observed" \
        "$status" "$(sha256sum "$evidence" | awk '{ print $1 }')" \
        >>"$output"
}

semantic()
{
    id=$1
    class=$2
    mutation=$3
    assertion=$4
    mode=$5
    target=$6
    directory="$tmp/$id"
    set +e
    observed=$("$runtime" "$directory" "control-$run_id" \
        "control-$run_id-$id" "$assertion" "$mode" 2>&1)
    status=$?
    set -e
    record "$id" "$class" "$mutation" "$assertion" "$target" \
        "$observed" "$status" "$directory/action-receipts.tsv"
}

harness()
{
    id=$1
    class=$2
    mutation=$3
    assertion=$4
    target=$5
    kind=$6
    case "$assertion" in
        BC08_COMPLETE_EFFECT)
            case_id=case-bc08-complete
            scenario=bc08-complete-effect--case-bc08-complete ;;
        BC08_MID_BOUNDARY_FAILURE)
            case_id=case-bc08-boundary
            scenario=bc08-mid-boundary-failure--case-bc08-boundary ;;
        *) exit 2 ;;
    esac
    namespace="ns-$side-$scenario"
    directory="$tmp/$id"
    cp -R "$run_dir/$scenario" "$directory"
    case "$kind" in
        action)
            : >"$directory/action-receipts.tsv"
            evidence="$directory/action-receipts.tsv" ;;
        coverage)
            sed '1d' "$directory/raw-observations.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/raw-observations.tsv"
            raw_sha=$(sha256sum "$directory/raw-observations.tsv" |
                awk '{ print $1 }')
            raw_bytes=$(wc -c <"$directory/raw-observations.tsv" |
                tr -d ' ')
            receipt_sha=$(sha256sum "$directory/action-receipts.tsv" |
                awk '{ print $1 }')
            printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
                "$raw_sha" "$raw_bytes" "$run_id" "$namespace" \
                "$scenario" "$receipt_sha" >"$directory/raw-seal.tsv"
            evidence="$directory/raw-observations.tsv" ;;
        raw)
            printf '%s\traw-forged\tforged\tforged\tforged\tforged\n' \
                "$scenario" >>"$directory/raw-observations.tsv"
            evidence="$directory/raw-observations.tsv" ;;
        hook)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$7="hook-bc08-after-transition"} {print}' \
                "$directory/fault-trigger-receipts.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-trigger-receipts.tsv"
            evidence="$directory/fault-trigger-receipts.tsv" ;;
        phase)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$8="after-transition"} {print}' \
                "$directory/fault-trigger-receipts.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-trigger-receipts.tsv"
            evidence="$directory/fault-trigger-receipts.tsv" ;;
        unreached)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$12="false"} {print}' \
                "$directory/fault-trigger-receipts.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-trigger-receipts.tsv"
            evidence="$directory/fault-trigger-receipts.tsv" ;;
        replay)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {ns=$4; nonce=$5}
                NR==2 {$4=ns; $5=nonce} {print}' \
                "$directory/fault-markers.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-markers.tsv"
            evidence="$directory/fault-markers.tsv" ;;
        rollback)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$5="rev-drift"} {print}' \
                "$directory/fault-inventory-rollback.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-inventory-rollback.tsv"
            evidence="$directory/fault-inventory-rollback.tsv" ;;
        unhealthy)
            sed '1d' "$directory/fault-inventory-reopened.tsv" \
                >"$directory/edit"
            mv "$directory/edit" "$directory/fault-inventory-reopened.tsv"
            evidence="$directory/fault-inventory-reopened.tsv" ;;
        *) exit 2 ;;
    esac
    set +e
    observed=$("$verifier" "$directory" "$run_id" "$namespace" \
        "$assertion" "$case_id" "$scenario" "$directory/nonexistent.db" \
        ordinary 2>&1)
    status=$?
    set -e
    record "$id" "$class" "$mutation" "$assertion" "$target" \
        "$observed" "$status" "$evidence"
}

while IFS='	' read -r id class mutation target
do
    case "$id" in
        neg-bc08-complete-effect)
            semantic "$id" "$class" "$mutation" BC08_COMPLETE_EFFECT \
                mutant-incomplete-effect-set "$target" ;;
        neg-bc08-mid-boundary-failure)
            semantic "$id" "$class" "$mutation" \
                BC08_MID_BOUNDARY_FAILURE \
                mutant-mid-boundary-partial-effect "$target" ;;
        neg-bc08-missing-current)
            semantic "$id" "$class" "$mutation" BC08_MISSING_CURRENT \
                mutant-missing-current "$target" ;;
        neg-bc08-missing-observation)
            semantic "$id" "$class" "$mutation" BC08_MISSING_OBSERVATION \
                mutant-missing-observation "$target" ;;
        neg-bc08-missing-result)
            semantic "$id" "$class" "$mutation" BC08_MISSING_RESULT \
                mutant-missing-result "$target" ;;
        neg-bc08-missing-transition)
            semantic "$id" "$class" "$mutation" BC08_MISSING_TRANSITION \
                mutant-missing-transition "$target" ;;
        neg-bc08-missing-view)
            semantic "$id" "$class" "$mutation" BC08_MISSING_VIEW \
                mutant-missing-view "$target" ;;
        harness-bc08-noop)
            harness "$id" "$class" "$mutation" BC08_COMPLETE_EFFECT \
                "$target" action ;;
        harness-bc08-observer-synthesis)
            harness "$id" "$class" "$mutation" BC08_COMPLETE_EFFECT \
                "$target" coverage ;;
        harness-bc08-raw-post-seal-tamper)
            harness "$id" "$class" "$mutation" BC08_COMPLETE_EFFECT \
                "$target" raw ;;
        harness-bc08-wrong-hook)
            harness "$id" "$class" "$mutation" \
                BC08_MID_BOUNDARY_FAILURE "$target" hook ;;
        harness-bc08-wrong-phase)
            harness "$id" "$class" "$mutation" \
                BC08_MID_BOUNDARY_FAILURE "$target" phase ;;
        harness-bc08-armed-unreached)
            harness "$id" "$class" "$mutation" \
                BC08_MID_BOUNDARY_FAILURE "$target" unreached ;;
        harness-bc08-replayed-marker)
            harness "$id" "$class" "$mutation" \
                BC08_MID_BOUNDARY_FAILURE "$target" replay ;;
        harness-bc08-rollback-drift)
            harness "$id" "$class" "$mutation" \
                BC08_MID_BOUNDARY_FAILURE "$target" rollback ;;
        harness-bc08-db-unhealthy)
            harness "$id" "$class" "$mutation" \
                BC08_MID_BOUNDARY_FAILURE "$target" unhealthy ;;
        *) exit 2 ;;
    esac
done <"$mutants"

awk -F '	' 'NF != 8 || seen[$1]++ { exit 1 } { count++ }
    END { if (count != 16) exit 1 }' "$output" ||
    { echo BC08_RUN_CONTROL_RECEIPT_INVALID >&2; exit 1; }
