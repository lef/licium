#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc09-mutants.tsv"
runtime="$script_dir/run-bc09-runtime.sh"
verifier="$script_dir/verify-bc09-runtime.sh"

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
        echo BC09_CONTROL_EXECUTION_INVALID >&2
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
    target=$5
    directory="$tmp/$id"
    set +e
    observed=$(
        "$runtime" "$directory" "control-$run_id" \
            "control-$run_id-$id" "$assertion" mutant-persistent 2>&1
    )
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
    scenario=$(
        awk -F '	' -v assertion="$assertion" '
            $1 == assertion { print $3 }
        ' "$base_dir/bc09-scenario-ids.tsv"
    )
    [ -n "$scenario" ] || exit 2
    namespace="ns-$side-$scenario"
    directory="$tmp/$id"
    cp -R "$run_dir/$scenario" "$directory"
    case "$kind" in
        armed-unreached)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$12="false"} {print}
            ' "$directory/fault-trigger-receipts.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-trigger-receipts.tsv"
            evidence="$directory/fault-trigger-receipts.tsv"
            ;;
        command-custody)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$8="not-a-digest"} {print}
            ' "$directory/command-receipts.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/command-receipts.tsv"
            evidence="$directory/command-receipts.tsv"
            ;;
        db-unhealthy)
            sed '1d' "$directory/fault-inventory-reopened.tsv" \
                >"$directory/edit"
            mv "$directory/edit" "$directory/fault-inventory-reopened.tsv"
            evidence="$directory/fault-inventory-reopened.tsv"
            ;;
        duplicate-delivery)
            sed '1d' "$directory/action-receipts.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/action-receipts.tsv"
            evidence="$directory/action-receipts.tsv"
            ;;
        noop)
            : >"$directory/action-receipts.tsv"
            evidence="$directory/action-receipts.tsv"
            ;;
        observer-synthesis)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$6="forged"} {print}
            ' "$directory/normalized-observations.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/normalized-observations.tsv"
            evidence="$directory/normalized-observations.tsv"
            ;;
        raw-post-seal)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$6="forged"} {print}
            ' "$directory/raw-observations.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/raw-observations.tsv"
            evidence="$directory/raw-observations.tsv"
            ;;
        replayed-marker)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {nonce=$5}
                NR==2 {$5=nonce}
                {print}
            ' "$directory/fault-markers.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-markers.tsv"
            evidence="$directory/fault-markers.tsv"
            ;;
        rollback-drift)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$5="rev-drift"} {print}
            ' "$directory/fault-inventory-rollback.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-inventory-rollback.tsv"
            evidence="$directory/fault-inventory-rollback.tsv"
            ;;
        wrong-hook)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$7="hook-bc09-rejection-stale"} {print}
            ' "$directory/fault-trigger-receipts.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-trigger-receipts.tsv"
            evidence="$directory/fault-trigger-receipts.tsv"
            ;;
        wrong-phase)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$8="rejection-stale"} {print}
            ' "$directory/fault-trigger-receipts.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/fault-trigger-receipts.tsv"
            evidence="$directory/fault-trigger-receipts.tsv"
            ;;
        *) exit 2 ;;
    esac
    set +e
    observed=$(
        "$verifier" "$directory" "$run_id" "$namespace" "$assertion" \
            "$scenario" 2>&1
    )
    status=$?
    set -e
    record "$id" "$class" "$mutation" "$assertion" "$target" \
        "$observed" "$status" "$evidence"
}

while IFS='	' read -r id class mutation registry_target
do
    case "$id" in
        neg-bc09-diagnostic-ephemeral)
            semantic "$id" "$class" "$mutation" BC09_DIAGNOSTIC_EPHEMERAL \
                "$registry_target" ;;
        neg-bc09-duplicate-persists)
            semantic "$id" "$class" "$mutation" BC09_DUPLICATE_PERSISTS \
                "$registry_target" ;;
        neg-bc09-failpoint-persists)
            semantic "$id" "$class" "$mutation" BC09_FAILPOINT_PERSISTS \
                "$registry_target" ;;
        neg-bc09-failure-no-persistent-artifact)
            semantic "$id" "$class" "$mutation" \
                BC09_FAILURE_NO_PERSISTENT_ARTIFACT "$registry_target" ;;
        neg-bc09-incomplete-persists)
            semantic "$id" "$class" "$mutation" BC09_INCOMPLETE_PERSISTS \
                "$registry_target" ;;
        neg-bc09-rejected-persists)
            semantic "$id" "$class" "$mutation" BC09_REJECTED_PERSISTS \
                "$registry_target" ;;
        neg-bc09-stale-persists)
            semantic "$id" "$class" "$mutation" BC09_STALE_PERSISTS \
                "$registry_target" ;;
        harness-bc09-armed-unreached)
            harness "$id" "$class" "$mutation" BC09_FAILPOINT_PERSISTS \
                BC09_FAULT_TRIGGER_CONTRACT_INVALID armed-unreached ;;
        harness-bc09-command-custody)
            harness "$id" "$class" "$mutation" BC09_STALE_PERSISTS \
                BC09_COMMAND_CUSTODY_INVALID command-custody ;;
        harness-bc09-db-unhealthy)
            harness "$id" "$class" "$mutation" BC09_FAILPOINT_PERSISTS \
                BC09_FAULT_INVENTORY_CONTRACT_INVALID db-unhealthy ;;
        harness-bc09-duplicate-delivery)
            harness "$id" "$class" "$mutation" BC09_DUPLICATE_PERSISTS \
                BC09_ACTION_RECEIPT_CONTRACT_INVALID duplicate-delivery ;;
        harness-bc09-noop)
            harness "$id" "$class" "$mutation" BC09_STALE_PERSISTS \
                BC09_ACTION_RECEIPT_CONTRACT_INVALID noop ;;
        harness-bc09-observer-synthesis)
            harness "$id" "$class" "$mutation" BC09_STALE_PERSISTS \
                BC09_NORMALIZED_CONTRACT_INVALID observer-synthesis ;;
        harness-bc09-raw-post-seal-tamper)
            harness "$id" "$class" "$mutation" BC09_STALE_PERSISTS \
                BC09_RAW_SEAL_INVALID raw-post-seal ;;
        harness-bc09-replayed-marker)
            harness "$id" "$class" "$mutation" BC09_FAILPOINT_PERSISTS \
                BC09_FAULT_MARKER_CONTRACT_INVALID replayed-marker ;;
        harness-bc09-rollback-drift)
            harness "$id" "$class" "$mutation" BC09_FAILPOINT_PERSISTS \
                BC09_FAULT_INVENTORY_CONTRACT_INVALID rollback-drift ;;
        harness-bc09-wrong-hook)
            harness "$id" "$class" "$mutation" BC09_FAILPOINT_PERSISTS \
                BC09_FAULT_TRIGGER_CONTRACT_INVALID wrong-hook ;;
        harness-bc09-wrong-phase)
            harness "$id" "$class" "$mutation" BC09_FAILPOINT_PERSISTS \
                BC09_FAULT_TRIGGER_CONTRACT_INVALID wrong-phase ;;
        *) exit 2 ;;
    esac
done <"$mutants"

awk -F '	' 'NF != 8 || seen[$1]++ { exit 1 } { count++ }
    END { if (count != 18) exit 1 }' "$output" ||
    { echo BC09_RUN_CONTROL_RECEIPT_INVALID >&2; exit 1; }
