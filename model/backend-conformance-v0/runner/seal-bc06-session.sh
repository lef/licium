#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
canonical="$script_dir/materialize-bc06-canonical.sh"
manifest_builder="$script_dir/build-payload-manifest.sh"
report_builder="$script_dir/materialize-report.sh"
outer_builder="$script_dir/build-outer-receipt.sh"
sealed_run_verifier="$script_dir/verify-sealed-run.sh"
sealed_session_verifier="$script_dir/verify-sealed-session.sh"
session_control_materializer="$script_dir/materialize-bc06-session-controls.sh"
session_layout_verifier="$script_dir/verify-bc06-session-layout.sh"

[ "$#" -eq 1 ] || {
    echo "usage: seal-bc06-session.sh SESSION_DIR" >&2
    exit 2
}

session_dir=$1
run_a="$session_dir/run-a"
run_b="$session_dir/run-b"

"$sealed_run_verifier" "$run_a" >/dev/null
"$sealed_run_verifier" "$run_b" >/dev/null
cmp -s "$run_a/assertions.tsv" "$run_b/assertions.tsv" || {
    echo BC06_SECOND_RUN_DRIFT_DETECTED >&2
    exit 1
}
cmp -s "$run_a/run-metadata.tsv" "$run_b/run-metadata.tsv" || {
    echo BC06_SECOND_RUN_DRIFT_DETECTED >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
"$canonical" "$run_a" "$tmp/canonical-a.tsv"
"$canonical" "$run_b" "$tmp/canonical-b.tsv"
cmp -s "$tmp/canonical-a.tsv" "$tmp/canonical-b.tsv" || {
    echo BC06_SECOND_RUN_DRIFT_DETECTED >&2
    exit 1
}
cp "$tmp/canonical-a.tsv" "$session_dir/canonical-comparison.tsv"
"$session_control_materializer" "$session_dir" "$tmp/control-receipts.tsv"
cp "$tmp/control-receipts.tsv" "$session_dir/control-receipts.tsv"

{
    awk -F '	' -v OFS='	' '{ print "run-a",$0 }' "$run_a/assertions.tsv"
    awk -F '	' -v OFS='	' '{ print "run-b",$0 }' "$run_b/assertions.tsv"
} >"$session_dir/aggregate-dispositions.tsv"
cp "$run_a/assertions.tsv" "$session_dir/assertions.tsv"

{
    printf 'meta\tglobal\tartifact-kind\tbc06-partial-session\n'
    awk -F '	' '$1 == "binding" && ($2 == "closure" || $2 == "contract")' \
        "$run_a/run-metadata.tsv"
} >"$session_dir/run-metadata.tsv"

run_a_outer_sha=$(sha256sum "$run_a/outer-receipt.tsv" | awk '{ print $1 }')
run_b_outer_sha=$(sha256sum "$run_b/outer-receipt.tsv" | awk '{ print $1 }')
comparison_sha=$(sha256sum "$session_dir/canonical-comparison.tsv" |
    awk '{ print $1 }')
aggregate_sha=$(sha256sum "$session_dir/aggregate-dispositions.tsv" |
    awk '{ print $1 }')
{
    printf 'binding\tsession\trun-a-outer-sha256\t%s\n' "$run_a_outer_sha"
    printf 'binding\tsession\trun-b-outer-sha256\t%s\n' "$run_b_outer_sha"
    printf 'binding\tsession\tcanonical-comparison-sha256\t%s\n' \
        "$comparison_sha"
    printf 'binding\tsession\taggregate-dispositions-sha256\t%s\n' \
        "$aggregate_sha"
} >>"$session_dir/run-metadata.tsv"

"$session_layout_verifier" "$session_dir" preseal >/dev/null
"$manifest_builder" "$session_dir" "$session_dir/payload-manifest.tsv"
"$report_builder" "$session_dir/assertions.tsv" "$session_dir/report.tsv"
cat "$session_dir/run-metadata.tsv" >>"$session_dir/report.tsv"
manifest_sha=$(sha256sum "$session_dir/payload-manifest.tsv" | awk '{ print $1 }')
printf 'binding\tevidence\tpayload-manifest-sha256\t%s\n' "$manifest_sha" \
    >>"$session_dir/report.tsv"
"$outer_builder" "$session_dir"
"$sealed_session_verifier" "$session_dir"
