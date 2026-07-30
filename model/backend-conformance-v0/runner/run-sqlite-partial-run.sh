#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
scenarios="$base_dir/sqlite-partial-scenarios.tsv"
adapter="$base_dir/profiles/sqlite-reference/run.sh"
negative_runner="$script_dir/run-bc02-negative-runtime.sh"
bc01_controls="$script_dir/materialize-bc01-run-controls.sh"
bc03_controls="$script_dir/materialize-bc03-run-controls.sh"
bc04_controls="$script_dir/materialize-bc04-run-controls.sh"
bc05_controls="$script_dir/materialize-bc05-run-controls.sh"
bc06_controls="$script_dir/materialize-bc06-run-controls.sh"
bc07_controls="$script_dir/materialize-bc07-run-controls.sh"
bc08_controls="$script_dir/materialize-bc08-run-controls.sh"
bc09_controls="$script_dir/materialize-bc09-run-controls.sh"
bc10_controls="$script_dir/materialize-bc10-run-controls.sh"
bc11_controls="$script_dir/materialize-bc11-run-controls.sh"
bc12_controls="$script_dir/materialize-bc12-run-controls.sh"
assertion_materializer="$script_dir/materialize-sqlite-partial-assertions.sh"
manifest_builder="$script_dir/build-payload-manifest.sh"
report_builder="$script_dir/materialize-report.sh"
outer_builder="$script_dir/build-outer-receipt.sh"
verifier="$script_dir/verify-sqlite-partial-run.sh"

[ "$#" -eq 4 ] || {
    echo "usage: run-sqlite-partial-run.sh RUN_DIR RUN_ID SIDE LIFECYCLE_DIR" >&2
    exit 2
}

run_dir=$1
run_id=$2
side=$3
lifecycle=$4
case "$side" in a|b) ;; *) exit 2 ;; esac
[ ! -e "$run_dir" ] || {
    echo SQLITE_PARTIAL_RUN_NOT_FRESH >&2
    exit 1
}

mkdir -p "$run_dir"
: >"$run_dir/runtime-status.tsv"

while IFS='	' read -r ordinal suite assertion case_id scenario \
    runner_path verifier_path evidence_policy
do
    scenario_dir="$run_dir/$scenario"
    namespace="ns-$side-$scenario"
    case "$suite" in
        BC01)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC01_RUNTIME_VALID" ] || exit 1
            ;;
        BC02)
            "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                "$namespace" "$assertion" "$case_id" ordinary
            output=BC02_RUNTIME_VALID
            ;;
        BC03)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC03_RUNTIME_VALID" ] || exit 1
            ;;
        BC04)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC04_RUNTIME_VALID" ] || exit 1
            ;;
        BC05)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC05_RUNTIME_VALID" ] || exit 1
            ;;
        BC06)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC06_RUNTIME_VALID" ] || exit 1
            ;;
        BC07)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC07_RUNTIME_VALID" ] || exit 1
            ;;
        BC08)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC08_RUNTIME_VALID" ] || exit 1
            ;;
        BC09)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC09_RUNTIME_CONTRACT_VALID
BC09_RUNTIME_VALID" ] || exit 1
            output=BC09_RUNTIME_VALID
            ;;
        BC10)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC10_RUNTIME_CONTRACT_VALID
BC10_RUNTIME_VALID" ] || exit 1
            output=BC10_RUNTIME_VALID
            ;;
        BC11)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC11_RUNTIME_CONTRACT_VALID
BC11_RUNTIME_VALID" ] || exit 1
            output=BC11_RUNTIME_VALID
            ;;
        BC12)
            output=$(
                "$base_dir/$runner_path" "$scenario_dir" "$run_id" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC12_RUNTIME_CONTRACT_VALID
BC12_RUNTIME_VALID" ] || exit 1
            output=BC12_RUNTIME_VALID
            ;;
        *)
            exit 1
            ;;
    esac
    printf '%s\t%s\t%s\t%s\n' \
        "$ordinal" "$suite" "$scenario" "$output" \
        >>"$run_dir/runtime-status.tsv"
done <"$scenarios"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
"$negative_runner" "$tmp/bc02-negative" "$run_id" \
    "negative-$side" "$run_dir/bc02-negative-receipts.tsv" >/dev/null
"$bc01_controls" "$run_dir" "$run_id" \
    "$run_dir/bc01-control-receipts.tsv"
"$bc03_controls" "$run_dir" "$run_id" \
    "$run_dir/bc03-control-receipts.tsv"
"$bc04_controls" "$run_dir" "$run_id" \
    "$run_dir/bc04-control-receipts.tsv"
"$bc05_controls" "$run_dir" "$run_id" \
    "$run_dir/bc05-control-receipts.tsv"
"$bc06_controls" "$run_dir" "$run_id" \
    "$run_dir/bc06-control-receipts.tsv"
"$bc07_controls" "$run_dir" "$run_id" \
    "$run_dir/bc07-control-receipts.tsv"
"$bc08_controls" "$run_dir" "$run_id" \
    "$run_dir/bc08-control-receipts.tsv"
"$bc09_controls" "$run_dir" "$run_id" \
    "$run_dir/bc09-control-receipts.tsv"
"$bc10_controls" "$run_dir" "$run_id" \
    "$run_dir/bc10-control-receipts.tsv"
"$bc11_controls" "$run_dir" "$run_id" \
    "$run_dir/bc11-control-receipts.tsv"
"$bc12_controls" "$run_dir" "$run_id" \
    "$run_dir/bc12-control-receipts.tsv"

"$adapter" lifecycle-sentinel "$lifecycle" observe "$run_id" sentinel-a \
    >"$run_dir/namespace-inventory.tsv"

{
    "$adapter" describe
    printf 'meta\tglobal\tartifact-kind\tsqlite-partial-run\n'
    printf 'meta\tglobal\trun-id\t%s\n' "$run_id"
    printf 'meta\tglobal\tside\t%s\n' "$side"
    for contract in \
        scenarios.tsv \
        execution-map.tsv \
        sqlite-partial-scenarios.tsv \
        sqlite-partial-bc02-negative-execution.tsv \
        sqlite-partial-canonical.tsv \
        sqlite-partial-run-artifacts.tsv \
        bc02-runtime-artifacts.tsv \
        bc01-runtime-artifacts.tsv \
        bc03-runtime-artifacts.tsv \
        bc03-mutants.tsv \
        bc04-runtime-artifacts.tsv \
        bc04-mutants.tsv \
        bc05-runtime-artifacts.tsv \
        bc05-mutants.tsv \
        bc06-runtime-artifacts.tsv \
        bc07-runtime-artifacts.tsv \
        bc07-mutants.tsv \
        bc08-runtime-artifacts.tsv \
        bc08-mutants.tsv \
        bc09-runtime-artifacts.tsv \
        bc09-mutants.tsv \
        bc10-runtime-artifacts.tsv \
        bc10-mutants.tsv \
        bc11-runtime-artifacts.tsv \
        bc11-mutants.tsv \
        bc12-runtime-artifacts.tsv \
        bc12-mutants.tsv
    do
        contract_name=$(printf '%s' "$contract" | tr 'A-Z_.' 'a-z---')
        printf 'binding\tcontract\t%s\t%s\n' \
            "$contract_name" \
            "$(sha256sum "$base_dir/$contract" | awk '{ print $1 }')"
    done
} >"$run_dir/run-metadata.tsv"

"$assertion_materializer" "$run_dir/assertions.tsv"
"$verifier" "$run_dir" "$run_id" "$side" "$lifecycle" preseal >/dev/null

"$manifest_builder" "$run_dir" "$run_dir/payload-manifest.tsv"
"$report_builder" "$run_dir/assertions.tsv" "$run_dir/report.tsv"
cat "$run_dir/run-metadata.tsv" >>"$run_dir/report.tsv"
printf 'binding\tevidence\tpayload-manifest-sha256\t%s\n' \
    "$(sha256sum "$run_dir/payload-manifest.tsv" | awk '{ print $1 }')" \
    >>"$run_dir/report.tsv"
"$outer_builder" "$run_dir"

"$verifier" "$run_dir" "$run_id" "$side" "$lifecycle" sealed
