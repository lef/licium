#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc10-mutants.tsv"
runtime="$script_dir/run-bc10-runtime.sh"
verifier="$script_dir/verify-bc10-runtime.sh"

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
        echo BC10_CONTROL_EXECUTION_INVALID >&2
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
        ' "$base_dir/bc10-scenario-ids.tsv"
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
        neg-bc10-explanation-closed)
            semantic "$id" "$class" "$mutation" \
                BC10_EXPLANATION_CLOSED "$target" ;;
        neg-bc10-explanation-leak)
            semantic "$id" "$class" "$mutation" \
                BC10_EXPLANATION_LEAK "$target" ;;
        neg-bc10-replay-closed)
            semantic "$id" "$class" "$mutation" \
                BC10_REPLAY_CLOSED "$target" ;;
        neg-bc10-replay-leak)
            semantic "$id" "$class" "$mutation" \
                BC10_REPLAY_LEAK "$target" ;;
        neg-bc10-result-closed)
            semantic "$id" "$class" "$mutation" \
                BC10_RESULT_CLOSED "$target" ;;
        neg-bc10-result-leak)
            semantic "$id" "$class" "$mutation" \
                BC10_RESULT_LEAK "$target" ;;
        neg-bc10-view-closed)
            semantic "$id" "$class" "$mutation" \
                BC10_VIEW_CLOSED "$target" ;;
        neg-bc10-view-leak-provenance|neg-bc10-view-leak-secret)
            semantic "$id" "$class" "$mutation" \
                BC10_VIEW_LEAK "$target" ;;
        harness-bc10-noop)
            harness "$id" "$class" "$mutation" BC10_RESULT_CLOSED \
                "$target" noop ;;
        harness-bc10-observer-synthesis)
            harness "$id" "$class" "$mutation" BC10_RESULT_CLOSED \
                "$target" observer-synthesis ;;
        harness-bc10-raw-post-seal)
            harness "$id" "$class" "$mutation" BC10_RESULT_CLOSED \
                "$target" raw-post-seal ;;
        *) exit 2 ;;
    esac
done <"$mutants"

awk -F '	' 'NF != 8 || seen[$1]++ { exit 1 } { count++ }
    END { if (count != 12) exit 1 }' "$output" ||
    { echo BC10_RUN_CONTROL_RECEIPT_INVALID >&2; exit 1; }
