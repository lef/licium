#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runner="$script_dir/run-bc02-runtime.sh"
verifier="$script_dir/verify-bc02-runtime.sh"

[ -x "$runner" ] || {
    echo BC02_RUNTIME_RUNNER_MISSING >&2
    exit 1
}

[ -x "$verifier" ] || {
    echo BC02_RUNTIME_VERIFIER_MISSING >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

baseline="$tmp/baseline"
"$runner" "$baseline" run-bc02-baseline ns-bc02-baseline \
    BC02_COMPLETE_AVAILABLE case-bc02-complete ordinary
"$verifier" "$baseline" run-bc02-baseline ns-bc02-baseline \
    BC02_COMPLETE_AVAILABLE case-bc02-complete >/dev/null

for case_id in \
    case-bc02-incomplete-missing \
    case-bc02-incomplete-substitution
do
    name=${case_id#case-bc02-}
    directory="$tmp/$name"
    run="run-bc02-$name"
    namespace="ns-bc02-$name"
    set +e
    incomplete_output=$(
        "$runner" "$directory" "$run" "$namespace" \
            BC02_INCOMPLETE_AS_COMPLETE "$case_id" ordinary 2>&1
    )
    incomplete_status=$?
    set -e
    [ "$incomplete_status" -eq 0 ] || {
        [ "$incomplete_output" = "" ] || printf '%s\n' "$incomplete_output" >&2
        echo BC02_INCOMPLETE_RUNTIME_MISSING >&2
        exit 1
    }
    "$verifier" "$directory" "$run" "$namespace" \
        BC02_INCOMPLETE_AS_COMPLETE "$case_id" >/dev/null
done

set +e
retry_output=$(
    "$runner" "$tmp/healthy-retry" run-bc02-healthy-retry \
        ns-bc02-healthy-retry BC02_HEALTHY_RETRY \
        case-bc02-incomplete-corrected ordinary 2>&1
)
retry_status=$?
set -e
[ "$retry_status" -eq 0 ] || {
    [ "$retry_output" = "" ] || printf '%s\n' "$retry_output" >&2
    echo BC02_HEALTHY_RETRY_RUNTIME_MISSING >&2
    exit 1
}
"$verifier" "$tmp/healthy-retry" run-bc02-healthy-retry \
    ns-bc02-healthy-retry BC02_HEALTHY_RETRY \
    case-bc02-incomplete-corrected >/dev/null

for assertion in \
    BC02_PARTIAL_RESIDUE \
    BC02_ROLLBACK_COMPLETE \
    BC02_POISONED_RETRY
do
    for case_id in \
        case-bc02-after-root-header \
        case-bc02-after-root-member
    do
        assertion_name=$(printf '%s\n' "$assertion" |
            tr '[:upper:]_' '[:lower:]-')
        case_name=${case_id#case-bc02-}
        name="$assertion_name--$case_name"
        set +e
        fault_output=$(
            "$runner" "$tmp/$name" "run-$name" "ns-$name" \
                "$assertion" "$case_id" ordinary 2>&1
        )
        fault_status=$?
        set -e
        [ "$fault_status" -eq 0 ] || {
            [ "$fault_output" = "" ] || printf '%s\n' "$fault_output" >&2
            echo BC02_FAULT_RUNTIME_MISSING >&2
            exit 1
        }
        "$verifier" "$tmp/$name" "run-$name" "ns-$name" \
            "$assertion" "$case_id" >/dev/null
    done
done

expect_rejected()
{
    name=$1
    expected=$2
    directory="$tmp/$name"
    shift 2
    cp -R "$baseline" "$directory"
    "$@" "$directory"
    set +e
    output=$(
        "$verifier" "$directory" run-bc02-baseline ns-bc02-baseline \
            BC02_COMPLETE_AVAILABLE case-bc02-complete 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC02_CONTROL_ACCEPTED: $name" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        printf '%s\n' "$output" >&2
        echo "BC02_CONTROL_VERDICT_INVALID: $name" >&2
        exit 1
    }
}

remove_artifact()
{
    rm "$1/raw-observations.tsv"
}

add_layout_path()
{
    mkdir "$1/unregistered"
}

tamper_action()
{
    sed -i 's/root-02/root-tampered/' "$1/action-receipts.tsv"
}

tamper_receipt_set_seal()
{
    seal="$1/raw-seal.tsv"
    awk -F '	' -v OFS='	' '
        {
            $8 = "0000000000000000000000000000000000000000000000000000000000000000"
            print
        }
    ' "$seal" > "$seal.new"
    mv "$seal.new" "$seal"
    chmod 644 "$seal"
}

forge_oracle()
{
    sed -i 's/\tPASS\t/\tFAIL\t/' "$1/oracle-result.tsv"
}

tamper_raw_and_reseal()
{
    directory=$1
    raw="$directory/raw-observations.tsv"
    seal="$directory/raw-seal.tsv"
    sed -i 's/root-02/root-tampered/' "$raw"
    raw_sha=$(sha256sum "$raw" | awk '{ print $1 }')
    raw_bytes=$(wc -c < "$raw" | tr -d ' ')
    awk -F '	' -v OFS='	' -v sha="$raw_sha" -v bytes="$raw_bytes" '
        { $3 = sha; $4 = bytes; print }
    ' "$seal" > "$seal.new"
    mv "$seal.new" "$seal"
    chmod 644 "$seal"
}

tamper_command_argv()
{
    receipts="$1/command-receipts.tsv"
    awk -F '	' -v OFS='	' '
        NR == 1 {
            $12 = "0000000000000000000000000000000000000000000000000000000000000000"
        }
        { print }
    ' "$receipts" > "$receipts.new"
    mv "$receipts.new" "$receipts"
    chmod 644 "$receipts"
}

tamper_command_stdout()
{
    receipts="$1/command-receipts.tsv"
    awk -F '	' -v OFS='	' '
        $4 == "form" {
            $8 = "0000000000000000000000000000000000000000000000000000000000000000"
        }
        { print }
    ' "$receipts" > "$receipts.new"
    mv "$receipts.new" "$receipts"
    chmod 644 "$receipts"
}

tamper_command_stderr()
{
    receipts="$1/command-receipts.tsv"
    awk -F '	' -v OFS='	' '
        $4 == "setup" {
            $10 = "0000000000000000000000000000000000000000000000000000000000000000"
        }
        { print }
    ' "$receipts" > "$receipts.new"
    mv "$receipts.new" "$receipts"
    chmod 644 "$receipts"
}

expect_rejected missing-artifact BC02_RUNTIME_LAYOUT_INVALID remove_artifact
expect_rejected extra-layout-path BC02_RUNTIME_LAYOUT_INVALID add_layout_path
expect_rejected action-receipt-tamper BC02_RUNTIME_ACTION_RECEIPT_INVALID \
    tamper_action
expect_rejected receipt-set-seal-tamper BC02_RAW_SEAL_INVALID \
    tamper_receipt_set_seal
expect_rejected oracle-forgery BC02_RUNTIME_ORACLE_RECEIPT_INVALID forge_oracle
expect_rejected raw-tamper-resealed BC02_RUNTIME_SEMANTIC_ARTIFACT_INVALID \
    tamper_raw_and_reseal
expect_rejected command-argv-tamper BC02_COMMAND_CUSTODY_INVALID \
    tamper_command_argv
expect_rejected command-stdout-tamper BC02_COMMAND_CUSTODY_INVALID \
    tamper_command_stdout
expect_rejected command-stderr-tamper BC02_COMMAND_CUSTODY_INVALID \
    tamper_command_stderr

expect_fault_rejected()
{
    name=$1
    source=$2
    run=$3
    namespace=$4
    assertion=$5
    case_id=$6
    expected=$7
    directory="$tmp/$name"
    shift 7
    cp -R "$source" "$directory"
    "$@" "$directory"
    set +e
    output=$(
        "$verifier" "$directory" "$run" "$namespace" \
            "$assertion" "$case_id" 2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC02_FAULT_CONTROL_ACCEPTED: $name" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        printf '%s\n' "$output" >&2
        echo "BC02_FAULT_CONTROL_VERDICT_INVALID: $name" >&2
        exit 1
    }
}

fault_partial="$tmp/bc02-partial-residue--after-root-header"
fault_partial_run=run-bc02-partial-residue--after-root-header
fault_partial_ns=ns-bc02-partial-residue--after-root-header
fault_poisoned="$tmp/bc02-poisoned-retry--after-root-header"
fault_poisoned_run=run-bc02-poisoned-retry--after-root-header
fault_poisoned_ns=ns-bc02-poisoned-retry--after-root-header

fault_activation_replay()
{
    file="$1/fault-activation-receipts.tsv"
    sed -i 's/fault-nonce/replayed-nonce/' "$file"
}

fault_trigger_identity()
{
    file="$1/fault-trigger-receipts.tsv"
    sed -i 's/error-bc02-after-root-header/error-bc02-after-root-member/' "$file"
}

fault_command_status()
{
    file="$1/command-receipts.tsv"
    awk -F '	' -v OFS='	' '$4 == "fault" { $7=0 } { print }' \
        "$file" > "$file.new"
    mv "$file.new" "$file"
    chmod 644 "$file"
}

fault_command_stdout_digest()
{
    file="$1/command-receipts.tsv"
    awk -F '	' -v OFS='	' '
        $4 == "fault" {
            $8="0000000000000000000000000000000000000000000000000000000000000000"
        }
        { print }
    ' "$file" > "$file.new"
    mv "$file.new" "$file"
    chmod 644 "$file"
}

fault_command_stderr_digest()
{
    file="$1/command-receipts.tsv"
    awk -F '	' -v OFS='	' '
        $4 == "fault" {
            $10="0000000000000000000000000000000000000000000000000000000000000000"
        }
        { print }
    ' "$file" > "$file.new"
    mv "$file.new" "$file"
    chmod 644 "$file"
}

fault_forged_observer()
{
    file="$1/observer-custody-receipts.tsv"
    sed -i 's/observer-connection-01/observer-connection-forged/' "$file"
}

fault_inventory_drift()
{
    file="$1/inventory-rollback-after.tsv"
    sed -i 's/value-a/value-drift/' "$file"
}

fault_retry_hook()
{
    file="$1/command-receipts.tsv"
    awk -F '	' -v OFS='	' '
        $4 == "retry" { $6="fault-injected" }
        { print }
    ' "$file" > "$file.new"
    mv "$file.new" "$file"
    chmod 644 "$file"
}

fault_retry_commit_forgery()
{
    directory=$1
    file="$directory/data-version-receipts.tsv"
    after=$(awk -F '	' '$6 == "fault-after" { print $8 }' "$file")
    awk -F '	' -v OFS='	' -v after="$after" '
        $6 == "retry-commit" { $8=after }
        { print }
    ' "$file" > "$file.new"
    mv "$file.new" "$file"
    chmod 644 "$file"

    awk -F '	' '$6 == "retry-commit"' "$file" \
        > "$directory/retry-commit.stdout"
    stdout_sha=$(sha256sum "$directory/retry-commit.stdout" |
        awk '{ print $1 }')
    stdout_bytes=$(wc -c < "$directory/retry-commit.stdout" | tr -d ' ')
    commands="$directory/command-receipts.tsv"
    awk -F '	' -v OFS='	' -v sha="$stdout_sha" \
        -v bytes="$stdout_bytes" '
        $4 == "retry-commit" { $8=sha; $9=bytes }
        { print }
    ' "$commands" > "$commands.new"
    mv "$commands.new" "$commands"
    chmod 644 "$commands"
    rm "$directory/retry-commit.stdout"
}

fault_binding_forgery()
{
    file="$1/evidence-binding-receipts.tsv"
    awk -F '	' -v OFS='	' '
        {
            $8="0000000000000000000000000000000000000000000000000000000000000000"
            print
        }
    ' "$file" > "$file.new"
    mv "$file.new" "$file"
    chmod 644 "$file"
}

fault_raw_digest_forgery()
{
    directory=$1
    raw="$directory/raw-observations.tsv"
    seal="$directory/raw-seal.tsv"
    awk -F '	' -v OFS='	' '
        $2 == "raw-trigger-07" {
            $6="0000000000000000000000000000000000000000000000000000000000000000/0000000000000000000000000000000000000000000000000000000000000000/0000000000000000000000000000000000000000000000000000000000000000/0000000000000000000000000000000000000000000000000000000000000000"
        }
        { print }
    ' "$raw" > "$raw.new"
    mv "$raw.new" "$raw"
    raw_sha=$(sha256sum "$raw" | awk '{ print $1 }')
    raw_bytes=$(wc -c < "$raw" | tr -d ' ')
    awk -F '	' -v OFS='	' -v sha="$raw_sha" -v bytes="$raw_bytes" '
        { $3=sha; $4=bytes; print }
    ' "$seal" > "$seal.new"
    mv "$seal.new" "$seal"
    chmod 644 "$raw" "$seal"
}

fault_gate_revision_forgery()
{
    file="$1/gate-results.tsv"
    awk -F '	' -v OFS='	' '
        {
            $9="0000000000000000000000000000000000000000000000000000000000000000"
            print
        }
    ' "$file" > "$file.new"
    mv "$file.new" "$file"
    chmod 644 "$file"
}

fault_pragma_forgery()
{
    file="$1/pragma.tsv"
    awk -F '	' -v OFS='	' '
        NR == 1 { $5="foreign-keys-forged"; $6=0 }
        { print }
    ' "$file" > "$file.new"
    mv "$file.new" "$file"
    chmod 644 "$file"
}

expect_fault_rejected fault-activation-replay "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_ACTIVATION_INVALID \
    fault_activation_replay
expect_fault_rejected fault-trigger-identity "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_TRIGGER_INVALID \
    fault_trigger_identity
expect_fault_rejected fault-command-status "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_COMMAND_CUSTODY_INVALID \
    fault_command_status
expect_fault_rejected fault-command-stdout "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_COMMAND_CUSTODY_INVALID \
    fault_command_stdout_digest
expect_fault_rejected fault-command-stderr "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_COMMAND_CUSTODY_INVALID \
    fault_command_stderr_digest
expect_fault_rejected fault-forged-observer "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_OBSERVER_CUSTODY_INVALID \
    fault_forged_observer
expect_fault_rejected fault-inventory-drift "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_RUNTIME_INVENTORY_INVALID \
    fault_inventory_drift
expect_fault_rejected fault-retry-hook "$fault_poisoned" \
    "$fault_poisoned_run" "$fault_poisoned_ns" BC02_POISONED_RETRY \
    case-bc02-after-root-header BC02_FAULT_COMMAND_CUSTODY_INVALID \
    fault_retry_hook
expect_fault_rejected fault-retry-commit "$fault_poisoned" \
    "$fault_poisoned_run" "$fault_poisoned_ns" BC02_POISONED_RETRY \
    case-bc02-after-root-header BC02_FAULT_DATA_VERSION_INVALID \
    fault_retry_commit_forgery
expect_fault_rejected fault-binding-forgery "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_EVIDENCE_BINDING_INVALID \
    fault_binding_forgery
expect_fault_rejected fault-raw-reseal "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_RAW_INVALID \
    fault_raw_digest_forgery
expect_fault_rejected fault-gate-revision "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_GATE_RESULT_INVALID \
    fault_gate_revision_forgery
expect_fault_rejected fault-pragma "$fault_partial" \
    "$fault_partial_run" "$fault_partial_ns" BC02_PARTIAL_RESIDUE \
    case-bc02-after-root-header BC02_FAULT_PRAGMA_INVALID \
    fault_pragma_forgery

revision_environment="$tmp/revision-drift-environment"
cp -R "$script_dir/.." "$revision_environment"
printf '%s\n' '# self-test implementation revision drift' \
    >> "$revision_environment/sqlite-reference/sut-bc02.sh"
set +e
revision_output=$(
    "$revision_environment/runner/verify-bc02-runtime.sh" \
        "$fault_partial" "$fault_partial_run" "$fault_partial_ns" \
        BC02_PARTIAL_RESIDUE case-bc02-after-root-header 2>&1
)
revision_status=$?
set -e
[ "$revision_status" -ne 0 ] || {
    echo BC02_FAULT_IMPLEMENTATION_DRIFT_ACCEPTED >&2
    exit 1
}
[ "$revision_output" = "BC02_FAULT_IMPLEMENTATION_REVISION_INVALID" ] || {
    printf '%s\n' "$revision_output" >&2
    echo BC02_FAULT_IMPLEMENTATION_DRIFT_CONTROL_INVALID >&2
    exit 1
}

set +e
mutant_output=$(
    "$runner" "$tmp/mutant-complete-unavailable" \
        run-bc02-mutant-complete-unavailable \
        ns-bc02-mutant-complete-unavailable \
        BC02_COMPLETE_AVAILABLE case-bc02-complete \
        mutant-complete-unavailable 2>&1
)
mutant_status=$?
set -e

[ "$mutant_status" -ne 0 ] || {
    echo BC02_COMPLETE_UNAVAILABLE_MUTANT_ACCEPTED >&2
    exit 1
}
[ "$mutant_output" = "BC02_ORACLE_MISMATCH" ] || {
    printf '%s\n' "$mutant_output" >&2
    echo BC02_COMPLETE_UNAVAILABLE_CONTROL_INVALID >&2
    exit 1
}

set +e
substitution_output=$(
    "$runner" "$tmp/mutant-count-only-completeness" \
        run-bc02-mutant-count-only-completeness \
        ns-bc02-mutant-count-only-completeness \
        BC02_INCOMPLETE_AS_COMPLETE \
        case-bc02-incomplete-substitution \
        mutant-count-only-completeness 2>&1
)
substitution_status=$?
set -e

[ "$substitution_status" -ne 0 ] || {
    echo BC02_COUNT_ONLY_COMPLETENESS_MUTANT_ACCEPTED >&2
    exit 1
}
[ "$substitution_output" = "BC02_ORACLE_MISMATCH" ] || {
    [ "$substitution_output" = "" ] ||
        printf '%s\n' "$substitution_output" >&2
    echo BC02_SUBSTITUTION_MUTANT_MISSING >&2
    exit 1
}

for correction_mutant in \
    mutant-correction-cleans-root \
    mutant-correction-forbidden-write
do
    set +e
    correction_output=$(
        "$runner" "$tmp/$correction_mutant" \
            "run-bc02-$correction_mutant" \
            "ns-bc02-$correction_mutant" \
            BC02_HEALTHY_RETRY case-bc02-incomplete-corrected \
            "$correction_mutant" 2>&1
    )
    correction_status=$?
    set -e
    [ "$correction_status" -ne 0 ] || {
        echo "BC02_CORRECTION_MUTANT_ACCEPTED: $correction_mutant" >&2
        exit 1
    }
    [ "$correction_output" = "BC02_CORRECTION_WRITESET_INVALID" ] || {
        [ "$correction_output" = "" ] ||
            printf '%s\n' "$correction_output" >&2
        echo "BC02_CORRECTION_CONTROL_INVALID: $correction_mutant" >&2
        exit 1
    }
done

echo "10 BC02 runtime baselines"
echo "27 BC02 runtime controls detected"
