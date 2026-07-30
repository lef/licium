#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
vectors=${VECTORS_DIR:-"$script_dir/vectors"}

fail()
{
    echo "$1" >&2
    exit 1
}

[ -d "$vectors" ] || fail VECTOR_INVENTORY_INVALID
[ -f "$vectors/vector-bindings.tsv" ] &&
    [ -f "$vectors/vector-bindings.sha256" ] ||
    fail VECTOR_INVENTORY_INVALID

(
    cd "$vectors"
    sha256sum -c vector-bindings.sha256 >/dev/null 2>&1
) || fail VECTOR_BINDING_INVALID

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

cut -f1 "$vectors/vector-bindings.tsv" >"$tmp/expected-files"
find "$vectors" -maxdepth 1 -type f -name '*.tsv' -print |
    while IFS= read -r file
    do
        name=${file##*/}
        [ "$name" = vector-bindings.tsv ] || printf '%s\n' "$name"
    done |
    LC_ALL=C sort >"$tmp/actual-files"
cmp -s "$tmp/expected-files" "$tmp/actual-files" ||
    fail VECTOR_INVENTORY_INVALID

while IFS='	' read -r name digest
do
    [ -f "$vectors/$name" ] || fail VECTOR_INVENTORY_INVALID
    actual=$(sha256sum "$vectors/$name" | awk '{ print $1 }')
    [ "$actual" = "$digest" ] || fail VECTOR_DIGEST_MISMATCH
done <"$vectors/vector-bindings.tsv"

for name in \
    expected-accepted.tsv \
    expected-projection.tsv \
    expected-rejected.tsv \
    observations.tsv \
    vector-bindings.tsv \
    vector-controls.tsv
do
    LC_ALL=C sort -c "$vectors/$name" >/dev/null 2>&1 ||
        fail VECTOR_ORDER_INVALID
done

awk -F '	' 'NF != 3 { exit 1 } END { if (NR != 1) exit 1 }' \
    "$vectors/credential-store.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 4 { exit 1 } END { if (NR != 1) exit 1 }' \
    "$vectors/credential-authority-binding.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 6 { exit 1 } END { if (NR != 1) exit 1 }' \
    "$vectors/pinned-evaluation.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 3 || $1 != "envelope" || seen[$2]++ { exit 1 }
    END { if (NR != 9) exit 1 }' \
    "$vectors/expected-accepted.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 3 || $1 !~ /^(relation|value)$/ ||
        seen[$1 FS $2]++ { exit 1 }
    END { if (NR != 2) exit 1 }' \
    "$vectors/expected-projection.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 3 || $2 != "rejected" || seen[$1]++ { exit 1 }
    END { if (NR != 3) exit 1 }' \
    "$vectors/expected-rejected.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 2 || seen[$1]++ { exit 1 }
    END { if (NR != 4) exit 1 }' \
    "$vectors/forbidden-sentinels.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 2 || seen[$1]++ { exit 1 }
    END { if (NR != 3) exit 1 }' \
    "$vectors/provider-tuple.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 8 { exit 1 } END { if (NR != 1) exit 1 }' \
    "$vectors/adapter-mapping-policy.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 10 || seen[$1]++ { exit 1 }
    END { if (NR != 6) exit 1 }' \
    "$vectors/subject-tuples.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 10 || $1 !~ /^PI-N(0[1-9]|1[0-9])$/ ||
        seen[$1]++ { exit 1 }
    END { if (NR != 19) exit 1 }' \
    "$vectors/negative-controls.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 2 ||
        $1 !~ /^(PN(0[1-9]|1[0-5])|OI(0[1-9]|1[0-2])|BR0[1-8])$/ ||
        seen[$1]++ { exit 1 }
    END { if (NR != 35) exit 1 }' \
    "$vectors/observations.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 2 || $1 !~ /^[a-z0-9-]+[.]tsv$/ ||
        $2 !~ /^[0-9a-f]{64}$/ || seen[$1]++ { exit 1 }
    END { if (NR != 13) exit 1 }' \
    "$vectors/vector-bindings.tsv" ||
    fail VECTOR_SCHEMA_INVALID
awk -F '	' 'NF != 4 || $1 !~ /^V-N0[1-6]$/ || seen[$1]++ {
        exit 1
    } END { if (NR != 6) exit 1 }' \
    "$vectors/vector-controls.tsv" ||
    fail VECTOR_SCHEMA_INVALID

echo PROTOCOL_INTEGRATION_VECTORS_VALID
