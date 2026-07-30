#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc06-runtime.sh"
verifier="$script_dir/verify-bc06-runtime.sh"
normalizer="$script_dir/normalize-bc06.sh"

[ -x "$runner" ] || {
    echo "BC06_RUNTIME_RUNNER_MISSING" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

expect_runner_marker()
{
    name=$1
    assertion=$2
    mode=$3
    marker=$4
    directory="$tmp/$name"
    set +e
    output=$(
        "$runner" "$directory" "run-$name" "ns-$name" \
            "$assertion" "$mode" 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC06 runtime mutant unexpectedly passed: $name" >&2
        exit 1
    }
    [ "$output" = "$marker" ] || {
        echo "wrong BC06 runtime marker: expected $marker, got $output" >&2
        exit 1
    }
    echo "ok $marker"
}

for assertion in \
    BC06_OBSERVATION_WRITE \
    BC06_PURE_ZERO_AXES \
    BC06_REPOSITORY_UNCHANGED \
    BC06_RESULT_WRITE \
    BC06_STATE_WRITE
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    output=$(
        "$runner" "$tmp/$name" "run-$name" "ns-$name" "$assertion"
    )
    [ "$output" = "BC06_RUNTIME_VALID" ] || {
        echo "wrong BC06 baseline output: $assertion -> $output" >&2
        exit 1
    }
done
echo "ok 5 BC06 runtime baselines"

expect_runner_marker observation-write BC06_OBSERVATION_WRITE \
    mutant-observation-write BC06_OBSERVATION_WRITE_DETECTED
expect_runner_marker all-three BC06_PURE_ZERO_AXES \
    mutant-all-three-axis-write BC06_AXIS_WRITE_DETECTED
expect_runner_marker repository-drift BC06_REPOSITORY_UNCHANGED \
    mutant-repository-drift BC06_REPOSITORY_DRIFT_DETECTED
expect_runner_marker result-write BC06_RESULT_WRITE \
    mutant-result-write BC06_RESULT_WRITE_DETECTED
expect_runner_marker state-write BC06_STATE_WRITE \
    mutant-state-write BC06_STATE_WRITE_DETECTED
expect_runner_marker no-outcome BC06_PURE_ZERO_AXES \
    mutant-noop BC06_SUT_OUTCOME_MISSING

evidence="$tmp/evidence-baseline"
run=run-evidence
namespace=ns-evidence
assertion=BC06_PURE_ZERO_AXES
"$runner" "$evidence" "$run" "$namespace" "$assertion" >/dev/null

sed 's/public-a/public-b/g' "$evidence/raw-observations.tsv" \
    >"$tmp/raw-tampered.tsv"
cp "$tmp/raw-tampered.tsv" "$evidence/raw-observations.tsv"
set +e
output=$(
    "$verifier" "$evidence" "$run" "$namespace" "$assertion" \
        "$evidence/$namespace.db" 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "BC06_RAW_SEAL_INVALID" ] || {
    echo "raw post-seal tamper wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_RAW_SEAL_INVALID"

synthesis="$tmp/synthesis"
run=run-synthesis
namespace=ns-synthesis
"$runner" "$synthesis" "$run" "$namespace" "$assertion" >/dev/null
sed 's/obs-010/obs-099/' "$synthesis/normalized-observations.tsv" \
    >"$tmp/normalized-synthesized.tsv"
cp "$tmp/normalized-synthesized.tsv" \
    "$synthesis/normalized-observations.tsv"
set +e
output=$(
    "$verifier" "$synthesis" "$run" "$namespace" "$assertion" \
        "$synthesis/$namespace.db" 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "BC06_COVERAGE_INVALID" ] || {
    echo "observer synthesis wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_COVERAGE_INVALID"

missing="$tmp/missing-artifact"
run=run-missing
namespace=ns-missing
"$runner" "$missing" "$run" "$namespace" "$assertion" >/dev/null
rm "$missing/exclusions.tsv"
set +e
output=$(
    "$verifier" "$missing" "$run" "$namespace" "$assertion" \
        "$missing/$namespace.db" 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$output" = "BC06_REQUIRED_ARTIFACT_MISSING" ] || {
    echo "missing artifact wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_REQUIRED_ARTIFACT_MISSING"

argv="$tmp/argv-custody"
run=run-argv
namespace=ns-argv
"$runner" "$argv" "$run" "$namespace" "$assertion" >/dev/null
awk -F '	' -v OFS='	' '
    { $12 = "0000000000000000000000000000000000000000000000000000000000000000"; print }
' "$argv/command-receipts.tsv" >"$tmp/argv-mutated.tsv"
cp "$tmp/argv-mutated.tsv" "$argv/command-receipts.tsv"
set +e
output=$(
    "$verifier" "$argv" "$run" "$namespace" "$assertion" \
        "$argv/$namespace.db" 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "BC06_COMMAND_CUSTODY_INVALID" ] || {
    echo "argv custody wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_COMMAND_CUSTODY_INVALID"

stdout="$tmp/stdout-custody"
run=run-stdout
namespace=ns-stdout
"$runner" "$stdout" "$run" "$namespace" "$assertion" >/dev/null
awk -F '	' -v OFS='	' '
    $4 == "observe-before" {
        $8 = "0000000000000000000000000000000000000000000000000000000000000000"
    }
    { print }
' "$stdout/command-receipts.tsv" >"$tmp/stdout-mutated.tsv"
cp "$tmp/stdout-mutated.tsv" "$stdout/command-receipts.tsv"
set +e
output=$(
    "$verifier" "$stdout" "$run" "$namespace" "$assertion" \
        "$stdout/$namespace.db" 2>&1
)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = "BC06_COMMAND_CUSTODY_INVALID" ] || {
    echo "stdout custody wrong result: $status $output" >&2
    exit 1
}
echo "ok BC06_COMMAND_CUSTODY_INVALID_STDOUT"

provenance="$tmp/status-provenance"
run=run-provenance
namespace=ns-provenance
"$runner" "$provenance" "$run" "$namespace" "$assertion" >/dev/null
awk -F '	' -v OFS='	' '
    $2 == "raw-013" || $2 == "raw-014" { $6 = "rejected" }
    { print }
' "$provenance/raw-observations.tsv" >"$tmp/raw-status-mutated.tsv"
"$normalizer" "$tmp/raw-status-mutated.tsv" "$assertion" \
    >"$tmp/normalized-status-derived.tsv"
awk -F '	' '
    $2 == "obs-001" || $2 == "obs-005" {
        if ($5 != "rejected") exit 1
        found++
    }
    END { if (found != 2) exit 1 }
' "$tmp/normalized-status-derived.tsv" || {
    echo "normalized status was not derived from raw receipt" >&2
    exit 1
}
echo "ok BC06_NORMALIZED_STATUS_PROVENANCE"

echo "12 BC06 runtime controls detected"
