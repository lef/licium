#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc09-session.sh"
verifier="$script_dir/verify-bc09-session.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$runner" "$tmp/session")" = BC09_SESSION_VALID ] || exit 1

cp -R "$tmp/session" "$tmp/copied"
cp "$tmp/copied/run-a/bc09-stale-persists/action-receipts.tsv" \
    "$tmp/copied/run-b/bc09-stale-persists/action-receipts.tsv"
set +e
output=$("$verifier" "$tmp/copied" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = BC09_COPIED_RUN_DETECTED ] ||
    exit 1
echo BC09_COPIED_RUN_DETECTED

cp -R "$tmp/session" "$tmp/rewritten-copy"
cp -R "$tmp/rewritten-copy/run-a/." "$tmp/rewritten-copy/run-b/"
for receipt in "$tmp/rewritten-copy"/run-b/*/action-receipts.tsv
do
    awk -F '	' 'BEGIN { OFS=FS }
        {$1="run-b"; sub(/^ns-a-/, "ns-b-", $2)}
        NR==1 {$12="forged-copy-nonce"}
        {print}
    ' "$receipt" >"$tmp/edit"
    mv "$tmp/edit" "$receipt"
done
set +e
output=$("$verifier" "$tmp/rewritten-copy" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] &&
    [ "$output" = BC09_ACTION_RECEIPT_CONTRACT_INVALID ] ||
    exit 1
echo BC09_REWRITTEN_COPY_DETECTED

cp -R "$tmp/session" "$tmp/drift"
awk -F '	' 'BEGIN { OFS=FS }
    NR==1 {$6="forged"} {print}
' "$tmp/drift/run-b/bc09-stale-persists/normalized-observations.tsv" \
    >"$tmp/edit"
mv "$tmp/edit" \
    "$tmp/drift/run-b/bc09-stale-persists/normalized-observations.tsv"
set +e
output=$("$verifier" "$tmp/drift" 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] && [ "$output" = BC09_NORMALIZED_CONTRACT_INVALID ] ||
    exit 1
echo BC09_SECOND_RUN_DRIFT_DETECTED

echo "3 BC09 session controls detected"
