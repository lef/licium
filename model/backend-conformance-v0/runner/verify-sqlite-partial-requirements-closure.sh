#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
model_dir=$(CDPATH= cd -- "$base_dir/.." && pwd)
manifest="$base_dir/requirements-closure-sqlite-partial.tsv"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -f "$manifest" ] && [ ! -L "$manifest" ] ||
    fail SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_MISSING
[ "$(stat -c '%a' "$manifest")" = 644 ] ||
    fail SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_MODE_INVALID
[ "$(sha256sum "$manifest" | awk '{ print $1 }')" = \
    "18d6d087a4d8dc2d649e16431979e398352b58c8b8363ef969370370716ffb7e" ] ||
    fail SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_MANIFEST_INVALID

awk -F '	' '
    NF != 3 || $1 ~ /(^|\/)\.\.?($|\/)/ || $1 ~ /^\// ||
        $2 !~ /^(644|755)$/ ||
        $3 !~ /^[0-9a-f][0-9a-f]*$/ { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 56) exit 1 }
' "$manifest" || fail SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_SHAPE_INVALID
LC_ALL=C sort -c "$manifest" 2>/dev/null ||
    fail SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_SHAPE_INVALID

while IFS='	' read -r path mode expected
do
    file="$model_dir/$path"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_FILE_MISSING
    [ "$(stat -c '%a' "$file")" = "$mode" ] ||
        fail SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
    [ "$(sha256sum "$file" | awk '{ print $1 }')" = "$expected" ] ||
        fail SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
done < "$manifest"

"$script_dir/verify-sqlite-partial-requirements.sh" >/dev/null ||
    fail SQLITE_PARTIAL_REQUIREMENTS_CONTRACT_INVALID
"$script_dir/self-test-sqlite-partial-requirements.sh" >/dev/null ||
    fail SQLITE_PARTIAL_REQUIREMENTS_SELF_TEST_INVALID

echo SQLITE_PARTIAL_REQUIREMENTS_CLOSURE_VALID
