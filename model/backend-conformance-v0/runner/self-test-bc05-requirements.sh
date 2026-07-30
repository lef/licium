#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-bc05-requirements.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = BC05_REQUIREMENTS_VALID ] || {
    echo BC05_REQUIREMENTS_BASELINE_INVALID >&2
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
            awk 'NR != 1' "$work/backend-conformance-v0/bc05-cases.tsv" \
                >"$work/cases.tmp"
            mv "$work/cases.tmp" \
                "$work/backend-conformance-v0/bc05-cases.tsv"
            ;;
        scenario-rewire)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $3 = "bc05-forged-scenario" }
                { print }
            ' "$work/backend-conformance-v0/bc05-scenario-ids.tsv" \
                >"$work/scenario.tmp"
            mv "$work/scenario.tmp" \
                "$work/backend-conformance-v0/bc05-scenario-ids.tsv"
            ;;
        step-order)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "040" { $1 = "035" }
                { print }
            ' "$work/backend-conformance-v0/bc05-steps.tsv" \
                >"$work/steps.tmp"
            mv "$work/steps.tmp" \
                "$work/backend-conformance-v0/bc05-steps.tsv"
            ;;
        mutant-marker)
            sed 's/BC05_KNOWLEDGE_CUT_DRIFT_DETECTED/BC05_FORGED_MARKER/' \
                "$work/backend-conformance-v0/bc05-mutants.tsv" \
                >"$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/bc05-mutants.tsv"
            ;;
        artifact-cardinality)
            sed 's/action-receipts.tsv	13	2	/action-receipts.tsv	13	1	/' \
                "$work/backend-conformance-v0/bc05-runtime-artifacts.tsv" \
                >"$work/artifacts.tmp"
            mv "$work/artifacts.tmp" \
                "$work/backend-conformance-v0/bc05-runtime-artifacts.tsv"
            ;;
        raw-duplicate)
            first_raw=$(
                sed -n '1p' \
                    "$work/backend-conformance-v0/bc05-raw-template.tsv"
            )
            printf '%s\n' "$first_raw" \
                >>"$work/backend-conformance-v0/bc05-raw-template.tsv"
            ;;
        normalized-cut-drift)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 ~ /pinned-knowledge-cut/ &&
                    $3 == "pinned-result" {
                        $6 = "department:security"
                    }
                { print }
            ' "$work/backend-conformance-v0/bc05-normalized-contract.tsv" \
                >"$work/normalized.tmp"
            mv "$work/normalized.tmp" \
                "$work/backend-conformance-v0/bc05-normalized-contract.tsv"
            ;;
        coverage-drop)
            awk 'NR != 1' \
                "$work/backend-conformance-v0/bc05-coverage-template.tsv" \
                >"$work/coverage.tmp"
            mv "$work/coverage.tmp" \
                "$work/backend-conformance-v0/bc05-coverage-template.tsv"
            ;;
        inventory-derived-view)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { $2 = "published-view" }
                { print }
            ' "$work/backend-conformance-v0/bc05-inventory-before.tsv" \
                >"$work/inventory.tmp"
            mv "$work/inventory.tmp" \
                "$work/backend-conformance-v0/bc05-inventory-before.tsv"
            ;;
        reopened-drift)
            sed '0,/cut-b/s//cut-forged/' \
                "$work/backend-conformance-v0/bc05-inventory-reopened.tsv" \
                >"$work/reopened.tmp"
            mv "$work/reopened.tmp" \
                "$work/backend-conformance-v0/bc05-inventory-reopened.tsv"
            ;;
        document-claim)
            sed 's/83 - 36 = 47/83 - 36 = 0/' \
                "$work/BC05-SQLITE-SLICE.md" >"$work/document.tmp"
            mv "$work/document.tmp" "$work/BC05-SQLITE-SLICE.md"
            ;;
        requirement-mode)
            chmod 755 "$work/backend-conformance-v0/bc05-cases.tsv"
            ;;
        requirement-symlink)
            mv "$work/backend-conformance-v0/bc05-cases.tsv" \
                "$work/backend-conformance-v0/bc05-cases-target.tsv"
            ln -s bc05-cases-target.tsv \
                "$work/backend-conformance-v0/bc05-cases.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-bc05-requirements.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "BC05 requirements control unexpectedly passed: $id" >&2
        exit 1
    }
    [ "$output" = "$expected" ] || {
        echo "BC05 requirements control returned $output, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control case-drop BC05_CASE_REGISTRY_INVALID
run_control scenario-rewire BC05_SCENARIO_ID_REGISTRY_INVALID
run_control step-order BC05_STEP_REGISTRY_INVALID
run_control mutant-marker BC05_MUTANT_REGISTRY_INVALID
run_control artifact-cardinality BC05_RUNTIME_ARTIFACT_REGISTRY_INVALID
run_control raw-duplicate BC05_RAW_CONTRACT_INVALID
run_control normalized-cut-drift BC05_NORMALIZED_CONTRACT_INVALID
run_control coverage-drop BC05_COVERAGE_CONTRACT_INVALID
run_control inventory-derived-view BC05_INVENTORY_CONTRACT_INVALID
run_control reopened-drift BC05_INVENTORY_CONTRACT_INVALID
run_control document-claim BC05_DOCUMENT_INVALID
run_control requirement-mode BC05_REQUIREMENT_MODE_INVALID
run_control requirement-symlink BC05_REQUIREMENT_MISSING

echo "13 BC05 requirements mutations detected"
