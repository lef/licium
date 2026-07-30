#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases="$base_dir/bc09-cases.tsv"
runtime="$script_dir/run-bc09-runtime.sh"
verifier="$script_dir/verify-bc09-session.sh"

[ "$#" -eq 1 ] || exit 2
session_dir=$1
[ ! -e "$session_dir" ] || {
    echo BC09_SESSION_NOT_FRESH >&2
    exit 1
}
mkdir -p "$session_dir/run-a" "$session_dir/run-b"

for run in run-a run-b
do
    side=${run#run-}
    : >"$session_dir/$run/runtime-status.tsv"
    awk -F '	' '!seen[$1]++ { print $1 }' "$cases" |
        while IFS= read -r assertion
        do
            name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
            namespace="ns-$side-$name"
            output=$(
                "$runtime" "$session_dir/$run/$name" "$run" \
                    "$namespace" "$assertion"
            )
            [ "$output" = "BC09_RUNTIME_CONTRACT_VALID
BC09_RUNTIME_VALID" ] || exit 1
            printf '%s\tBC09_RUNTIME_VALID\n' "$assertion" \
                >>"$session_dir/$run/runtime-status.tsv"
        done
done

"$verifier" "$session_dir"
