#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases="$base_dir/bc06-cases.tsv"
runtime_runner="$script_dir/run-bc06-runtime.sh"
session_verifier="$script_dir/verify-bc06-session.sh"

[ "$#" -eq 1 ] || {
    echo "usage: run-bc06-session.sh SESSION_DIR" >&2
    exit 2
}

session_dir=$1
mkdir -p "$session_dir/run-a" "$session_dir/run-b"
lifecycle="$session_dir/lifecycle"
mkdir -p "$lifecycle/run-a" "$lifecycle/run-b"

for run in run-a run-b
do
    run_dir="$session_dir/$run"
    side=${run#run-}
    : >"$run_dir/runtime-status.tsv"
    while IFS='	' read -r assertion kind normal_mode control_mode count disposition
    do
        name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
        namespace="ns-$side-$name"
        output=$(
            "$runtime_runner" "$run_dir/$name" "$run" "$namespace" \
                "$assertion"
        )
        [ "$output" = "BC06_RUNTIME_VALID" ] || exit 1
        printf '%s\t%s\n' "$assertion" "$output" \
            >>"$run_dir/runtime-status.tsv"
    done <"$cases"
done

adapter="$base_dir/profiles/sqlite-reference/run.sh"
"$adapter" lifecycle-sentinel "$lifecycle" put run-a sentinel-a \
    >"$session_dir/lifecycle-command-receipt.tsv"
"$adapter" lifecycle-sentinel "$lifecycle" observe run-a sentinel-a \
    >"$session_dir/run-a/namespace-inventory.tsv"
"$adapter" lifecycle-sentinel "$lifecycle" observe run-b sentinel-a \
    >"$session_dir/run-b/namespace-inventory.tsv"

"$session_verifier" "$session_dir"
