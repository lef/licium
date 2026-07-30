#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc05-mutants.tsv"
runtime_runner="$script_dir/run-bc05-runtime.sh"
runtime_verifier="$script_dir/verify-bc05-runtime.sh"

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
    control_run="control-$run_id"
    control_ns="control-$run_id-$id"
    set +e
    observed=$("$runtime_runner" "$directory" "$control_run" \
        "$control_ns" "$assertion" "$mode" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC05_CONTROL_EXECUTION_INVALID >&2
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
    assertion=BC05_COMPLETE_CLOSURE
    case_id=case-bc05-complete
    scenario=bc05-complete-closure--case-bc05-complete
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
            sed -n '2,$p' "$directory/raw-observations.tsv" \
                >"$directory/raw-observations.tsv.tmp"
            mv "$directory/raw-observations.tsv.tmp" \
                "$directory/raw-observations.tsv"
            chmod 0644 "$directory/raw-observations.tsv"
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
        *)
            exit 2 ;;
    esac
    set +e
    observed=$("$runtime_verifier" "$directory" "$run_id" "$namespace" \
        "$assertion" "$case_id" "$scenario" "$directory/nonexistent.db" \
        ordinary 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC05_CONTROL_EXECUTION_INVALID >&2
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
        neg-bc05-ambient-advance)
            record_runtime "$id" "$class" "$mutation" \
                BC05_AMBIENT_ADVANCE mutant-ambient-closure-substitution \
                "$target"
            ;;
        neg-bc05-binding-omission)
            record_runtime "$id" "$class" "$mutation" \
                BC05_BINDING_OMISSION mutant-binding-omission "$target"
            ;;
        neg-bc05-complete-closure)
            record_runtime "$id" "$class" "$mutation" \
                BC05_COMPLETE_CLOSURE mutant-incomplete-closure-success \
                "$target"
            ;;
        neg-bc05-definition-omission)
            record_runtime "$id" "$class" "$mutation" \
                BC05_DEFINITION_OMISSION mutant-definition-omission "$target"
            ;;
        neg-bc05-missing-as-empty)
            record_runtime "$id" "$class" "$mutation" \
                BC05_MISSING_AS_EMPTY mutant-missing-as-empty "$target"
            ;;
        neg-bc05-pinned-knowledge-cut)
            record_runtime "$id" "$class" "$mutation" \
                BC05_PINNED_KNOWLEDGE_CUT mutant-knowledge-cut-drift "$target"
            ;;
        neg-bc05-root-omission)
            record_runtime "$id" "$class" "$mutation" \
                BC05_ROOT_OMISSION mutant-root-omission "$target"
            ;;
        neg-bc05-semantics-omission)
            record_runtime "$id" "$class" "$mutation" \
                BC05_SEMANTICS_OMISSION mutant-semantics-omission "$target"
            ;;
        neg-bc05-transitive-omission)
            record_runtime "$id" "$class" "$mutation" \
                BC05_TRANSITIVE_OMISSION mutant-transitive-omission "$target"
            ;;
        harness-bc05-noop)
            record_evidence "$id" "$class" "$mutation" "$target" action
            ;;
        harness-bc05-observer-synthesis)
            record_evidence "$id" "$class" "$mutation" "$target" normalized
            ;;
        harness-bc05-raw-post-seal-tamper)
            record_evidence "$id" "$class" "$mutation" "$target" raw
            ;;
        *)
            echo BC05_CONTROL_INVENTORY_INVALID >&2
            exit 1 ;;
    esac
done <"$mutants"

awk -F '	' '
    NF != 8 || seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 12) exit 1 }
' "$output" || {
    echo BC05_RUN_CONTROL_RECEIPT_INVALID >&2
    exit 1
}
