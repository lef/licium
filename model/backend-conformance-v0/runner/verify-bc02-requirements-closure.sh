#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
model_dir=$(CDPATH= cd -- "$base_dir/.." && pwd)
manifest="$base_dir/requirements-closure-bc02.tsv"

fail() {
    echo "$1" >&2
    exit 1
}

[ -f "$manifest" ] && [ ! -L "$manifest" ] ||
    fail BC02_REQUIREMENTS_CLOSURE_MISSING
[ "$(stat -c '%a' "$manifest")" = "644" ] ||
    fail BC02_REQUIREMENTS_CLOSURE_MODE_INVALID
[ "$(sha256sum "$manifest" | awk '{ print $1 }')" = \
    "d4ea7d864ac45aba6437a167907e50895c78c733b16be0f1a4c3c421d110b42f" ] ||
    fail BC02_REQUIREMENTS_CLOSURE_MANIFEST_INVALID

awk -F '	' '
    NF != 3 || $1 ~ /(^|\/)\.\.?($|\/)/ ||
        $1 ~ /^\// || $2 !~ /^(644|755)$/ ||
        $3 !~ /^[0-9a-f][0-9a-f]*$/ { exit 1 }
    seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 15) exit 1 }
' "$manifest" || fail BC02_REQUIREMENTS_CLOSURE_SHAPE_INVALID

while IFS='	' read -r path mode expected; do
    file="$model_dir/$path"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC02_REQUIREMENTS_CLOSURE_FILE_MISSING
    [ "$(stat -c '%a' "$file")" = "$mode" ] ||
        fail BC02_REQUIREMENTS_CLOSURE_FILE_MODE_INVALID
    [ "$(sha256sum "$file" | awk '{ print $1 }')" = "$expected" ] ||
        fail BC02_REQUIREMENTS_CLOSURE_FILE_DIGEST_INVALID
done < "$manifest"

"$script_dir/verify-bc02-contract.sh" ||
    fail BC02_REQUIREMENTS_CONTRACT_INVALID
"$script_dir/self-test-bc02-contract.sh" ||
    fail BC02_REQUIREMENTS_SELF_TEST_INVALID

echo BC02_REQUIREMENTS_CLOSURE_VALID
