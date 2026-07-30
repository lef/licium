#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc08-requirements.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC08_REQUIREMENTS_VALID ] || {
    echo BC08_REQUIREMENTS_BASELINE_INVALID >&2
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
            sed '1d' "$work/backend-conformance-v0/bc08-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" "$work/backend-conformance-v0/bc08-cases.tsv"
            ;;
        scenario-rewire)
            sed '1s/case-bc08-complete/case-bc08-forged/' \
                "$work/backend-conformance-v0/bc08-scenario-ids.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-scenario-ids.tsv"
            ;;
        step-order)
            sed 's/^050	/045	/' \
                "$work/backend-conformance-v0/bc08-steps.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" "$work/backend-conformance-v0/bc08-steps.tsv"
            ;;
        fault-step-recovery)
            sed '/healthy-action/d' \
                "$work/backend-conformance-v0/bc08-fault-steps.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-fault-steps.tsv"
            ;;
        fault-case-hook)
            sed '1s/hook-bc08-after-observation/hook-bc08-after-transition/' \
                "$work/backend-conformance-v0/bc08-fault-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-fault-cases.tsv"
            ;;
        fault-activation-case)
            sed '1s/case-bc08-after-observation/case-bc08-forged/' \
                "$work/backend-conformance-v0/bc08-fault-activation-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-fault-activation-template.tsv"
            ;;
        fault-configuration-phase)
            sed '1s/after-observation/after-transition/' \
                "$work/backend-conformance-v0/bc08-fault-configuration-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-fault-configuration-template.tsv"
            ;;
        fault-trigger-untriggered)
            sed '1s/	true	1	/	false	1	/' \
                "$work/backend-conformance-v0/bc08-fault-trigger-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-fault-trigger-template.tsv"
            ;;
        fault-marker-phase)
            sed '1s/after-observation/after-transition/' \
                "$work/backend-conformance-v0/bc08-fault-marker-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-fault-marker-template.tsv"
            ;;
        mutant-marker)
            sed 's/BC08_MISSING_VIEW_DETECTED/BC08_FORGED_MARKER/' \
                "$work/backend-conformance-v0/bc08-mutants.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-mutants.tsv"
            ;;
        artifact-cardinality)
            sed 's/raw-observations.tsv	6	12	/raw-observations.tsv	6	11	/' \
                "$work/backend-conformance-v0/bc08-runtime-artifacts.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-runtime-artifacts.tsv"
            ;;
        action-receipt-delivery)
            sed 's/{delivery}/{forged-delivery}/' \
                "$work/backend-conformance-v0/bc08-action-receipt-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-action-receipt-template.tsv"
            ;;
        raw-duplicate)
            sed -n '1p' "$work/backend-conformance-v0/bc08-raw-template.tsv" \
                >>"$work/backend-conformance-v0/bc08-raw-template.tsv"
            ;;
        normalized-retry)
            sed '0,/no-duplicate/s//duplicate/' \
                "$work/backend-conformance-v0/bc08-normalized-contract.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-normalized-contract.tsv"
            ;;
        normalized-hook-count)
            sed '0,/triggered-hooks	5/s//triggered-hooks	4/' \
                "$work/backend-conformance-v0/bc08-normalized-contract.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-normalized-contract.tsv"
            ;;
        coverage-drop)
            sed '1d' "$work/backend-conformance-v0/bc08-coverage-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-coverage-template.tsv"
            ;;
        inventory-result-rewrite)
            sed '0,/digest-result-1/s//digest-forged/' \
                "$work/backend-conformance-v0/bc08-inventory-after.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-inventory-after.tsv"
            cp "$work/backend-conformance-v0/bc08-inventory-after.tsv" \
                "$work/backend-conformance-v0/bc08-inventory-reopened.tsv"
            ;;
        reopened-drift)
            sed '1s/rev-2/rev-forged/' \
                "$work/backend-conformance-v0/bc08-inventory-reopened.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-inventory-reopened.tsv"
            ;;
        fault-rollback-drift)
            sed '1s/rev-1/rev-forged/' \
                "$work/backend-conformance-v0/bc08-fault-inventory-rollback.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-fault-inventory-rollback.tsv"
            ;;
        fault-reopened-drift)
            sed '1s/rev-2/rev-forged/' \
                "$work/backend-conformance-v0/bc08-fault-inventory-reopened.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-fault-inventory-reopened.tsv"
            ;;
        raw-seal-stage)
            sed 's/sealed-before-normalization/sealed-after-normalization/' \
                "$work/backend-conformance-v0/bc08-raw-seal-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc08-raw-seal-template.tsv"
            ;;
        document-claim)
            sed 's/83 - 49 = 34/83 - 49 = 0/' \
                "$work/BC08-SQLITE-SLICE.md" >"$work/mutant.tmp"
            mv "$work/mutant.tmp" "$work/BC08-SQLITE-SLICE.md"
            ;;
        requirement-mode)
            chmod 755 "$work/backend-conformance-v0/bc08-cases.tsv"
            ;;
        requirement-symlink)
            mv "$work/backend-conformance-v0/bc08-cases.tsv" \
                "$work/backend-conformance-v0/bc08-cases-target.tsv"
            ln -s bc08-cases-target.tsv \
                "$work/backend-conformance-v0/bc08-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc08-requirements.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC08 requirements control unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "BC08 requirements control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control case-drop BC08_CASE_REGISTRY_INVALID
run_control scenario-rewire BC08_SCENARIO_ID_REGISTRY_INVALID
run_control step-order BC08_STEP_REGISTRY_INVALID
run_control fault-step-recovery BC08_FAULT_STEP_REGISTRY_INVALID
run_control fault-case-hook BC08_FAULT_CASE_REGISTRY_INVALID
run_control fault-activation-case BC08_FAULT_ACTIVATION_CONTRACT_INVALID
run_control fault-configuration-phase BC08_FAULT_CONFIGURATION_CONTRACT_INVALID
run_control fault-trigger-untriggered BC08_FAULT_TRIGGER_CONTRACT_INVALID
run_control fault-marker-phase BC08_FAULT_MARKER_CONTRACT_INVALID
run_control mutant-marker BC08_MUTANT_REGISTRY_INVALID
run_control artifact-cardinality BC08_RUNTIME_ARTIFACT_REGISTRY_INVALID
run_control action-receipt-delivery BC08_ACTION_RECEIPT_CONTRACT_INVALID
run_control raw-duplicate BC08_RAW_CONTRACT_INVALID
run_control normalized-retry BC08_NORMALIZED_CONTRACT_INVALID
run_control normalized-hook-count BC08_NORMALIZED_CONTRACT_INVALID
run_control coverage-drop BC08_COVERAGE_CONTRACT_INVALID
run_control inventory-result-rewrite BC08_INVENTORY_CONTRACT_INVALID
run_control reopened-drift BC08_INVENTORY_CONTRACT_INVALID
run_control fault-rollback-drift BC08_FAULT_INVENTORY_CONTRACT_INVALID
run_control fault-reopened-drift BC08_FAULT_INVENTORY_CONTRACT_INVALID
run_control raw-seal-stage BC08_RAW_SEAL_CONTRACT_INVALID
run_control document-claim BC08_DOCUMENT_INVALID
run_control requirement-mode BC08_REQUIREMENT_MODE_INVALID
run_control requirement-symlink BC08_REQUIREMENT_MISSING

echo "24 BC08 requirements mutations detected"
