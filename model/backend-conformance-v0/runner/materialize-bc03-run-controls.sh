#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
mutants="$base_dir/bc03-mutants.tsv"
runtime_runner="$script_dir/run-bc03-runtime.sh"
runtime_verifier="$script_dir/verify-bc03-runtime.sh"

[ "$#" -eq 3 ] || {
    echo "usage: materialize-bc03-run-controls.sh RUN_DIR RUN_ID OUTPUT" >&2
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
        echo BC03_CONTROL_EXECUTION_INVALID >&2
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
    assertion=BC03_ACCEPTED_HEAD
    case_id=case-bc03-accepted
    scenario=bc03-accepted-head--case-bc03-accepted
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
            exit 2
            ;;
    esac
    set +e
    observed=$("$runtime_verifier" "$directory" "$run_id" "$namespace" \
        "$assertion" "$case_id" "$scenario" "$directory/nonexistent.db" \
        2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$observed" = "$target" ] || {
        echo BC03_CONTROL_EXECUTION_INVALID >&2
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
        neg-bc03-accepted-head)
            record_runtime "$id" "$class" "$mutation" \
                BC03_ACCEPTED_HEAD mutant-accepted-head-omission \
                "$target" inventory-after.tsv
            ;;
        neg-bc03-publication-separate)
            record_runtime "$id" "$class" "$mutation" \
                BC03_PUBLICATION_SEPARATE mutant-publication-root-collapse \
                "$target" inventory-after.tsv
            ;;
        neg-bc03-rejected-is-head)
            record_runtime "$id" "$class" "$mutation" \
                BC03_REJECTED_IS_HEAD mutant-rejected-head-inclusion \
                "$target" inventory-after.tsv
            ;;
        neg-bc03-stored-is-head)
            record_runtime "$id" "$class" "$mutation" \
                BC03_STORED_IS_HEAD mutant-stored-root-head-inclusion \
                "$target" inventory-after.tsv
            ;;
        neg-bc03-stored-root-separate)
            record_runtime "$id" "$class" "$mutation" \
                BC03_STORED_ROOT_SEPARATE \
                mutant-stored-root-publication-collapse \
                "$target" inventory-after.tsv
            ;;
        neg-bc03-wrong-authority-head)
            record_runtime "$id" "$class" "$mutation" \
                BC03_WRONG_AUTHORITY_HEAD \
                mutant-wrong-authority-head-inclusion \
                "$target" inventory-after.tsv
            ;;
        harness-bc03-noop)
            record_evidence "$id" "$class" "$mutation" "$target" action
            ;;
        harness-bc03-observer-synthesis)
            record_evidence "$id" "$class" "$mutation" "$target" normalized
            ;;
        harness-bc03-raw-post-seal-tamper)
            record_evidence "$id" "$class" "$mutation" "$target" raw
            ;;
        *)
            echo BC03_CONTROL_INVENTORY_INVALID >&2
            exit 1
            ;;
    esac
done <"$mutants"

awk -F '	' '
    NF != 8 || seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 9) exit 1 }
' "$output" || {
    echo BC03_RUN_CONTROL_RECEIPT_INVALID >&2
    exit 1
}
