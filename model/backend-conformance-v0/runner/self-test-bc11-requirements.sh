#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc11-requirements.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC11_REQUIREMENTS_VALID ] || {
    echo BC11_REQUIREMENTS_BASELINE_INVALID >&2
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
            sed '1d' "$work/backend-conformance-v0/bc11-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-cases.tsv"
            ;;
        case-operation)
            sed '1s/sut-explain-result/sut-forged/' \
                "$work/backend-conformance-v0/bc11-cases.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-cases.tsv"
            ;;
        scenario-rewire)
            sed '1s/case-bc11-explanation-closure/case-bc11-forged/' \
                "$work/backend-conformance-v0/bc11-scenario-ids.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-scenario-ids.tsv"
            ;;
        step-order)
            sed 's/^040	/025	/' \
                "$work/backend-conformance-v0/bc11-steps.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-steps.tsv"
            ;;
        action-receipt)
            sed 's/{surface}/{forged-surface}/' \
                "$work/backend-conformance-v0/bc11-action-receipt-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-action-receipt-template.tsv"
            ;;
        command-receipt)
            sed 's/{argv-sha256}/{forged-argv-sha256}/' \
                "$work/backend-conformance-v0/bc11-command-receipt-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-command-receipt-template.tsv"
            ;;
        raw-drop)
            sed '1d' "$work/backend-conformance-v0/bc11-raw-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-raw-template.tsv"
            ;;
        normalized-without-raw-coverage)
            awk -F '	' -v OFS='	' '
                !changed && $4 == "omission-binding" &&
                    $5 == "definition" && $6 == "available" {
                    $6 = "unavailable"
                    changed = 1
                }
                { print }
                END { if (!changed) exit 1 }
            ' "$work/backend-conformance-v0/bc11-normalized-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-normalized-template.tsv"
            ;;
        missing-role-collapse)
            for file in bc11-raw-template.tsv bc11-normalized-template.tsv
            do
                awk -F '	' -v OFS='	' '
                    !changed && $4 == "omission-binding" &&
                        $5 == "definition" && $6 == "available" {
                        $6 = "unavailable"
                        changed = 1
                    }
                    { print }
                    END { if (!changed) exit 1 }
                ' "$work/backend-conformance-v0/$file" >"$work/mutant.tmp"
                mv "$work/mutant.tmp" \
                    "$work/backend-conformance-v0/$file"
            done
            ;;
        silent-inventory-rewrite)
            for file in bc11-raw-template.tsv bc11-normalized-template.tsv
            do
                awk -F '	' -v OFS='	' '
                    $1 ~ /-silent-cross-link--/ &&
                        $3 == "inventory" && $4 == "after" &&
                        $5 == "source-record-digest" {
                        $6 = "digest-cross-link-forged"
                        changed = 1
                    }
                    { print }
                    END { if (!changed) exit 1 }
                ' "$work/backend-conformance-v0/$file" >"$work/mutant.tmp"
                mv "$work/mutant.tmp" \
                    "$work/backend-conformance-v0/$file"
            done
            ;;
        coverage-rewire)
            sed 's/obs-001/obs-007/' \
                "$work/backend-conformance-v0/bc11-coverage-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-coverage-template.tsv"
            ;;
        oracle-case-drop)
            sed '1d' "$work/backend-conformance-v0/bc11-oracle-contract.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-oracle-contract.tsv"
            ;;
        mutant-row-drop)
            sed '1d' "$work/backend-conformance-v0/bc11-mutants.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-mutants.tsv"
            ;;
        artifact-cardinality)
            sed 's/command-receipts.tsv	12	6/command-receipts.tsv	12	5/' \
                "$work/backend-conformance-v0/bc11-runtime-artifacts.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-runtime-artifacts.tsv"
            ;;
        raw-seal-stage)
            sed 's/sealed-before-normalization/sealed-after-normalization/' \
                "$work/backend-conformance-v0/bc11-raw-seal-template.tsv" \
                >"$work/mutant.tmp"
            mv "$work/mutant.tmp" \
                "$work/backend-conformance-v0/bc11-raw-seal-template.tsv"
            ;;
        requirement-mode)
            chmod 755 "$work/backend-conformance-v0/bc11-cases.tsv"
            ;;
        requirement-symlink)
            mv "$work/backend-conformance-v0/bc11-cases.tsv" \
                "$work/backend-conformance-v0/bc11-cases-target.tsv"
            ln -s bc11-cases-target.tsv \
                "$work/backend-conformance-v0/bc11-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc11-requirements.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC11 requirements control unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "BC11 requirements control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control case-drop BC11_CASE_REGISTRY_INVALID
run_control case-operation BC11_CASE_REGISTRY_INVALID
run_control scenario-rewire BC11_SCENARIO_ID_REGISTRY_INVALID
run_control step-order BC11_STEP_REGISTRY_INVALID
run_control action-receipt BC11_ACTION_RECEIPT_CONTRACT_INVALID
run_control command-receipt BC11_COMMAND_RECEIPT_CONTRACT_INVALID
run_control raw-drop BC11_RAW_CONTRACT_INVALID
run_control normalized-without-raw-coverage BC11_COVERAGE_CONTRACT_INVALID
run_control missing-role-collapse BC11_NORMALIZED_CONTRACT_INVALID
run_control silent-inventory-rewrite BC11_NORMALIZED_CONTRACT_INVALID
run_control coverage-rewire BC11_COVERAGE_CONTRACT_INVALID
run_control oracle-case-drop BC11_ORACLE_CONTRACT_INVALID
run_control mutant-row-drop BC11_MUTANT_REGISTRY_INVALID
run_control artifact-cardinality BC11_RUNTIME_ARTIFACT_REGISTRY_INVALID
run_control raw-seal-stage BC11_RAW_SEAL_CONTRACT_INVALID
run_control requirement-mode BC11_REQUIREMENT_MODE_INVALID
run_control requirement-symlink BC11_REQUIREMENT_MISSING

echo "17 BC11 requirements mutations detected"
