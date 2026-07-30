#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases="$base_dir/bc07-cases.tsv"
runtime_runner="$script_dir/run-bc07-runtime.sh"
session_verifier="$script_dir/verify-bc07-session.sh"

[ "$#" -eq 1 ] || {
    echo "usage: run-bc07-session.sh SESSION_DIR" >&2
    exit 2
}

session_dir=$1
[ ! -e "$session_dir" ] || {
    echo BC07_SESSION_NOT_FRESH >&2
    exit 1
}
mkdir -p "$session_dir/run-a" "$session_dir/run-b"

for run in run-a run-b
do
    run_dir="$session_dir/$run"
    side=${run#run-}
    : >"$run_dir/runtime-status.tsv"
    while IFS='	' read -r assertion _ _ _ _ _ _
    do
        name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
        namespace="ns-$side-$name"
        output=$(
            "$runtime_runner" "$run_dir/$name" "$run" "$namespace" \
                "$assertion"
        )
        [ "$output" = BC07_RUNTIME_VALID ] || exit 1
        printf '%s\t%s\n' "$assertion" "$output" \
            >>"$run_dir/runtime-status.tsv"
    done <"$cases"
done

"$session_verifier" "$session_dir"
