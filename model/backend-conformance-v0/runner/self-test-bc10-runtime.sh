#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
runner="$script_dir/run-bc10-runtime.sh"
verifier="$script_dir/verify-bc10-runtime.sh"

[ -x "$runner" ] || {
    echo BC10_RUNTIME_MISSING >&2
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
    [ "$output" = "BC10_RUNTIME_CONTRACT_VALID
BC10_RUNTIME_VALID" ] || exit 1
    baselines=$((baselines + 1))
done <<'EOF'
BC10_EXPLANATION_CLOSED
BC10_EXPLANATION_LEAK
BC10_REPLAY_CLOSED
BC10_REPLAY_LEAK
BC10_RESULT_CLOSED
BC10_RESULT_LEAK
BC10_VIEW_CLOSED
BC10_VIEW_LEAK
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
        echo "wrong BC10 semantic marker: $output, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_semantic_control BC10_RESULT_CLOSED mutant-result-closure-loss \
    BC10_RESULT_CLOSURE_LOSS_DETECTED
run_semantic_control BC10_RESULT_LEAK mutant-result-secret-leak \
    BC10_RESULT_SECRET_LEAK_DETECTED
run_semantic_control BC10_VIEW_CLOSED mutant-view-member-loss \
    BC10_VIEW_CLOSURE_LOSS_DETECTED
run_semantic_control BC10_VIEW_LEAK mutant-view-provenance-loss \
    BC10_VIEW_PROVENANCE_LOSS_DETECTED
run_semantic_control BC10_VIEW_LEAK mutant-view-secret-leak \
    BC10_VIEW_SECRET_LEAK_DETECTED
run_semantic_control BC10_REPLAY_CLOSED mutant-replay-closure-loss \
    BC10_REPLAY_CLOSURE_LOSS_DETECTED
run_semantic_control BC10_REPLAY_LEAK mutant-replay-executor-metadata \
    BC10_REPLAY_METADATA_LEAK_DETECTED
run_semantic_control BC10_EXPLANATION_CLOSED \
    mutant-explanation-member-loss \
    BC10_EXPLANATION_CLOSURE_LOSS_DETECTED
run_semantic_control BC10_EXPLANATION_LEAK \
    mutant-explanation-secret-leak \
    BC10_EXPLANATION_SECRET_LEAK_DETECTED

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
        ' "$base_dir/bc10-scenario-ids.tsv"
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
        echo "wrong BC10 harness marker: $output, expected $expected" >&2
        exit 1
    }
    printf 'ok harness %s\n' "$id"
}

result="$tmp/bc10-result-closed"
verify_mutation "$result" noop BC10_SUT_ACTION_MISSING \
    BC10_RESULT_CLOSED
verify_mutation "$result" observer-synthesis BC10_COVERAGE_INVALID \
    BC10_RESULT_CLOSED
verify_mutation "$result" raw-post-seal BC10_RAW_SEAL_INVALID \
    BC10_RESULT_CLOSED

printf '%s BC10 runtime baselines valid\n' "$baselines"
echo "12 BC10 runtime controls detected"
