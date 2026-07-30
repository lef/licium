#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
registry="$base_dir/bc06-runtime-artifacts.tsv"
inventory_template="$base_dir/bc06-inventory-template.tsv"
raw_template="$base_dir/bc06-raw-template.tsv"
normalized_contract="$base_dir/bc06-normalized-contract.tsv"
coverage_template="$base_dir/bc06-coverage-template.tsv"
oracle="$script_dir/oracle-bc06.sh"

[ "$#" -eq 5 ] || {
    echo "usage: verify-bc06-runtime.sh ARTIFACT_DIR RUN NS ASSERTION DB" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
db=$5

fail()
{
    echo "$1" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

while IFS='	' read -r name fields rows kind source
do
    file="$artifact_dir/$name"
    [ -f "$file" ] || fail BC06_REQUIRED_ARTIFACT_MISSING
done <"$registry"

[ ! -s "$artifact_dir/exclusions.tsv" ] &&
    [ ! -s "$artifact_dir/fault-markers.tsv" ] ||
    fail BC06_UNDECLARED_EXCLUSION_OR_FAULT

raw="$artifact_dir/raw-observations.tsv"
seal="$artifact_dir/raw-seal.tsv"
receipts="$artifact_dir/action-receipts.tsv"
find "$raw" -prune -type f -perm 0644 | awk 'NR == 1 { found = 1 } END { exit !found }' ||
    fail BC06_RAW_SEAL_INVALID
actual_raw_sha=$(sha256sum "$raw" | awk '{ print $1 }')
actual_raw_bytes=$(wc -c <"$raw" | tr -d ' ')
actual_receipt_sha=$(sha256sum "$receipts" | awk '{ print $1 }')
awk -F '	' -v raw_sha="$actual_raw_sha" -v raw_bytes="$actual_raw_bytes" \
    -v receipt_sha="$actual_receipt_sha" -v run="$run" -v ns="$namespace" \
    -v assertion="$assertion" '
    NF != 9 { exit 1 }
    $1 != "raw-observations.tsv" || $2 != "100644" { exit 1 }
    $3 != raw_sha || $4 != raw_bytes || $5 != run || $6 != ns { exit 1 }
    $7 != assertion || $8 != receipt_sha { exit 1 }
    $9 != "sealed-before-normalization" { exit 1 }
    { count++ }
    END { if (count != 1) exit 1 }
' "$seal" || fail BC06_RAW_SEAL_INVALID

while IFS='	' read -r name fields rows kind source
do
    file="$artifact_dir/$name"
    actual_rows=$(wc -l <"$file" | tr -d ' ')
    [ "$actual_rows" = "$rows" ] || fail BC06_ARTIFACT_SHAPE_INVALID
    if [ "$rows" -gt 0 ]; then
        awk -F '	' -v fields="$fields" 'NF != fields { exit 1 }' "$file" ||
            fail BC06_ARTIFACT_SHAPE_INVALID
    fi
done <"$registry"

[ ! -e "$db" ] || fail BC06_CLEANUP_FAILED

awk -F '	' -v run="$run" -v ns="$namespace" \
    -v assertion="$assertion" '
    NF != 12 { exit 1 }
    $1 != run || $2 != ns || $3 != assertion { exit 1 }
    $4 !~ /^(create|setup|inventory-before|observe-before|occurrence-1|occurrence-2|inventory-after|observe-after|reopen|destroy)$/ { exit 1 }
    seen[$4]++ { exit 1 }
    $7 != "0" { exit 1 }
    $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^(0|[1-9][0-9]*)$/ { exit 1 }
    $10 !~ /^[0-9a-f]{64}$/ || $11 !~ /^(0|[1-9][0-9]*)$/ { exit 1 }
    $12 !~ /^[0-9a-f]{64}$/ { exit 1 }
    { count++ }
    END { if (count != 10) exit 1 }
' "$artifact_dir/command-receipts.tsv" ||
    fail BC06_COMMAND_CUSTODY_INVALID

argv_digest()
{
    for argument in "$@"
    do
        if [ "$argument" = "$adapter" ]; then
            printf '%s\n' '{adapter-entrypoint}'
        elif [ "$argument" = "$db" ]; then
            printf '%s\n' '{database-path}'
        else
            printf '%s\n' "$argument"
        fi
    done | sha256sum | awk '{ print $1 }'
}

check_argv()
{
    phase=$1
    expected_operation=$2
    expected_mode=$3
    shift 3
    expected_sha=$(argv_digest "$@")
    awk -F '	' -v phase="$phase" -v operation="$expected_operation" \
        -v mode="$expected_mode" -v sha="$expected_sha" '
        $4 == phase && $5 == operation && $6 == mode && $12 == sha {
            found++
        }
        END { if (found != 1) exit 1 }
    ' "$artifact_dir/command-receipts.tsv" ||
        fail BC06_COMMAND_CUSTODY_INVALID
}

adapter="$base_dir/profiles/sqlite-reference/run.sh"
check_argv create profile-create-namespace normal \
    "$adapter" create "$namespace" "$db"
check_argv setup sut-setup-bc06 ordinary \
    "$adapter" operation "$db" "$run" "$namespace" "$assertion" \
    sut-setup-bc06 ordinary setup setup-nonce
check_argv inventory-before runner-bind-evidence ordinary \
    "$adapter" inventory "$db" "$run" "$namespace" "$assertion" before
check_argv observe-before runner-bind-evidence ordinary \
    "$adapter" observe "$db" "$run" "$namespace" "$assertion" \
    raw-bc06-observation before
check_argv occurrence-1 sut-evaluate-pure ordinary \
    "$adapter" operation "$db" "$run" "$namespace" "$assertion" \
    sut-evaluate-pure ordinary occurrence-1 "nonce-1-$run"
check_argv occurrence-2 sut-evaluate-pure ordinary \
    "$adapter" operation "$db" "$run" "$namespace" "$assertion" \
    sut-evaluate-pure ordinary occurrence-2 "nonce-2-$run"
check_argv inventory-after runner-bind-evidence ordinary \
    "$adapter" inventory "$db" "$run" "$namespace" "$assertion" after
check_argv observe-after runner-bind-evidence ordinary \
    "$adapter" observe "$db" "$run" "$namespace" "$assertion" \
    raw-bc06-observation after
check_argv reopen profile-reopen-namespace ordinary \
    "$adapter" reopen "$db" "$run" "$namespace" "$assertion"
check_argv destroy profile-destroy-namespace ordinary \
    "$adapter" destroy "$namespace" "$db"

pragma_sha=$(printf 'pragma\tforeign-keys\t1\n' | sha256sum | awk '{ print $1 }')
pragma_bytes=$(printf 'pragma\tforeign-keys\t1\n' | wc -c | tr -d ' ')
empty_sha=$(sha256sum /dev/null | awk '{ print $1 }')
awk -F '	' -v pragma_sha="$pragma_sha" -v pragma_bytes="$pragma_bytes" \
    -v empty_sha="$empty_sha" '
    $4 == "destroy" {
        if ($10 != empty_sha || $11 != 0) exit 1
        next
    }
    $10 != pragma_sha || $11 != pragma_bytes { exit 1 }
' "$artifact_dir/command-receipts.tsv" ||
    fail BC06_COMMAND_CUSTODY_INVALID

check_stdout()
{
    phase=$1
    expected=$2
    stdout_sha=$(sha256sum "$expected" | awk '{ print $1 }')
    stdout_bytes=$(wc -c <"$expected" | tr -d ' ')
    awk -F '	' -v phase="$phase" -v stdout_sha="$stdout_sha" \
        -v stdout_bytes="$stdout_bytes" '
        $4 == phase && $8 == stdout_sha && $9 == stdout_bytes { found++ }
        END { if (found != 1) exit 1 }
    ' "$artifact_dir/command-receipts.tsv" ||
        fail BC06_COMMAND_CUSTODY_INVALID
}

printf 'status\tcreate\taccepted\t%s\n' "$namespace" >"$tmp/create.out"
printf 'status\tsetup\taccepted\t%s\n' "$assertion" >"$tmp/setup.out"
awk -F '	' '$4 == "before"' "$raw" >"$tmp/observe-before.out"
sed -n '1p' "$receipts" >"$tmp/occurrence-1.out"
sed -n '2p' "$receipts" >"$tmp/occurrence-2.out"
awk -F '	' '$4 == "after"' "$raw" >"$tmp/observe-after.out"
printf 'status\treopen\taccepted\t%s\n' "$assertion" >"$tmp/reopen.out"
printf 'status\tdestroy\taccepted\t%s\n' "$namespace" >"$tmp/destroy.out"

check_stdout create "$tmp/create.out"
check_stdout setup "$tmp/setup.out"
check_stdout inventory-before "$artifact_dir/inventory-before.tsv"
check_stdout observe-before "$tmp/observe-before.out"
check_stdout occurrence-1 "$tmp/occurrence-1.out"
check_stdout occurrence-2 "$tmp/occurrence-2.out"
check_stdout inventory-after "$artifact_dir/inventory-after.tsv"
check_stdout observe-after "$tmp/observe-after.out"
check_stdout reopen "$tmp/reopen.out"
check_stdout destroy "$tmp/destroy.out"

awk -F '	' -v run="$run" -v ns="$namespace" \
    -v assertion="$assertion" '
    NF != 6 { exit 1 }
    $1 != run || $2 != ns || $3 != assertion { exit 1 }
    $4 !~ /^(create|setup|inventory-before|observe-before|occurrence-1|occurrence-2|inventory-after|observe-after|reopen)$/ { exit 1 }
    seen[$4]++ { exit 1 }
    $5 != "foreign-keys" || $6 != "1" { exit 1 }
    { count++ }
    END { if (count != 9) exit 1 }
' "$artifact_dir/pragma.tsv" || fail BC06_PRAGMA_EVIDENCE_INVALID

sed "s/{scenario}/$assertion/g" "$inventory_template" |
    LC_ALL=C sort >"$tmp/inventory-expected"
LC_ALL=C sort "$artifact_dir/inventory-before.tsv" >"$tmp/inventory-before"
LC_ALL=C sort "$artifact_dir/inventory-after.tsv" >"$tmp/inventory-after"
cmp -s "$tmp/inventory-expected" "$tmp/inventory-before" ||
    fail BC06_INVENTORY_EXPECTED_INVALID
cmp -s "$tmp/inventory-expected" "$tmp/inventory-after" ||
    fail BC06_INVENTORY_EXPECTED_INVALID

sed "s/{scenario}/$assertion/g" "$raw_template" |
    LC_ALL=C sort >"$tmp/raw-expected"
LC_ALL=C sort "$artifact_dir/raw-observations.tsv" >"$tmp/raw-actual"
cmp -s "$tmp/raw-expected" "$tmp/raw-actual" ||
    fail BC06_RAW_OBSERVATION_INVALID

awk -F '	' -v assertion="$assertion" '$1 == assertion' \
    "$normalized_contract" | LC_ALL=C sort >"$tmp/normalized-expected"
LC_ALL=C sort "$artifact_dir/normalized-observations.tsv" \
    >"$tmp/normalized-actual"

sed "s/{scenario}/$assertion/g" "$coverage_template" |
    LC_ALL=C sort >"$tmp/coverage-expected"
LC_ALL=C sort "$artifact_dir/coverage.tsv" >"$tmp/coverage-actual"
cmp -s "$tmp/coverage-expected" "$tmp/coverage-actual" ||
    fail BC06_COVERAGE_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { raw[$2] = 1; next }
    FILENAME == ARGV[2] { normalized[$2] = 1; next }
    {
        if (!($2 in raw) || !($5 in normalized)) exit 1
        raw_seen[$2] = 1
        normalized_seen[$5] = 1
    }
    END {
        for (id in raw) if (!raw_seen[id]) exit 1
        for (id in normalized) if (!normalized_seen[id]) exit 1
    }
' "$artifact_dir/raw-observations.tsv" \
    "$artifact_dir/normalized-observations.tsv" \
    "$artifact_dir/coverage.tsv" || fail BC06_COVERAGE_INVALID

"$oracle" "$artifact_dir" "$run" "$namespace" "$assertion" \
    >"$tmp/oracle-expected" || exit 1
cmp -s "$tmp/oracle-expected" "$artifact_dir/oracle-result.tsv" ||
    fail BC06_ORACLE_RESULT_INVALID

cmp -s "$tmp/normalized-expected" "$tmp/normalized-actual" ||
    fail BC06_NORMALIZED_OBSERVATION_INVALID

echo BC06_RUNTIME_VALID
