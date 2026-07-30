#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
run_runner="$script_dir/run-sqlite-partial-run.sh"
canonical="$script_dir/materialize-sqlite-partial-canonical.sh"
controls="$script_dir/materialize-sqlite-partial-session-controls.sh"
manifest_builder="$script_dir/build-payload-manifest.sh"
report_builder="$script_dir/materialize-report.sh"
outer_builder="$script_dir/build-outer-receipt.sh"
verifier="$script_dir/verify-sqlite-partial-session.sh"

[ "$#" -eq 1 ] || {
    echo "usage: run-sqlite-partial-session.sh SESSION_DIR" >&2
    exit 2
}

session_dir=$1
[ ! -e "$session_dir" ] || {
    echo SQLITE_PARTIAL_SESSION_NOT_FRESH >&2
    exit 1
}
lifecycle="$session_dir/lifecycle"
mkdir -p "$lifecycle/run-a" "$lifecycle/run-b"
"$adapter" lifecycle-sentinel "$lifecycle" put run-a sentinel-a \
    >"$session_dir/lifecycle-command-receipt.tsv"

"$run_runner" "$session_dir/run-a" run-a a "$lifecycle" >/dev/null
"$run_runner" "$session_dir/run-b" run-b b "$lifecycle" >/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
"$canonical" "$session_dir/run-a" "$tmp/canonical-a.tsv"
"$canonical" "$session_dir/run-b" "$tmp/canonical-b.tsv"
cmp -s "$tmp/canonical-a.tsv" "$tmp/canonical-b.tsv" ||
    { echo SQLITE_PARTIAL_CANONICAL_INVALID >&2; exit 1; }
cp "$tmp/canonical-a.tsv" "$session_dir/canonical-comparison.tsv"

{
    awk -F '	' -v OFS='	' '{ print "run-a",$0 }' \
        "$session_dir/run-a/assertions.tsv"
    awk -F '	' -v OFS='	' '{ print "run-b",$0 }' \
        "$session_dir/run-b/assertions.tsv"
} >"$session_dir/aggregate-dispositions.tsv"
cp "$session_dir/run-a/assertions.tsv" "$session_dir/assertions.tsv"

{
    printf 'meta\tglobal\tartifact-kind\tsqlite-partial-session\n'
    printf 'binding\tsession\trun-a-outer-sha256\t%s\n' \
        "$(sha256sum "$session_dir/run-a/outer-receipt.tsv" | awk '{ print $1 }')"
    printf 'binding\tsession\trun-b-outer-sha256\t%s\n' \
        "$(sha256sum "$session_dir/run-b/outer-receipt.tsv" | awk '{ print $1 }')"
    printf 'binding\tsession\tcanonical-comparison-sha256\t%s\n' \
        "$(sha256sum "$session_dir/canonical-comparison.tsv" | awk '{ print $1 }')"
    printf 'binding\tsession\taggregate-dispositions-sha256\t%s\n' \
        "$(sha256sum "$session_dir/aggregate-dispositions.tsv" | awk '{ print $1 }')"
} >"$session_dir/run-metadata.tsv"

: >"$session_dir/control-receipts.tsv"
"$controls" "$session_dir" "$tmp/control-receipts.tsv"
cp "$tmp/control-receipts.tsv" "$session_dir/control-receipts.tsv"

"$verifier" "$session_dir" preseal >/dev/null
"$manifest_builder" "$session_dir" "$session_dir/payload-manifest.tsv"
"$report_builder" "$session_dir/assertions.tsv" "$session_dir/report.tsv"
cat "$session_dir/run-metadata.tsv" >>"$session_dir/report.tsv"
printf 'binding\tevidence\tpayload-manifest-sha256\t%s\n' \
    "$(sha256sum "$session_dir/payload-manifest.tsv" | awk '{ print $1 }')" \
    >>"$session_dir/report.tsv"
"$outer_builder" "$session_dir"

"$verifier" "$session_dir" sealed
