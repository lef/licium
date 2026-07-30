#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
runner="$script_dir/run-bc12-runtime.sh"
verifier="$script_dir/verify-bc12-runtime.sh"

[ -x "$runner" ] || {
    echo BC12_RUNTIME_MISSING >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baselines=0
while IFS= read -r assertion
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    output=$(
        "$runner" "$tmp/$name" "run-$name" "ns-$name" "$assertion"
    )
    [ "$output" = "BC12_RUNTIME_CONTRACT_VALID
BC12_RUNTIME_VALID" ] || exit 1
    baselines=$((baselines + 1))
done <<'EOF'
BC12_ARCHIVE_BYPASS
BC12_CANONICAL_UNCHANGED
BC12_DECISION_PROVENANCE
BC12_DERIVED_PROTECTION
BC12_ELIGIBILITY_DELETE
BC12_FORGET_BYPASS
BC12_FORGET_CONSUMED
BC12_NOOP_EVALUATOR
BC12_PLACEMENT_DECISION
BC12_PROTECTION_BYPASS
BC12_WINDOW_BYPASS
EOF

run_semantic_control()
{
    assertion=$1
    mode=$2
    expected=$3
    name=$(printf '%s-%s' "$assertion" "$mode" |
        tr 'A-Z_' 'a-z-')
    set +e
    output=$(
        "$runner" "$tmp/semantic-$name" "run-semantic-$name" \
            "ns-semantic-$name" "$assertion" "$mode" 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$output" = "$expected" ] || {
        echo "wrong BC12 semantic marker: $output, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_semantic_control BC12_ARCHIVE_BYPASS mutant-detect-archive-state-bypass \
    BC12_ARCHIVE_BYPASS_NOT_DETECTED
run_semantic_control BC12_CANONICAL_UNCHANGED \
    mutant-detect-placement-inventory-change BC12_CANONICAL_CHANGED
run_semantic_control BC12_DECISION_PROVENANCE \
    mutant-detect-decision-provenance-loss BC12_DECISION_PROVENANCE_LOSS
run_semantic_control BC12_DERIVED_PROTECTION \
    mutant-detect-protection-derivation-loss BC12_DERIVED_PROTECTION_LOSS
run_semantic_control BC12_ELIGIBILITY_DELETE \
    mutant-detect-eligibility-as-delete BC12_ELIGIBILITY_DELETE_DETECTED
run_semantic_control BC12_FORGET_BYPASS mutant-detect-forget-bypass \
    BC12_FORGET_BYPASS_NOT_DETECTED
run_semantic_control BC12_FORGET_CONSUMED mutant-detect-unconsumed-forget \
    BC12_FORGET_NOT_CONSUMED
run_semantic_control BC12_NOOP_EVALUATOR \
    mutant-detect-noop-placement-evaluator BC12_NOOP_EVALUATOR_DETECTED
run_semantic_control BC12_PLACEMENT_DECISION \
    mutant-detect-placement-decision-loss BC12_PLACEMENT_DECISION_MISMATCH
run_semantic_control BC12_PROTECTION_BYPASS \
    mutant-detect-protection-bypass-witness \
    BC12_PROTECTION_BYPASS_NOT_DETECTED
run_semantic_control BC12_PROTECTION_BYPASS \
    mutant-detect-protection-bypass-conflict \
    BC12_PROTECTION_BYPASS_NOT_DETECTED
run_semantic_control BC12_PROTECTION_BYPASS \
    mutant-detect-protection-bypass-publication \
    BC12_PROTECTION_BYPASS_NOT_DETECTED
run_semantic_control BC12_WINDOW_BYPASS mutant-detect-policy-window-bypass \
    BC12_WINDOW_BYPASS_NOT_DETECTED

verify_mutation()
{
    source=$1
    id=$2
    expected=$3
    assertion=$4
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    scenario=$(
        awk -F '	' -v assertion="$assertion" '
            $1 == assertion { print $3 }
        ' "$base_dir/bc12-scenario-ids.tsv"
    )
    work="$tmp/harness-$id"
    cp -R "$source" "$work"

    case "$id" in
        noop)
            : >"$work/action-receipts.tsv"
            ;;
        observer-synthesis)
            printf '%s\tobs-999\tforged\tforged\tforged\tforged\n' \
                "$scenario" >>"$work/normalized-observations.tsv"
            ;;
        raw-post-seal)
            awk -F '	' 'BEGIN { OFS=FS }
                NR == 1 { $6="forged" }
                { print }
            ' "$work/raw-observations.tsv" >"$work/edit"
            mv "$work/edit" "$work/raw-observations.tsv"
            ;;
        *) exit 2 ;;
    esac

    set +e
    output=$(
        "$verifier" "$work" "run-$name" "ns-$name" "$assertion" \
            "$scenario" 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$output" = "$expected" ] || {
        echo "wrong BC12 harness marker: $output, expected $expected" >&2
        exit 1
    }
    printf 'ok harness %s\n' "$id"
}

result="$tmp/bc12-placement-decision"
verify_mutation "$result" noop BC12_SUT_ACTION_MISSING \
    BC12_PLACEMENT_DECISION
verify_mutation "$result" observer-synthesis BC12_COVERAGE_INVALID \
    BC12_PLACEMENT_DECISION
verify_mutation "$result" raw-post-seal BC12_RAW_SEAL_INVALID \
    BC12_PLACEMENT_DECISION

printf '%s BC12 runtime baselines valid\n' "$baselines"
echo "13 BC12 semantic controls and 3 harness controls detected"
