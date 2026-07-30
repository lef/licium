#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
runner="$script_dir/run-bc11-runtime.sh"
verifier="$script_dir/verify-bc11-runtime.sh"

[ -x "$runner" ] || {
    echo BC11_RUNTIME_MISSING >&2
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
    [ "$output" = "BC11_RUNTIME_CONTRACT_VALID
BC11_RUNTIME_VALID" ] || exit 1
    baselines=$((baselines + 1))
done <<'EOF'
BC11_EXPLANATION_CLOSURE
BC11_FINDING_CROSS_LINK
BC11_FINDING_DANGLING
BC11_LATEST_SUBSTITUTION
BC11_MISSING_AS_EMPTY
BC11_REPLAY_RESULT
BC11_SILENT_CROSS_LINK
BC11_SILENT_DANGLING
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
        echo "wrong BC11 semantic marker: $output, expected $expected" >&2
        exit 1
    }
    printf 'ok control %s\n' "$expected"
}

run_semantic_control BC11_EXPLANATION_CLOSURE \
    mutant-detect-explanation-member-loss \
    BC11_EXPLANATION_CLOSURE_LOSS_DETECTED
run_semantic_control BC11_FINDING_CROSS_LINK mutant-detect-missing-cross-link-finding \
    BC11_FINDING_CROSS_LINK_MISSING
run_semantic_control BC11_FINDING_DANGLING mutant-detect-missing-dangling-finding \
    BC11_FINDING_DANGLING_MISSING
run_semantic_control BC11_LATEST_SUBSTITUTION mutant-detect-latest-replay-substitution \
    BC11_LATEST_SUBSTITUTION_MISMATCH_DETECTED
run_semantic_control BC11_MISSING_AS_EMPTY mutant-detect-replay-missing-as-empty \
    BC11_MISSING_AS_EMPTY_NOT_DETECTED
run_semantic_control BC11_REPLAY_RESULT mutant-detect-replay-result-drift \
    BC11_REPLAY_RESULT_MISMATCH_DETECTED
run_semantic_control BC11_SILENT_CROSS_LINK mutant-detect-silent-cross-link-repair \
    BC11_SILENT_CROSS_LINK_DETECTED
run_semantic_control BC11_SILENT_DANGLING mutant-detect-silent-dangling-repair \
    BC11_SILENT_DANGLING_DETECTED

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
        ' "$base_dir/bc11-scenario-ids.tsv"
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
        echo "wrong BC11 harness marker: $output, expected $expected" >&2
        exit 1
    }
    printf 'ok harness %s\n' "$id"
}

result="$tmp/bc11-replay-result"
verify_mutation "$result" noop BC11_SUT_ACTION_MISSING \
    BC11_REPLAY_RESULT
verify_mutation "$result" observer-synthesis BC11_COVERAGE_INVALID \
    BC11_REPLAY_RESULT
verify_mutation "$result" raw-post-seal BC11_RAW_SEAL_INVALID \
    BC11_REPLAY_RESULT

printf '%s BC11 runtime baselines valid\n' "$baselines"
echo "11 BC11 runtime controls detected"
