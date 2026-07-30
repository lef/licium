#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

[ "$#" -eq 1 ] || {
    echo "usage: closure-digest.sh RELATIVE_PATH_MANIFEST" >&2
    exit 2
}

manifest=$1
case "$manifest" in
    /*|*..*|'') echo "invalid closure manifest path" >&2; exit 1 ;;
esac

manifest_file="$base_dir/$manifest"
[ -f "$manifest_file" ] || {
    echo "missing closure manifest: $manifest" >&2
    exit 1
}

inventory=$(mktemp)
trap 'rm -f "$inventory"' EXIT HUP INT TERM

manifest_sha=$(sha256sum "$manifest_file" | awk '{ print $1 }')
manifest_bytes=$(wc -c <"$manifest_file" | tr -d ' ')
printf 'manifest\t%s\t100644\t%s\t%s\n' \
    "$manifest" "$manifest_sha" "$manifest_bytes" >"$inventory"

previous=
while IFS= read -r path
do
    case "$path" in
        /*|*..*|'') echo "invalid closure path" >&2; exit 1 ;;
    esac
    [ -z "$previous" ] || [ "$previous" \< "$path" ] || {
        echo "closure paths are not strictly sorted" >&2
        exit 1
    }
    file="$base_dir/$path"
    [ -f "$file" ] && [ ! -L "$file" ] || {
        echo "missing or non-regular closure file: $path" >&2
        exit 1
    }
    mode=100644
    [ ! -x "$file" ] || mode=100755
    sha=$(sha256sum "$file" | awk '{ print $1 }')
    bytes=$(wc -c <"$file" | tr -d ' ')
    printf 'file\t%s\t%s\t%s\t%s\n' "$path" "$mode" "$sha" "$bytes" >>"$inventory"
    previous=$path
done <"$manifest_file"

sha256sum "$inventory" | awk '{ print $1 }'
