#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
scenarios="$base_dir/bc01-scenario-ids.tsv"
runtime_runner="$script_dir/run-bc01-runtime.sh"
control_materializer="$script_dir/materialize-bc01-run-controls.sh"
session_verifier="$script_dir/verify-bc01-session.sh"
adapter="$base_dir/profiles/sqlite-reference/run.sh"

[ "$#" -eq 1 ] || exit 2
session_dir=$1
[ ! -e "$session_dir" ] || {
    echo BC01_SESSION_NOT_FRESH >&2
    exit 1
}
mkdir -p "$session_dir/run-a" "$session_dir/run-b" \
    "$session_dir/lifecycle/run-a" "$session_dir/lifecycle/run-b"

for side in a b
do
    run="run-$side"
    run_dir="$session_dir/$run"
    : >"$run_dir/runtime-status.tsv"
    while IFS='	' read -r assertion case_id scenario
    do
        namespace="ns-$side-$scenario"
        output=$("$runtime_runner" "$run_dir/$scenario" "$run" \
            "$namespace" "$assertion")
        [ "$output" = BC01_RUNTIME_VALID ] || exit 1
        printf '%s\t%s\t%s\n' "$assertion" "$scenario" "$output" \
            >>"$run_dir/runtime-status.tsv"
    done <"$scenarios"
    "$control_materializer" "$run_dir" "$run" \
        "$run_dir/control-receipts.tsv"
done

"$adapter" lifecycle-sentinel "$session_dir/lifecycle" put run-a sentinel-a \
    >"$session_dir/lifecycle-command-receipt.tsv"
"$adapter" lifecycle-sentinel "$session_dir/lifecycle" observe run-a sentinel-a \
    >"$session_dir/run-a/namespace-inventory.tsv"
"$adapter" lifecycle-sentinel "$session_dir/lifecycle" observe run-b sentinel-a \
    >"$session_dir/run-b/namespace-inventory.tsv"

"$session_verifier" "$session_dir"
