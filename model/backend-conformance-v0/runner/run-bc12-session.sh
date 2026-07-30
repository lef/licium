#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
runtime="$script_dir/run-bc12-runtime.sh"
verifier="$script_dir/verify-bc12-session.sh"

[ "$#" -eq 1 ] || exit 2
session_dir=$1
[ ! -e "$session_dir" ] || {
    echo BC12_SESSION_NOT_FRESH >&2
    exit 1
}
mkdir -p "$session_dir/run-a" "$session_dir/run-b"

for run in run-a run-b
do
    side=${run#run-}
    : >"$session_dir/$run/runtime-status.tsv"
    while IFS='	' read -r assertion _ _
    do
        name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
        namespace="ns-$side-$name"
        output=$(
            "$runtime" "$session_dir/$run/$name" "$run" \
                "$namespace" "$assertion"
        )
        [ "$output" = "BC12_RUNTIME_CONTRACT_VALID
BC12_RUNTIME_VALID" ] || exit 1
        printf '%s\tBC12_RUNTIME_VALID\n' "$assertion" \
            >>"$session_dir/$run/runtime-status.tsv"
    done <"$base_dir/bc12-scenario-ids.tsv"
done

chmod 0644 "$session_dir/run-a/runtime-status.tsv" \
    "$session_dir/run-b/runtime-status.tsv"
"$verifier" "$session_dir"
