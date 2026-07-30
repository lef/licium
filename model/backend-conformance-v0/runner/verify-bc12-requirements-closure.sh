#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
manifest="$base_dir/requirements-closure-bc12.tsv"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -f "$manifest" ] && [ ! -L "$manifest" ] ||
    fail BC12_REQUIREMENTS_CLOSURE_MISSING
[ "$(stat -c '%a' "$manifest")" = 644 ] ||
    fail BC12_REQUIREMENTS_CLOSURE_MODE_INVALID
[ "$(sha256sum "$manifest" | awk '{ print $1 }')" = \
    "2cbe803647f8ea331d8d7f98adba8d23c88175f0a8ebff52b20ef53d13fc1a35" ] ||
    fail BC12_REQUIREMENTS_CLOSURE_MANIFEST_INVALID

awk -F '	' '
    NF != 3 || $1 ~ /(^|\/)\.\.?($|\/)/ || $1 ~ /^\// ||
        $2 !~ /^(644|755)$/ ||
        $3 !~ /^[0-9a-f][0-9a-f]*$/ { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 19) exit 1 }
' "$manifest" || fail BC12_REQUIREMENTS_CLOSURE_SHAPE_INVALID
LC_ALL=C sort -c "$manifest" 2>/dev/null ||
    fail BC12_REQUIREMENTS_CLOSURE_SHAPE_INVALID

while IFS='	' read -r path mode expected
do
    file="$model_dir/$path"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC12_REQUIREMENTS_CLOSURE_FILE_MISSING
    [ "$(stat -c '%a' "$file")" = "$mode" ] ||
        fail BC12_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
    [ "$(sha256sum "$file" | awk '{ print $1 }')" = "$expected" ] ||
        fail BC12_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
done <"$manifest"

"$script_dir/verify-bc12-requirements.sh" >/dev/null ||
    fail BC12_REQUIREMENTS_CONTRACT_INVALID
"$script_dir/self-test-bc12-requirements.sh" >/dev/null ||
    fail BC12_REQUIREMENTS_SELF_TEST_INVALID

echo BC12_REQUIREMENTS_CLOSURE_VALID
