#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
model_dir=$(CDPATH= cd -- "$base_dir/.." && pwd)
manifest="$base_dir/requirements-closure-bc01.tsv"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -f "$manifest" ] && [ ! -L "$manifest" ] ||
    fail BC01_REQUIREMENTS_CLOSURE_MISSING
[ "$(stat -c '%a' "$manifest")" = 644 ] ||
    fail BC01_REQUIREMENTS_CLOSURE_MODE_INVALID
[ "$(sha256sum "$manifest" | awk '{ print $1 }')" = \
    "d58ed1705f818548d49517299696eda4c2fb42fbcf29468ef5403f27c250eff0" ] ||
    fail BC01_REQUIREMENTS_CLOSURE_MANIFEST_INVALID

awk -F '	' '
    NF != 3 || $1 ~ /(^|\/)\.\.?($|\/)/ || $1 ~ /^\// ||
        $2 !~ /^(644|755)$/ || $3 !~ /^[0-9a-f][0-9a-f]*$/ { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 31) exit 1 }
' "$manifest" || fail BC01_REQUIREMENTS_CLOSURE_SHAPE_INVALID
LC_ALL=C sort -c "$manifest" 2>/dev/null ||
    fail BC01_REQUIREMENTS_CLOSURE_SHAPE_INVALID

while IFS='	' read -r path mode expected
do
    file="$model_dir/$path"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC01_REQUIREMENTS_CLOSURE_FILE_MISSING
    [ "$(stat -c '%a' "$file")" = "$mode" ] ||
        fail BC01_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
    [ "$(sha256sum "$file" | awk '{ print $1 }')" = "$expected" ] ||
        fail BC01_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
done < "$manifest"

"$script_dir/verify-bc01-contract.sh" ||
    fail BC01_REQUIREMENTS_CONTRACT_INVALID
"$script_dir/self-test-bc01-contract.sh" ||
    fail BC01_REQUIREMENTS_SELF_TEST_INVALID

echo BC01_REQUIREMENTS_CLOSURE_VALID
