#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc04-requirements.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC04_REQUIREMENTS_VALID ] || {
    echo BC04_REQUIREMENTS_BASELINE_INVALID >&2
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
            awk 'NR != 1' "$work/backend-conformance-v0/bc04-cases.tsv" \
                >"$work/cases.tmp"
            mv "$work/cases.tmp" \
                "$work/backend-conformance-v0/bc04-cases.tsv"
            ;;
        scenario-rewire)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $3 = "bc04-forged-scenario" }
                { print }
            ' "$work/backend-conformance-v0/bc04-scenario-ids.tsv" \
                >"$work/scenario.tmp"
            mv "$work/scenario.tmp" \
                "$work/backend-conformance-v0/bc04-scenario-ids.tsv"
            ;;
        step-order)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "040" { $1 = "035" }
                { print }
            ' "$work/backend-conformance-v0/bc04-steps.tsv" \
                >"$work/steps.tmp"
            mv "$work/steps.tmp" \
                "$work/backend-conformance-v0/bc04-steps.tsv"
            ;;
        mutant-marker)
            sed 's/BC04_EXACT_READ_SUBSTITUTED/BC04_FORGED_MARKER/' \
                "$work/backend-conformance-v0/bc04-mutants.tsv" \
                >"$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/bc04-mutants.tsv"
            ;;
        artifact-cardinality)
            sed 's/action-receipts.tsv	13	2	/action-receipts.tsv	13	1	/' \
                "$work/backend-conformance-v0/bc04-runtime-artifacts.tsv" \
                >"$work/artifacts.tmp"
            mv "$work/artifacts.tmp" \
                "$work/backend-conformance-v0/bc04-runtime-artifacts.tsv"
            ;;
        raw-duplicate)
            sed -n '1p' "$work/backend-conformance-v0/bc04-raw-template.tsv" \
                >>"$work/backend-conformance-v0/bc04-raw-template.tsv"
            ;;
        normalized-leak)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 ~ /unaccepted-available/ &&
                    $3 == "published-secret-leaks" { $6 = "1" }
                { print }
            ' "$work/backend-conformance-v0/bc04-normalized-contract.tsv" \
                >"$work/normalized.tmp"
            mv "$work/normalized.tmp" \
                "$work/backend-conformance-v0/bc04-normalized-contract.tsv"
            ;;
        coverage-drop)
            awk 'NR != 1' \
                "$work/backend-conformance-v0/bc04-coverage-template.tsv" \
                >"$work/coverage.tmp"
            mv "$work/coverage.tmp" \
                "$work/backend-conformance-v0/bc04-coverage-template.tsv"
            ;;
        inventory-derived-view)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $2 = "published-view" }
                { print }
            ' "$work/backend-conformance-v0/bc04-inventory-before.tsv" \
                >"$work/inventory.tmp"
            mv "$work/inventory.tmp" \
                "$work/backend-conformance-v0/bc04-inventory-before.tsv"
            ;;
        reopened-drift)
            sed 's/must-not-leak-unaccepted/forged-value/' \
                "$work/backend-conformance-v0/bc04-inventory-reopened.tsv" \
                >"$work/reopened.tmp"
            mv "$work/reopened.tmp" \
                "$work/backend-conformance-v0/bc04-inventory-reopened.tsv"
            ;;
        document-claim)
            sed 's/83／83 full conformanceを主張しない/83／83 full conformanceを主張する/' \
                "$work/BC04-SQLITE-SLICE.md" >"$work/document.tmp"
            mv "$work/document.tmp" "$work/BC04-SQLITE-SLICE.md"
            ;;
        requirement-mode)
            chmod 755 "$work/backend-conformance-v0/bc04-cases.tsv"
            ;;
        requirement-symlink)
            mv "$work/backend-conformance-v0/bc04-cases.tsv" \
                "$work/backend-conformance-v0/bc04-cases-target.tsv"
            ln -s bc04-cases-target.tsv \
                "$work/backend-conformance-v0/bc04-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc04-requirements.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC04 requirements control unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "BC04 requirements control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control case-drop BC04_CASE_REGISTRY_INVALID
run_control scenario-rewire BC04_SCENARIO_ID_REGISTRY_INVALID
run_control step-order BC04_STEP_REGISTRY_INVALID
run_control mutant-marker BC04_MUTANT_REGISTRY_INVALID
run_control artifact-cardinality BC04_RUNTIME_ARTIFACT_REGISTRY_INVALID
run_control raw-duplicate BC04_RAW_CONTRACT_INVALID
run_control normalized-leak BC04_NORMALIZED_CONTRACT_INVALID
run_control coverage-drop BC04_COVERAGE_CONTRACT_INVALID
run_control inventory-derived-view BC04_INVENTORY_CONTRACT_INVALID
run_control reopened-drift BC04_INVENTORY_CONTRACT_INVALID
run_control document-claim BC04_DOCUMENT_INVALID
run_control requirement-mode BC04_REQUIREMENT_MODE_INVALID
run_control requirement-symlink BC04_REQUIREMENT_MISSING

echo "13 BC04 requirements mutations detected"
