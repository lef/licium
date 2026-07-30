#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
oracle="$script_dir/oracle-bc07.sh"
adapter="$base_dir/profiles/sqlite-reference/run.sh"

[ "$#" -eq 8 ] || exit 2
artifact_dir=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
scenario=$6
db=$7
execution_mode=$8
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

case "$assertion:$case_id" in
    BC07_EFFECT_101:case-bc07-effect|\
    BC07_OBSERVATION_WITHOUT_TRANSITION:case-bc07-orphan|\
    BC07_RESULT_REWRITE:case-bc07-rewrite)
        action=sut-apply-effect ;;
    BC07_ORDINARY_000:case-bc07-ordinary)
        action=sut-evaluate-pure ;;
    BC07_RECORD_IMPLIES_EFFECT:case-bc07-record-effect|\
    BC07_RECORD_ONLY_010:case-bc07-record)
        action=sut-record-result ;;
    *) exit 2 ;;
esac

fail()
{
    echo "$1" >&2
    exit 1
}

for name in action-receipts.tsv command-receipts.tsv coverage.tsv \
    exclusions.tsv fault-markers.tsv inventory-after.tsv \
    inventory-before.tsv inventory-reopened.tsv \
    normalized-observations.tsv oracle-result.tsv pragma.tsv \
    raw-observations.tsv raw-seal.tsv
do
    [ -f "$artifact_dir/$name" ] && [ ! -L "$artifact_dir/$name" ] ||
        fail BC07_REQUIRED_ARTIFACT_MISSING
done
[ ! -s "$artifact_dir/exclusions.tsv" ] &&
    [ ! -s "$artifact_dir/fault-markers.tsv" ] ||
    fail BC07_UNDECLARED_EXCLUSION_OR_FAULT
[ ! -e "$db" ] || fail BC07_CLEANUP_FAILED

awk -F '	' -v run="$run" -v ns="$namespace" \
    -v scenario="$scenario" '
    NF != 12 || $1 != run || $2 != ns || $3 != scenario { exit 1 }
    END { if (NR != 1) exit 1 }
' "$artifact_dir/action-receipts.tsv" ||
    fail BC07_SUT_ACTION_MISSING

raw="$artifact_dir/raw-observations.tsv"
receipts="$artifact_dir/action-receipts.tsv"
raw_sha=$(sha256sum "$raw" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$raw" | tr -d ' ')
receipt_sha=$(sha256sum "$receipts" | awk '{ print $1 }')
awk -F '	' -v raw_sha="$raw_sha" -v raw_bytes="$raw_bytes" \
    -v receipt_sha="$receipt_sha" -v run="$run" -v ns="$namespace" \
    -v scenario="$scenario" '
    NF != 9 || $1 != "raw-observations.tsv" || $2 != "100644" ||
        $3 != raw_sha || $4 != raw_bytes || $5 != run || $6 != ns ||
        $7 != scenario || $8 != receipt_sha ||
        $9 != "sealed-before-normalization" { exit 1 }
    END { if (NR != 1) exit 1 }
' "$artifact_dir/raw-seal.tsv" || fail BC07_RAW_SEAL_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { raw[$2] = 1; next }
    FILENAME == ARGV[2] { normalized[$2] = 1; next }
    {
        if (!($2 in raw) || !($5 in normalized) ||
            $3 != "record" || $6 != "all") exit 1
        raw_seen[$2] = 1
        normalized_seen[$5] = 1
    }
    END {
        if (length(raw) != 8 || length(normalized) != 8) exit 1
        for (id in raw) if (!raw_seen[id]) exit 1
        for (id in normalized) if (!normalized_seen[id]) exit 1
    }
' "$raw" "$artifact_dir/normalized-observations.tsv" \
    "$artifact_dir/coverage.tsv" || fail BC07_COVERAGE_INVALID

check_shape()
{
    file=$1
    fields=$2
    rows=$3
    [ "$(wc -l <"$file" | tr -d ' ')" = "$rows" ] ||
        fail BC07_ARTIFACT_SHAPE_INVALID
    [ "$rows" -eq 0 ] || awk -F '	' -v fields="$fields" \
        'NF != fields { exit 1 }' "$file" ||
        fail BC07_ARTIFACT_SHAPE_INVALID
}

expected_before=$(awk -F '	' -v scenario="$scenario" \
    '$1 == scenario { n++ } END { print n+0 }' \
    "$base_dir/bc07-inventory-before.tsv")
expected_after=$(awk -F '	' -v scenario="$scenario" \
    '$1 == scenario { n++ } END { print n+0 }' \
    "$base_dir/bc07-inventory-after.tsv")
check_shape "$receipts" 12 1
check_shape "$artifact_dir/command-receipts.tsv" 12 9
check_shape "$artifact_dir/pragma.tsv" 6 8
check_shape "$raw" 6 8
check_shape "$artifact_dir/normalized-observations.tsv" 6 8
check_shape "$artifact_dir/coverage.tsv" 6 8
check_shape "$artifact_dir/inventory-before.tsv" 6 "$expected_before"
check_shape "$artifact_dir/inventory-after.tsv" 6 "$expected_after"
check_shape "$artifact_dir/inventory-reopened.tsv" 6 "$expected_after"
check_shape "$artifact_dir/oracle-result.tsv" 6 1
check_shape "$artifact_dir/raw-seal.tsv" 9 1

awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" \
    -v action="$action" -v action_mode="$execution_mode" '
    BEGIN {
        phase[1] = "create"; operation[1] = "profile-create-namespace"; mode[1] = "normal"
        phase[2] = "setup"; operation[2] = "sut-setup-bc07"; mode[2] = "ordinary"
        phase[3] = "inventory-before"; operation[3] = "profile-inventory-bc07"; mode[3] = "ordinary"
        phase[4] = "action"; operation[4] = action; mode[4] = action_mode
        phase[5] = "observe-after"; operation[5] = "profile-observe-bc07"; mode[5] = "ordinary"
        phase[6] = "inventory-after"; operation[6] = "profile-inventory-bc07"; mode[6] = "ordinary"
        phase[7] = "reopen"; operation[7] = "profile-reopen-namespace"; mode[7] = "normal"
        phase[8] = "inventory-reopened"; operation[8] = "profile-inventory-bc07"; mode[8] = "ordinary"
        phase[9] = "destroy"; operation[9] = "profile-destroy-namespace"; mode[9] = "normal"
    }
    NF != 12 || $1 != run || $2 != ns || $3 != assertion ||
        $4 != phase[NR] || $5 != operation[NR] || $6 != mode[NR] ||
        $7 != "0" ||
        $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^(0|[1-9][0-9]*)$/ ||
        $10 !~ /^[0-9a-f]{64}$/ || $11 !~ /^(0|[1-9][0-9]*)$/ ||
        $12 !~ /^[0-9a-f]{64}$/ { exit 1 }
    END { if (NR != 9) exit 1 }
' "$artifact_dir/command-receipts.tsv" ||
    fail BC07_COMMAND_CUSTODY_INVALID

argv_digest()
{
    for argument in "$@"
    do
        case "$argument" in
            "$adapter") printf '%s\n' '{adapter-entrypoint}' ;;
            "$db") printf '%s\n' '{database-path}' ;;
            "$artifact_dir/action-receipts.tsv")
                printf '%s\n' '{action-receipts-path}' ;;
            "$artifact_dir/inventory-before.tsv")
                printf '%s\n' '{inventory-before-path}' ;;
            *) printf '%s\n' "$argument" ;;
        esac
    done | sha256sum | awk '{ print $1 }'
}

check_argv()
{
    phase=$1
    shift
    expected_sha=$(argv_digest "$@")
    awk -F '	' -v phase="$phase" -v sha="$expected_sha" '
        $4 == phase && $12 == sha { found++ }
        END { if (found != 1) exit 1 }
    ' "$artifact_dir/command-receipts.tsv" ||
        fail BC07_COMMAND_CUSTODY_INVALID
}

check_argv create "$adapter" create-bc07 "$namespace" "$db"
check_argv setup "$adapter" operation-bc07 "$db" "$run" "$namespace" \
    "$assertion" "$case_id" sut-setup-bc07 ordinary setup "setup-$run"
check_argv inventory-before "$adapter" inventory-bc07 "$db" \
    "$assertion" "$case_id" before
check_argv action "$adapter" operation-bc07 "$db" "$run" "$namespace" \
    "$assertion" "$case_id" "$action" "$execution_mode" action \
    "action-$run"
check_argv observe-after "$adapter" observe-bc07 "$db" "$assertion" \
    "$case_id" after "$artifact_dir/inventory-before.tsv" \
    "$artifact_dir/action-receipts.tsv"
check_argv inventory-after "$adapter" inventory-bc07 "$db" \
    "$assertion" "$case_id" after
check_argv reopen "$adapter" reopen "$db" "$run" "$namespace" "$assertion"
check_argv inventory-reopened "$adapter" inventory-bc07 "$db" \
    "$assertion" "$case_id" reopened
check_argv destroy "$adapter" destroy "$namespace" "$db"

pragma_sha=$(printf 'pragma\tforeign-keys\t1\n' |
    sha256sum | awk '{ print $1 }')
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
    fail BC07_COMMAND_CUSTODY_INVALID

check_stdout()
{
    phase=$1
    expected=$2
    stdout_sha=$(sha256sum "$expected" | awk '{ print $1 }')
    stdout_bytes=$(wc -c <"$expected" | tr -d ' ')
    awk -F '	' -v phase="$phase" -v sha="$stdout_sha" \
        -v bytes="$stdout_bytes" '
        $4 == phase && $8 == sha && $9 == bytes { found++ }
        END { if (found != 1) exit 1 }
    ' "$artifact_dir/command-receipts.tsv" ||
        fail BC07_COMMAND_CUSTODY_INVALID
}

printf 'status\tcreate\taccepted\t%s\n' "$namespace" >"$tmp/create.out"
printf 'status\tsetup\taccepted\t%s\n' "$case_id" >"$tmp/setup.out"
printf 'status\treopen\taccepted\t%s\n' "$assertion" >"$tmp/reopen.out"
printf 'status\tdestroy\taccepted\t%s\n' "$namespace" >"$tmp/destroy.out"
check_stdout create "$tmp/create.out"
check_stdout setup "$tmp/setup.out"
check_stdout inventory-before "$artifact_dir/inventory-before.tsv"
check_stdout action "$artifact_dir/action-receipts.tsv"
check_stdout observe-after "$artifact_dir/raw-observations.tsv"
check_stdout inventory-after "$artifact_dir/inventory-after.tsv"
check_stdout reopen "$tmp/reopen.out"
check_stdout inventory-reopened "$artifact_dir/inventory-reopened.tsv"
check_stdout destroy "$tmp/destroy.out"

awk -F '	' -v mode="$execution_mode" '
    NF != 12 || $5 != mode || $11 != "accepted" ||
        $12 !~ /^action-/ { exit 1 }
    END { if (NR != 1) exit 1 }
' "$receipts" || fail BC07_ACTION_RECEIPT_INVALID

"$oracle" "$artifact_dir" "$assertion" "$case_id" "$scenario" \
    >"$tmp/oracle.expected"
cmp -s "$tmp/oracle.expected" "$artifact_dir/oracle-result.tsv" ||
    fail BC07_ORACLE_RESULT_INVALID

echo BC07_RUNTIME_VALID
