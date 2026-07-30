#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc12-mutants.tsv"
runtime="$script_dir/run-bc12-runtime.sh"
verifier="$script_dir/verify-bc12-runtime.sh"

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
        echo BC12_CONTROL_EXECUTION_INVALID >&2
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
    mode="mutant-$mutation"
    set +e
    observed=$(
        "$runtime" "$directory" "control-$run_id" \
            "control-$run_id-$id" "$assertion" "$mode" 2>&1
    )
    status=$?
    set -e
    record "$id" "$class" "$mutation" "$assertion" "$target" \
        "$observed" "$status" "$directory/action-receipts.tsv"
}

protection_bundle()
{
    id=$1
    class=$2
    mutation=$3
    assertion=$4
    target=$5
    evidence="$tmp/$id-evidence.tsv"
    : >"$evidence"
    for source in witness conflict publication
    do
        directory="$tmp/$id-$source"
        mode="mutant-$mutation-$source"
        set +e
        observed=$(
            "$runtime" "$directory" "control-$run_id" \
                "control-$run_id-$id-$source" "$assertion" "$mode" 2>&1
        )
        status=$?
        set -e
        [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
            echo BC12_CONTROL_EXECUTION_INVALID >&2
            exit 1
        }
        cat "$directory/action-receipts.tsv" >>"$evidence"
    done
    record "$id" "$class" "$mutation" "$assertion" "$target" \
        "$target" 1 "$evidence"
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
        ' "$base_dir/bc12-scenario-ids.tsv"
    )
    [ -n "$scenario" ] || exit 2
    namespace="ns-$side-$scenario"
    directory="$tmp/$id"
    cp -R "$run_dir/$scenario" "$directory"
    case "$kind" in
        noop)
            : >"$directory/action-receipts.tsv"
            evidence="$directory/action-receipts.tsv"
            ;;
        observer-synthesis)
            printf '%s\tobs-999\tforged\tforged\tforged\tforged\n' \
                "$scenario" >>"$directory/normalized-observations.tsv"
            evidence="$directory/normalized-observations.tsv"
            ;;
        raw-post-seal)
            awk -F '	' 'BEGIN { OFS=FS }
                NR == 1 { $6="forged" }
                { print }
            ' "$directory/raw-observations.tsv" >"$directory/edit"
            mv "$directory/edit" "$directory/raw-observations.tsv"
            evidence="$directory/raw-observations.tsv"
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

while IFS='	' read -r id negative_id class mutation target
do
    case "$id" in
        neg-bc12-archive-bypass)
            semantic "$id" "$class" "$mutation" \
                BC12_ARCHIVE_BYPASS "$target" ;;
        neg-bc12-canonical-unchanged)
            semantic "$id" "$class" "$mutation" \
                BC12_CANONICAL_UNCHANGED "$target" ;;
        neg-bc12-decision-provenance)
            semantic "$id" "$class" "$mutation" \
                BC12_DECISION_PROVENANCE "$target" ;;
        neg-bc12-derived-protection)
            semantic "$id" "$class" "$mutation" \
                BC12_DERIVED_PROTECTION "$target" ;;
        neg-bc12-eligibility-delete)
            semantic "$id" "$class" "$mutation" \
                BC12_ELIGIBILITY_DELETE "$target" ;;
        neg-bc12-forget-bypass)
            semantic "$id" "$class" "$mutation" \
                BC12_FORGET_BYPASS "$target" ;;
        neg-bc12-forget-consumed)
            semantic "$id" "$class" "$mutation" \
                BC12_FORGET_CONSUMED "$target" ;;
        neg-bc12-noop-evaluator)
            semantic "$id" "$class" "$mutation" \
                BC12_NOOP_EVALUATOR "$target" ;;
        neg-bc12-placement-decision)
            semantic "$id" "$class" "$mutation" \
                BC12_PLACEMENT_DECISION "$target" ;;
        neg-bc12-protection-bypass)
            protection_bundle "$id" "$class" "$mutation" \
                BC12_PROTECTION_BYPASS "$target" ;;
        neg-bc12-window-bypass)
            semantic "$id" "$class" "$mutation" \
                BC12_WINDOW_BYPASS "$target" ;;
        harness-bc12-missing-sut-action)
            harness "$id" "$class" "$mutation" BC12_PLACEMENT_DECISION \
                "$target" noop ;;
        harness-bc12-normalized-synthesis-without-raw-coverage)
            harness "$id" "$class" "$mutation" BC12_PLACEMENT_DECISION \
                "$target" observer-synthesis ;;
        harness-bc12-raw-post-seal-tamper)
            harness "$id" "$class" "$mutation" BC12_PLACEMENT_DECISION \
                "$target" raw-post-seal ;;
        *) exit 2 ;;
    esac
done <"$mutants"

awk -F '	' 'NF != 8 || seen[$1]++ { exit 1 } { count++ }
    END { if (count != 14) exit 1 }' "$output" ||
    { echo BC12_RUN_CONTROL_RECEIPT_INVALID >&2; exit 1; }
