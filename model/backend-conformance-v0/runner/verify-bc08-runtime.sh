#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
oracle="$script_dir/oracle-bc08.sh"

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

fail()
{
    echo "$1" >&2
    exit 1
}

awk -F '	' '{ print $1 }' "$base_dir/bc08-runtime-artifacts.tsv" |
    LC_ALL=C sort >"$tmp/expected-files"
find "$artifact_dir" -maxdepth 1 -type f -printf '%f\n' |
    LC_ALL=C sort >"$tmp/actual-files"
cmp -s "$tmp/expected-files" "$tmp/actual-files" ||
    fail BC08_RUNTIME_ARTIFACT_SET_INVALID
[ ! -e "$db" ] || fail BC08_CLEANUP_FAILED
[ -s "$artifact_dir/action-receipts.tsv" ] ||
    fail BC08_SUT_ACTION_MISSING

raw="$artifact_dir/raw-observations.tsv"
raw_sha=$(sha256sum "$raw" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$raw" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
awk -F '	' -v raw_sha="$raw_sha" -v raw_bytes="$raw_bytes" \
    -v receipt_sha="$receipt_sha" -v run="$run" -v ns="$namespace" \
    -v scenario="$scenario" '
    NF != 9 || $1 != "raw-observations.tsv" || $2 != "100644" ||
        $3 != raw_sha || $4 != raw_bytes || $5 != run || $6 != ns ||
        $7 != scenario || $8 != receipt_sha ||
        $9 != "sealed-before-normalization" { exit 1 }
    END { if (NR != 1) exit 1 }
' "$artifact_dir/raw-seal.tsv" || fail BC08_RAW_SEAL_INVALID

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
        if (length(raw) != 12 || length(normalized) != 12) exit 1
        for (id in raw) if (!raw_seen[id]) exit 1
        for (id in normalized) if (!normalized_seen[id]) exit 1
    }
' "$raw" "$artifact_dir/normalized-observations.tsv" \
    "$artifact_dir/coverage.tsv" || fail BC08_COVERAGE_INVALID

if [ "$assertion" = BC08_MID_BOUNDARY_FAILURE ]; then
    cmp -s "$artifact_dir/fault-inventory-setup.tsv" \
        "$artifact_dir/fault-inventory-rollback.tsv" ||
        fail BC08_ROLLBACK_INVENTORY_INVALID
    cmp -s "$artifact_dir/fault-inventory-healthy.tsv" \
        "$artifact_dir/fault-inventory-reopened.tsv" ||
        fail BC08_FAULT_RECOVERY_INVALID
fi

check_shape()
{
    file=$1
    fields=$2
    rows=$3
    [ "$(wc -l <"$artifact_dir/$file" | tr -d ' ')" = "$rows" ] ||
        fail BC08_ARTIFACT_SHAPE_INVALID
    [ "$rows" -eq 0 ] || awk -F '	' -v fields="$fields" \
        'NF != fields { exit 1 }' "$artifact_dir/$file" ||
        fail BC08_ARTIFACT_SHAPE_INVALID
}

before_rows=$(awk -F '	' -v scenario="$scenario" \
    '$1 == scenario { n++ } END { print n+0 }' \
    "$base_dir/bc08-inventory-before.tsv")
after_rows=$(awk -F '	' -v scenario="$scenario" \
    '$1 == scenario { n++ } END { print n+0 }' \
    "$base_dir/bc08-inventory-after.tsv")
check_shape action-receipts.tsv 15 2
check_shape command-receipts.tsv 12 10
check_shape coverage.tsv 6 12
check_shape exclusions.tsv 6 0
check_shape inventory-before.tsv 6 "$before_rows"
check_shape inventory-after.tsv 6 "$after_rows"
check_shape inventory-reopened.tsv 6 "$after_rows"
check_shape normalized-observations.tsv 6 12
check_shape oracle-result.tsv 6 1
check_shape pragma.tsv 6 8
check_shape raw-observations.tsv 6 12
check_shape raw-seal.tsv 9 1

if [ "$assertion" = BC08_MID_BOUNDARY_FAILURE ]; then
    check_shape fault-activation-receipts.tsv 10 5
    check_shape fault-configuration-receipts.tsv 14 5
    check_shape fault-trigger-receipts.tsv 21 5
    check_shape fault-markers.tsv 11 5
    check_shape fault-inventory-setup.tsv 6 20
    check_shape fault-inventory-rollback.tsv 6 20
    check_shape fault-inventory-healthy.tsv 6 40
    check_shape fault-inventory-reopened.tsv 6 40
else
    for file in fault-activation-receipts.tsv \
        fault-configuration-receipts.tsv fault-trigger-receipts.tsv \
        fault-markers.tsv fault-inventory-setup.tsv \
        fault-inventory-rollback.tsv fault-inventory-healthy.tsv \
        fault-inventory-reopened.tsv
    do
        check_shape "$file" 1 0
    done
fi

raw="$artifact_dir/raw-observations.tsv"
raw_sha=$(sha256sum "$raw" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$raw" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
awk -F '	' -v raw_sha="$raw_sha" -v raw_bytes="$raw_bytes" \
    -v receipt_sha="$receipt_sha" -v run="$run" -v ns="$namespace" \
    -v scenario="$scenario" '
    NF != 9 || $1 != "raw-observations.tsv" || $2 != "100644" ||
        $3 != raw_sha || $4 != raw_bytes || $5 != run || $6 != ns ||
        $7 != scenario || $8 != receipt_sha ||
        $9 != "sealed-before-normalization" { exit 1 }
    END { if (NR != 1) exit 1 }
' "$artifact_dir/raw-seal.tsv" || fail BC08_RAW_SEAL_INVALID

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
        if (length(raw) != 12 || length(normalized) != 12) exit 1
        for (id in raw) if (!raw_seen[id]) exit 1
        for (id in normalized) if (!normalized_seen[id]) exit 1
    }
' "$raw" "$artifact_dir/normalized-observations.tsv" \
    "$artifact_dir/coverage.tsv" || fail BC08_COVERAGE_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" \
    -v assertion="$assertion" -v action_mode="$execution_mode" '
    BEGIN {
        phase[1]="create"; op[1]="profile-create-namespace"; mode[1]="normal"
        phase[2]="setup"; op[2]="sut-setup-bc08"; mode[2]="ordinary"
        phase[3]="inventory-before"; op[3]="profile-inventory-bc08"; mode[3]="ordinary"
        phase[4]="action"; op[4]="sut-apply-effect"; mode[4]=action_mode
        phase[5]="retry"; op[5]="sut-apply-effect"; mode[5]="retry"
        phase[6]="observe-after"; op[6]="profile-observe-bc08"; mode[6]="ordinary"
        phase[7]="inventory-after"; op[7]="profile-inventory-bc08"; mode[7]="ordinary"
        phase[8]="reopen"; op[8]="profile-reopen-namespace"; mode[8]="normal"
        phase[9]="inventory-reopened"; op[9]="profile-inventory-bc08"; mode[9]="ordinary"
        phase[10]="destroy"; op[10]="profile-destroy-namespace"; mode[10]="normal"
    }
    NF != 12 || $1 != run || $2 != ns || $3 != assertion ||
        $4 != phase[NR] || $5 != op[NR] || $6 != mode[NR] ||
        $7 != 0 || $8 !~ /^[0-9a-f]{64}$/ ||
        $9 !~ /^(0|[1-9][0-9]*)$/ || $10 !~ /^[0-9a-f]{64}$/ ||
        $11 !~ /^(0|[1-9][0-9]*)$/ || $12 !~ /^[0-9a-f]{64}$/ {
            exit 1
        }
    END { if (NR != 10) exit 1 }
' "$artifact_dir/command-receipts.tsv" ||
    fail BC08_COMMAND_CUSTODY_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" \
    -v assertion="$assertion" '
    NF != 6 || $1 != run || $2 != ns || $3 != assertion ||
        $5 != "foreign-keys" || $6 != 1 { exit 1 }
    END { if (NR != 8) exit 1 }
' "$artifact_dir/pragma.tsv" || fail BC08_PRAGMA_EVIDENCE_INVALID

if [ "$assertion" = BC08_MID_BOUNDARY_FAILURE ]; then
    awk -F '	' '
        NR == FNR {
            hook[$1]=$2; phase[$1]=$3; ordinal[$1]=$5+0; expected[$1]=1
            next
        }
        !($4 in expected) || $7 != hook[$4] { exit 1 }
        END { if (NR-FNR != 5) exit 1 }
    ' "$base_dir/bc08-fault-cases.tsv" \
        "$artifact_dir/fault-trigger-receipts.tsv" ||
        fail BC08_FAULT_HOOK_INVALID
    awk -F '	' '
        NR == FNR { phase[$1]=$3; expected[$1]=1; next }
        !($4 in expected) || $8 != phase[$4] { exit 1 }
    ' "$base_dir/bc08-fault-cases.tsv" \
        "$artifact_dir/fault-trigger-receipts.tsv" ||
        fail BC08_FAULT_PHASE_INVALID
    awk -F '	' '
        $12 != "true" || $13 != 1 || $15 != 0 ||
            $18 !~ /^LICIUM_BC08_FAULT_/ { exit 1 }
        END { if (NR != 5) exit 1 }
    ' "$artifact_dir/fault-trigger-receipts.tsv" ||
        fail BC08_FAULT_UNREACHED
    awk -F '	' '
        NF != 11 || seen[$4 SUBSEP $5]++ || $9 != "true" { exit 1 }
        END { if (NR != 5) exit 1 }
    ' "$artifact_dir/fault-markers.tsv" ||
        fail BC08_FAULT_REPLAY_DETECTED
    cmp -s "$artifact_dir/fault-inventory-setup.tsv" \
        "$artifact_dir/fault-inventory-rollback.tsv" ||
        fail BC08_ROLLBACK_INVENTORY_INVALID
    cmp -s "$artifact_dir/fault-inventory-healthy.tsv" \
        "$artifact_dir/fault-inventory-reopened.tsv" ||
        fail BC08_FAULT_RECOVERY_INVALID
    awk -F '	' -v run="$run" -v assertion="$assertion" '
        NF != 21 || $1 != run || $3 != assertion ||
            $6 != "sut-apply-effect" || $12 != "true" ||
            $13 != 1 || $15 != 0 || $16 != "ok" ||
            $18 !~ /^LICIUM_BC08_FAULT_/ ||
            $19 !~ /^[0-9a-f]{64}$/ ||
            $20 !~ /^[0-9a-f]{64}$/ ||
            $21 != "injected-rollback" || seen[$7]++ { exit 1 }
        END { if (NR != 5) exit 1 }
    ' "$artifact_dir/fault-trigger-receipts.tsv" ||
        fail BC08_FAULT_TRIGGER_INVALID
    awk -F '	' '
        NF != 11 || $9 != "true" || $10 != $11 || seen[$7]++ {
            exit 1
        }
        END { if (NR != 5) exit 1 }
    ' "$artifact_dir/fault-markers.tsv" ||
        fail BC08_ROLLBACK_INVENTORY_INVALID
fi

"$oracle" "$artifact_dir" "$run" "$namespace" "$assertion" "$case_id" \
    "$scenario" >"$tmp/oracle.expected"
cmp -s "$tmp/oracle.expected" "$artifact_dir/oracle-result.tsv" ||
    fail BC08_ORACLE_RESULT_INVALID

echo BC08_RUNTIME_VALID
