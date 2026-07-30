#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc06-mutants.tsv"
runtime_runner="$script_dir/run-bc06-runtime.sh"
runtime_verifier="$script_dir/verify-bc06-runtime.sh"

[ "$#" -eq 3 ] || {
    echo "usage: materialize-bc06-run-controls.sh RUN_DIR RUN_ID OUTPUT" >&2
    exit 2
}

run_dir=$1
run_id=$2
output=$3

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
    observed=$(
        "$runtime_runner" "$directory" "$control_run" "$control_ns" \
            "$assertion" "$mode" 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC06_CONTROL_EXECUTION_INVALID >&2
        exit 1
    }
    evidence_sha=$(sha256sum "$directory/$evidence_name" | awk '{ print $1 }')
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
    assertion=BC06_PURE_ZERO_AXES
    name=bc06-pure-zero-axes
    side=${run_id#run-}
    namespace="ns-$side-$name"
    directory="$tmp/$id"
    cp -R "$run_dir/$name" "$directory"
    case "$kind" in
        raw)
            file="$directory/raw-observations.tsv"
            sed 's/public-a/public-b/' "$file" >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$file"
            ;;
        normalized)
            file="$directory/normalized-observations.tsv"
            sed 's/obs-010/obs-099/' "$file" >"$tmp/mutated.tsv"
            cp "$tmp/mutated.tsv" "$file"
            ;;
        *)
            exit 2
            ;;
    esac
    set +e
    observed=$(
        "$runtime_verifier" "$directory" "$run_id" "$namespace" \
            "$assertion" "$run_dir/$name/$namespace.db" 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC06_CONTROL_EXECUTION_INVALID >&2
        exit 1
    }
    evidence_sha=$(sha256sum "$file" | awk '{ print $1 }')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$class" "$mutation" "$assertion" "$target" "$observed" \
        "$status" "$evidence_sha" >>"$output"
}

while IFS='	' read -r id class mutation target
do
    case "$id" in
        neg-bc06-observation-write)
            record_runtime "$id" "$class" "$mutation" \
                BC06_OBSERVATION_WRITE mutant-observation-write "$target" \
                inventory-after.tsv
            ;;
        neg-bc06-pure-zero-axes)
            record_runtime "$id" "$class" "$mutation" \
                BC06_PURE_ZERO_AXES mutant-all-three-axis-write "$target" \
                inventory-after.tsv
            ;;
        neg-bc06-repository-unchanged)
            record_runtime "$id" "$class" "$mutation" \
                BC06_REPOSITORY_UNCHANGED mutant-repository-drift "$target" \
                inventory-after.tsv
            ;;
        neg-bc06-result-write)
            record_runtime "$id" "$class" "$mutation" \
                BC06_RESULT_WRITE mutant-result-write "$target" \
                inventory-after.tsv
            ;;
        neg-bc06-state-write)
            record_runtime "$id" "$class" "$mutation" \
                BC06_STATE_WRITE mutant-state-write "$target" \
                inventory-after.tsv
            ;;
        harness-bc06-noop)
            record_runtime "$id" "$class" "$mutation" \
                BC06_PURE_ZERO_AXES mutant-noop "$target" \
                action-receipts.tsv
            ;;
        harness-bc06-raw-post-seal-tamper)
            record_evidence "$id" "$class" "$mutation" "$target" raw
            ;;
        harness-bc06-observer-synthesis)
            record_evidence "$id" "$class" "$mutation" "$target" normalized
            ;;
        harness-bc06-copied-run|harness-bc06-second-run-drift|\
harness-bc06-sentinel-leak)
            ;;
        *)
            echo BC06_CONTROL_INVENTORY_INVALID >&2
            exit 1
            ;;
    esac
done <"$mutants"

awk -F '	' '
    NF != 8 || seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 8) exit 1 }
' "$output" || {
    echo BC06_RUN_CONTROL_RECEIPT_INVALID >&2
    exit 1
}
