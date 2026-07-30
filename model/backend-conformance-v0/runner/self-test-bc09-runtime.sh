#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
runner="$script_dir/run-bc09-runtime.sh"
verifier="$script_dir/verify-bc09-runtime.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baselines=0
while IFS= read -r assertion
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    output=$(
        "$runner" "$tmp/$name" "run-$name" "ns-$name" "$assertion"
    )
    [ "$output" = "BC09_RUNTIME_CONTRACT_VALID
BC09_RUNTIME_VALID" ] || exit 1
    baselines=$((baselines + 1))
done <<'EOF'
BC09_DIAGNOSTIC_EPHEMERAL
BC09_DUPLICATE_PERSISTS
BC09_FAILPOINT_PERSISTS
BC09_FAILURE_NO_PERSISTENT_ARTIFACT
BC09_INCOMPLETE_PERSISTS
BC09_REJECTED_PERSISTS
BC09_STALE_PERSISTS
EOF

run_semantic_control()
{
    assertion=$1
    expected=$2
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    set +e
    output=$(
        "$runner" "$tmp/semantic-$name" "run-semantic-$name" \
            "ns-semantic-$name" "$assertion" mutant-persistent 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$output" = "$expected" ] || {
        echo "wrong BC09 semantic marker: $output, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_semantic_control BC09_DIAGNOSTIC_EPHEMERAL \
    BC09_DIAGNOSTIC_PERSISTENCE_DETECTED
run_semantic_control BC09_DUPLICATE_PERSISTS \
    BC09_DUPLICATE_ARTIFACT_DETECTED
run_semantic_control BC09_FAILPOINT_PERSISTS \
    BC09_FAILPOINT_ARTIFACT_DETECTED
run_semantic_control BC09_FAILURE_NO_PERSISTENT_ARTIFACT \
    BC09_PERSISTENT_ARTIFACT_DETECTED
run_semantic_control BC09_INCOMPLETE_PERSISTS \
    BC09_INCOMPLETE_ARTIFACT_DETECTED
run_semantic_control BC09_REJECTED_PERSISTS \
    BC09_REJECTED_ARTIFACT_DETECTED
run_semantic_control BC09_STALE_PERSISTS \
    BC09_STALE_ARTIFACT_DETECTED

verify_mutation()
{
    source=$1
    id=$2
    expected=$3
    assertion=$4
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    scenario=$(
        awk -F '	' -v assertion="$assertion" '
            $1 == assertion { print $3 }
        ' "$base_dir/bc09-scenario-ids.tsv"
    )
    work="$tmp/harness-$id"
    cp -R "$source" "$work"

    case "$id" in
        armed-unreached)
            awk -F '	' 'BEGIN { OFS=FS } NR==1 {$12="false"} {print}' \
                "$work/fault-trigger-receipts.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-trigger-receipts.tsv"
            ;;
        command-custody)
            awk -F '	' 'BEGIN { OFS=FS } NR==1 {$8="not-a-digest"} {print}' \
                "$work/command-receipts.tsv" >"$work/edit"
            mv "$work/edit" "$work/command-receipts.tsv"
            ;;
        db-unhealthy)
            sed '1d' "$work/fault-inventory-reopened.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-inventory-reopened.tsv"
            ;;
        duplicate-delivery)
            sed '1d' "$work/action-receipts.tsv" >"$work/edit"
            mv "$work/edit" "$work/action-receipts.tsv"
            ;;
        noop)
            : >"$work/action-receipts.tsv"
            ;;
        observer-synthesis)
            awk -F '	' 'BEGIN { OFS=FS } NR==1 {$6="forged"} {print}' \
                "$work/normalized-observations.tsv" >"$work/edit"
            mv "$work/edit" "$work/normalized-observations.tsv"
            ;;
        raw-post-seal)
            awk -F '	' 'BEGIN { OFS=FS } NR==1 {$6="forged"} {print}' \
                "$work/raw-observations.tsv" >"$work/edit"
            mv "$work/edit" "$work/raw-observations.tsv"
            ;;
        replayed-marker)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {nonce=$5}
                NR==2 {$5=nonce}
                {print}
            ' "$work/fault-markers.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-markers.tsv"
            ;;
        rollback-drift)
            awk -F '	' 'BEGIN { OFS=FS } NR==1 {$5="rev-drift"} {print}' \
                "$work/fault-inventory-rollback.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-inventory-rollback.tsv"
            ;;
        wrong-hook)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$7="hook-bc09-rejection-stale"} {print}
            ' "$work/fault-trigger-receipts.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-trigger-receipts.tsv"
            ;;
        wrong-phase)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$8="rejection-stale"} {print}
            ' "$work/fault-trigger-receipts.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-trigger-receipts.tsv"
            ;;
        *)
            exit 2
            ;;
    esac

    set +e
    output=$(
        "$verifier" "$work" "run-$name" "ns-$name" "$assertion" \
            "$scenario" 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$output" = "$expected" ] || {
        echo "wrong BC09 harness marker: $output, expected $expected" >&2
        exit 1
    }
    printf 'ok harness %s\n' "$id"
}

stale="$tmp/bc09-stale-persists"
duplicate="$tmp/bc09-duplicate-persists"
failpoint="$tmp/bc09-failpoint-persists"

verify_mutation "$failpoint" armed-unreached \
    BC09_FAULT_TRIGGER_CONTRACT_INVALID BC09_FAILPOINT_PERSISTS
verify_mutation "$stale" command-custody \
    BC09_COMMAND_CUSTODY_INVALID BC09_STALE_PERSISTS
verify_mutation "$failpoint" db-unhealthy \
    BC09_FAULT_INVENTORY_CONTRACT_INVALID BC09_FAILPOINT_PERSISTS
verify_mutation "$duplicate" duplicate-delivery \
    BC09_ACTION_RECEIPT_CONTRACT_INVALID BC09_DUPLICATE_PERSISTS
verify_mutation "$stale" noop \
    BC09_ACTION_RECEIPT_CONTRACT_INVALID BC09_STALE_PERSISTS
verify_mutation "$stale" observer-synthesis \
    BC09_NORMALIZED_CONTRACT_INVALID BC09_STALE_PERSISTS
verify_mutation "$stale" raw-post-seal \
    BC09_RAW_SEAL_INVALID BC09_STALE_PERSISTS
verify_mutation "$failpoint" replayed-marker \
    BC09_FAULT_MARKER_CONTRACT_INVALID BC09_FAILPOINT_PERSISTS
verify_mutation "$failpoint" rollback-drift \
    BC09_FAULT_INVENTORY_CONTRACT_INVALID BC09_FAILPOINT_PERSISTS
verify_mutation "$failpoint" wrong-hook \
    BC09_FAULT_TRIGGER_CONTRACT_INVALID BC09_FAILPOINT_PERSISTS
verify_mutation "$failpoint" wrong-phase \
    BC09_FAULT_TRIGGER_CONTRACT_INVALID BC09_FAILPOINT_PERSISTS

printf '%s BC09 runtime baselines valid\n' "$baselines"
echo "18 BC09 runtime controls detected"
