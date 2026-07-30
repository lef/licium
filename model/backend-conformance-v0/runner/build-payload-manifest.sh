#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: build-payload-manifest.sh ROOT MANIFEST" >&2
    exit 2
}

root=$1
manifest=$2

[ -d "$root" ] || exit 2

find "$root" -type l -print | awk 'NR == 1 { exit 1 }' ||
    { echo PAYLOAD_SYMLINK_INVALID >&2; exit 1; }
find "$root" ! -type d ! -type f -print | awk 'NR == 1 { exit 1 }' ||
    { echo PAYLOAD_SPECIAL_FILE_INVALID >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
find "$root" -type f -print >"$tmp/paths"
: >"$tmp/rows"
while IFS= read -r file
do
    relative=${file#"$root"/}
    case "$relative" in
        payload-manifest.tsv|report.tsv|outer-receipt.tsv)
            continue
            ;;
    esac
    case "$relative" in
        /*|*../*|../*|*/..)
            echo PAYLOAD_PATH_INVALID >&2
            exit 1
            ;;
    esac
    find "$file" -prune -type f -perm 0644 |
        awk 'NR == 1 { found = 1 } END { exit !found }' ||
        { echo PAYLOAD_MODE_INVALID >&2; exit 1; }
    sha=$(sha256sum "$file" | awk '{ print $1 }')
    bytes=$(wc -c <"$file" | tr -d ' ')
    printf '%s\t100644\t%s\t%s\tevidence\n' \
        "$relative" "$sha" "$bytes" >>"$tmp/rows"
done <"$tmp/paths"
LC_ALL=C sort "$tmp/rows" >"$manifest"
chmod 0644 "$manifest"
