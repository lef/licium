#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

here=$(CDPATH= cd "$(dirname "$0")" && pwd)
manifest="$here/manifest.tsv"
root="$here/session-b"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/licium-v3-evidence.XXXXXX")
trap 'status=$?; rm -rf "$tmp"; exit "$status"' EXIT HUP INT TERM
tab=$(printf '\t')

fail()
{
    echo "$1" >&2
    exit 1
}

[ -f "$manifest" ] && [ ! -L "$manifest" ] ||
    fail SQLITE_REFERENCE_EVIDENCE_MANIFEST_MISSING
[ "$(sha256sum "$manifest" | awk '{ print $1 }')" = \
    fbf0def4fc1ce169b165616a12e900c22fe56a8796a376118531f581b721a8da ] ||
    fail SQLITE_REFERENCE_EVIDENCE_MANIFEST_INVALID

awk -F "$tab" '
    NF != 4 || $1 == "" || $1 ~ /(^|\/)\.\.?($|\/)/ || $1 ~ /^\// ||
        $2 != "100644" || $3 !~ /^[0-9]+$/ ||
        $4 !~ /^[0-9a-f][0-9a-f]*$/ { exit 1 }
    seen[$1]++ { exit 1 }
    END { if (NR != 47) exit 1 }
' "$manifest" || fail SQLITE_REFERENCE_EVIDENCE_MANIFEST_SHAPE_INVALID
LC_ALL=C sort -c "$manifest" 2>/dev/null ||
    fail SQLITE_REFERENCE_EVIDENCE_MANIFEST_ORDER_INVALID

awk -F "$tab" '{ print $1 }' "$manifest" >"$tmp/expected-paths"
find "$root" ! -type d -print |
    sed "s#^$here/##" |
    LC_ALL=C sort >"$tmp/actual-paths"
cmp "$tmp/expected-paths" "$tmp/actual-paths" ||
    fail SQLITE_REFERENCE_EVIDENCE_PATH_SET_INVALID

find "$root" -type d -print |
    sed "s#^$here/##" |
    LC_ALL=C sort >"$tmp/actual-directories"
printf '%s\n' session-b session-b/run-a session-b/run-b |
    LC_ALL=C sort >"$tmp/expected-directories"
cmp "$tmp/expected-directories" "$tmp/actual-directories" ||
    fail SQLITE_REFERENCE_EVIDENCE_DIRECTORY_SET_INVALID

while IFS="$tab" read -r path mode bytes digest
do
    file="$here/$path"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail SQLITE_REFERENCE_EVIDENCE_FILE_INVALID
    [ "100$(stat -c '%a' "$file")" = "$mode" ] ||
        fail SQLITE_REFERENCE_EVIDENCE_MODE_INVALID
    [ "$(wc -c <"$file" | tr -d ' ')" = "$bytes" ] ||
        fail SQLITE_REFERENCE_EVIDENCE_BYTES_INVALID
    [ "$(sha256sum "$file" | awk '{ print $1 }')" = "$digest" ] ||
        fail SQLITE_REFERENCE_EVIDENCE_DIGEST_INVALID
done <"$manifest"

[ "$(sha256sum "$root/outer-receipt.tsv" | awk '{ print $1 }')" = \
    6df6d4d3563882f6495f3b95c27b3f65049d3ef60da846dad8fe3da445ec070f ] ||
    fail SQLITE_REFERENCE_EVIDENCE_OUTER_INVALID
[ "$(sha256sum "$root/report.tsv" | awk '{ print $1 }')" = \
    b0b4f58cf95d61113d94250c6764b081dfaca3253ec178a01c6b6900eac452b7 ] ||
    fail SQLITE_REFERENCE_EVIDENCE_REPORT_INVALID
[ "$(sha256sum "$root/payload-manifest.tsv" | awk '{ print $1 }')" = \
    10de84ce7ad3b9671b356e2a5f981390752bc03f22e6863b58bed0fe07729571 ] ||
    fail SQLITE_REFERENCE_EVIDENCE_PAYLOAD_MANIFEST_INVALID

echo SQLITE_REFERENCE_EVIDENCE_VALID
