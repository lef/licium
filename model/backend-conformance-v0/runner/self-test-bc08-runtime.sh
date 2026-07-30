#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
runner="$script_dir/run-bc08-runtime.sh"
verifier="$script_dir/verify-bc08-runtime.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baseline=0
while IFS='	' read -r assertion _ _ _ _ _ _
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    output=$("$runner" "$tmp/$name" "run-$name" "ns-$name" "$assertion")
    [ "$output" = BC08_RUNTIME_VALID ] || exit 1
    baseline=$((baseline + 1))
done <"$base_dir/bc08-cases.tsv"

repro="$tmp/repro-bc08-complete-effect"
output=$(
    "$runner" "$repro" run-bc08-complete-effect \
        ns-bc08-complete-effect BC08_COMPLETE_EFFECT
)
[ "$output" = BC08_RUNTIME_VALID ] || exit 1
cmp -s "$tmp/bc08-complete-effect/command-receipts.tsv" \
    "$repro/command-receipts.tsv" || {
        echo BC08_RUNTIME_PATH_DEPENDENT >&2
        exit 1
    }
echo BC08_RUNTIME_PATH_INDEPENDENT

run_semantic_control()
{
    assertion=$1
    mode=$2
    expected=$3
    set +e
    output=$("$runner" "$tmp/control-$assertion" "run-control-$assertion" \
        "ns-control-$assertion" "$assertion" "$mode" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || exit 1
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "wrong BC08 marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_semantic_control BC08_COMPLETE_EFFECT \
    mutant-incomplete-effect-set BC08_INCOMPLETE_EFFECT_DETECTED
run_semantic_control BC08_MID_BOUNDARY_FAILURE \
    mutant-mid-boundary-partial-effect BC08_PARTIAL_EFFECT_DETECTED
run_semantic_control BC08_MISSING_CURRENT \
    mutant-missing-current BC08_MISSING_CURRENT_DETECTED
run_semantic_control BC08_MISSING_OBSERVATION \
    mutant-missing-observation BC08_MISSING_OBSERVATION_DETECTED
run_semantic_control BC08_MISSING_RESULT \
    mutant-missing-result BC08_MISSING_RESULT_DETECTED
run_semantic_control BC08_MISSING_TRANSITION \
    mutant-missing-transition BC08_MISSING_TRANSITION_DETECTED
run_semantic_control BC08_MISSING_VIEW \
    mutant-missing-view BC08_MISSING_VIEW_DETECTED

normal="$tmp/bc08-complete-effect"
boundary="$tmp/bc08-mid-boundary-failure"

verify_mutation()
{
    source=$1
    id=$2
    expected=$3
    assertion=$4
    case_id=$5
    scenario=$6
    work="$tmp/harness-$id"
    cp -R "$source" "$work"
    case "$id" in
        action-missing)
            : >"$work/action-receipts.tsv"
            ;;
        normalized-without-raw)
            sed '1d' "$work/raw-observations.tsv" >"$work/edit"
            mv "$work/edit" "$work/raw-observations.tsv"
            raw_sha=$(sha256sum "$work/raw-observations.tsv" |
                awk '{ print $1 }')
            raw_bytes=$(wc -c <"$work/raw-observations.tsv" | tr -d ' ')
            receipt_sha=$(sha256sum "$work/action-receipts.tsv" |
                awk '{ print $1 }')
            printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
                "$raw_sha" "$raw_bytes" "run-bc08-complete-effect" \
                "ns-bc08-complete-effect" "$scenario" "$receipt_sha" \
                >"$work/raw-seal.tsv"
            ;;
        raw-post-seal)
            printf '%s\traw-forged\tforged\tforged\tforged\tforged\n' \
                "$scenario" >>"$work/raw-observations.tsv"
            ;;
        wrong-hook)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$7="hook-bc08-after-transition"} {print}' \
                "$work/fault-trigger-receipts.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-trigger-receipts.tsv"
            ;;
        wrong-phase)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$8="after-transition"} {print}' \
                "$work/fault-trigger-receipts.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-trigger-receipts.tsv"
            ;;
        armed-unreached)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$12="false"} {print}' \
                "$work/fault-trigger-receipts.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-trigger-receipts.tsv"
            ;;
        replayed-marker)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==2 {$4=first_ns; $5=first_nonce}
                NR==1 {first_ns=$4; first_nonce=$5} {print}' \
                "$work/fault-markers.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-markers.tsv"
            ;;
        rollback-drift)
            awk -F '	' 'BEGIN { OFS=FS }
                NR==1 {$5="rev-drift"} {print}' \
                "$work/fault-inventory-rollback.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-inventory-rollback.tsv"
            ;;
        db-unhealthy)
            sed '1d' "$work/fault-inventory-reopened.tsv" >"$work/edit"
            mv "$work/edit" "$work/fault-inventory-reopened.tsv"
            ;;
        *) exit 2 ;;
    esac
    set +e
    output=$("$verifier" "$work" "run-$(
        printf '%s' "$assertion" | tr 'A-Z_' 'a-z-'
    )" "ns-$(
        printf '%s' "$assertion" | tr 'A-Z_' 'a-z-'
    )" "$assertion" "$case_id" "$scenario" "$work/nonexistent.db" \
        ordinary 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || exit 1
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "wrong BC08 harness marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

normal_assertion=BC08_COMPLETE_EFFECT
normal_case=case-bc08-complete
normal_scenario=bc08-complete-effect--case-bc08-complete
verify_mutation "$normal" action-missing BC08_SUT_ACTION_MISSING \
    "$normal_assertion" "$normal_case" "$normal_scenario"
verify_mutation "$normal" normalized-without-raw BC08_COVERAGE_INVALID \
    "$normal_assertion" "$normal_case" "$normal_scenario"
verify_mutation "$normal" raw-post-seal BC08_RAW_SEAL_INVALID \
    "$normal_assertion" "$normal_case" "$normal_scenario"

boundary_assertion=BC08_MID_BOUNDARY_FAILURE
boundary_case=case-bc08-boundary
boundary_scenario=bc08-mid-boundary-failure--case-bc08-boundary
verify_mutation "$boundary" wrong-hook BC08_FAULT_HOOK_INVALID \
    "$boundary_assertion" "$boundary_case" "$boundary_scenario"
verify_mutation "$boundary" wrong-phase BC08_FAULT_PHASE_INVALID \
    "$boundary_assertion" "$boundary_case" "$boundary_scenario"
verify_mutation "$boundary" armed-unreached BC08_FAULT_UNREACHED \
    "$boundary_assertion" "$boundary_case" "$boundary_scenario"
verify_mutation "$boundary" replayed-marker BC08_FAULT_REPLAY_DETECTED \
    "$boundary_assertion" "$boundary_case" "$boundary_scenario"
verify_mutation "$boundary" rollback-drift \
    BC08_ROLLBACK_INVENTORY_INVALID "$boundary_assertion" \
    "$boundary_case" "$boundary_scenario"
verify_mutation "$boundary" db-unhealthy BC08_FAULT_RECOVERY_INVALID \
    "$boundary_assertion" "$boundary_case" "$boundary_scenario"

printf '%s BC08 runtime baselines valid\n' "$baseline"
echo "16 BC08 runtime controls detected"
