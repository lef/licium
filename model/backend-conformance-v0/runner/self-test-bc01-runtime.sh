#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc01-runtime.sh"
verifier="$script_dir/verify-bc01-runtime.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

scenario_for()
{
    case "$1" in
        BC01_ASSOCIATION_IDEMPOTENT)
            printf '%s\n' bc01-association-idempotent--case-bc01-retry
            ;;
        BC01_DISTINCT_OCCURRENCE)
            printf '%s\n' bc01-distinct-occurrence--case-bc01-distinct
            ;;
        BC01_OCCURRENCE_COLLAPSE)
            printf '%s\n' bc01-occurrence-collapse--case-bc01-distinct
            ;;
        BC01_PAYLOAD_COLLISION)
            printf '%s\n' bc01-payload-collision--case-bc01-payload-collision
            ;;
        BC01_RETRY_DUPLICATION)
            printf '%s\n' bc01-retry-duplication--case-bc01-retry
            ;;
    esac
}

case_for()
{
    case "$1" in
        BC01_ASSOCIATION_IDEMPOTENT|BC01_RETRY_DUPLICATION)
            printf '%s\n' case-bc01-retry
            ;;
        BC01_DISTINCT_OCCURRENCE|BC01_OCCURRENCE_COLLAPSE)
            printf '%s\n' case-bc01-distinct
            ;;
        BC01_PAYLOAD_COLLISION)
            printf '%s\n' case-bc01-payload-collision
            ;;
    esac
}

baseline=0
for assertion in BC01_ASSOCIATION_IDEMPOTENT BC01_DISTINCT_OCCURRENCE \
    BC01_OCCURRENCE_COLLAPSE BC01_PAYLOAD_COLLISION \
    BC01_RETRY_DUPLICATION
do
    run="baseline-$assertion"
    namespace="ns-$assertion"
    "$runner" "$tmp/$assertion" "$run" "$namespace" "$assertion" \
        >"$tmp/$assertion.out"
    [ "$(cat "$tmp/$assertion.out")" = BC01_RUNTIME_VALID ] || exit 1
    baseline=$((baseline + 1))
done

run_semantic()
{
    assertion=$1
    mode=$2
    expected=$3
    set +e
    output=$("$runner" "$tmp/$mode" "run-$mode" "ns-$mode" \
        "$assertion" "$mode" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC01 semantic mutant unexpectedly passed: $mode" >&2
        exit 1
    }
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "wrong BC01 semantic marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok semantic %s\n' "$expected"
}

run_semantic BC01_ASSOCIATION_IDEMPOTENT \
    mutant-association-duplication BC01_ASSOCIATION_DUPLICATION_DETECTED
run_semantic BC01_DISTINCT_OCCURRENCE \
    mutant-distinct-collapse BC01_DISTINCT_OCCURRENCE_COLLAPSE_DETECTED
run_semantic BC01_OCCURRENCE_COLLAPSE \
    mutant-occurrence-collapse BC01_OCCURRENCE_COLLAPSE_DETECTED
run_semantic BC01_PAYLOAD_COLLISION \
    mutant-payload-collision-acceptance BC01_PAYLOAD_COLLISION_ACCEPTED
run_semantic BC01_RETRY_DUPLICATION \
    mutant-retry-duplication BC01_RETRY_DUPLICATION_DETECTED

refresh_raw_seal()
{
    work=$1
    raw_sha=$(sha256sum "$work/raw-observations.tsv" | awk '{ print $1 }')
    raw_bytes=$(wc -c <"$work/raw-observations.tsv" | tr -d ' ')
    awk -F '	' -v OFS='	' -v sha="$raw_sha" -v bytes="$raw_bytes" '
        { $3 = sha; $4 = bytes; print }
    ' "$work/raw-seal.tsv" >"$work/raw-seal.tsv.tmp"
    mv "$work/raw-seal.tsv.tmp" "$work/raw-seal.tsv"
}

refresh_receipt_bindings()
{
    work=$1
    receipt_sha=$(sha256sum "$work/action-receipts.tsv" |
        awk '{ print $1 }')
    action_sha=$(sed -n '2p' "$work/action-receipts.tsv" |
        sha256sum | awk '{ print $1 }')
    action_bytes=$(sed -n '2p' "$work/action-receipts.tsv" |
        wc -c | tr -d ' ')
    awk -F '	' -v OFS='	' -v receipt_sha="$receipt_sha" '
        { $8 = receipt_sha; print }
    ' "$work/raw-seal.tsv" >"$work/raw-seal.tsv.tmp"
    mv "$work/raw-seal.tsv.tmp" "$work/raw-seal.tsv"
    awk -F '	' -v OFS='	' -v sha="$action_sha" \
        -v bytes="$action_bytes" '
        $4 == "action" {
            $8 = sha
            $9 = bytes
        }
        { print }
    ' "$work/command-receipts.tsv" >"$work/command-receipts.tsv.tmp"
    mv "$work/command-receipts.tsv.tmp" "$work/command-receipts.tsv"
}

run_control()
{
    id=$1
    expected=$2
    work="$tmp/control-$id"
    cp -R "$tmp/BC01_ASSOCIATION_IDEMPOTENT" "$work"
    run=baseline-BC01_ASSOCIATION_IDEMPOTENT
    namespace=ns-BC01_ASSOCIATION_IDEMPOTENT
    assertion=BC01_ASSOCIATION_IDEMPOTENT
    case_id=$(case_for "$assertion")
    scenario=$(scenario_for "$assertion")

    case "$id" in
        action-missing)
            sed -n '1p' "$work/action-receipts.tsv" \
                >"$work/action-receipts.tsv.tmp"
            mv "$work/action-receipts.tsv.tmp" "$work/action-receipts.tsv"
            ;;
        argv-custody)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $4 == "action" {
                    $12 = "0000000000000000000000000000000000000000000000000000000000000000"
                }
                { print }
            ' "$work/command-receipts.tsv" >"$work/command-receipts.tsv.tmp"
            mv "$work/command-receipts.tsv.tmp" "$work/command-receipts.tsv"
            ;;
        normalized-without-raw)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $2 == "raw-009" { $2 = "raw-synthesized" }
                { print }
            ' "$work/raw-observations.tsv" >"$work/raw-observations.tsv.tmp"
            mv "$work/raw-observations.tsv.tmp" "$work/raw-observations.tsv"
            refresh_raw_seal "$work"
            ;;
        oracle-result)
            awk -F '	' 'BEGIN { OFS = "\t" }
                { $3 = "FAIL"; print }
            ' "$work/oracle-result.tsv" >"$work/oracle-result.tsv.tmp"
            mv "$work/oracle-result.tsv.tmp" "$work/oracle-result.tsv"
            ;;
        raw-post-seal)
            printf '\n' >>"$work/raw-observations.tsv"
            ;;
        receipt-nonce)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $5 != "sut-setup-bc01" { $13 = "wrong-action-nonce" }
                { print }
            ' "$work/action-receipts.tsv" \
                >"$work/action-receipts.tsv.tmp"
            mv "$work/action-receipts.tsv.tmp" \
                "$work/action-receipts.tsv"
            refresh_receipt_bindings "$work"
            ;;
        reopened-drift)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $2 == "association" && $3 == "alice" {
                    $5 = "public-x"
                }
                { print }
            ' "$work/inventory-reopened.tsv" \
                >"$work/inventory-reopened.tsv.tmp"
            mv "$work/inventory-reopened.tsv.tmp" \
                "$work/inventory-reopened.tsv"
            stdout_sha=$(sha256sum "$work/inventory-reopened.tsv" |
                awk '{ print $1 }')
            stdout_bytes=$(wc -c <"$work/inventory-reopened.tsv" |
                tr -d ' ')
            awk -F '	' -v OFS='	' -v sha="$stdout_sha" \
                -v bytes="$stdout_bytes" '
                $4 == "inventory-reopened" {
                    $8 = sha
                    $9 = bytes
                }
                { print }
            ' "$work/command-receipts.tsv" \
                >"$work/command-receipts.tsv.tmp"
            mv "$work/command-receipts.tsv.tmp" \
                "$work/command-receipts.tsv"
            ;;
        stdout-custody)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $4 == "action" {
                    $8 = "0000000000000000000000000000000000000000000000000000000000000000"
                }
                { print }
            ' "$work/command-receipts.tsv" >"$work/command-receipts.tsv.tmp"
            mv "$work/command-receipts.tsv.tmp" "$work/command-receipts.tsv"
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
        echo "BC01 runtime control unexpectedly passed: $id" >&2
        exit 1
    }
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "wrong BC01 runtime control marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_control action-missing BC01_SUT_ACTION_MISSING
run_control argv-custody BC01_COMMAND_CUSTODY_INVALID
run_control normalized-without-raw BC01_COVERAGE_INVALID
run_control oracle-result BC01_ORACLE_RESULT_INVALID
run_control raw-post-seal BC01_RAW_SEAL_INVALID
run_control receipt-nonce BC01_ACTION_RECEIPT_INVALID
run_control reopened-drift BC01_INVENTORY_EXPECTED_INVALID
run_control stdout-custody BC01_COMMAND_CUSTODY_INVALID

set +e
freshness=$("$runner" "$tmp/BC01_ASSOCIATION_IDEMPOTENT" run-again \
    ns-again BC01_ASSOCIATION_IDEMPOTENT 2>&1)
freshness_status=$?
set -e
[ "$freshness_status" -ne 0 ] &&
    [ "$freshness" = BC01_RUNTIME_NOT_FRESH ] || exit 1
echo "ok control BC01_RUNTIME_NOT_FRESH"

echo "$baseline BC01 runtime baselines"
echo "14 BC01 runtime controls detected"
