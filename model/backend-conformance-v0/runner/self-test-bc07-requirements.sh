#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc07-requirements.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC07_REQUIREMENTS_VALID ] || {
    echo BC07_REQUIREMENTS_BASELINE_INVALID >&2
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
            sed '1d' "$work/backend-conformance-v0/bc07-cases.tsv" \
                >"$work/cases.tmp"
            mv "$work/cases.tmp" "$work/backend-conformance-v0/bc07-cases.tsv"
            ;;
        scenario-rewire)
            sed '1s/case-bc07-effect/case-bc07-forged/' \
                "$work/backend-conformance-v0/bc07-scenario-ids.tsv" \
                >"$work/scenario.tmp"
            mv "$work/scenario.tmp" \
                "$work/backend-conformance-v0/bc07-scenario-ids.tsv"
            ;;
        step-order)
            sed 's/^040	/035	/' \
                "$work/backend-conformance-v0/bc07-steps.tsv" \
                >"$work/steps.tmp"
            mv "$work/steps.tmp" "$work/backend-conformance-v0/bc07-steps.tsv"
            ;;
        mutant-marker)
            sed 's/BC07_RESULT_REWRITE_DETECTED/BC07_FORGED_MARKER/' \
                "$work/backend-conformance-v0/bc07-mutants.tsv" \
                >"$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/bc07-mutants.tsv"
            ;;
        artifact-cardinality)
            sed 's/raw-observations.tsv	6	8	/raw-observations.tsv	6	7	/' \
                "$work/backend-conformance-v0/bc07-runtime-artifacts.tsv" \
                >"$work/artifacts.tmp"
            mv "$work/artifacts.tmp" \
                "$work/backend-conformance-v0/bc07-runtime-artifacts.tsv"
            ;;
        action-receipt-axis)
            sed 's/{axis-vector}/{forged-vector}/' \
                "$work/backend-conformance-v0/bc07-action-receipt-template.tsv" \
                >"$work/receipt.tmp"
            mv "$work/receipt.tmp" \
                "$work/backend-conformance-v0/bc07-action-receipt-template.tsv"
            ;;
        raw-duplicate)
            sed -n '1p' "$work/backend-conformance-v0/bc07-raw-template.tsv" \
                >>"$work/backend-conformance-v0/bc07-raw-template.tsv"
            ;;
        normalized-axis)
            sed '0,/axis-vector	101/s//axis-vector	010/' \
                "$work/backend-conformance-v0/bc07-normalized-contract.tsv" \
                >"$work/normalized.tmp"
            mv "$work/normalized.tmp" \
                "$work/backend-conformance-v0/bc07-normalized-contract.tsv"
            ;;
        coverage-drop)
            sed '1d' "$work/backend-conformance-v0/bc07-coverage-template.tsv" \
                >"$work/coverage.tmp"
            mv "$work/coverage.tmp" \
                "$work/backend-conformance-v0/bc07-coverage-template.tsv"
            ;;
        inventory-result-rewrite)
            sed '0,/digest-rewrite/s//digest-forged/' \
                "$work/backend-conformance-v0/bc07-inventory-after.tsv" \
                >"$work/inventory.tmp"
            mv "$work/inventory.tmp" \
                "$work/backend-conformance-v0/bc07-inventory-after.tsv"
            cp "$work/backend-conformance-v0/bc07-inventory-after.tsv" \
                "$work/backend-conformance-v0/bc07-inventory-reopened.tsv"
            ;;
        reopened-drift)
            sed '0,/state-1/s//state-forged/' \
                "$work/backend-conformance-v0/bc07-inventory-reopened.tsv" \
                >"$work/reopened.tmp"
            mv "$work/reopened.tmp" \
                "$work/backend-conformance-v0/bc07-inventory-reopened.tsv"
            ;;
        raw-seal-stage)
            sed 's/sealed-before-normalization/sealed-after-normalization/' \
                "$work/backend-conformance-v0/bc07-raw-seal-template.tsv" \
                >"$work/seal.tmp"
            mv "$work/seal.tmp" \
                "$work/backend-conformance-v0/bc07-raw-seal-template.tsv"
            ;;
        document-claim)
            sed 's/83 - 42 = 41/83 - 42 = 0/' \
                "$work/BC07-SQLITE-SLICE.md" >"$work/document.tmp"
            mv "$work/document.tmp" "$work/BC07-SQLITE-SLICE.md"
            ;;
        requirement-mode)
            chmod 755 "$work/backend-conformance-v0/bc07-cases.tsv"
            ;;
        requirement-symlink)
            mv "$work/backend-conformance-v0/bc07-cases.tsv" \
                "$work/backend-conformance-v0/bc07-cases-target.tsv"
            ln -s bc07-cases-target.tsv \
                "$work/backend-conformance-v0/bc07-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc07-requirements.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC07 requirements control unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "BC07 requirements control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control case-drop BC07_CASE_REGISTRY_INVALID
run_control scenario-rewire BC07_SCENARIO_ID_REGISTRY_INVALID
run_control step-order BC07_STEP_REGISTRY_INVALID
run_control mutant-marker BC07_MUTANT_REGISTRY_INVALID
run_control artifact-cardinality BC07_RUNTIME_ARTIFACT_REGISTRY_INVALID
run_control action-receipt-axis BC07_ACTION_RECEIPT_CONTRACT_INVALID
run_control raw-duplicate BC07_RAW_CONTRACT_INVALID
run_control normalized-axis BC07_NORMALIZED_CONTRACT_INVALID
run_control coverage-drop BC07_COVERAGE_CONTRACT_INVALID
run_control inventory-result-rewrite BC07_INVENTORY_CONTRACT_INVALID
run_control reopened-drift BC07_INVENTORY_CONTRACT_INVALID
run_control raw-seal-stage BC07_RAW_SEAL_CONTRACT_INVALID
run_control document-claim BC07_DOCUMENT_INVALID
run_control requirement-mode BC07_REQUIREMENT_MODE_INVALID
run_control requirement-symlink BC07_REQUIREMENT_MISSING

echo "15 BC07 requirements mutations detected"
