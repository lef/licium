#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
model_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
verifier="$script_dir/verify-sqlite-partial-requirements.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ "$("$verifier")" = SQLITE_PARTIAL_REQUIREMENTS_VALID ] || {
    echo SQLITE_PARTIAL_REQUIREMENTS_BASELINE_INVALID >&2
    exit 1
}

run_control()
{
    id=$1
    expected=$2
    work="$tmp/$id"
    cp -R "$model_dir" "$work"

    case "$id" in
        scenario-drop)
            awk 'NR != 1' \
                "$work/backend-conformance-v0/sqlite-partial-scenarios.tsv" \
                > "$work/scenarios.tmp"
            mv "$work/scenarios.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-scenarios.tsv"
            ;;
        negative-rewire)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "neg-bc02-healthy-retry" {
                    $6 = "bc02-complete-available--case-bc02-complete"
                }
                { print }
            ' "$work/backend-conformance-v0/sqlite-partial-bc02-negative-execution.tsv" \
                > "$work/negative.tmp"
            mv "$work/negative.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-bc02-negative-execution.tsv"
            ;;
        receipt-shape)
            awk -F '	' 'BEGIN { OFS = "\t" }
                NR == 1 { print $1,$2,$3,$4,$5,$6,$7; next }
                { print }
            ' "$work/backend-conformance-v0/sqlite-partial-bc02-negative-receipt-template.tsv" \
                > "$work/receipt.tmp"
            mv "$work/receipt.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-bc02-negative-receipt-template.tsv"
            ;;
        bc02-raw-comparison)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $1 == "BC02" && $3 == "coverage.tsv" {
                    $3 = "raw-observations.tsv"
                }
                { print }
            ' "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc01-canonical-drop)
            awk -F '	' '$1 != "BC01" || $3 != "inventory-reopened.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc03-canonical-drop)
            awk -F '	' '$1 != "BC03" || $3 != "inventory-reopened.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc04-canonical-drop)
            awk -F '	' '$1 != "BC04" || $3 != "inventory-reopened.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc05-canonical-drop)
            awk -F '	' '$1 != "BC05" || $3 != "inventory-reopened.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc07-canonical-drop)
            awk -F '	' '$1 != "BC07" || $3 != "inventory-reopened.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc08-canonical-drop)
            awk -F '	' '$1 != "BC08" || $3 != "fault-trigger-receipts.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc09-canonical-drop)
            awk -F '	' '$1 != "BC09" || $3 != "fault-trigger-receipts.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc10-canonical-drop)
            awk -F '	' '$1 != "BC10" || $3 != "raw-observations.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc11-canonical-drop)
            awk -F '	' '$1 != "BC11" || $3 != "raw-observations.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        bc12-canonical-drop)
            awk -F '	' '$1 != "BC12" || $3 != "raw-observations.tsv"' \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                > "$work/canonical.tmp"
            mv "$work/canonical.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        run-layout)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $4 == "runtime-status.tsv" { $5 = "rows=14" }
                { print }
            ' "$work/backend-conformance-v0/sqlite-partial-run-artifacts.tsv" \
                > "$work/run-layout.tmp"
            mv "$work/run-layout.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-run-artifacts.tsv"
            ;;
        session-layout)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $4 == "aggregate-dispositions.tsv" { $5 = "rows=165" }
                { print }
            ' "$work/backend-conformance-v0/sqlite-partial-session-artifacts.tsv" \
                > "$work/session-layout.tmp"
            mv "$work/session-layout.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-artifacts.tsv"
            ;;
        outer-cardinality)
            awk -F '	' 'BEGIN { OFS = "\t" }
                $4 == "outer-receipt.tsv" { $5 = "rows=1" }
                { print }
            ' "$work/backend-conformance-v0/sqlite-partial-run-artifacts.tsv" \
                > "$work/run-layout.tmp"
            mv "$work/run-layout.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-run-artifacts.tsv"
            ;;
        mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc02-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc01-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc01-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc03-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc03-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc04-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc04-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc05-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc05-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc07-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc07-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc08-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc08-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc09-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc09-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc10-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc10-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc11-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc11-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        bc12-mutant-drop)
            awk '$1 != "harness-sqlite-partial-bc12-drift"' \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv" \
                > "$work/mutants.tmp"
            mv "$work/mutants.tmp" \
                "$work/backend-conformance-v0/sqlite-partial-session-mutants.tsv"
            ;;
        document-claim)
            sed 's/FULL_GATE_NONPASS/FULL_GATE_PASS/' \
                "$work/SQLITE-PARTIAL-SESSION.md" > "$work/document.tmp"
            mv "$work/document.tmp" "$work/SQLITE-PARTIAL-SESSION.md"
            ;;
        requirement-mode)
            chmod 755 \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        requirement-symlink)
            mv "$work/backend-conformance-v0/sqlite-partial-canonical.tsv" \
                "$work/backend-conformance-v0/canonical-target.tsv"
            ln -s canonical-target.tsv \
                "$work/backend-conformance-v0/sqlite-partial-canonical.tsv"
            ;;
        *)
            echo "unknown control: $id" >&2
            exit 1
            ;;
    esac

    set +e
    output=$(
        "$work/backend-conformance-v0/runner/verify-sqlite-partial-requirements.sh" \
            2>&1
    )
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo "requirements control unexpectedly passed: $id" >&2
        exit 1
    }
    actual=$(printf '%s\n' "$output" | tail -n 1)
    [ "$actual" = "$expected" ] || {
        echo "requirements control returned $actual, expected $expected: $id" >&2
        exit 1
    }
    printf '%s\n' "$id"
}

run_control scenario-drop SQLITE_PARTIAL_SCENARIO_REGISTRY_INVALID
run_control negative-rewire SQLITE_PARTIAL_NEGATIVE_REGISTRY_INVALID
run_control receipt-shape SQLITE_PARTIAL_NEGATIVE_RECEIPT_TEMPLATE_INVALID
run_control bc02-raw-comparison SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc01-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc03-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc04-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc05-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc07-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc08-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc09-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc10-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc11-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control bc12-canonical-drop SQLITE_PARTIAL_CANONICAL_ALLOWLIST_INVALID
run_control run-layout SQLITE_PARTIAL_RUN_LAYOUT_INVALID
run_control session-layout SQLITE_PARTIAL_SESSION_LAYOUT_INVALID
run_control outer-cardinality SQLITE_PARTIAL_RUN_LAYOUT_INVALID
run_control mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc01-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc03-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc04-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc05-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc07-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc08-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc09-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc10-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc11-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control bc12-mutant-drop SQLITE_PARTIAL_SESSION_MUTANT_INVALID
run_control document-claim SQLITE_PARTIAL_DOCUMENT_INVALID
run_control requirement-mode SQLITE_PARTIAL_REQUIREMENT_MODE_INVALID
run_control requirement-symlink SQLITE_PARTIAL_REQUIREMENT_MISSING

echo "31 SQLite partial requirements mutations detected"
