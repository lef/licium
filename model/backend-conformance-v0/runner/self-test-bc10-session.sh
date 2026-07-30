#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc10-session.sh"
verifier="$script_dir/verify-bc10-session.sh"

[ -x "$runner" ] && [ -x "$verifier" ] || {
    echo BC10_SESSION_MISSING >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$runner" "$tmp/session")" = BC10_SESSION_VALID ] || exit 1
echo BC10_SESSION_VALID

cp -R "$tmp/session" "$tmp/copied"
cp "$tmp/copied/run-a/bc10-result-closed/action-receipts.tsv" \
    "$tmp/copied/run-b/bc10-result-closed/action-receipts.tsv"
set +e
output=$("$verifier" "$tmp/copied" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = BC10_COPIED_RUN_DETECTED ] ||
    exit 1
echo BC10_COPIED_RUN_DETECTED

cp -R "$tmp/session" "$tmp/drift"
target="$tmp/drift/run-b/bc10-result-closed/normalized-observations.tsv"
awk -F '	' 'BEGIN { OFS=FS }
    NR == 1 { $6="forged" }
    { print }
' "$target" >"$tmp/edit"
mv "$tmp/edit" "$target"
set +e
output=$("$verifier" "$tmp/drift" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$output" = BC10_SECOND_RUN_DRIFT_DETECTED ] || exit 1
echo BC10_SECOND_RUN_DRIFT_DETECTED

set +e
output=$("$runner" "$tmp/session" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = BC10_SESSION_NOT_FRESH ] ||
    exit 1
echo BC10_SESSION_NOT_FRESH
echo "3 BC10 session controls detected"
