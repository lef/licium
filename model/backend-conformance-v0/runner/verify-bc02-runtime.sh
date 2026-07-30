#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
registry="$base_dir/bc02-runtime-artifacts.tsv"
cardinality="$base_dir/bc02-artifact-cardinality.tsv"

[ "$#" -eq 5 ] || {
    echo "usage: verify-bc02-runtime.sh ARTIFACT_DIR RUN NS ASSERTION CASE" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
case_id=$5

fail()
{
    echo "$1" >&2
    exit 1
}

case "$assertion:$case_id" in
    BC02_PARTIAL_RESIDUE:case-bc02-after-root-header|\
    BC02_PARTIAL_RESIDUE:case-bc02-after-root-member|\
    BC02_POISONED_RETRY:case-bc02-after-root-header|\
    BC02_POISONED_RETRY:case-bc02-after-root-member|\
    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-header|\
    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-member)
        exec "$script_dir/verify-bc02-fault-runtime.sh" "$@"
        ;;
esac

case "$assertion:$case_id" in
    BC02_COMPLETE_AVAILABLE:case-bc02-complete)
        scenario=bc02-complete-available--case-bc02-complete
        after_stage=success-after
        resolution_stage=success
        after_inventory=inventory-success-after.tsv
        oracle_id=oracle-bc02-complete-available
        form_attempt=attempt-complete
        inventory_stages="setup-before success-after"
        ;;
    BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-missing|\
    BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-substitution)
        scenario=bc02-incomplete-as-complete--"$case_id"
        after_stage=rollback-after
        resolution_stage=unavailable
        after_inventory=inventory-rollback-after.tsv
        oracle_id=oracle-bc02-incomplete-as-complete
        form_attempt=attempt-initial
        inventory_stages="setup-before rollback-after"
        ;;
    BC02_HEALTHY_RETRY:case-bc02-incomplete-corrected)
        scenario=bc02-healthy-retry--case-bc02-incomplete-corrected
        after_stage=rollback-after
        resolution_stage=unavailable
        after_inventory=inventory-rollback-after.tsv
        oracle_id=oracle-bc02-healthy-retry
        form_attempt=attempt-initial
        inventory_stages="setup-before rollback-after correction-after retry-after"
        healthy_retry=1
        ;;
    *)
        fail BC02_RUNTIME_IDENTITY_INVALID
        ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

cut -f1 "$registry" | LC_ALL=C sort > "$tmp/expected-layout"
find "$artifact_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' |
    LC_ALL=C sort > "$tmp/actual-layout"
cmp -s "$tmp/expected-layout" "$tmp/actual-layout" ||
    fail BC02_RUNTIME_LAYOUT_INVALID

while IFS='	' read -r name fields cardinality_class kind source; do
    file="$artifact_dir/$name"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC02_REQUIRED_ARTIFACT_MISSING
    [ "$(stat -c '%a' "$file")" = "644" ] ||
        fail BC02_RUNTIME_ARTIFACT_MODE_INVALID
    expected_rows=$(awk -F '	' -v scenario="$scenario" -v name="$name" '
        $1 == scenario && $2 == name { print $4 }
    ' "$cardinality")
    [ "$expected_rows" != "" ] ||
        fail BC02_RUNTIME_CARDINALITY_MISSING
    [ "$(wc -l < "$file" | tr -d ' ')" = "$expected_rows" ] ||
        fail BC02_RUNTIME_ARTIFACT_SHAPE_INVALID
    if [ "$expected_rows" -gt 0 ]; then
        awk -F '	' -v fields="$fields" 'NF != fields { exit 1 }' "$file" ||
            fail BC02_RUNTIME_ARTIFACT_SHAPE_INVALID
    fi
done < "$registry"

for stage in $inventory_stages; do
    actual="$artifact_dir/inventory-$stage.tsv"
    template=$(awk -F '	' -v assertion="$assertion" -v case_id="$case_id" \
        -v stage="$stage" '
        $1 == assertion && $2 == case_id && $3 == stage { print $5 }
    ' "$base_dir/bc02-inventory-map.tsv")
    sed "s/{scenario}/$scenario/g" "$base_dir/$template" > "$tmp/$stage.expected"
    cmp -s "$tmp/$stage.expected" "$actual" ||
        fail BC02_RUNTIME_INVENTORY_INVALID
done

awk -F '	' -v OFS='	' -v run="$run" -v namespace_id="$namespace" \
    -v assertion="$assertion" -v case_id="$case_id" '
    $3 == assertion && $4 == case_id {
        $1 = run
        $2 = namespace_id
        gsub(/\{nonce\}/, "form-nonce", $15)
        gsub(/\{nonce-initial\}/, "form-nonce", $15)
        gsub(/\{nonce-retry\}/, "retry-nonce", $15)
        print
    }
' "$base_dir/bc02-root-action-receipt-template.tsv" \
    > "$tmp/action-receipts.expected"
cmp -s "$tmp/action-receipts.expected" "$artifact_dir/action-receipts.tsv" ||
    fail BC02_RUNTIME_ACTION_RECEIPT_INVALID

awk -F '	' -v OFS='	' -v run="$run" -v namespace_id="$namespace" \
    -v assertion="$assertion" -v case_id="$case_id" '
    $3 == assertion && $4 == case_id {
        $1 = run
        $2 = namespace_id
        print
    }
' "$base_dir/bc02-resolution-receipt-template.tsv" \
    > "$tmp/resolution-receipts.expected"
cmp -s "$tmp/resolution-receipts.expected" \
    "$artifact_dir/resolution-receipts.tsv" ||
    fail BC02_RUNTIME_RESOLUTION_INVALID

if [ "${healthy_retry:-0}" -eq 1 ]; then
    awk -F '	' -v OFS='	' -v run="$run" \
        -v namespace_id="$namespace" '
        {
            $1 = run
            $2 = namespace_id
            gsub(/\{nonce-correction\}/, "correction-nonce", $11)
            print
        }
    ' "$base_dir/bc02-correction-receipt-template.tsv" \
        > "$tmp/correction-receipts.expected"
    cmp -s "$tmp/correction-receipts.expected" \
        "$artifact_dir/correction-receipts.tsv" ||
        fail BC02_RUNTIME_CORRECTION_RECEIPT_INVALID

    guard="$base_dir/sqlite-reference/correction-guard-bc02.sql"
    guard_sha=$(sha256sum "$guard" | awk '{ print $1 }')
    printf '%s\t%s\t%s\t%s\tcorrection-correction-02\tsut-correct-root-input\tsource_object\tobject-c\tinsert-only\tguard-bc02-v1\t%s\tenforced\tcorrection-nonce\n' \
        "$run" "$namespace" "$assertion" "$case_id" "$guard_sha" \
        > "$tmp/correction-guard.expected"
    cmp -s "$tmp/correction-guard.expected" \
        "$artifact_dir/correction-write-guard-receipts.tsv" ||
        fail BC02_RUNTIME_CORRECTION_GUARD_INVALID
fi

adapter="$base_dir/profiles/sqlite-reference/run.sh"
db="$artifact_dir/$namespace.db"
expected_commands="$tmp/command-receipts.tsv"
: > "$expected_commands"
printf 'pragma\tforeign-keys\t1\n' > "$tmp/pragma.err"
: > "$tmp/empty.err"
printf 'status\tcreate\taccepted\t%s\n' "$namespace" > "$tmp/create.out"
printf 'status\tsetup\taccepted\t%s\n' "$assertion" > "$tmp/setup.out"
printf 'status\treopen\taccepted\t%s\n' "$assertion" > "$tmp/reopen.out"
printf 'status\tdestroy\taccepted\t%s\n' "$namespace" > "$tmp/destroy.out"
awk -F '	' -v stage="$resolution_stage" '$5 == stage' \
    "$artifact_dir/resolution-receipts.tsv" \
    > "$tmp/success.out"
awk -F '	' '$5 == "reopened"' "$artifact_dir/resolution-receipts.tsv" \
    > "$tmp/reopened.out"
form_stdout="$artifact_dir/action-receipts.tsv"
if [ "${healthy_retry:-0}" -eq 1 ]; then
    sed -n '1p' "$artifact_dir/action-receipts.tsv" > "$tmp/form.out"
    sed -n '2p' "$artifact_dir/action-receipts.tsv" > "$tmp/retry.out"
    awk -F '	' '$5 == "retry-success"' \
        "$artifact_dir/resolution-receipts.tsv" > "$tmp/retry-success.out"
    {
        printf '%s\n' \
            'PRAGMA foreign_keys=ON;' \
            'BEGIN IMMEDIATE;' \
            'INSERT INTO source_object' \
            "             VALUES ('object-c','pair','value-c');" \
            '-- TRIGGER correction_guard_source_insert;' \
            'COMMIT;'
        printf 'pragma\tforeign-keys\t1\n'
    } > "$tmp/correction.err"
    form_stdout="$tmp/form.out"
fi

expected_command()
{
    phase=$1
    operation=$2
    command_mode=$3
    stdout=$4
    stderr=$5
    shift 5

    argv_sha=$(
        for argument in "$@"; do
            if [ "$argument" = "$adapter" ]; then
                printf '%s\n' '{adapter-entrypoint}'
            elif [ "$argument" = "$db" ]; then
                printf '%s\n' '{database-path}'
            else
                printf '%s\n' "$argument"
            fi
        done | sha256sum | awk '{ print $1 }'
    )

    printf '%s\t%s\t%s\t%s\t%s\t%s\t0\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$assertion" "$phase" "$operation" \
        "$command_mode" \
        "$(sha256sum "$stdout" | awk '{ print $1 }')" \
        "$(wc -c < "$stdout" | tr -d ' ')" \
        "$(sha256sum "$stderr" | awk '{ print $1 }')" \
        "$(wc -c < "$stderr" | tr -d ' ')" \
        "$argv_sha" >> "$expected_commands"
}

expected_command create profile-create-namespace normal \
    "$tmp/create.out" "$tmp/pragma.err" \
    "$adapter" create-bc02 "$namespace" "$db"
expected_command setup sut-setup-bc02 ordinary \
    "$tmp/setup.out" "$tmp/pragma.err" \
    "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc02 ordinary setup setup-nonce
expected_command setup-before runner-bind-evidence ordinary \
    "$artifact_dir/inventory-setup-before.tsv" "$tmp/pragma.err" \
    "$adapter" inventory-bc02 "$db" "$scenario"
expected_command form sut-form-root ordinary \
    "$form_stdout" "$tmp/pragma.err" \
    "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-form-root ordinary "$form_attempt" form-nonce
expected_command "$after_stage" runner-bind-evidence ordinary \
    "$artifact_dir/$after_inventory" "$tmp/pragma.err" \
    "$adapter" inventory-bc02 "$db" "$scenario"
expected_command "$resolution_stage" runner-bind-evidence ordinary \
    "$tmp/success.out" "$tmp/pragma.err" \
    "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" "$resolution_stage"
if [ "${healthy_retry:-0}" -eq 1 ]; then
    expected_command correction sut-correct-root-input ordinary \
        "$artifact_dir/correction-receipts.tsv" "$tmp/correction.err" \
        "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" sut-correct-root-input ordinary \
        correction-correction-02 correction-nonce
    expected_command correction-after runner-bind-evidence ordinary \
        "$artifact_dir/inventory-correction-after.tsv" "$tmp/pragma.err" \
        "$adapter" inventory-bc02 "$db" "$scenario"
    expected_command retry sut-retry-root ordinary \
        "$tmp/retry.out" "$tmp/pragma.err" \
        "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" sut-retry-root ordinary attempt-retry retry-nonce
    expected_command retry-after runner-bind-evidence ordinary \
        "$artifact_dir/inventory-retry-after.tsv" "$tmp/pragma.err" \
        "$adapter" inventory-bc02 "$db" "$scenario"
    expected_command retry-success runner-bind-evidence ordinary \
        "$tmp/retry-success.out" "$tmp/pragma.err" \
        "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" retry-success
fi
expected_command durability-reopen profile-reopen-namespace ordinary \
    "$tmp/reopen.out" "$tmp/pragma.err" \
    "$adapter" reopen "$db" "$run" "$namespace" "$assertion"
expected_command reopened runner-bind-evidence ordinary \
    "$tmp/reopened.out" "$tmp/pragma.err" \
    "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" reopened
expected_command destroy profile-destroy-namespace normal \
    "$tmp/destroy.out" "$tmp/empty.err" \
    "$adapter" destroy "$namespace" "$db"

cmp -s "$expected_commands" "$artifact_dir/command-receipts.tsv" ||
    fail BC02_COMMAND_CUSTODY_INVALID

expected_pragma_rows=8
[ "${healthy_retry:-0}" -eq 0 ] || expected_pragma_rows=13
awk -F '	' -v run="$run" -v namespace_id="$namespace" \
    -v assertion="$assertion" -v expected_rows="$expected_pragma_rows" '
    NF != 6 || $1 != run || $2 != namespace_id ||
        $3 != assertion ||
        $5 != "foreign-keys" || $6 != 1 { exit 1 }
    { seen[$4]++ }
    END {
        if (NR != expected_rows || seen["destroy"]) exit 1
    }
' "$artifact_dir/pragma.tsv" ||
    fail BC02_PRAGMA_EVIDENCE_INVALID

raw="$artifact_dir/raw-observations.tsv"
seal="$artifact_dir/raw-seal.tsv"
receipt_set="$tmp/receipt-set.tsv"
if [ "${healthy_retry:-0}" -eq 1 ]; then
    receipt_sources="action-receipts.tsv
command-receipts.tsv
correction-receipts.tsv
correction-write-guard-receipts.tsv
inventory-correction-after.tsv
inventory-retry-after.tsv
inventory-rollback-after.tsv
inventory-setup-before.tsv
resolution-receipts.tsv"
else
    receipt_sources="action-receipts.tsv
$after_inventory
resolution-receipts.tsv"
fi
printf '%s\n' "$receipt_sources" | LC_ALL=C sort |
while IFS= read -r source; do
    file="$artifact_dir/$source"
    printf '%s\t%s\t%s\n' "$source" \
        "$(sha256sum "$file" | awk '{ print $1 }')" \
        "$(wc -c < "$file" | tr -d ' ')"
done > "$receipt_set"

awk -F '	' -v raw_sha="$(sha256sum "$raw" | awk '{ print $1 }')" \
    -v raw_bytes="$(wc -c < "$raw" | tr -d ' ')" \
    -v run="$run" -v namespace_id="$namespace" -v scenario="$scenario" \
    -v receipt_sha="$(sha256sum "$receipt_set" | awk '{ print $1 }')" '
    NF != 9 || $1 != "raw-observations.tsv" || $2 != "100644" ||
        $3 != raw_sha || $4 != raw_bytes || $5 != run || $6 != namespace_id ||
        $7 != scenario || $8 != receipt_sha ||
        $9 != "sealed-before-normalization" { exit 1 }
    END { if (NR != 1) exit 1 }
' "$seal" || fail BC02_RAW_SEAL_INVALID

setup_sha=$(sha256sum "$artifact_dir/inventory-setup-before.tsv" |
    awk '{ print $1 }')
rollback_sha=$(sha256sum "$artifact_dir/inventory-rollback-after.tsv" |
    awk '{ print $1 }')
correction_sha=$(sha256sum "$artifact_dir/inventory-correction-after.tsv" |
    awk '{ print $1 }')
rollback_protected_sha=$(
    awk -F '	' '$2 != "source-object"' \
        "$artifact_dir/inventory-rollback-after.tsv" |
        sha256sum | awk '{ print $1 }'
)
correction_protected_sha=$(
    awk -F '	' '$2 != "source-object"' \
        "$artifact_dir/inventory-correction-after.tsv" |
        sha256sum | awk '{ print $1 }'
)
awk -F '	' -v scenario="$scenario" -v setup_sha="$setup_sha" \
    -v rollback_sha="$rollback_sha" -v correction_sha="$correction_sha" \
    -v rollback_protected_sha="$rollback_protected_sha" \
    -v correction_protected_sha="$correction_protected_sha" '
    $1 == scenario {
        gsub(/\{setup-before-sha256\}/, setup_sha)
        gsub(/\{rollback-after-sha256\}/, rollback_sha)
        gsub(/\{correction-after-sha256\}/, correction_sha)
        gsub(/\{rollback-protected-sha256\}/, rollback_protected_sha)
        gsub(/\{correction-protected-sha256\}/, correction_protected_sha)
        print
    }
' "$base_dir/bc02-raw-template.tsv" > "$tmp/raw-observations.tsv.expected"
cmp -s "$tmp/raw-observations.tsv.expected" "$raw" ||
    fail BC02_RUNTIME_SEMANTIC_ARTIFACT_INVALID

for pair in \
    "bc02-normalized-contract.tsv:normalized-observations.tsv" \
    "bc02-coverage-template.tsv:coverage.tsv"
do
    contract=${pair%%:*}
    artifact=${pair#*:}
    awk -F '	' -v scenario="$scenario" '$1 == scenario' \
        "$base_dir/$contract" > "$tmp/$artifact.expected"
    cmp -s "$tmp/$artifact.expected" "$artifact_dir/$artifact" ||
        fail BC02_RUNTIME_SEMANTIC_ARTIFACT_INVALID
done

expected_sha=$(sha256sum "$tmp/normalized-observations.tsv.expected" |
    awk '{ print $1 }')
actual_sha=$(sha256sum "$artifact_dir/normalized-observations.tsv" |
    awk '{ print $1 }')
oracle_revision=$(sha256sum "$script_dir/oracle-bc02.sh" | awk '{ print $1 }')
awk -F '	' -v scenario="$scenario" -v expected_sha="$expected_sha" \
    -v actual_sha="$actual_sha" -v revision="$oracle_revision" \
    -v oracle_id="$oracle_id" '
    NF != 8 || $1 != scenario ||
        $2 != oracle_id || $3 != "exact" ||
        $4 != "norm-bc02-observation" ||
        $5 != expected_sha || $6 != actual_sha ||
        $7 != "PASS" || $8 != revision { exit 1 }
    END { if (NR != 1) exit 1 }
' "$artifact_dir/oracle-result.tsv" ||
    fail BC02_RUNTIME_ORACLE_RECEIPT_INVALID

find "$artifact_dir" -mindepth 1 -maxdepth 1 -name '*.db' |
    awk 'NR { exit 1 }' || fail BC02_RUNTIME_CLEANUP_FAILED

echo BC02_RUNTIME_VALID
