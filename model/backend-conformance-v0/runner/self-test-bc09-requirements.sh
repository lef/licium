#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc09-requirements.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC09_REQUIREMENTS_VALID ] || {
    echo BC09_REQUIREMENTS_BASELINE_INVALID >&2
    exit 1
}

run_control()
{
    id=$1
    expected=$2
    work="$tmp/$id"
    cp -R "$model_dir" "$work"

    case "$id" in
        case-drop)
            sed '1d' "$work/backend-conformance-v0/bc09-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" "$work/backend-conformance-v0/bc09-cases.tsv"
            ;;
        case-disposition)
            sed '1s/	duplicate	/	rejected	/' \
                "$work/backend-conformance-v0/bc09-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" "$work/backend-conformance-v0/bc09-cases.tsv"
            ;;
        scenario-rewire)
            sed '1s/case-bc09-diagnostic/case-bc09-forged/' \
                "$work/backend-conformance-v0/bc09-scenario-ids.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-scenario-ids.tsv"
            ;;
        step-order)
            sed 's/^050	/045	/' \
                "$work/backend-conformance-v0/bc09-steps.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" "$work/backend-conformance-v0/bc09-steps.tsv"
            ;;
        fault-step-recovery)
            sed '/healthy-action/d' \
                "$work/backend-conformance-v0/bc09-fault-steps.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-fault-steps.tsv"
            ;;
        fault-case-hook)
            sed '1s/hook-bc09-accepted-write/hook-bc09-rejection-stale/' \
                "$work/backend-conformance-v0/bc09-fault-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-fault-cases.tsv"
            ;;
        action-receipt-delivery)
            sed 's/{delivery}/{forged-delivery}/' \
                "$work/backend-conformance-v0/bc09-action-receipt-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-action-receipt-template.tsv"
            ;;
        command-receipt-argv)
            sed 's/{argv-sha256}/{forged-argv-sha256}/' \
                "$work/backend-conformance-v0/bc09-command-receipt-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-command-receipt-template.tsv"
            ;;
        raw-relation)
            sed '1s/	diagnostic	/	forged	/' \
                "$work/backend-conformance-v0/bc09-raw-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-raw-template.tsv"
            ;;
        normalized-placeholder)
            sed '1s/{diagnostic-disposition}/{forged-disposition}/' \
                "$work/backend-conformance-v0/bc09-normalized-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-normalized-template.tsv"
            ;;
        coverage-drop)
            sed '1d' "$work/backend-conformance-v0/bc09-coverage-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-coverage-template.tsv"
            ;;
        inventory-after-drift)
            sed '1s/rev-1/rev-forged/' \
                "$work/backend-conformance-v0/bc09-inventory-after.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-inventory-after.tsv"
            ;;
        inventory-stale-accepted)
            sed '/^case-stale	effect-request/s/rev-0/rev-1/' \
                "$work/backend-conformance-v0/bc09-inventory-before.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-inventory-before.tsv"
            cp "$work/backend-conformance-v0/bc09-inventory-before.tsv" \
                "$work/backend-conformance-v0/bc09-inventory-after.tsv"
            cp "$work/backend-conformance-v0/bc09-inventory-before.tsv" \
                "$work/backend-conformance-v0/bc09-inventory-reopened.tsv"
            cp "$work/backend-conformance-v0/bc09-inventory-before.tsv" \
                "$work/backend-conformance-v0/bc09-fault-inventory-setup.tsv"
            cp "$work/backend-conformance-v0/bc09-inventory-before.tsv" \
                "$work/backend-conformance-v0/bc09-fault-inventory-rollback.tsv"
            ;;
        fault-rollback-drift)
            sed '1s/rev-1/rev-forged/' \
                "$work/backend-conformance-v0/bc09-fault-inventory-rollback.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-fault-inventory-rollback.tsv"
            ;;
        fault-healthy-incomplete)
            sed '1d' "$work/backend-conformance-v0/bc09-fault-inventory-healthy.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-fault-inventory-healthy.tsv"
            ;;
        fault-reopened-drift)
            sed '1s/rev-2/rev-forged/' \
                "$work/backend-conformance-v0/bc09-fault-inventory-reopened.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-fault-inventory-reopened.tsv"
            ;;
        fault-activation-case)
            sed '1s/case-fault/case-forged/' \
                "$work/backend-conformance-v0/bc09-fault-activation-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-fault-activation-template.tsv"
            ;;
        fault-configuration-phase)
            sed '1s/accepted-write/rejection-stale/' \
                "$work/backend-conformance-v0/bc09-fault-configuration-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-fault-configuration-template.tsv"
            ;;
        fault-trigger-untriggered)
            sed '1s/	true	1	/	false	1	/' \
                "$work/backend-conformance-v0/bc09-fault-trigger-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-fault-trigger-template.tsv"
            ;;
        fault-marker-phase)
            sed '1s/accepted-write/rejection-stale/' \
                "$work/backend-conformance-v0/bc09-fault-marker-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-fault-marker-template.tsv"
            ;;
        mutant-marker)
            sed 's/BC09_STALE_ARTIFACT_DETECTED/BC09_FORGED_MARKER/' \
                "$work/backend-conformance-v0/bc09-mutants.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-mutants.tsv"
            ;;
        artifact-cardinality)
            sed 's/fault-trigger-receipts.tsv	21	5	/fault-trigger-receipts.tsv	21	4	/' \
                "$work/backend-conformance-v0/bc09-runtime-artifacts.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-runtime-artifacts.tsv"
            ;;
        raw-seal-stage)
            sed 's/sealed-before-normalization/sealed-after-normalization/' \
                "$work/backend-conformance-v0/bc09-raw-seal-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc09-raw-seal-template.tsv"
            ;;
        document-claim)
            sed 's/83 - 56 = 27/83 - 56 = 0/' \
                "$work/BC09-SQLITE-SLICE.md" >"$work/mutant.tmp"
            mv "$work/mutant.tmp" "$work/BC09-SQLITE-SLICE.md"
            ;;
        requirement-mode)
            chmod 755 "$work/backend-conformance-v0/bc09-cases.tsv"
            ;;
        requirement-symlink)
            mv "$work/backend-conformance-v0/bc09-cases.tsv" \
                "$work/backend-conformance-v0/bc09-cases-target.tsv"
            ln -s bc09-cases-target.tsv \
                "$work/backend-conformance-v0/bc09-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc09-requirements.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC09 requirements control unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "BC09 requirements control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control case-drop BC09_CASE_REGISTRY_INVALID
run_control case-disposition BC09_CASE_REGISTRY_INVALID
run_control scenario-rewire BC09_SCENARIO_ID_REGISTRY_INVALID
run_control step-order BC09_STEP_REGISTRY_INVALID
run_control fault-step-recovery BC09_FAULT_STEP_REGISTRY_INVALID
run_control fault-case-hook BC09_FAULT_CASE_REGISTRY_INVALID
run_control action-receipt-delivery BC09_ACTION_RECEIPT_CONTRACT_INVALID
run_control command-receipt-argv BC09_COMMAND_RECEIPT_CONTRACT_INVALID
run_control raw-relation BC09_RAW_CONTRACT_INVALID
run_control normalized-placeholder BC09_NORMALIZED_CONTRACT_INVALID
run_control coverage-drop BC09_COVERAGE_CONTRACT_INVALID
run_control inventory-after-drift BC09_INVENTORY_CONTRACT_INVALID
run_control inventory-stale-accepted BC09_INVENTORY_CONTRACT_INVALID
run_control fault-rollback-drift BC09_FAULT_INVENTORY_CONTRACT_INVALID
run_control fault-healthy-incomplete BC09_FAULT_INVENTORY_CONTRACT_INVALID
run_control fault-reopened-drift BC09_FAULT_INVENTORY_CONTRACT_INVALID
run_control fault-activation-case BC09_FAULT_ACTIVATION_CONTRACT_INVALID
run_control fault-configuration-phase BC09_FAULT_CONFIGURATION_CONTRACT_INVALID
run_control fault-trigger-untriggered BC09_FAULT_TRIGGER_CONTRACT_INVALID
run_control fault-marker-phase BC09_FAULT_MARKER_CONTRACT_INVALID
run_control mutant-marker BC09_MUTANT_REGISTRY_INVALID
run_control artifact-cardinality BC09_RUNTIME_ARTIFACT_REGISTRY_INVALID
run_control raw-seal-stage BC09_RAW_SEAL_CONTRACT_INVALID
run_control document-claim BC09_DOCUMENT_INVALID
run_control requirement-mode BC09_REQUIREMENT_MODE_INVALID
run_control requirement-symlink BC09_REQUIREMENT_MISSING

echo "26 BC09 requirements mutations detected"
