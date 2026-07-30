#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
builder="$script_dir/build-payload-manifest.sh"

[ "$#" -eq 1 ] || {
    echo "usage: verify-payload-manifest.sh ROOT" >&2
    exit 2
}

root=$1
manifest="$root/payload-manifest.tsv"
[ -f "$manifest" ] || {
    echo PAYLOAD_MANIFEST_MISSING >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
"$builder" "$root" "$tmp/payload-manifest.tsv"
cmp -s "$manifest" "$tmp/payload-manifest.tsv" || {
    echo PAYLOAD_MANIFEST_INVALID >&2
    exit 1
}

echo PAYLOAD_MANIFEST_VALID
