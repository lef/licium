#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc05-runtime.sh"
verifier="$script_dir/verify-bc05-runtime.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baseline=0
while IFS='	' read -r assertion _ case_id _ _ _ _
do
    dir="$tmp/$assertion"
    output=$("$runner" "$dir" "run-$assertion" "ns-$assertion" \
        "$assertion")
    [ "$output" = BC05_RUNTIME_VALID ] || exit 1
    baseline=$((baseline + 1))
done <"$script_dir/../bc05-cases.tsv"

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
    [ "$status" -ne 0 ] || exit 1
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "wrong BC05 marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_semantic_control BC05_AMBIENT_ADVANCE \
    mutant-ambient-closure-substitution BC05_AMBIENT_ADVANCE_DETECTED
run_semantic_control BC05_BINDING_OMISSION \
    mutant-binding-omission BC05_BINDING_OMISSION_DETECTED
run_semantic_control BC05_COMPLETE_CLOSURE \
    mutant-incomplete-closure-success BC05_INCOMPLETE_CLOSURE_ACCEPTED
run_semantic_control BC05_DEFINITION_OMISSION \
    mutant-definition-omission BC05_DEFINITION_OMISSION_DETECTED
run_semantic_control BC05_MISSING_AS_EMPTY \
    mutant-missing-as-empty BC05_MISSING_AS_EMPTY_DETECTED
run_semantic_control BC05_PINNED_KNOWLEDGE_CUT \
    mutant-knowledge-cut-drift BC05_KNOWLEDGE_CUT_DRIFT_DETECTED
run_semantic_control BC05_ROOT_OMISSION \
    mutant-root-omission BC05_ROOT_OMISSION_DETECTED
run_semantic_control BC05_SEMANTICS_OMISSION \
    mutant-semantics-omission BC05_SEMANTICS_OMISSION_DETECTED
run_semantic_control BC05_TRANSITIVE_OMISSION \
    mutant-transitive-omission BC05_TRANSITIVE_OMISSION_DETECTED

baseline_dir="$tmp/BC05_COMPLETE_CLOSURE"
run='run-BC05_COMPLETE_CLOSURE'
namespace=ns-BC05_COMPLETE_CLOSURE
assertion=BC05_COMPLETE_CLOSURE
case_id=case-bc05-complete
scenario=bc05-complete-closure--case-bc05-complete

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
            exit 2 ;;
    esac
    set +e
    output=$("$verifier" "$work" "$run" "$namespace" "$assertion" \
        "$case_id" "$scenario" "$work/nonexistent.db" ordinary 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || exit 1
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "wrong BC05 harness marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_harness_control action-missing BC05_SUT_ACTION_MISSING
run_harness_control normalized-without-raw BC05_COVERAGE_INVALID
run_harness_control raw-post-seal BC05_RAW_SEAL_INVALID

set +e
freshness=$("$runner" "$baseline_dir" run-again ns-again \
    BC05_COMPLETE_CLOSURE 2>&1)
freshness_status=$?
set -e
[ "$freshness_status" -ne 0 ] &&
    [ "$freshness" = BC05_RUNTIME_NOT_FRESH ] || exit 1
echo "ok control BC05_RUNTIME_NOT_FRESH"

echo "$baseline BC05 runtime baselines"
echo "13 BC05 runtime controls detected"
