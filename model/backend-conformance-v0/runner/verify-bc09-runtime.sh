#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

[ "$#" -eq 5 ] || {
    echo "usage: verify-bc09-runtime.sh ARTIFACT_DIR RUN NAMESPACE ASSERTION SCENARIO" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
scenario=$5

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases_registry="$base_dir/bc09-cases.tsv"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail()
{
    echo "$1" >&2
    exit 1
}

[ -d "$artifact_dir" ] && [ ! -L "$artifact_dir" ] ||
    fail BC09_ARTIFACT_SET_INVALID

cat >"$tmp/expected-files" <<'EOF'
action-receipts.tsv
command-receipts.tsv
coverage.tsv
exclusions.tsv
fault-activation-receipts.tsv
fault-configuration-receipts.tsv
fault-inventory-healthy.tsv
fault-inventory-reopened.tsv
fault-inventory-rollback.tsv
fault-inventory-setup.tsv
fault-markers.tsv
fault-trigger-receipts.tsv
inventory-after.tsv
inventory-before.tsv
inventory-reopened.tsv
normalized-observations.tsv
oracle-result.tsv
pragma.tsv
raw-observations.tsv
raw-seal.tsv
EOF
find "$artifact_dir" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' |
    sort >"$tmp/actual-files"
cmp -s "$tmp/expected-files" "$tmp/actual-files" ||
    fail BC09_ARTIFACT_SET_INVALID

while IFS= read -r name
do
    file="$artifact_dir/$name"
    [ ! -L "$file" ] && [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC09_ARTIFACT_MODE_INVALID
done <"$tmp/expected-files"

awk -F '	' -v assertion="$assertion" '
    $1 == assertion && !seen[$3]++ { print $3 }
' "$cases_registry" >"$tmp/cases"
case_count=$(wc -l <"$tmp/cases" | tr -d ' ')
[ "$case_count" -gt 0 ] || fail BC09_CASE_COVERAGE_INVALID

expected_scenario=$(
    awk -F '	' -v assertion="$assertion" '
        $1 == assertion { print $3; found++ }
        END { if (found != 1) exit 1 }
    ' "$base_dir/bc09-scenario-ids.tsv"
) || fail BC09_SCENARIO_ID_INVALID
[ "$scenario" = "$expected_scenario" ] ||
    fail BC09_SCENARIO_ID_INVALID

check_shape()
{
    name=$1
    fields=$2
    rows=$3
    marker=$4
    awk -F '	' -v fields="$fields" -v rows="$rows" '
        NF != fields { exit 1 }
        END { if (NR != rows) exit 1 }
    ' "$artifact_dir/$name" || fail "$marker"
}

observation_rows=$((case_count * 10))
inventory_rows=$((case_count * 5))
action_rows=$case_count
if rg -qx 'case-duplicate' "$tmp/cases"; then
    action_rows=$((action_rows + 1))
fi
if [ "$assertion" = BC09_FAILPOINT_PERSISTS ]; then
    action_rows=$((action_rows + 5))
fi

check_shape action-receipts.tsv 14 "$action_rows" \
    BC09_ACTION_RECEIPT_CONTRACT_INVALID
awk -F '	' 'NF != 12 { exit 1 } END { if (NR == 0) exit 1 }' \
    "$artifact_dir/command-receipts.tsv" ||
    fail BC09_COMMAND_CUSTODY_INVALID
check_shape coverage.tsv 6 "$observation_rows" BC09_COVERAGE_INVALID
check_shape exclusions.tsv 6 0 BC09_EXCLUSION_INVALID
check_shape inventory-after.tsv 6 "$inventory_rows" \
    BC09_INVENTORY_CONTRACT_INVALID
check_shape inventory-before.tsv 6 "$inventory_rows" \
    BC09_INVENTORY_CONTRACT_INVALID
check_shape inventory-reopened.tsv 6 "$inventory_rows" \
    BC09_INVENTORY_CONTRACT_INVALID
check_shape normalized-observations.tsv 6 "$observation_rows" \
    BC09_NORMALIZED_CONTRACT_INVALID
check_shape oracle-result.tsv 6 1 BC09_ORACLE_INVALID
awk -F '	' 'NF != 6 { exit 1 } END { if (NR == 0) exit 1 }' \
    "$artifact_dir/pragma.tsv" || fail BC09_PRAGMA_EVIDENCE_INVALID
check_shape raw-observations.tsv 6 "$observation_rows" \
    BC09_RAW_CONTRACT_INVALID
check_shape raw-seal.tsv 9 1 BC09_RAW_SEAL_INVALID

if [ "$assertion" = BC09_FAILPOINT_PERSISTS ]; then
    check_shape fault-activation-receipts.tsv 10 5 \
        BC09_FAULT_ACTIVATION_CONTRACT_INVALID
    check_shape fault-configuration-receipts.tsv 14 5 \
        BC09_FAULT_CONFIGURATION_CONTRACT_INVALID
    check_shape fault-inventory-healthy.tsv 6 45 \
        BC09_FAULT_INVENTORY_CONTRACT_INVALID
    check_shape fault-inventory-reopened.tsv 6 45 \
        BC09_FAULT_INVENTORY_CONTRACT_INVALID
    check_shape fault-inventory-rollback.tsv 6 25 \
        BC09_FAULT_INVENTORY_CONTRACT_INVALID
    check_shape fault-inventory-setup.tsv 6 25 \
        BC09_FAULT_INVENTORY_CONTRACT_INVALID
    check_shape fault-markers.tsv 11 5 \
        BC09_FAULT_MARKER_CONTRACT_INVALID
    check_shape fault-trigger-receipts.tsv 21 5 \
        BC09_FAULT_TRIGGER_CONTRACT_INVALID
else
    for name in fault-activation-receipts.tsv \
        fault-configuration-receipts.tsv fault-inventory-healthy.tsv \
        fault-inventory-reopened.tsv fault-inventory-rollback.tsv \
        fault-inventory-setup.tsv fault-markers.tsv \
        fault-trigger-receipts.tsv
    do
        [ ! -s "$artifact_dir/$name" ] ||
            fail BC09_UNEXPECTED_FAULT_EVIDENCE
    done
fi

# Action receipts bind the direct SUT output to the assertion and case
# registry.  Healthy recovery receipts are additional evidence and are not
# used to derive the failure observation.
awk -F '	' -v run="$run" -v ns="$namespace" \
    -v assertion="$assertion" '
    FILENAME == ARGV[1] && $1 == assertion {
        valid[$3] = 1
        expected_disposition[$3] = $7
        expected_reason[$3] = $8
        expected_delivery[$3] = $9
        next
    }
    FILENAME == ARGV[2] {
        if ($1 != run || $2 != ns "-" substr($4, 6) ||
            $3 != assertion || !($4 in valid) ||
            $5 != "sut-apply-effect" ||
            $6 !~ /^delivery-[12]$/ || $7 != "effect-1" ||
            $8 != "result-1" || $11 !~ /^[04]$/ ||
            $12 == "" || $13 != "impl-bc09-v0" ||
            $14 !~ /^(attempt-[12]|healthy)$/) exit 1
        if ($14 == "healthy") {
            if (assertion != "BC09_FAILPOINT_PERSISTS" ||
                $9 != "accepted" || $10 != "applied" || $11 != "4" ||
                $12 != "healthy-" $4 || healthy[$4]++) exit 1
            next
        }
        expected_nonce = "action-" run "-" $4
        if (assertion == "BC09_FAILPOINT_PERSISTS" ||
            ((assertion == "BC09_DIAGNOSTIC_EPHEMERAL" ||
              assertion == "BC09_FAILURE_NO_PERSISTENT_ARTIFACT") &&
             $4 == "case-fault"))
            expected_nonce = "fault-" run "-" substr($4, 6)
        if ($12 != expected_nonce) exit 1
        ordinary[$4]++
        last_disposition[$4] = $9
        last_reason[$4] = $10
    }
    END {
        for (item in valid) {
            if (ordinary[item] != expected_delivery[item] ||
                last_disposition[item] != expected_disposition[item] ||
                last_reason[item] != expected_reason[item]) exit 1
            if (assertion == "BC09_FAILPOINT_PERSISTS" &&
                healthy[item] != 1) exit 1
        }
    }
' "$cases_registry" "$artifact_dir/action-receipts.tsv" ||
    fail BC09_ACTION_RECEIPT_CONTRACT_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" \
    -v assertion="$assertion" '
    $1 != run || $2 != ns || $3 != assertion ||
        $4 == "" || $5 == "" || $6 == "" ||
        $7 !~ /^(0|19)$/ ||
        $8 !~ /^[0-9a-f][0-9a-f]*$/ || $9 !~ /^[0-9]+$/ ||
        $10 !~ /^[0-9a-f][0-9a-f]*$/ || $11 !~ /^[0-9]+$/ ||
        $12 !~ /^[0-9a-f][0-9a-f]*$/ { exit 1 }
    { status[$7]++ }
    END {
        if (status[0] == 0) exit 1
        if ((assertion == "BC09_FAILPOINT_PERSISTS" ||
             assertion == "BC09_DIAGNOSTIC_EPHEMERAL" ||
             assertion == "BC09_FAILURE_NO_PERSISTENT_ARTIFACT") &&
            status[19] == 0) exit 1
    }
' "$artifact_dir/command-receipts.tsv" ||
    fail BC09_COMMAND_CUSTODY_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" \
    -v assertion="$assertion" '
    $1 != run || $2 != ns || $3 != assertion ||
        $4 == "" || $5 != "foreign-keys" || $6 != "1" { exit 1 }
' "$artifact_dir/pragma.tsv" ||
    fail BC09_PRAGMA_EVIDENCE_INVALID

for name in inventory-before.tsv inventory-after.tsv inventory-reopened.tsv
do
    sort -c "$artifact_dir/$name" 2>/dev/null ||
        fail BC09_INVENTORY_CONTRACT_INVALID
done
cmp -s "$artifact_dir/inventory-before.tsv" \
    "$artifact_dir/inventory-after.tsv" &&
    cmp -s "$artifact_dir/inventory-before.tsv" \
        "$artifact_dir/inventory-reopened.tsv" ||
    fail BC09_INVENTORY_CONTRACT_INVALID

awk -F '	' 'NR == FNR { wanted[$1] = 1; next }
    $1 in wanted { print }
' "$tmp/cases" "$base_dir/bc09-inventory-before.tsv" \
    >"$tmp/expected-inventory"
cmp -s "$tmp/expected-inventory" "$artifact_dir/inventory-before.tsv" ||
    fail BC09_INVENTORY_CONTRACT_INVALID

raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
awk -F '	' -v raw_sha="$raw_sha" -v raw_bytes="$raw_bytes" \
    -v run="$run" -v ns="$namespace" -v scenario="$scenario" \
    -v receipt_sha="$receipt_sha" '
    $1 != "raw-observations.tsv" || $2 != "100644" ||
        $3 != raw_sha || $4 != raw_bytes || $5 != run ||
        $6 != ns || $7 != scenario || $8 != receipt_sha ||
        $9 != "sealed-before-normalization" { exit 1 }
' "$artifact_dir/raw-seal.tsv" || fail BC09_RAW_SEAL_INVALID

"$script_dir/normalize-bc09.sh" "$artifact_dir/raw-observations.tsv" \
    "$tmp/normalized"
cmp -s "$tmp/normalized" "$artifact_dir/normalized-observations.tsv" ||
    fail BC09_NORMALIZED_CONTRACT_INVALID

awk -F '	' 'BEGIN { OFS=FS }
    {
        normalized=$2
        sub(/^raw-/, "obs-", normalized)
        print $1,$2,"record",$1,normalized,"all"
    }
' "$artifact_dir/raw-observations.tsv" >"$tmp/coverage"
cmp -s "$tmp/coverage" "$artifact_dir/coverage.tsv" ||
    fail BC09_COVERAGE_INVALID

"$script_dir/oracle-bc09.sh" \
    "$artifact_dir/normalized-observations.tsv" "$cases_registry" \
    "$assertion" "$scenario" "$tmp/oracle"
cmp -s "$tmp/oracle" "$artifact_dir/oracle-result.tsv" ||
    fail BC09_ORACLE_INVALID

if [ "$assertion" = BC09_FAILPOINT_PERSISTS ]; then
    for name in fault-inventory-setup.tsv fault-inventory-rollback.tsv \
        fault-inventory-healthy.tsv fault-inventory-reopened.tsv
    do
        sort -c "$artifact_dir/$name" 2>/dev/null ||
            fail BC09_FAULT_INVENTORY_CONTRACT_INVALID
    done
    cmp -s "$artifact_dir/fault-inventory-setup.tsv" \
        "$base_dir/bc09-fault-inventory-setup.tsv" &&
        cmp -s "$artifact_dir/fault-inventory-rollback.tsv" \
            "$base_dir/bc09-fault-inventory-rollback.tsv" &&
        cmp -s "$artifact_dir/fault-inventory-healthy.tsv" \
            "$base_dir/bc09-fault-inventory-healthy.tsv" &&
        cmp -s "$artifact_dir/fault-inventory-reopened.tsv" \
            "$base_dir/bc09-fault-inventory-reopened.tsv" ||
        fail BC09_FAULT_INVENTORY_CONTRACT_INVALID

    awk -F '	' '
        FILENAME == ARGV[1] { binding[$1] = $2 FS $3 FS int($5/10); next }
        FILENAME == ARGV[2] {
            if (!($4 in binding) ||
                binding[$4] != ($7 FS $8 FS $14) ||
                $3 != "BC09_FAILPOINT_PERSISTS" ||
                $5 != "attempt-bc09-" substr($4, 6) ||
                $6 != "sut-apply-effect" ||
                $9 == "" || $10 != "impl-bc09-v0" || $11 == "" ||
                $12 != "true" || $13 != "1" || $15 != "0" ||
                $16 != "ok" ||
                $18 !~ /^LICIUM_BC09_FAULT_/ ||
                $19 == "" || $20 == "" ||
                $21 != "injected-rollback" || seen[$4]++) exit 1
        }
        END { if (length(seen) != 5) exit 1 }
    ' "$base_dir/bc09-fault-cases.tsv" \
        "$artifact_dir/fault-trigger-receipts.tsv" ||
        fail BC09_FAULT_TRIGGER_CONTRACT_INVALID

    awk -F '	' '
        FILENAME == ARGV[1] { binding[$1] = $2 FS $3; next }
        FILENAME == ARGV[2] {
            if (!($4 in binding) || binding[$4] != ($7 FS $8) ||
                $3 != "BC09_FAILPOINT_PERSISTS" ||
                $5 != "attempt-bc09-" substr($4, 6) ||
                $6 != "sut-apply-effect" || $9 == "" ||
                $10 != "impl-bc09-v0" || seen[$4]++) exit 1
        }
        END { if (length(seen) != 5) exit 1 }
    ' "$base_dir/bc09-fault-cases.tsv" \
        "$artifact_dir/fault-activation-receipts.tsv" ||
        fail BC09_FAULT_ACTIVATION_CONTRACT_INVALID

    awk -F '	' '
        FILENAME == ARGV[1] { binding[$1] = $2 FS $3; next }
        FILENAME == ARGV[2] {
            if (!($4 in binding) || binding[$4] != ($5 FS $6) ||
                $3 != "BC09_FAILPOINT_PERSISTS" ||
                $7 == "" || $8 != "impl-bc09-v0" || $9 == "" ||
                $10 != "trigger-bc09-" $6 ||
                $11 == "" || $12 == "" || $13 == "" ||
                $14 != "configured" || seen[$4]++) exit 1
        }
        END { if (length(seen) != 5) exit 1 }
    ' "$base_dir/bc09-fault-cases.tsv" \
        "$artifact_dir/fault-configuration-receipts.tsv" ||
        fail BC09_FAULT_CONFIGURATION_CONTRACT_INVALID

    awk -F '	' '
        FILENAME == ARGV[1] { binding[$1] = $2 FS $3; next }
        FILENAME == ARGV[2] {
            if ($1 != "BC09_FAILPOINT_PERSISTS" ||
                !($3 in binding) || binding[$3] != ($7 FS $8) ||
                $2 == "" || $4 == "" || $5 == "" ||
                $6 != "impl-bc09-v0" || $9 != "true" ||
                $10 == "" || $10 != $11 || seen[$3]++ ||
                seen_nonce[$5]++) exit 1
        }
        END { if (length(seen) != 5) exit 1 }
    ' "$base_dir/bc09-fault-cases.tsv" "$artifact_dir/fault-markers.tsv" ||
        fail BC09_FAULT_MARKER_CONTRACT_INVALID
fi

find "$artifact_dir" -type f -name '*.db' -print -quit |
    awk 'NF { exit 1 }' || fail BC09_DATABASE_RESIDUE_INVALID

echo BC09_RUNTIME_CONTRACT_VALID
