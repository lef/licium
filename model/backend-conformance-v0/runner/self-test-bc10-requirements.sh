#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc10-requirements.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC10_REQUIREMENTS_VALID ] || {
    echo BC10_REQUIREMENTS_BASELINE_INVALID >&2
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
            sed '1d' "$work/backend-conformance-v0/bc10-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-cases.tsv"
            ;;
        case-operation)
            sed '1s/sut-explain-result/sut-forged/' \
                "$work/backend-conformance-v0/bc10-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-cases.tsv"
            ;;
        scenario-rewire)
            sed '1s/case-bc10-explanation-closed/case-bc10-forged/' \
                "$work/backend-conformance-v0/bc10-scenario-ids.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-scenario-ids.tsv"
            ;;
        step-order)
            sed 's/^040	/025	/' \
                "$work/backend-conformance-v0/bc10-steps.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-steps.tsv"
            ;;
        action-receipt)
            sed 's/{surface}/{forged-surface}/' \
                "$work/backend-conformance-v0/bc10-action-receipt-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-action-receipt-template.tsv"
            ;;
        command-receipt)
            sed 's/{argv-sha256}/{forged-argv-sha256}/' \
                "$work/backend-conformance-v0/bc10-command-receipt-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-command-receipt-template.tsv"
            ;;
        raw-drop)
            sed '1d' "$work/backend-conformance-v0/bc10-raw-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-raw-template.tsv"
            ;;
        normalized-leak)
            sed '1,/	secret-count	0$/s/	secret-count	0$/	secret-count	1/' \
                "$work/backend-conformance-v0/bc10-normalized-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-normalized-template.tsv"
            ;;
        coverage-rewire)
            sed '1s/obs-001/obs-007/' \
                "$work/backend-conformance-v0/bc10-coverage-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-coverage-template.tsv"
            ;;
        oracle-view-drop)
            sed '/neg-bc10-view-leak-provenance/d' \
                "$work/backend-conformance-v0/bc10-oracle-contract.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-oracle-contract.tsv"
            ;;
        mutant-view-dual)
            sed '/neg-bc10-view-leak-secret/d' \
                "$work/backend-conformance-v0/bc10-mutants.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-mutants.tsv"
            ;;
        artifact-cardinality)
            sed 's/command-receipts.tsv	12	6	/command-receipts.tsv	12	5	/' \
                "$work/backend-conformance-v0/bc10-runtime-artifacts.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-runtime-artifacts.tsv"
            ;;
        raw-seal-stage)
            sed 's/sealed-before-normalization/sealed-after-normalization/' \
                "$work/backend-conformance-v0/bc10-raw-seal-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc10-raw-seal-template.tsv"
            ;;
        document-claim)
            sed 's/83 - 64 = 19/83 - 64 = 0/' \
                "$work/BC10-SQLITE-SLICE.md" >"$work/mutant.tmp"
            mv "$work/mutant.tmp" "$work/BC10-SQLITE-SLICE.md"
            ;;
        requirement-mode)
            chmod 755 "$work/backend-conformance-v0/bc10-cases.tsv"
            ;;
        requirement-symlink)
            mv "$work/backend-conformance-v0/bc10-cases.tsv" \
                "$work/backend-conformance-v0/bc10-cases-target.tsv"
            ln -s bc10-cases-target.tsv \
                "$work/backend-conformance-v0/bc10-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc10-requirements.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC10 requirements control unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "BC10 requirements control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control case-drop BC10_CASE_REGISTRY_INVALID
run_control case-operation BC10_CASE_REGISTRY_INVALID
run_control scenario-rewire BC10_SCENARIO_ID_REGISTRY_INVALID
run_control step-order BC10_STEP_REGISTRY_INVALID
run_control action-receipt BC10_ACTION_RECEIPT_CONTRACT_INVALID
run_control command-receipt BC10_COMMAND_RECEIPT_CONTRACT_INVALID
run_control raw-drop BC10_RAW_CONTRACT_INVALID
run_control normalized-leak BC10_COVERAGE_CONTRACT_INVALID
run_control coverage-rewire BC10_COVERAGE_CONTRACT_INVALID
run_control oracle-view-drop BC10_ORACLE_CONTRACT_INVALID
run_control mutant-view-dual BC10_MUTANT_REGISTRY_INVALID
run_control artifact-cardinality BC10_RUNTIME_ARTIFACT_REGISTRY_INVALID
run_control raw-seal-stage BC10_RAW_SEAL_CONTRACT_INVALID
run_control document-claim BC10_DOCUMENT_INVALID
run_control requirement-mode BC10_REQUIREMENT_MODE_INVALID
run_control requirement-symlink BC10_REQUIREMENT_MISSING

echo "16 BC10 requirements mutations detected"
