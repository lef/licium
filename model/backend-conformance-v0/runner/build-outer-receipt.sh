#!/bin/sh
set -eu

[ "$#" -eq 1 ] || {
    echo "usage: build-outer-receipt.sh ROOT" >&2
    exit 2
}

root=$1
manifest="$root/payload-manifest.tsv"
report="$root/report.tsv"
outer="$root/outer-receipt.tsv"

[ -f "$manifest" ] && [ -f "$report" ] || exit 2

manifest_sha=$(sha256sum "$manifest" | awk '{ print $1 }')
manifest_bytes=$(wc -c <"$manifest" | tr -d ' ')
report_sha=$(sha256sum "$report" | awk '{ print $1 }')
report_bytes=$(wc -c <"$report" | tr -d ' ')

{
    printf 'payload-manifest.tsv\t100644\t%s\t%s\tpayload-manifest\n' \
        "$manifest_sha" "$manifest_bytes"
    printf 'report.tsv\t100644\t%s\t%s\treport\n' \
        "$report_sha" "$report_bytes"
} >"$outer"
chmod 0644 "$outer"
