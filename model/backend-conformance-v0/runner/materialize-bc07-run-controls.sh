#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc07-mutants.tsv"
runtime_runner="$script_dir/run-bc07-runtime.sh"
runtime_verifier="$script_dir/verify-bc07-runtime.sh"

[ "$#" -eq 3 ] || exit 2
run_dir=$1
run_id=$2
output=$3
side=${run_id#run-}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: >"$output"

record_runtime()
{
    id=$1
    class=$2
    mutation=$3
    assertion=$4
    mode=$5
    target=$6
    directory="$tmp/$id"
    set +e
    observed=$("$runtime_runner" "$directory" "control-$run_id" \
        "control-$run_id-$id" "$assertion" "$mode" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC07_CONTROL_EXECUTION_INVALID >&2
        exit 1
    }
    evidence_sha=$(sha256sum "$directory/normalized-observations.tsv" |
        awk '{ print $1 }')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$class" "$mutation" "$assertion" "$target" "$observed" \
        "$status" "$evidence_sha" >>"$output"
}

record_evidence()
{
    id=$1
    class=$2
    mutation=$3
    target=$4
    kind=$5
    assertion=BC07_EFFECT_101
    case_id=case-bc07-effect
    scenario=bc07-effect-101--case-bc07-effect
    namespace="ns-$side-$scenario"
    directory="$tmp/$id"
    cp -R "$run_dir/$scenario" "$directory"
    case "$kind" in
        action)
            : >"$directory/action-receipts.tsv"
            evidence="$directory/action-receipts.tsv"
            ;;
        normalized)
            sed '1d' "$directory/raw-observations.tsv" \
                >"$directory/raw-observations.tmp"
            mv "$directory/raw-observations.tmp" \
                "$directory/raw-observations.tsv"
            raw_sha=$(sha256sum "$directory/raw-observations.tsv" |
                awk '{ print $1 }')
            raw_bytes=$(wc -c <"$directory/raw-observations.tsv" |
                tr -d ' ')
            receipt_sha=$(sha256sum "$directory/action-receipts.tsv" |
                awk '{ print $1 }')
            printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
                "$raw_sha" "$raw_bytes" "$run_id" "$namespace" \
                "$scenario" "$receipt_sha" >"$directory/raw-seal.tsv"
            evidence="$directory/raw-observations.tsv"
            ;;
        raw)
            printf '%s\traw-forged\tforged\tafter\tvalue\tforged\n' \
                "$scenario" >>"$directory/raw-observations.tsv"
            evidence="$directory/raw-observations.tsv"
            ;;
        *) exit 2 ;;
    esac
    set +e
    observed=$("$runtime_verifier" "$directory" "$run_id" "$namespace" \
        "$assertion" "$case_id" "$scenario" "$directory/nonexistent.db" \
        ordinary 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC07_CONTROL_EXECUTION_INVALID >&2
        exit 1
    }
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$class" "$mutation" "$assertion" "$target" "$observed" \
        "$status" "$(sha256sum "$evidence" | awk '{ print $1 }')" \
        >>"$output"
}

while IFS='	' read -r id class mutation target
do
    case "$id" in
        neg-bc07-effect-101)
            record_runtime "$id" "$class" "$mutation" BC07_EFFECT_101 \
                mutant-effect-axis-mismatch "$target" ;;
        neg-bc07-observation-without-transition)
            record_runtime "$id" "$class" "$mutation" \
                BC07_OBSERVATION_WITHOUT_TRANSITION \
                mutant-orphan-observation "$target" ;;
        neg-bc07-ordinary-000)
            record_runtime "$id" "$class" "$mutation" BC07_ORDINARY_000 \
                mutant-ordinary-axis-write "$target" ;;
        neg-bc07-record-implies-effect)
            record_runtime "$id" "$class" "$mutation" \
                BC07_RECORD_IMPLIES_EFFECT mutant-record-state-effect \
                "$target" ;;
        neg-bc07-record-only-010)
            record_runtime "$id" "$class" "$mutation" BC07_RECORD_ONLY_010 \
                mutant-record-axis-mismatch "$target" ;;
        neg-bc07-result-rewrite)
            record_runtime "$id" "$class" "$mutation" BC07_RESULT_REWRITE \
                mutant-effect-result-rewrite "$target" ;;
        harness-bc07-noop)
            record_evidence "$id" "$class" "$mutation" "$target" action ;;
        harness-bc07-observer-synthesis)
            record_evidence "$id" "$class" "$mutation" "$target" normalized ;;
        harness-bc07-raw-post-seal-tamper)
            record_evidence "$id" "$class" "$mutation" "$target" raw ;;
        *) echo BC07_CONTROL_INVENTORY_INVALID >&2; exit 1 ;;
    esac
done <"$mutants"

awk -F '	' 'NF != 8 || seen[$1]++ { exit 1 } { count++ }
    END { if (count != 9) exit 1 }' "$output" ||
    { echo BC07_RUN_CONTROL_RECEIPT_INVALID >&2; exit 1; }
