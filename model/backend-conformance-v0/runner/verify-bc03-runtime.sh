#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
oracle="$script_dir/oracle-bc03.sh"

[ "$#" -eq 7 ] || {
    echo "usage: verify-bc03-runtime.sh ARTIFACT_DIR RUN NS ASSERTION CASE SCENARIO DB" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
scenario=$6
db=$7

fail()
{
    echo "$1" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for name in action-receipts.tsv command-receipts.tsv coverage.tsv \
    exclusions.tsv fault-markers.tsv inventory-after.tsv \
    inventory-before.tsv inventory-reopened.tsv \
    normalized-observations.tsv oracle-result.tsv pragma.tsv \
    raw-observations.tsv raw-seal.tsv
do
    [ -f "$artifact_dir/$name" ] && [ ! -L "$artifact_dir/$name" ] ||
        fail BC03_REQUIRED_ARTIFACT_MISSING
done

[ ! -s "$artifact_dir/exclusions.tsv" ] &&
    [ ! -s "$artifact_dir/fault-markers.tsv" ] ||
    fail BC03_UNDECLARED_EXCLUSION_OR_FAULT
[ ! -e "$db" ] || fail BC03_CLEANUP_FAILED

awk -F '	' '
    NF == 13 && $5 == "sut-setup-bc03" { setup++ }
    NF == 13 && $5 != "sut-setup-bc03" { action++ }
    END {
        if (setup != 1 || action != 1) exit 1
    }
' "$artifact_dir/action-receipts.tsv" ||
    fail BC03_SUT_ACTION_MISSING

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
    { count++ }
    END { if (count != 1) exit 1 }
' "$artifact_dir/raw-seal.tsv" || fail BC03_RAW_SEAL_INVALID

find "$raw" -prune -type f -perm 0644 |
    awk 'NR == 1 { found = 1 } END { exit !found }' ||
    fail BC03_RAW_SEAL_INVALID

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
' "$raw" "$artifact_dir/normalized-observations.tsv" \
    "$artifact_dir/coverage.tsv" || fail BC03_COVERAGE_INVALID

expected_raw=$(awk -F '	' -v scenario="$scenario" \
    '$1 == scenario { n++ } END { print n+0 }' \
    "$base_dir/bc03-raw-template.tsv")
expected_normalized=$(awk -F '	' -v scenario="$scenario" \
    '$1 == scenario { n++ } END { print n+0 }' \
    "$base_dir/bc03-normalized-contract.tsv")
expected_coverage=$(awk -F '	' -v scenario="$scenario" \
    '$1 == scenario { n++ } END { print n+0 }' \
    "$base_dir/bc03-coverage-template.tsv")

check_shape()
{
    file=$1
    fields=$2
    rows=$3
    [ "$(wc -l <"$file" | tr -d ' ')" = "$rows" ] ||
        fail BC03_ARTIFACT_SHAPE_INVALID
    [ "$rows" -eq 0 ] || awk -F '	' -v fields="$fields" \
        'NF != fields { exit 1 }' "$file" ||
        fail BC03_ARTIFACT_SHAPE_INVALID
}

before_rows=$(awk -F '	' -v scenario="$scenario" \
    '$1 == scenario { n++ } END { print n+0 }' \
    "$base_dir/bc03-inventory-before.tsv")
after_rows=$(awk -F '	' -v scenario="$scenario" \
    '$1 == scenario { n++ } END { print n+0 }' \
    "$base_dir/bc03-inventory-after.tsv")

check_shape "$artifact_dir/action-receipts.tsv" 13 2
check_shape "$artifact_dir/command-receipts.tsv" 12 9
check_shape "$artifact_dir/coverage.tsv" 6 "$expected_coverage"
check_shape "$artifact_dir/exclusions.tsv" 6 0
check_shape "$artifact_dir/fault-markers.tsv" 6 0
check_shape "$artifact_dir/inventory-before.tsv" 6 "$before_rows"
check_shape "$artifact_dir/inventory-after.tsv" 6 "$after_rows"
check_shape "$artifact_dir/inventory-reopened.tsv" 6 "$after_rows"
check_shape "$artifact_dir/normalized-observations.tsv" 6 \
    "$expected_normalized"
check_shape "$artifact_dir/oracle-result.tsv" 6 1
check_shape "$artifact_dir/pragma.tsv" 6 8
check_shape "$artifact_dir/raw-observations.tsv" 6 "$expected_raw"
check_shape "$artifact_dir/raw-seal.tsv" 9 1

awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" '
    NF != 12 || $1 != run || $2 != ns || $3 != assertion ||
        $4 !~ /^(create|setup|inventory-before|action|observe-after|inventory-after|reopen|inventory-reopened|destroy)$/ ||
        seen[$4]++ || $7 != "0" ||
        $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^(0|[1-9][0-9]*)$/ ||
        $10 !~ /^[0-9a-f]{64}$/ || $11 !~ /^(0|[1-9][0-9]*)$/ ||
        $12 !~ /^[0-9a-f]{64}$/ { exit 1 }
    { count++ }
    END { if (count != 9) exit 1 }
' "$artifact_dir/command-receipts.tsv" ||
    fail BC03_COMMAND_CUSTODY_INVALID

case "$assertion" in
    BC03_ACCEPTED_HEAD|BC03_PUBLICATION_SEPARATE)
        action=sut-publish-root
        action_root=root-accepted
        action_publication=pub-accepted
        action_authority=authority-main
        action_decision=accepted
        action_effect=inserted
        ;;
    BC03_REJECTED_IS_HEAD)
        action=sut-publish-root
        action_root=root-rejected
        action_publication=pub-rejected
        action_authority=authority-main
        action_decision=rejected
        action_effect=inserted
        ;;
    BC03_STORED_IS_HEAD|BC03_STORED_ROOT_SEPARATE)
        action=sut-store-root
        action_root=root-stored
        action_publication=-
        action_authority=-
        action_decision=-
        action_effect=inserted
        ;;
    BC03_WRONG_AUTHORITY_HEAD)
        action=sut-derive-heads
        action_root=root-other
        action_publication=pub-other
        action_authority=authority-main
        action_decision=accepted
        action_effect=unchanged
        ;;
    *)
        fail BC03_ASSERTION_INVALID
        ;;
esac

awk -F '	' -v run="$run" -v ns="$namespace" -v scenario="$scenario" \
    -v case_id="$case_id" -v action="$action" \
    -v action_root="$action_root" \
    -v action_publication="$action_publication" \
    -v action_authority="$action_authority" \
    -v action_decision="$action_decision" \
    -v action_effect="$action_effect" '
    NF != 13 || $1 != run || $2 != ns || $3 != scenario ||
        $4 != case_id || $6 != "accepted" || $7 != "-" { exit 1 }
    $5 == "sut-setup-bc03" {
        if ($13 != "setup-" run) exit 1
        if (case_id == "case-bc03-wrong-authority") {
            if ($8 != "root-other" || $9 != "pub-other" ||
                $10 != "authority-other" || $11 != "accepted" ||
                $12 != "inserted") exit 1
        } else if ($8 != "-" || $9 != "-" || $10 != "-" ||
                   $11 != "-" || $12 != "unchanged") exit 1
        setup++
        next
    }
    $5 == action {
        if ($8 != action_root || $9 != action_publication ||
            $10 != action_authority || $11 != action_decision ||
            $12 != action_effect || $13 != "action-" run) exit 1
        action_count++
        next
    }
    { exit 1 }
    END { if (setup != 1 || action_count != 1) exit 1 }
' "$receipts" || fail BC03_ACTION_RECEIPT_INVALID

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
        fail BC03_COMMAND_CUSTODY_INVALID
}

check_argv create profile-create-namespace normal \
    "$adapter" create-bc03 "$namespace" "$db"
check_argv setup sut-setup-bc03 ordinary \
    "$adapter" operation-bc03 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc03 ordinary setup "setup-$run"
check_argv inventory-before profile-inventory-bc03 ordinary \
    "$adapter" inventory-bc03 "$db" "$assertion" "$case_id" before
check_argv action "$action" ordinary \
    "$adapter" operation-bc03 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" "$action" ordinary action "action-$run"
check_argv observe-after profile-observe-bc03 ordinary \
    "$adapter" observe-bc03 "$db" "$assertion" "$case_id" after
check_argv inventory-after profile-inventory-bc03 ordinary \
    "$adapter" inventory-bc03 "$db" "$assertion" "$case_id" after
check_argv reopen profile-reopen-namespace ordinary \
    "$adapter" reopen "$db" "$run" "$namespace" "$assertion"
check_argv inventory-reopened profile-inventory-bc03 ordinary \
    "$adapter" inventory-bc03 "$db" "$assertion" "$case_id" reopened
check_argv destroy profile-destroy-namespace ordinary \
    "$adapter" destroy "$namespace" "$db"

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
    fail BC03_COMMAND_CUSTODY_INVALID

check_stdout()
{
    phase=$1
    expected=$2
    stdout_sha=$(sha256sum "$expected" | awk '{ print $1 }')
    stdout_bytes=$(wc -c <"$expected" | tr -d ' ')
    awk -F '	' -v phase="$phase" -v stdout_sha="$stdout_sha" \
        -v stdout_bytes="$stdout_bytes" '
        $4 == phase && $8 == stdout_sha && $9 == stdout_bytes {
            found++
        }
        END { if (found != 1) exit 1 }
    ' "$artifact_dir/command-receipts.tsv" ||
        fail BC03_COMMAND_CUSTODY_INVALID
}

printf 'status\tcreate\taccepted\t%s\n' "$namespace" >"$tmp/create.out"
sed -n '1p' "$receipts" >"$tmp/setup.out"
sed -n '2p' "$receipts" >"$tmp/action.out"
awk -F '	' '$2 != "raw-001"' "$raw" >"$tmp/observe-after.out"
printf 'status\treopen\taccepted\t%s\n' "$assertion" >"$tmp/reopen.out"
printf 'status\tdestroy\taccepted\t%s\n' "$namespace" >"$tmp/destroy.out"

check_stdout create "$tmp/create.out"
check_stdout setup "$tmp/setup.out"
check_stdout inventory-before "$artifact_dir/inventory-before.tsv"
check_stdout action "$tmp/action.out"
check_stdout observe-after "$tmp/observe-after.out"
check_stdout inventory-after "$artifact_dir/inventory-after.tsv"
check_stdout reopen "$tmp/reopen.out"
check_stdout inventory-reopened "$artifact_dir/inventory-reopened.tsv"
check_stdout destroy "$tmp/destroy.out"

awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" '
    NF != 6 || $1 != run || $2 != ns || $3 != assertion ||
        $4 !~ /^(create|setup|inventory-before|action|observe-after|inventory-after|reopen|inventory-reopened)$/ ||
        seen[$4]++ || $5 != "foreign-keys" || $6 != "1" { exit 1 }
    { count++ }
    END { if (count != 8) exit 1 }
' "$artifact_dir/pragma.tsv" || fail BC03_PRAGMA_EVIDENCE_INVALID

for stage in before after reopened
do
    template="$base_dir/bc03-inventory-$stage.tsv"
    awk -F '	' -v scenario="$scenario" '$1 == scenario' "$template" |
        LC_ALL=C sort >"$tmp/inventory-$stage.expected"
    LC_ALL=C sort "$artifact_dir/inventory-$stage.tsv" \
        >"$tmp/inventory-$stage.actual"
    cmp -s "$tmp/inventory-$stage.expected" \
        "$tmp/inventory-$stage.actual" ||
        fail BC03_INVENTORY_EXPECTED_INVALID
    awk -F '	' '$2 == "authority-head" { exit 1 }' \
        "$artifact_dir/inventory-$stage.tsv" ||
        fail BC03_DERIVED_HEAD_PERSISTED
done

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc03-raw-template.tsv" | LC_ALL=C sort >"$tmp/raw.expected"
LC_ALL=C sort "$raw" >"$tmp/raw.actual"
cmp -s "$tmp/raw.expected" "$tmp/raw.actual" ||
    fail BC03_RAW_OBSERVATION_INVALID

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc03-normalized-contract.tsv" |
    LC_ALL=C sort >"$tmp/normalized.expected"
LC_ALL=C sort "$artifact_dir/normalized-observations.tsv" \
    >"$tmp/normalized.actual"
cmp -s "$tmp/normalized.expected" "$tmp/normalized.actual" ||
    fail BC03_NORMALIZED_OBSERVATION_INVALID

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc03-coverage-template.tsv" |
    LC_ALL=C sort >"$tmp/coverage.expected"
LC_ALL=C sort "$artifact_dir/coverage.tsv" >"$tmp/coverage.actual"
cmp -s "$tmp/coverage.expected" "$tmp/coverage.actual" ||
    fail BC03_COVERAGE_INVALID

"$oracle" "$artifact_dir" "$run" "$namespace" "$assertion" \
    "$case_id" "$scenario" >"$tmp/oracle.expected"
cmp -s "$tmp/oracle.expected" "$artifact_dir/oracle-result.tsv" ||
    fail BC03_ORACLE_RESULT_INVALID

echo BC03_RUNTIME_VALID
