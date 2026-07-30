#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc04-runtime.sh"
verifier="$script_dir/verify-bc04-runtime.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baseline=0
while IFS='	' read -r assertion _ case_id _ _ _ _
do
    dir="$tmp/$assertion"
    output=$("$runner" "$dir" "run-$assertion" "ns-$assertion" \
        "$assertion")
    [ "$output" = BC04_RUNTIME_VALID ] || exit 1
    baseline=$((baseline + 1))
done <"$script_dir/../bc04-cases.tsv"

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
        echo "wrong BC04 marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_semantic_control BC04_AMBIENT_FALLBACK \
    mutant-ambient-read-fallback BC04_AMBIENT_FALLBACK_DETECTED
run_semantic_control BC04_EXACT_PUBLISHED_COLLAPSE \
    mutant-read-mode-collapse BC04_EXACT_PUBLISHED_COLLAPSE_DETECTED
run_semantic_control BC04_EXACT_READ \
    mutant-exact-read-substitution BC04_EXACT_READ_SUBSTITUTED
run_semantic_control BC04_PUBLISHED_READ \
    mutant-published-read-substitution BC04_PUBLISHED_READ_SUBSTITUTED
run_semantic_control BC04_UNACCEPTED_AVAILABLE \
    mutant-unaccepted-read-availability BC04_UNACCEPTED_AVAILABLE_DETECTED

baseline_dir="$tmp/BC04_EXACT_READ"
run='run-BC04_EXACT_READ'
namespace=ns-BC04_EXACT_READ
assertion=BC04_EXACT_READ
case_id=case-bc04-exact
scenario=bc04-exact-read--case-bc04-exact

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
        echo "wrong BC04 harness marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_harness_control action-missing BC04_SUT_ACTION_MISSING
run_harness_control normalized-without-raw BC04_COVERAGE_INVALID
run_harness_control raw-post-seal BC04_RAW_SEAL_INVALID

set +e
freshness=$("$runner" "$baseline_dir" run-again ns-again \
    BC04_EXACT_READ 2>&1)
freshness_status=$?
set -e
[ "$freshness_status" -ne 0 ] &&
    [ "$freshness" = BC04_RUNTIME_NOT_FRESH ] || exit 1
echo "ok control BC04_RUNTIME_NOT_FRESH"

echo "$baseline BC04 runtime baselines"
echo "9 BC04 runtime controls detected"
