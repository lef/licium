#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc01-mutants.tsv"
runtime_runner="$script_dir/run-bc01-runtime.sh"
runtime_verifier="$script_dir/verify-bc01-runtime.sh"

[ "$#" -eq 3 ] || {
    echo "usage: materialize-bc01-run-controls.sh RUN_DIR RUN_ID OUTPUT" >&2
    exit 2
}

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
    evidence_name=$7
    directory="$tmp/$id"
    control_run="control-$run_id"
    control_ns="control-$run_id-$id"
    set +e
    observed=$("$runtime_runner" "$directory" "$control_run" \
        "$control_ns" "$assertion" "$mode" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC01_CONTROL_EXECUTION_INVALID >&2
        exit 1
    }
    evidence_sha=$(sha256sum "$directory/$evidence_name" | awk '{ print $1 }')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$class" "$mutation" "$assertion" "$target" "$target" \
        "$status" "$evidence_sha" >>"$output"
}

record_evidence()
{
    id=$1
    class=$2
    mutation=$3
    target=$4
    kind=$5
    assertion=BC01_ASSOCIATION_IDEMPOTENT
    case_id=case-bc01-retry
    scenario=bc01-association-idempotent--case-bc01-retry
    namespace="ns-$side-$scenario"
    directory="$tmp/$id"
    cp -R "$run_dir/$scenario" "$directory"
    case "$kind" in
        action)
            sed -n '1p' "$directory/action-receipts.tsv" \
                >"$directory/action-receipts.tsv.tmp"
            mv "$directory/action-receipts.tsv.tmp" \
                "$directory/action-receipts.tsv"
            evidence="$directory/action-receipts.tsv"
            ;;
        normalized)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $2 == "raw-009" { $2 = "raw-synthesized" }
                { print }
            ' "$directory/raw-observations.tsv" \
                >"$directory/raw-observations.tsv.tmp"
            mv "$directory/raw-observations.tsv.tmp" \
                "$directory/raw-observations.tsv"
            raw_sha=$(sha256sum "$directory/raw-observations.tsv" |
                awk '{ print $1 }')
            raw_bytes=$(wc -c <"$directory/raw-observations.tsv" |
                tr -d ' ')
            awk -F '	' -v OFS='	' -v sha="$raw_sha" \
                -v bytes="$raw_bytes" '
                { $3 = sha; $4 = bytes; print }
            ' "$directory/raw-seal.tsv" >"$directory/raw-seal.tsv.tmp"
            mv "$directory/raw-seal.tsv.tmp" "$directory/raw-seal.tsv"
            evidence="$directory/raw-observations.tsv"
            ;;
        raw)
            printf '\n' >>"$directory/raw-observations.tsv"
            evidence="$directory/raw-observations.tsv"
            ;;
        *)
            exit 2
            ;;
    esac
    set +e
    observed=$("$runtime_verifier" "$directory" "$run_id" "$namespace" \
        "$assertion" "$case_id" "$scenario" "$directory/nonexistent.db" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC01_CONTROL_EXECUTION_INVALID >&2
        exit 1
    }
    evidence_sha=$(sha256sum "$evidence" | awk '{ print $1 }')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$class" "$mutation" "$assertion" "$target" "$observed" \
        "$status" "$evidence_sha" >>"$output"
}

while IFS='	' read -r id class mutation target
do
    case "$id" in
        neg-bc01-association-idempotent)
            record_runtime "$id" "$class" "$mutation" \
                BC01_ASSOCIATION_IDEMPOTENT mutant-association-duplication \
                "$target" inventory-after.tsv
            ;;
        neg-bc01-distinct-occurrence)
            record_runtime "$id" "$class" "$mutation" \
                BC01_DISTINCT_OCCURRENCE mutant-distinct-collapse \
                "$target" inventory-after.tsv
            ;;
        neg-bc01-occurrence-collapse)
            record_runtime "$id" "$class" "$mutation" \
                BC01_OCCURRENCE_COLLAPSE mutant-occurrence-collapse \
                "$target" inventory-after.tsv
            ;;
        neg-bc01-payload-collision)
            record_runtime "$id" "$class" "$mutation" \
                BC01_PAYLOAD_COLLISION mutant-payload-collision-acceptance \
                "$target" inventory-after.tsv
            ;;
        neg-bc01-retry-duplication)
            record_runtime "$id" "$class" "$mutation" \
                BC01_RETRY_DUPLICATION mutant-retry-duplication \
                "$target" inventory-after.tsv
            ;;
        harness-bc01-noop)
            record_evidence "$id" "$class" "$mutation" "$target" action
            ;;
        harness-bc01-observer-synthesis)
            record_evidence "$id" "$class" "$mutation" "$target" normalized
            ;;
        harness-bc01-raw-post-seal-tamper)
            record_evidence "$id" "$class" "$mutation" "$target" raw
            ;;
        harness-bc01-copied-run|harness-bc01-second-run-drift|\
harness-bc01-sentinel-leak)
            ;;
        *)
            echo BC01_CONTROL_INVENTORY_INVALID >&2
            exit 1
            ;;
    esac
done <"$mutants"

awk -F '	' '
    NF != 8 || seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 8) exit 1 }
' "$output" || {
    echo BC01_RUN_CONTROL_RECEIPT_INVALID >&2
    exit 1
}
