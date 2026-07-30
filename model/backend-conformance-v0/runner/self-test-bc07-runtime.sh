#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
runner="$script_dir/run-bc07-runtime.sh"
verifier="$script_dir/verify-bc07-runtime.sh"
adapter="$base_dir/profiles/sqlite-reference/run.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baseline=0
while IFS='	' read -r assertion _ _ _ _ _ _
do
    dir="$tmp/$assertion"
    output=$("$runner" "$dir" "run-$assertion" "ns-$assertion" \
        "$assertion")
    [ "$output" = BC07_RUNTIME_VALID ] || exit 1
    baseline=$((baseline + 1))
done <"$script_dir/../bc07-cases.tsv"

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
        echo "wrong BC07 marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_semantic_control BC07_EFFECT_101 \
    mutant-effect-axis-mismatch BC07_EFFECT_AXIS_MISMATCH_DETECTED
run_semantic_control BC07_OBSERVATION_WITHOUT_TRANSITION \
    mutant-orphan-observation BC07_ORPHAN_OBSERVATION_DETECTED
run_semantic_control BC07_ORDINARY_000 \
    mutant-ordinary-axis-write BC07_ORDINARY_AXIS_WRITE_DETECTED
run_semantic_control BC07_RECORD_IMPLIES_EFFECT \
    mutant-record-state-effect BC07_RECORD_STATE_EFFECT_DETECTED
run_semantic_control BC07_RECORD_ONLY_010 \
    mutant-record-axis-mismatch BC07_RECORD_AXIS_MISMATCH_DETECTED
run_semantic_control BC07_RESULT_REWRITE \
    mutant-effect-result-rewrite BC07_RESULT_REWRITE_DETECTED

baseline_dir="$tmp/BC07_EFFECT_101"
run='run-BC07_EFFECT_101'
namespace=ns-BC07_EFFECT_101
assertion=BC07_EFFECT_101
case_id=case-bc07-effect
scenario=bc07-effect-101--case-bc07-effect

run_harness_control()
{
    id=$1
    expected=$2
    work="$tmp/harness-$id"
    cp -R "$baseline_dir" "$work"
    case "$id" in
        action-missing)
            : >"$work/action-receipts.tsv"
            ;;
        normalized-without-raw)
            sed '1d' "$work/raw-observations.tsv" >"$work/raw.tmp"
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
        command-argv)
            awk -F '	' 'BEGIN { OFS = FS }
                $4 == "action" {
                    $12 = "0000000000000000000000000000000000000000000000000000000000000000"
                }
                { print }
            ' "$work/command-receipts.tsv" >"$work/command.tmp"
            mv "$work/command.tmp" "$work/command-receipts.tsv"
            ;;
        *) exit 2 ;;
    esac
    set +e
    output=$("$verifier" "$work" "$run" "$namespace" "$assertion" \
        "$case_id" "$scenario" "$work/nonexistent.db" ordinary 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || exit 1
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "wrong BC07 harness marker: $actual, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_harness_control action-missing BC07_SUT_ACTION_MISSING
run_harness_control normalized-without-raw BC07_COVERAGE_INVALID
run_harness_control raw-post-seal BC07_RAW_SEAL_INVALID
run_harness_control command-argv BC07_COMMAND_CUSTODY_INVALID

guard_db="$tmp/expected-revision.db"
"$adapter" create-bc07 ns-guard "$guard_db" >/dev/null 2>/dev/null
"$adapter" operation-bc07 "$guard_db" run-guard ns-guard \
    BC07_EFFECT_101 case-bc07-effect sut-setup-bc07 ordinary setup \
    setup-guard >/dev/null 2>/dev/null
sqlite3 -batch -bail "$guard_db" \
    "UPDATE authoritative_state SET revision_ref='state-stale';"
set +e
guard_output=$(
    "$adapter" operation-bc07 "$guard_db" run-guard ns-guard \
        BC07_EFFECT_101 case-bc07-effect sut-apply-effect ordinary action \
        action-guard 2>&1
)
guard_status=$?
set -e
[ "$guard_status" -ne 0 ] &&
    [ "$guard_output" = BC07_EXPECTED_REVISION_MISMATCH ] || exit 1
[ "$(sqlite3 -batch -bail -noheader -tabs "$guard_db" "
SELECT revision_ref,
       (SELECT COUNT(*) FROM state_transition),
       (SELECT COUNT(*) FROM decision_observation),
       (SELECT result_payload FROM evaluation_result),
       (SELECT result_digest FROM evaluation_result)
  FROM authoritative_state;
")" = "state-stale	0	0	accepted	digest-effect" ] || exit 1
"$adapter" destroy ns-guard "$guard_db" >/dev/null
echo "ok BC07_EXPECTED_REVISION_GUARD_VALID"

set +e
freshness=$("$runner" "$baseline_dir" run-again ns-again \
    BC07_EFFECT_101 2>&1)
freshness_status=$?
set -e
[ "$freshness_status" -ne 0 ] &&
    [ "$freshness" = BC07_RUNTIME_NOT_FRESH ] || exit 1

printf '%s BC07 runtime baselines valid\n' "$baseline"
echo "11 BC07 runtime controls detected"
