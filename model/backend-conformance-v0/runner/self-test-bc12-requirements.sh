#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc12-requirements.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC12_REQUIREMENTS_VALID ] || {
    echo BC12_REQUIREMENTS_BASELINE_INVALID >&2
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
            sed '1d' "$work/backend-conformance-v0/bc12-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-cases.tsv"
            ;;
        protection-subcase-collapse)
            awk -F '	' 'BEGIN { OFS=FS }
                $1 == "BC12_PROTECTION_BYPASS" { $8=1; changed=1 }
                { print }
                END { if (!changed) exit 1 }
            ' \
                "$work/backend-conformance-v0/bc12-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-cases.tsv"
            ;;
        protection-subcase-rewire)
            sed '/^conflict	/s/mutant-detect-protection-bypass-conflict/mutant-detect-protection-bypass-witness/' \
                "$work/backend-conformance-v0/bc12-protection-subcases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-protection-subcases.tsv"
            ;;
        protection-subcase-forget-forgery)
            sed '/^witness	/s/forget-audit/forget-forged/' \
                "$work/backend-conformance-v0/bc12-protection-subcases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-protection-subcases.tsv"
            ;;
        scenario-rewire)
            sed '1s/case-bc12-archive-bypass/case-bc12-forged/' \
                "$work/backend-conformance-v0/bc12-scenario-ids.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-scenario-ids.tsv"
            ;;
        step-order)
            sed 's/^040	/025	/' \
                "$work/backend-conformance-v0/bc12-steps.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-steps.tsv"
            ;;
        action-receipt)
            sed 's/{root-set-1}/{forged-root-set}/' \
                "$work/backend-conformance-v0/bc12-action-receipt-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-action-receipt-template.tsv"
            ;;
        command-receipt)
            sed 's/{argv-sha256}/{forged-argv-sha256}/' \
                "$work/backend-conformance-v0/bc12-command-receipt-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-command-receipt-template.tsv"
            ;;
        raw-drop)
            sed '1d' "$work/backend-conformance-v0/bc12-raw-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-raw-template.tsv"
            ;;
        normalized-without-raw-coverage)
            sed '1s/complete/forged/' \
                "$work/backend-conformance-v0/bc12-normalized-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-normalized-template.tsv"
            ;;
        protection-source-collapse)
            for file in bc12-raw-template.tsv bc12-normalized-template.tsv
            do
                sed 's/conflict:conflict-1/witness:conflict-1/' \
                    "$work/backend-conformance-v0/$file" >"$work/mutant.tmp"
                mv "$work/mutant.tmp" \
                    "$work/backend-conformance-v0/$file"
            done
            ;;
        window-bypass)
            for file in bc12-raw-template.tsv bc12-normalized-template.tsv
            do
                sed '/-window-bypass--.*	decision	r-forgotten	before	/s/retain:policy-window/release-eligible:-/' \
                    "$work/backend-conformance-v0/$file" >"$work/mutant.tmp"
                mv "$work/mutant.tmp" \
                    "$work/backend-conformance-v0/$file"
            done
            ;;
        canonical-rewrite)
            for file in bc12-raw-template.tsv bc12-normalized-template.tsv
            do
                sed '/-canonical-unchanged--.*	inventory	after	canonical-digest/s/digest-canonical-1/digest-canonical-forged/' \
                    "$work/backend-conformance-v0/$file" >"$work/mutant.tmp"
                mv "$work/mutant.tmp" \
                    "$work/backend-conformance-v0/$file"
            done
            ;;
        coverage-rewire)
            sed '1s/obs-001/obs-006/' \
                "$work/backend-conformance-v0/bc12-coverage-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-coverage-template.tsv"
            ;;
        oracle-case-drop)
            sed '1d' "$work/backend-conformance-v0/bc12-oracle-contract.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-oracle-contract.tsv"
            ;;
        mutant-row-drop)
            sed '1d' "$work/backend-conformance-v0/bc12-mutants.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-mutants.tsv"
            ;;
        artifact-cardinality)
            sed 's/command-receipts.tsv	12	6/command-receipts.tsv	12	5/' \
                "$work/backend-conformance-v0/bc12-runtime-artifacts.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-runtime-artifacts.tsv"
            ;;
        raw-seal-stage)
            sed 's/sealed-before-normalization/sealed-after-normalization/' \
                "$work/backend-conformance-v0/bc12-raw-seal-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc12-raw-seal-template.tsv"
            ;;
        requirement-mode)
            chmod 755 "$work/backend-conformance-v0/bc12-cases.tsv"
            ;;
        requirement-symlink)
            mv "$work/backend-conformance-v0/bc12-cases.tsv" \
                "$work/backend-conformance-v0/bc12-cases-target.tsv"
            ln -s bc12-cases-target.tsv \
                "$work/backend-conformance-v0/bc12-cases.tsv"
            ;;
        *) exit 2 ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc12-requirements.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] && [ "$output" = "$expected" ] || {
        echo "BC12 requirements control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control case-drop BC12_CASE_REGISTRY_INVALID
run_control protection-subcase-collapse BC12_CASE_REGISTRY_INVALID
run_control protection-subcase-rewire BC12_PROTECTION_SUBCASE_REGISTRY_INVALID
run_control protection-subcase-forget-forgery BC12_PROTECTION_SUBCASE_REGISTRY_INVALID
run_control scenario-rewire BC12_SCENARIO_ID_REGISTRY_INVALID
run_control step-order BC12_STEP_REGISTRY_INVALID
run_control action-receipt BC12_ACTION_RECEIPT_CONTRACT_INVALID
run_control command-receipt BC12_COMMAND_RECEIPT_CONTRACT_INVALID
run_control raw-drop BC12_COVERAGE_CONTRACT_INVALID
run_control normalized-without-raw-coverage BC12_COVERAGE_CONTRACT_INVALID
run_control protection-source-collapse BC12_NORMALIZED_CONTRACT_INVALID
run_control window-bypass BC12_NORMALIZED_CONTRACT_INVALID
run_control canonical-rewrite BC12_NORMALIZED_CONTRACT_INVALID
run_control coverage-rewire BC12_COVERAGE_CONTRACT_INVALID
run_control oracle-case-drop BC12_ORACLE_CONTRACT_INVALID
run_control mutant-row-drop BC12_MUTANT_REGISTRY_INVALID
run_control artifact-cardinality BC12_RUNTIME_ARTIFACT_REGISTRY_INVALID
run_control raw-seal-stage BC12_RAW_SEAL_CONTRACT_INVALID
run_control requirement-mode BC12_REQUIREMENT_MODE_INVALID
run_control requirement-symlink BC12_REQUIREMENT_MISSING

echo "20 BC12 requirements mutations detected"
