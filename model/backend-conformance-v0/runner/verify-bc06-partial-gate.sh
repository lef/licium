#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
profile="$base_dir/profiles/sqlite-reference/profile.tsv"
session_runner="$script_dir/run-bc06-session.sh"
run_materializer="$script_dir/materialize-bc06-run.sh"
session_sealer="$script_dir/seal-bc06-session.sh"
profile_report="$script_dir/verify-profile-report.sh"
full_gate="$script_dir/verify-full-gate.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
session="$tmp/session"

"$session_runner" "$session" >/dev/null
"$run_materializer" "$session/run-a" run-a >/dev/null
"$run_materializer" "$session/run-b" run-b >/dev/null
"$session_sealer" "$session" >/dev/null

for artifact_dir in "$session/run-a" "$session/run-b" "$session"
do
    "$profile_report" "$profile" "$artifact_dir/assertions.tsv" >/dev/null
    awk -F '	' '
        $5 == "PASS" { pass++ }
        $5 == "UNTESTED" { untested++ }
        $5 == "FAIL" { fail++ }
        $5 == "UNAVAILABLE" { unavailable++ }
        $5 == "INVALID" { invalid++ }
        $1 == "BC06" && $5 != "PASS" { exit 1 }
        $1 != "BC06" && $5 != "UNTESTED" { exit 1 }
        END {
            if (pass != 5 || untested != 78 ||
                fail != 0 || unavailable != 0 || invalid != 0) exit 1
        }
    ' "$artifact_dir/assertions.tsv" || {
        echo BC06_PARTIAL_DISPOSITION_INVALID >&2
        exit 1
    }
    set +e
    output=$("$full_gate" "$artifact_dir" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$output" = "FULL_GATE_NONPASS" ] || {
        echo BC06_PARTIAL_FULL_GATE_INVALID >&2
        exit 1
    }
done

echo BC06_PARTIAL_GATE_VALID
