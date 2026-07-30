#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc03-runtime.sh"
verifier="$script_dir/verify-bc03-runtime.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baseline=0
while IFS='	' read -r assertion _ case_id _ _ _ _
do
    scenario=$(awk -F '	' -v assertion="$assertion" \
        '$1 == assertion { print $3 }' \
        "$script_dir/../bc03-scenario-ids.tsv")
    dir="$tmp/$assertion"
    output=$("$runner" "$dir" "run-$assertion" "ns-$assertion" \
        "$assertion")
    [ "$output" = BC03_RUNTIME_VALID ] || exit 1
    baseline=$((baseline + 1))
done <"$script_dir/../bc03-cases.tsv"

run_semantic_control()
{
    assertion=$1
    mode=$2
    expected=$3
    dir="$tmp/control-$assertion"
    set +e
    output=$("$runner" "$dir" "run-control-$assertion" \
        "ns-control-$assertion" "$assertion" "$mode" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC03 semantic control unexpectedly passed: $assertion" >&2
        exit 1
    }
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "wrong BC03 marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_semantic_control BC03_ACCEPTED_HEAD \
    mutant-accepted-head-omission BC03_ACCEPTED_HEAD_MISSING
run_semantic_control BC03_PUBLICATION_SEPARATE \
    mutant-publication-root-collapse \
    BC03_PUBLICATION_ROOT_COLLAPSE_DETECTED
run_semantic_control BC03_REJECTED_IS_HEAD \
    mutant-rejected-head-inclusion BC03_REJECTED_HEAD_DETECTED
run_semantic_control BC03_STORED_IS_HEAD \
    mutant-stored-root-head-inclusion BC03_STORED_ROOT_HEAD_DETECTED
run_semantic_control BC03_STORED_ROOT_SEPARATE \
    mutant-stored-root-publication-collapse \
    BC03_STORED_ROOT_PUBLICATION_COLLAPSE_DETECTED
run_semantic_control BC03_WRONG_AUTHORITY_HEAD \
    mutant-wrong-authority-head-inclusion \
    BC03_WRONG_AUTHORITY_HEAD_DETECTED

baseline_dir="$tmp/BC03_ACCEPTED_HEAD"
run=run-BC03_ACCEPTED_HEAD
namespace=ns-BC03_ACCEPTED_HEAD
assertion=BC03_ACCEPTED_HEAD
case_id=case-bc03-accepted
scenario=bc03-accepted-head--case-bc03-accepted

run_harness_control()
{
    id=$1
    expected=$2
    work="$tmp/harness-$id"
    cp -R "$baseline_dir" "$work"

    case "$id" in
        action-missing)
            sed -n '1p' "$work/action-receipts.tsv" \
                >"$work/action-receipts.tmp"
            mv "$work/action-receipts.tmp" "$work/action-receipts.tsv"
            ;;
        normalized-without-raw)
            sed -n '2,$p' "$work/raw-observations.tsv" >"$work/raw.tmp"
            mv "$work/raw.tmp" "$work/raw-observations.tsv"
            chmod 0644 "$work/raw-observations.tsv"
            raw_sha=$(sha256sum "$work/raw-observations.tsv" |
                awk '{ print $1 }')
            raw_bytes=$(wc -c <"$work/raw-observations.tsv" | tr -d ' ')
            receipt_sha=$(sha256sum "$work/action-receipts.tsv" |
                awk '{ print $1 }')
            printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
                "$raw_sha" "$raw_bytes" "$run" "$namespace" "$scenario" \
                "$receipt_sha" >"$work/raw-seal.tsv"
            ;;
        raw-post-seal)
            printf '%s\traw-forged\tforged\tafter\tvalue\tforged\n' \
                "$scenario" >>"$work/raw-observations.tsv"
            ;;
        *)
            exit 2
            ;;
    esac

    set +e
    output=$("$verifier" "$work" "$run" "$namespace" "$assertion" \
        "$case_id" "$scenario" "$work/nonexistent.db" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC03 harness control unexpectedly passed: $id" >&2
        exit 1
    }
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "wrong BC03 harness marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_harness_control action-missing BC03_SUT_ACTION_MISSING
run_harness_control normalized-without-raw BC03_COVERAGE_INVALID
run_harness_control raw-post-seal BC03_RAW_SEAL_INVALID

set +e
freshness=$("$runner" "$baseline_dir" run-again ns-again \
    BC03_ACCEPTED_HEAD 2>&1)
freshness_status=$?
set -e
[ "$freshness_status" -ne 0 ] &&
    [ "$freshness" = BC03_RUNTIME_NOT_FRESH ] || exit 1
echo "ok control BC03_RUNTIME_NOT_FRESH"

echo "$baseline BC03 runtime baselines"
echo "10 BC03 runtime controls detected"
