#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
model_dir=$(CDPATH= cd -- "$base_dir/.." && pwd)
manifest="$base_dir/requirements-closure-bc09.tsv"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -f "$manifest" ] && [ ! -L "$manifest" ] ||
    fail BC09_REQUIREMENTS_CLOSURE_MISSING
[ "$(stat -c '%a' "$manifest")" = 644 ] ||
    fail BC09_REQUIREMENTS_CLOSURE_MODE_INVALID
[ "$(sha256sum "$manifest" | awk '{ print $1 }')" = \
    "ca1709ee9d7a42e92478e488b8152b692a1b7f6e1f858e97fb78720d97c9484f" ] ||
    fail BC09_REQUIREMENTS_CLOSURE_MANIFEST_INVALID

awk -F '	' '
    NF != 3 || $1 ~ /(^|\/)\.\.?($|\/)/ || $1 ~ /^\// ||
        $2 !~ /^(644|755)$/ ||
        $3 !~ /^[0-9a-f][0-9a-f]*$/ { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 33) exit 1 }
' "$manifest" || fail BC09_REQUIREMENTS_CLOSURE_SHAPE_INVALID
sort -c "$manifest" 2>/dev/null ||
    fail BC09_REQUIREMENTS_CLOSURE_SHAPE_INVALID

while IFS='	' read -r path mode expected
do
    file="$model_dir/$path"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC09_REQUIREMENTS_CLOSURE_FILE_MISSING
    [ "$(stat -c '%a' "$file")" = "$mode" ] ||
        fail BC09_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
    [ "$(sha256sum "$file" | awk '{ print $1 }')" = "$expected" ] ||
        fail BC09_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
done <"$manifest"

"$script_dir/verify-bc09-requirements.sh" >/dev/null ||
    fail BC09_REQUIREMENTS_CONTRACT_INVALID
"$script_dir/self-test-bc09-requirements.sh" >/dev/null ||
    fail BC09_REQUIREMENTS_SELF_TEST_INVALID

echo BC09_REQUIREMENTS_CLOSURE_VALID
