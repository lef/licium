#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sealed_run_verifier="$script_dir/verify-sealed-run.sh"
sealed_root_verifier="$script_dir/verify-sealed-run.sh"
canonical="$script_dir/materialize-bc06-canonical.sh"
session_control_verifier="$script_dir/verify-bc06-session-controls.sh"

[ "$#" -eq 1 ] || {
    echo "usage: verify-sealed-session.sh SESSION_DIR" >&2
    exit 2
}

session_dir=$1
run_a="$session_dir/run-a"
run_b="$session_dir/run-b"

fail()
{
    echo "$1" >&2
    exit 1
}

if ! "$sealed_run_verifier" "$run_a" >/dev/null 2>&1; then
    fail SESSION_RUN_A_INVALID
fi
if ! "$sealed_run_verifier" "$run_b" >/dev/null 2>&1; then
    fail SESSION_RUN_B_INVALID
fi
if ! "$sealed_root_verifier" "$session_dir" >/dev/null 2>&1; then
    fail SESSION_SEAL_INVALID
fi

cmp -s "$run_a/assertions.tsv" "$run_b/assertions.tsv" ||
    fail SESSION_DISPOSITION_DRIFT
cmp -s "$run_a/run-metadata.tsv" "$run_b/run-metadata.tsv" ||
    fail SESSION_RUNTIME_BINDING_DRIFT
cmp -s "$run_a/assertions.tsv" "$session_dir/assertions.tsv" ||
    fail SESSION_DISPOSITION_DRIFT

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
"$canonical" "$run_a" "$tmp/canonical-a.tsv"
"$canonical" "$run_b" "$tmp/canonical-b.tsv"
cmp -s "$tmp/canonical-a.tsv" "$tmp/canonical-b.tsv" ||
    fail BC06_SECOND_RUN_DRIFT_DETECTED
cmp -s "$tmp/canonical-a.tsv" "$session_dir/canonical-comparison.tsv" ||
    fail SESSION_COMPARISON_INVALID

{
    awk -F '	' -v OFS='	' '{ print "run-a",$0 }' "$run_a/assertions.tsv"
    awk -F '	' -v OFS='	' '{ print "run-b",$0 }' "$run_b/assertions.tsv"
} >"$tmp/aggregate.tsv"
cmp -s "$tmp/aggregate.tsv" "$session_dir/aggregate-dispositions.tsv" ||
    fail SESSION_AGGREGATE_INVALID

"$session_control_verifier" "$session_dir" >/dev/null ||
    fail BC06_SESSION_CONTROL_RECEIPT_INVALID

run_a_outer_sha=$(sha256sum "$run_a/outer-receipt.tsv" | awk '{ print $1 }')
run_b_outer_sha=$(sha256sum "$run_b/outer-receipt.tsv" | awk '{ print $1 }')
comparison_sha=$(sha256sum "$session_dir/canonical-comparison.tsv" |
    awk '{ print $1 }')
aggregate_sha=$(sha256sum "$session_dir/aggregate-dispositions.tsv" |
    awk '{ print $1 }')
awk -F '	' -v a="$run_a_outer_sha" -v b="$run_b_outer_sha" \
    -v comparison="$comparison_sha" -v aggregate="$aggregate_sha" '
    $0 == "binding\tsession\trun-a-outer-sha256\t" a { a_seen++ }
    $0 == "binding\tsession\trun-b-outer-sha256\t" b { b_seen++ }
    $0 == "binding\tsession\tcanonical-comparison-sha256\t" comparison { comparison_seen++ }
    $0 == "binding\tsession\taggregate-dispositions-sha256\t" aggregate { aggregate_seen++ }
    END {
        if (a_seen != 1 || b_seen != 1 ||
            comparison_seen != 1 || aggregate_seen != 1) exit 1
    }
' "$session_dir/report.tsv" || fail SESSION_REPORT_BINDING_INVALID

echo SESSION_SEAL_VALID
