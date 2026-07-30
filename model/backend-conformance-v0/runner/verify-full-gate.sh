#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verify="$script_dir/verify-report.sh"
profile_verify="$script_dir/verify-profile-report.sh"
session_verify="$script_dir/verify-sqlite-partial-session.sh"
profile="$script_dir/../profiles/sqlite-reference/profile.tsv"

[ "$#" -eq 1 ] || {
    echo "usage: verify-full-gate.sh ARTIFACT_DIR" >&2
    exit 2
}

artifact_dir=$1
"$verify" "$artifact_dir" >/dev/null

LC_ALL=C awk -F '	' '
    NF != 8 || $5 != "PASS" { nonpass = 1 }
    { count++ }
    END { exit nonpass || count != 83 ? 1 : 0 }
' "$artifact_dir/assertions.tsv" || {
    echo "FULL_GATE_NONPASS" >&2
    exit 1
}

"$profile_verify" "$profile" "$artifact_dir/assertions.tsv" >/dev/null 2>&1 || {
    echo "FULL_GATE_PROFILE_INVALID" >&2
    exit 1
}

"$session_verify" "$artifact_dir" sealed >/dev/null 2>&1 || {
    echo "FULL_GATE_SESSION_INVALID" >&2
    exit 1
}

echo SQLITE_FULL_CONFORMANCE_VALID
