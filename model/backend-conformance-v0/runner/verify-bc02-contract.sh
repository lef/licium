#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
    echo "$1" >&2
    exit 1
}

require_fields() {
    file=$1
    fields=$2
    marker=$3
    awk -F '	' -v fields="$fields" '
        NF != fields { exit 1 }
        END { if (NR == 0) exit 1 }
    ' "$file" || fail "$marker"
}

digest_manifest="$base_dir/bc02-contract-digests.tsv"
[ -f "$digest_manifest" ] || fail BC02_CONTRACT_DIGEST_MANIFEST_MISSING
[ "$(sha256sum "$digest_manifest" | awk '{ print $1 }')" = \
    "472bfc11179df3288dd5574c992f354de4f3e51a689baa5d57ef1c90a5353227" ] ||
    fail BC02_CONTRACT_DIGEST_MANIFEST_INVALID
require_fields "$digest_manifest" 3 BC02_CONTRACT_DIGEST_MANIFEST_INVALID

for file in "$base_dir"/bc02-*.tsv "$base_dir"/step-registry-levels.tsv; do
    [ "$(basename "$file")" = "bc02-contract-digests.tsv" ] && continue
    basename "$file"
done | sort > "$tmp/actual-contract-files"
cut -f1 "$digest_manifest" | sort > "$tmp/declared-contract-files"
cmp -s "$tmp/actual-contract-files" "$tmp/declared-contract-files" ||
    fail BC02_CONTRACT_FILE_SET_INVALID

while IFS='	' read -r name mode expected; do
    case "$name" in
        */*|.*|'') fail BC02_CONTRACT_DIGEST_ENTRY_INVALID ;;
    esac
    [ "$mode" = "100644" ] || fail BC02_CONTRACT_DIGEST_ENTRY_INVALID
    file="$base_dir/$name"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC02_REQUIRED_CONTRACT_MISSING
    [ "$(stat -c '%a' "$file")" = "644" ] ||
        fail BC02_CONTRACT_FILE_MODE_INVALID
    [ "$(sha256sum "$file" | awk '{ print $1 }')" = "$expected" ] ||
        fail BC02_CONTRACT_FILE_DIGEST_INVALID
done < "$digest_manifest"

require_fields "$base_dir/bc02-cases.tsv" 11 BC02_CASE_CONTRACT_INVALID
require_fields "$base_dir/bc02-steps.tsv" 7 BC02_STEP_CONTRACT_INVALID
require_fields "$base_dir/bc02-inventory-map.tsv" 6 BC02_INVENTORY_MAP_INVALID
require_fields "$base_dir/bc02-normalized-contract.tsv" 6 BC02_NORMALIZED_CONTRACT_INVALID
require_fields "$base_dir/bc02-mutants.tsv" 5 BC02_MUTANT_CONTRACT_INVALID
require_fields "$base_dir/bc02-mutant-applicability.tsv" 3 BC02_MUTANT_APPLICABILITY_INVALID
require_fields "$base_dir/bc02-artifact-cardinality.tsv" 5 BC02_ARTIFACT_CARDINALITY_INVALID
require_fields "$base_dir/bc02-tsv-schemas.tsv" 4 BC02_SCHEMA_REGISTRY_INVALID
require_fields "$base_dir/bc02-mandatory-gate-sets.tsv" 6 BC02_MANDATORY_GATE_SET_INVALID
require_fields "$base_dir/bc02-scenario-gates.tsv" 2 BC02_SCENARIO_GATE_MAP_INVALID
require_fields "$base_dir/bc02-gate-results-template.tsv" 9 BC02_GATE_RESULT_CONTRACT_INVALID

while IFS='	' read -r name fields columns constraints; do
    case "$name" in
        *'*'*)
            found=0
            for file in "$base_dir"/$name; do
                [ -f "$file" ] || continue
                found=1
                require_fields "$file" "$fields" BC02_SCHEMA_FIELD_COUNT_INVALID
            done
            [ "$found" = 1 ] || fail BC02_SCHEMA_TARGET_MISSING
            ;;
        *)
            file="$base_dir/$name"
            [ -f "$file" ] && [ ! -L "$file" ] ||
                fail BC02_REQUIRED_CONTRACT_MISSING
            require_fields "$file" "$fields" BC02_SCHEMA_FIELD_COUNT_INVALID
            ;;
    esac
    [ "$(printf '%s\n' "$columns" | awk -F ',' '{ print NF }')" = "$fields" ] ||
        fail BC02_SCHEMA_COLUMN_COUNT_INVALID
done < "$base_dir/bc02-tsv-schemas.tsv"

awk -F '	' '
    function scenario(assertion, case_id, value) {
        value = tolower(assertion)
        gsub(/_/, "-", value)
        return value "--" case_id
    }
    BEGIN {
        expected["BC02_COMPLETE_AVAILABLE" SUBSEP "case-bc02-complete"] = ("positive" SUBSEP "complete" SUBSEP "sut-form-root" SUBSEP "-" SUBSEP "-" SUBSEP "-" SUBSEP "complete" SUBSEP "complete" SUBSEP "PASS")
        expected["BC02_HEALTHY_RETRY" SUBSEP "case-bc02-incomplete-corrected"] = ("positive" SUBSEP "incomplete-missing" SUBSEP "sut-form-root" SUBSEP "-" SUBSEP "sut-correct-root-input" SUBSEP "sut-retry-root" SUBSEP "root-unavailable" SUBSEP "complete" SUBSEP "PASS")
        expected["BC02_INCOMPLETE_AS_COMPLETE" SUBSEP "case-bc02-incomplete-missing"] = ("control" SUBSEP "incomplete-missing" SUBSEP "sut-form-root" SUBSEP "-" SUBSEP "-" SUBSEP "-" SUBSEP "root-unavailable" SUBSEP "root-unavailable" SUBSEP "PASS")
        expected["BC02_INCOMPLETE_AS_COMPLETE" SUBSEP "case-bc02-incomplete-substitution"] = ("control" SUBSEP "incomplete-substitution" SUBSEP "sut-form-root" SUBSEP "-" SUBSEP "-" SUBSEP "-" SUBSEP "root-unavailable" SUBSEP "root-unavailable" SUBSEP "PASS")
        expected["BC02_PARTIAL_RESIDUE" SUBSEP "case-bc02-after-root-header"] = ("control" SUBSEP "complete" SUBSEP "sut-form-root" SUBSEP "hook-bc02-after-root-header" SUBSEP "-" SUBSEP "-" SUBSEP "fault-rollback" SUBSEP "rollback-clean" SUBSEP "PASS")
        expected["BC02_PARTIAL_RESIDUE" SUBSEP "case-bc02-after-root-member"] = ("control" SUBSEP "complete" SUBSEP "sut-form-root" SUBSEP "hook-bc02-after-root-member" SUBSEP "-" SUBSEP "-" SUBSEP "fault-rollback" SUBSEP "rollback-clean" SUBSEP "PASS")
        expected["BC02_POISONED_RETRY" SUBSEP "case-bc02-after-root-header"] = ("control" SUBSEP "complete" SUBSEP "sut-form-root" SUBSEP "hook-bc02-after-root-header" SUBSEP "-" SUBSEP "sut-retry-root" SUBSEP "fault-rollback" SUBSEP "complete" SUBSEP "PASS")
        expected["BC02_POISONED_RETRY" SUBSEP "case-bc02-after-root-member"] = ("control" SUBSEP "complete" SUBSEP "sut-form-root" SUBSEP "hook-bc02-after-root-member" SUBSEP "-" SUBSEP "sut-retry-root" SUBSEP "fault-rollback" SUBSEP "complete" SUBSEP "PASS")
        expected["BC02_ROLLBACK_COMPLETE" SUBSEP "case-bc02-after-root-header"] = ("positive" SUBSEP "complete" SUBSEP "sut-form-root" SUBSEP "hook-bc02-after-root-header" SUBSEP "-" SUBSEP "-" SUBSEP "fault-rollback" SUBSEP "rollback-clean" SUBSEP "PASS")
        expected["BC02_ROLLBACK_COMPLETE" SUBSEP "case-bc02-after-root-member"] = ("positive" SUBSEP "complete" SUBSEP "sut-form-root" SUBSEP "hook-bc02-after-root-member" SUBSEP "-" SUBSEP "-" SUBSEP "fault-rollback" SUBSEP "rollback-clean" SUBSEP "PASS")
    }
    {
        key = $1 SUBSEP $2
        value = $3 SUBSEP $4 SUBSEP $5 SUBSEP $6 SUBSEP $7 SUBSEP $8 SUBSEP $9 SUBSEP $10 SUBSEP $11
        if (!(key in expected) || value != expected[key] || seen[key]++) exit 1
        print scenario($1, $2)
        count++
    }
    END {
        if (count != 10) exit 1
        for (key in expected) if (seen[key] != 1) exit 1
    }
' "$base_dir/bc02-cases.tsv" > "$tmp/scenarios.unsorted" ||
    fail BC02_CASE_CONTRACT_INVALID
sort "$tmp/scenarios.unsorted" > "$tmp/scenarios"

[ "$(wc -l < "$tmp/scenarios" | tr -d ' ')" = 10 ] ||
    fail BC02_CASE_CONTRACT_INVALID

awk -F '	' '
    BEGIN {
        expected["sut-setup-bc02"] = "sut" SUBSEP "prepare-root-state"
        expected["sut-form-root"] = "sut" SUBSEP "form-complete-root"
        expected["sut-retry-root"] = "sut" SUBSEP "retry-root-formation"
        expected["sut-correct-root-input"] = "sut" SUBSEP "add-missing-root-source-input"
    }
    $1 in expected {
        if (($2 SUBSEP $3) != expected[$1] || seen[$1]++) exit 1
    }
    END {
        for (id in expected) if (seen[id] != 1) exit 1
    }
' "$base_dir/operation-registry.tsv" || fail BC02_OPERATION_REGISTRY_INVALID

awk -F '	' '
    BEGIN {
        expected["hook-bc02-after-root-header"] = "BC02" SUBSEP "after-root-header" SUBSEP "sut-form-root"
        expected["hook-bc02-after-root-member"] = "BC02" SUBSEP "after-root-member" SUBSEP "sut-form-root"
    }
    $2 == "BC02" {
        if (!($1 in expected) ||
            ($2 SUBSEP $3 SUBSEP $4) != expected[$1] ||
            seen[$1]++) exit 1
        count++
    }
    END {
        if (count != 2) exit 1
        for (id in expected) if (seen[id] != 1) exit 1
    }
' "$base_dir/fault-hooks.tsv" || fail BC02_FAULT_REGISTRY_INVALID

awk -F '	' '
    $1 == "set-bc02-root-boundaries" {
        if ($2 != "hook-bc02-after-root-header" &&
            $2 != "hook-bc02-after-root-member") exit 1
        if ($3 != "all" || seen[$2]++) exit 1
        count++
    }
    END {
        if (count != 2 ||
            seen["hook-bc02-after-root-header"] != 1 ||
            seen["hook-bc02-after-root-member"] != 1) exit 1
    }
' "$base_dir/fault-hook-sets.tsv" || fail BC02_FAULT_SET_REGISTRY_INVALID

awk -F '	' '
    function scenario(assertion, case_id, value) {
        value = tolower(assertion)
        gsub(/_/, "-", value)
        return value "--" case_id
    }
    NR == FNR {
        id = scenario($1, $2)
        valid_scenario[id] = 1
        scenario_assertion[id] = $1
        next
    }
    {
        if (!($2 in valid_scenario) || $3 != "required" ||
            $1 != scenario_assertion[$2] ||
            $4 != "all-required-scenarios-pass-and-gates" ||
            $5 != "INVALID>FAIL>UNAVAILABLE>UNTESTED>PASS" ||
            $6 != "oracle-result+mandatory-gates") exit 1
        if (seen[$2]++) exit 1
        assertion_count[$1]++
        count++
    }
    END {
        if (count != 10 ||
            assertion_count["BC02_COMPLETE_AVAILABLE"] != 1 ||
            assertion_count["BC02_HEALTHY_RETRY"] != 1 ||
            assertion_count["BC02_INCOMPLETE_AS_COMPLETE"] != 2 ||
            assertion_count["BC02_PARTIAL_RESIDUE"] != 2 ||
            assertion_count["BC02_POISONED_RETRY"] != 2 ||
            assertion_count["BC02_ROLLBACK_COMPLETE"] != 2) exit 1
        for (id in valid_scenario) if (!seen[id]) exit 1
    }
' "$base_dir/bc02-cases.tsv" "$base_dir/bc02-assertion-aggregation.tsv" ||
    fail BC02_ASSERTION_AGGREGATION_INVALID

awk -F '	' \
    -v aggregation="$base_dir/bc02-assertion-aggregation.tsv" \
    -v execution="$base_dir/execution-map.tsv" \
    -v registry="$base_dir/oracle-registry.tsv" '
    FILENAME == aggregation {
        assertion[$2] = $1
        next
    }
    FILENAME == execution && $2 == "BC02" {
        oracle_for_assertion[$1] = $10
        next
    }
    FILENAME == registry && $1 ~ /^oracle-bc02-/ {
        oracle_kind[$1] = $2
        oracle_target[$1] = $3
        oracle_count++
        next
    }
    FILENAME != ARGV[4] { next }
    {
        if (!($1 in assertion)) exit 1
        expected_oracle = oracle_for_assertion[assertion[$1]]
        if ($2 != expected_oracle ||
            $3 != oracle_kind[expected_oracle] ||
            $4 != oracle_target[expected_oracle] ||
            $5 != "{expected-sha256}" || $6 != "{actual-sha256}" ||
            $7 != "PASS" || $8 != "{evaluator-revision}") exit 1
        if (seen[$1]++) exit 1
        count++
    }
    END {
        if (oracle_count != 6 || count != 10) exit 1
        for (id in assertion) if (!seen[id]) exit 1
    }
' "$base_dir/bc02-assertion-aggregation.tsv" \
    "$base_dir/execution-map.tsv" "$base_dir/oracle-registry.tsv" \
    "$base_dir/bc02-oracle-result-template.tsv" ||
    fail BC02_ORACLE_CONTRACT_INVALID

awk -F '	' '
    BEGIN {
        expected_set["gate-set-partial"] = "fault-configuration-valid,activation-bound,trigger-bound,command-nonzero,exact-error-identity,transient-shape,same-connection-health,setup-inventory-exact,rollback-inventory-exact,target-residue-zero,no-commit,reopened-unavailable"
        expected_set["gate-set-poisoned"] = "fault-configuration-valid,activation-bound,trigger-bound,command-nonzero,exact-error-identity,transient-shape,same-connection-health,setup-inventory-exact,rollback-inventory-exact,no-commit,retry-reopen,retry-hook-absent,retry-commit,retry-resolution,durability-reopen,durability-resolution"
        expected_set["gate-set-rollback"] = "fault-configuration-valid,activation-bound,trigger-bound,command-nonzero,exact-error-identity,transient-shape,same-connection-health,setup-inventory-exact,rollback-inventory-exact,rollback-inventory-equality,no-commit,reopened-unavailable"

        definition["fault-configuration-valid"] = "INVALID" SUBSEP "fault-configuration-invalid" SUBSEP "fault-configuration-receipts.tsv"
        definition["activation-bound"] = "INVALID" SUBSEP "fault-activation-unbound" SUBSEP "fault-activation-receipts.tsv"
        definition["trigger-bound"] = "INVALID" SUBSEP "fault-trigger-unbound" SUBSEP "evidence-binding-receipts.tsv"
        definition["command-nonzero"] = "INVALID" SUBSEP "fault-command-status-invalid" SUBSEP "command-receipts.tsv"
        definition["exact-error-identity"] = "INVALID" SUBSEP "fault-error-identity-invalid" SUBSEP "fault-trigger-receipts.tsv"
        definition["transient-shape"] = "INVALID" SUBSEP "fault-phase-shape-invalid" SUBSEP "fault-trigger-receipts.tsv"
        definition["same-connection-health"] = "INVALID" SUBSEP "fault-connection-custody-invalid" SUBSEP "fault-trigger-receipts.tsv"
        definition["setup-inventory-exact"] = "INVALID" SUBSEP "scenario-precondition-invalid" SUBSEP "inventory-setup-before.tsv"
        definition["rollback-inventory-exact"] = "FAIL" SUBSEP "rollback-inventory-drift" SUBSEP "inventory-rollback-after.tsv"
        definition["target-residue-zero"] = "FAIL" SUBSEP "partial-residue-present" SUBSEP "inventory-rollback-after.tsv"
        definition["rollback-inventory-equality"] = "FAIL" SUBSEP "rollback-inventory-not-equal" SUBSEP "inventory-setup-before.tsv+inventory-rollback-after.tsv"
        definition["no-commit"] = "FAIL" SUBSEP "failed-attempt-committed" SUBSEP "data-version-receipts.tsv"
        definition["reopened-unavailable"] = "FAIL" SUBSEP "failed-root-became-available" SUBSEP "resolution-receipts.tsv"
        definition["retry-reopen"] = "INVALID" SUBSEP "retry-reopen-invalid" SUBSEP "command-receipts.tsv"
        definition["retry-hook-absent"] = "FAIL" SUBSEP "retry-hook-retriggered" SUBSEP "command-receipts.tsv+fault-trigger-receipts.tsv"
        definition["retry-commit"] = "FAIL" SUBSEP "retry-not-committed" SUBSEP "data-version-receipts.tsv"
        definition["retry-resolution"] = "FAIL" SUBSEP "retry-root-unavailable" SUBSEP "resolution-receipts.tsv"
        definition["durability-reopen"] = "INVALID" SUBSEP "durability-reopen-invalid" SUBSEP "command-receipts.tsv"
        definition["durability-resolution"] = "FAIL" SUBSEP "reopened-retry-root-unavailable" SUBSEP "resolution-receipts.tsv"
    }
    {
        if (!($1 in expected_set) || !($3 in definition) ||
            ($4 SUBSEP $5 SUBSEP $6) != definition[$3] ||
            $2 != sprintf("%03d", (count[$1] + 1) * 10) ||
            seen[$1 SUBSEP $3]++) exit 1
        actual_set[$1] = actual_set[$1] (actual_set[$1] ? "," : "") $3
        count[$1]++
        total++
    }
    END {
        if (total != 40) exit 1
        for (id in expected_set)
            if (actual_set[id] != expected_set[id]) exit 1
    }
' "$base_dir/bc02-mandatory-gate-sets.tsv" ||
    fail BC02_MANDATORY_GATE_SET_INVALID

awk -F '	' '
    function scenario(assertion, case_id, value) {
        value = tolower(assertion)
        gsub(/_/, "-", value)
        return value "--" case_id
    }
    NR == FNR {
        id = scenario($1, $2)
        valid[id] = 1
        assertion[id] = $1
        next
    }
    {
        expected = assertion[$1] == "BC02_PARTIAL_RESIDUE" ? "gate-set-partial" :
            (assertion[$1] == "BC02_POISONED_RETRY" ? "gate-set-poisoned" :
            (assertion[$1] == "BC02_ROLLBACK_COMPLETE" ? "gate-set-rollback" : ""))
        if (!($1 in valid) || expected == "" || $2 != expected) exit 1
        if (seen[$1]++) exit 1
        count++
    }
    END { if (count != 6) exit 1 }
' "$base_dir/bc02-cases.tsv" "$base_dir/bc02-scenario-gates.tsv" ||
    fail BC02_SCENARIO_GATE_MAP_INVALID

awk -F '	' \
    -v definitions="$base_dir/bc02-mandatory-gate-sets.tsv" \
    -v scenarios="$base_dir/bc02-scenario-gates.tsv" '
    FILENAME == definitions {
        n[$1]++
        ordinal[$1, n[$1]] = $2
        gate[$1, n[$1]] = $3
        evidence[$1, n[$1]] = $6
        next
    }
    FILENAME == scenarios {
        scenario_set[$1] = $2
        for (i = 1; i <= n[$2]; i++)
            expected[$1 SUBSEP $2 SUBSEP ordinal[$2, i] SUBSEP gate[$2, i]] = evidence[$2, i]
        next
    }
    {
        key = $1 SUBSEP $2 SUBSEP $3 SUBSEP $4
        if (!(key in expected) || $5 != expected[key] ||
            $6 != "{evidence-sha256}" || $7 != "PASS" || $8 != "-" ||
            $9 != "{evaluator-revision}" || seen[key]++) exit 1
        count++
    }
    END {
        if (count != 80) exit 1
        for (key in expected) if (seen[key] != 1) exit 1
    }
' "$base_dir/bc02-mandatory-gate-sets.tsv" \
    "$base_dir/bc02-scenario-gates.tsv" \
    "$base_dir/bc02-gate-results-template.tsv" ||
    fail BC02_GATE_RESULT_CONTRACT_INVALID

awk -F '	' '
    {
        key = $1 SUBSEP $2
        if ($3 !~ /^[0-9][0-9][0-9]$/ || $6 != "same") exit 1
        if (seen[key SUBSEP $3]++) exit 1
        if (key in previous && ($3 + 0) <= previous[key]) exit 1
        previous[key] = $3 + 0
        cases[key] = 1
        count++
    }
    END {
        if (count != 103) exit 1
        for (key in cases) {
            gsub(SUBSEP, "\t", key)
            print key
        }
    }
' "$base_dir/bc02-steps.tsv" > "$tmp/step-cases.unsorted" ||
    fail BC02_STEP_CONTRACT_INVALID
sort "$tmp/step-cases.unsorted" > "$tmp/step-cases"

cut -f1,2 "$base_dir/bc02-cases.tsv" | sort > "$tmp/case-pairs"
cmp -s "$tmp/case-pairs" "$tmp/step-cases" ||
    fail BC02_STEP_CASE_COVERAGE_INVALID

awk -F '	' '
    function expected_sequence(assertion) {
        if (assertion == "BC02_COMPLETE_AVAILABLE")
            return "setup,setup-before,form,success-after,success,durability-reopen,reopened"
        if (assertion == "BC02_HEALTHY_RETRY")
            return "setup,setup-before,initial-form,rollback-after,unavailable,correction,correction-after,retry,retry-after,retry-success,durability-reopen,reopened"
        if (assertion == "BC02_INCOMPLETE_AS_COMPLETE")
            return "setup,setup-before,form,rollback-after,unavailable,durability-reopen,reopened"
        if (assertion == "BC02_POISONED_RETRY")
            return "setup,configure-before-baseline,setup-before,fault-before,fault,fault-after,rollback-after,unavailable,retry-reopen,retry,retry-after,retry-commit,retry-success,durability-reopen,reopened"
        if (assertion == "BC02_PARTIAL_RESIDUE" ||
            assertion == "BC02_ROLLBACK_COMPLETE")
            return "setup,configure-before-baseline,setup-before,fault-before,fault,fault-after,rollback-after,unavailable,durability-reopen,reopened"
        return ""
    }
    function expected_hook(case_id) {
        if (case_id == "case-bc02-after-root-header")
            return "hook-bc02-after-root-header"
        if (case_id == "case-bc02-after-root-member")
            return "hook-bc02-after-root-member"
        return "-"
    }
    {
        key = $1 SUBSEP $2
        sequence[key] = sequence[key] (sequence[key] ? "," : "") $7
        stage = $7
        if (stage == "setup" &&
            ($4 != "setup-operation" || $5 != "sut-setup-bc02")) exit 1
        if ((stage == "setup-before" || stage == "rollback-after" ||
             stage == "success-after" || stage == "correction-after" ||
             stage == "retry-after") &&
            ($4 != "inventory-observation" || $5 != "inventory-repository")) exit 1
        if ((stage == "form" || stage == "initial-form") &&
            ($4 != "action-operation" || $5 != "sut-form-root")) exit 1
        if (stage == "retry" &&
            ($4 != "action-operation" || $5 != "sut-retry-root")) exit 1
        if (stage == "correction" &&
            ($4 != "correction-operation" || $5 != "sut-correct-root-input")) exit 1
        if (stage == "configure-before-baseline" &&
            ($4 != "fault-configuration" || $5 != expected_hook($2))) exit 1
        if (stage == "fault" &&
            ($4 != "fault-operation" || $5 != expected_hook($2))) exit 1
        if ((stage == "fault-before" || stage == "fault-after" ||
             stage == "retry-commit") &&
            ($4 != "health-observation" || $5 != "sqlite-data-version")) exit 1
        if ((stage == "retry-reopen" || stage == "durability-reopen") &&
            ($4 != "reopen-operation" || $5 != "profile-reopen-namespace")) exit 1
        if ((stage == "success" || stage == "unavailable" ||
             stage == "retry-success" || stage == "reopened") &&
            ($4 != "resolution-observation" || $5 != "norm-bc02-observation")) exit 1
    }
    END {
        for (key in sequence) {
            split(key, parts, SUBSEP)
            if (sequence[key] != expected_sequence(parts[1])) exit 1
        }
    }
' "$base_dir/bc02-steps.tsv" || fail BC02_STEP_SEMANTICS_INVALID

awk -F '	' '$4 == "inventory-observation" { print $1 "	" $2 "	" $7 }' \
    "$base_dir/bc02-steps.tsv" | sort > "$tmp/inventory-steps"
cut -f1-3 "$base_dir/bc02-inventory-map.tsv" | sort > "$tmp/inventory-map"
cmp -s "$tmp/inventory-steps" "$tmp/inventory-map" ||
    fail BC02_INVENTORY_MAP_COVERAGE_INVALID
[ "$(wc -l < "$tmp/inventory-map" | tr -d ' ')" = 24 ] ||
    fail BC02_INVENTORY_MAP_COVERAGE_INVALID

awk -F '	' '
    function expected_template(assertion, case_id, stage) {
        if (assertion == "BC02_COMPLETE_AVAILABLE")
            return stage == "setup-before" ?
                "bc02-inventory-complete-before.tsv" :
                "bc02-inventory-complete-after.tsv"
        if (assertion == "BC02_HEALTHY_RETRY") {
            if (stage == "setup-before" || stage == "rollback-after")
                return "bc02-inventory-incomplete-missing.tsv"
            if (stage == "correction-after")
                return "bc02-inventory-complete-before.tsv"
            return "bc02-inventory-complete-after.tsv"
        }
        if (assertion == "BC02_INCOMPLETE_AS_COMPLETE")
            return case_id == "case-bc02-incomplete-missing" ?
                "bc02-inventory-incomplete-missing.tsv" :
                "bc02-inventory-incomplete-substitution.tsv"
        if (assertion ~ /^BC02_(PARTIAL_RESIDUE|POISONED_RETRY|ROLLBACK_COMPLETE)$/) {
            if (stage == "retry-after")
                return "bc02-inventory-complete-after.tsv"
            return "bc02-inventory-complete-before.tsv"
        }
        return ""
    }
    function expected_role(assertion, stage) {
        if (assertion == "BC02_HEALTHY_RETRY" && stage == "correction-after")
            return "expected-exact-delta"
        if (assertion == "BC02_ROLLBACK_COMPLETE")
            return stage == "setup-before" ? "equality-left" : "equality-right"
        if (assertion == "BC02_PARTIAL_RESIDUE" ||
            (assertion == "BC02_POISONED_RETRY" && stage != "retry-after"))
            return "harness-expected-exact"
        return "expected-exact"
    }
    {
        if ($4 != "inventory-" $3 ".tsv" ||
            $5 != expected_template($1, $2, $3) ||
            $6 != expected_role($1, $3)) exit 1
    }
' "$base_dir/bc02-inventory-map.tsv" ||
    fail BC02_INVENTORY_MAP_SEMANTICS_INVALID

awk -F '	' '
    function expected_source(file, object) {
        if (file ~ /incomplete-missing/) return object == "object-a" || object == "object-b"
        if (file ~ /incomplete-substitution/)
            return object == "object-a" || object == "object-b" || object == "object-x"
        return object == "object-a" || object == "object-b" || object == "object-c"
    }
    function expected_value(object) {
        return object == "object-a" ? "value-a" :
            (object == "object-b" ? "value-b" :
            (object == "object-c" ? "value-c" :
            (object == "object-x" ? "value-x" : "")))
    }
    {
        file = FILENAME
        if ($1 != "{scenario}" || $6 != "0001") exit 1
        rows[file]++
        if ($2 == "root-required-member" && $4 == "object-ref") {
            expected = $3 == "request-02/0001" ? "object-a" :
                ($3 == "request-02/0002" ? "object-b" :
                ($3 == "request-02/0003" ? "object-c" : ""))
            if (expected == "" || $5 != expected ||
                required[file SUBSEP $3]++) exit 1
        }
        if ($2 == "source-object" && $3 != "@relation") {
            if (!expected_source(file, $3)) exit 1
            if ($4 == "kind" && $5 == "pair") source_kind[file SUBSEP $3]++
            else if ($4 == "value" && $5 == expected_value($3))
                source_value[file SUBSEP $3]++
            else exit 1
        }
        if ($2 == "root-member" && $3 != "@relation") {
            expected = $3 == "root-02/0001" ? "object-a" :
                ($3 == "root-02/0002" ? "object-b" :
                ($3 == "root-02/0003" ? "object-c" : ""))
            if (file !~ /complete-after/ || $4 != "object-ref" ||
                $5 != expected || expected == "") exit 1
            root_member[file SUBSEP $3]++
        }
    }
    END {
        for (file in rows) {
            expected_rows = file ~ /complete-after/ ? 24 :
                (file ~ /incomplete-missing/ ? 15 : 17)
            if (rows[file] != expected_rows) exit 1
            if (required[file SUBSEP "request-02/0001"] != 1 ||
                required[file SUBSEP "request-02/0002"] != 1 ||
                required[file SUBSEP "request-02/0003"] != 1) exit 1
            for (object in all_objects) delete all_objects[object]
        }
        for (key in source_kind) if (source_kind[key] != 1 || source_value[key] != 1) exit 1
        for (key in source_value) if (source_value[key] != 1 || source_kind[key] != 1) exit 1
    }
' "$base_dir/bc02-inventory-complete-before.tsv" \
    "$base_dir/bc02-inventory-complete-after.tsv" \
    "$base_dir/bc02-inventory-incomplete-missing.tsv" \
    "$base_dir/bc02-inventory-incomplete-substitution.tsv" ||
    fail BC02_INVENTORY_FIXTURE_SEMANTICS_INVALID

cut -f7 "$base_dir/bc02-steps.tsv" | sort -u > "$tmp/used-stages"
cut -f1 "$base_dir/bc02-stage-enums.tsv" | sort -u > "$tmp/declared-stages"
cmp -s "$tmp/used-stages" "$tmp/declared-stages" ||
    fail BC02_STAGE_ENUM_INVALID

awk -F '	' '
    {
        if ($1 !~ /^bc02-[a-z0-9-]+--case-bc02-[a-z0-9-]+$/ ||
            $2 !~ /^obs-[a-z0-9-]+$/) exit 1
        if (seen[$1 SUBSEP $2]++) exit 1
        scenario[$1] = 1
        count++
    }
    END {
        if (count != 134) exit 1
        for (id in scenario) print id
    }
' "$base_dir/bc02-normalized-contract.tsv" > "$tmp/normalized-scenarios.unsorted" ||
    fail BC02_NORMALIZED_CONTRACT_INVALID
sort "$tmp/normalized-scenarios.unsorted" > "$tmp/normalized-scenarios"
cmp -s "$tmp/scenarios" "$tmp/normalized-scenarios" ||
    fail BC02_NORMALIZED_SCENARIO_COVERAGE_INVALID

awk -F '	' '
    {
        scenario = $1
        observation = $2
        if ($3 == "input-membership") {
            if ($4 != "request-02" || $5 != "incomplete" || $6 != "2/3")
                exit 1
            input_membership++
        } else if ($3 == "membership") {
            if ($4 != "root-02" || $5 != "complete" || $6 != "3/3")
                exit 1
        }
        if (observation == "obs-failure-reason") {
            if ($3 != "failure" || $4 != "object-c" ||
                $5 != "missing-required-member" || $6 != "root-unavailable")
                exit 1
            failure_reason++
        }
        if (observation == "obs-command-status" &&
            ($3 != "fault-command" || $5 != "nonzero" || $6 != "70"))
            exit 1
        if (observation == "obs-no-commit" &&
            ($3 != "sqlite-profile" || $4 != "data-version" ||
             $5 != "unchanged" || $6 != "1")) exit 1
        if (observation == "obs-retry-commit" &&
            ($3 != "sqlite-profile" || $4 != "data-version" ||
             $5 != "changed" || $6 != "1")) exit 1
        if (observation == "obs-failing-connection-health" &&
            ($4 != "failing-connection" || $5 != "healthy" || $6 != "1"))
            exit 1
        if (observation == "obs-trigger") {
            if ($5 != "triggered") exit 1
            if (scenario ~ /after-root-header$/ &&
                ($4 != "after-root-header" || $6 != "1/0/0")) exit 1
            if (scenario ~ /after-root-member$/ &&
                ($4 != "after-root-member" || $6 != "1/1/0")) exit 1
        }
        if (observation == "obs-error-identity") {
            if (scenario ~ /after-root-header$/ &&
                ($5 != "error-bc02-after-root-header" ||
                 $6 != "LICIUM_BC02_FAULT_AFTER_ROOT_HEADER")) exit 1
            if (scenario ~ /after-root-member$/ &&
                ($5 != "error-bc02-after-root-member" ||
                 $6 != "LICIUM_BC02_FAULT_AFTER_ROOT_MEMBER")) exit 1
            if (scenario ~ /^bc02-healthy-retry/ &&
                ($5 != "error-bc02-incomplete" ||
                 $6 != "LICIUM_BC02_ROOT_INCOMPLETE")) exit 1
        }
        if (scenario ~ /^bc02-partial-residue/ && observation == "obs-rollback")
            exit 1
    }
    END {
        if (input_membership != 3 || failure_reason != 3) exit 1
    }
' "$base_dir/bc02-normalized-contract.tsv" ||
    fail BC02_NORMALIZED_SEMANTICS_INVALID

while IFS='	' read -r scenario expected_count expected_sha256; do
    actual_count=$(awk -F '	' -v scenario="$scenario" '
        $1 == scenario { count++ }
        END { print count + 0 }
    ' "$base_dir/bc02-normalized-contract.tsv")
    actual_sha256=$(awk -F '	' -v scenario="$scenario" '
        $1 == scenario
    ' "$base_dir/bc02-normalized-contract.tsv" | sha256sum | awk '{ print $1 }')
    [ "$actual_count" = "$expected_count" ] &&
        [ "$actual_sha256" = "$expected_sha256" ] ||
        fail BC02_NORMALIZED_SEMANTIC_SEAL_INVALID
done <<'BC02_NORMALIZED_SEMANTIC_SEALS'
bc02-complete-available--case-bc02-complete	8	3b2d2adecf065ff3e9dfabdf4732e92f23dad02e3e0a59a9ff0b151c1f59977a
bc02-healthy-retry--case-bc02-incomplete-corrected	14	cadf669a2b5c0e4745ae1faf27ba1a2a1749076906a53871e330c0f03d67a2da
bc02-incomplete-as-complete--case-bc02-incomplete-missing	11	4e2c60895f2d21b05017216730fbd53253ca17249b4b6158560b358a927337ef
bc02-incomplete-as-complete--case-bc02-incomplete-substitution	11	4e3aee88c1cf27deabbe00712f355a0b2ee8b5e8374832ec634b6bd047b47806
bc02-partial-residue--case-bc02-after-root-header	12	b7a110ea08c4e57a42a9db55738c714a7b5b8c507bba3434227748b0077ade10
bc02-partial-residue--case-bc02-after-root-member	12	b105115530d795bff3c7fb7cdd5d977c9ec1317f8f1427c7c9ee5f6633aca085
bc02-poisoned-retry--case-bc02-after-root-header	20	986bc8346103c19b6161dc028c8aff0496a2ae5e7007680ec1ca6f8058d0d19b
bc02-poisoned-retry--case-bc02-after-root-member	20	3996fe52fe37588ce4427046e8e960931cbc38d57bdccee21e3f97152d9e6158
bc02-rollback-complete--case-bc02-after-root-header	13	7dd00e94b285315166a9d323f7273b2f088af3035b7646860c4093e925692a95
bc02-rollback-complete--case-bc02-after-root-member	13	4baf61c7b3206c48afaac49f6234136270084e03b5073a2d36e9c687e393e935
BC02_NORMALIZED_SEMANTIC_SEALS

cut -f1 "$base_dir/bc02-runtime-artifacts.tsv" | sort > "$tmp/runtime-artifacts"
awk -F '	' '
    NR == FNR {
        scenario[$1] = 1
        next
    }
    FILENAME == ARGV[2] {
        artifact[$1] = 1
        next
    }
    {
        if (!($1 in scenario) || !($2 in artifact) ||
            $3 != "required" || $4 !~ /^[0-9]+$/) exit 1
        if (seen[$1 SUBSEP $2]++) exit 1
        scenario_count[$1]++
        artifact_count[$2]++
        count++
    }
    END {
        if (count != 250) exit 1
        for (id in scenario) if (scenario_count[id] != 25) exit 1
        for (id in artifact) if (artifact_count[id] != 10) exit 1
    }
' "$tmp/scenarios" "$tmp/runtime-artifacts" \
    "$base_dir/bc02-artifact-cardinality.tsv" ||
    fail BC02_ARTIFACT_CARDINALITY_INVALID

for artifact in raw-observations.tsv coverage.tsv normalized-observations.tsv; do
    case "$artifact" in
        raw-observations.tsv) contract="$base_dir/bc02-raw-template.tsv" ;;
        coverage.tsv) contract="$base_dir/bc02-coverage-template.tsv" ;;
        normalized-observations.tsv) contract="$base_dir/bc02-normalized-contract.tsv" ;;
    esac
    awk -F '	' -v artifact="$artifact" '
        NR == FNR {
            expected[$1]++
            next
        }
        $2 == artifact {
            seen[$1] = 1
            if (($4 + 0) != expected[$1]) exit 1
        }
        END {
            for (id in expected) if (!(id in seen)) exit 1
        }
    ' "$contract" "$base_dir/bc02-artifact-cardinality.tsv" ||
        fail BC02_ARTIFACT_CARDINALITY_INVALID
done

awk -F '	' '
    function scenario(assertion, case_id, value) {
        value = tolower(assertion)
        gsub(/_/, "-", value)
        return value "--" case_id
    }
    function is_fault(s) {
        return s ~ /^bc02-(partial-residue|poisoned-retry|rollback-complete)--/
    }
    function expected(s, artifact, n) {
        if (artifact == "command-receipts.tsv") return step_count[s] + 2
        if (artifact == "pragma.tsv") return step_count[s] + 1
        if (artifact == "action-receipts.tsv") {
            if (s ~ /^bc02-healthy-retry--/) return 2
            if (s ~ /^bc02-(complete-available|incomplete-as-complete|poisoned-retry)--/) return 1
            return 0
        }
        if (artifact == "correction-receipts.tsv" ||
            artifact == "correction-write-guard-receipts.tsv")
            return s ~ /^bc02-healthy-retry--/ ? 1 : 0
        if (artifact == "data-version-receipts.tsv")
            return s ~ /^bc02-poisoned-retry--/ ? 3 : (is_fault(s) ? 2 : 0)
        if (artifact == "evidence-binding-receipts.tsv" ||
            artifact == "fault-activation-receipts.tsv" ||
            artifact == "fault-configuration-receipts.tsv" ||
            artifact == "fault-markers.tsv" ||
            artifact == "fault-trigger-receipts.tsv" ||
            artifact == "observer-custody-receipts.tsv")
            return is_fault(s) ? 1 : 0
        if (artifact == "exclusions.tsv") return 0
        if (artifact == "gate-results.tsv") {
            if (s ~ /^bc02-partial-residue--/) return 12
            if (s ~ /^bc02-poisoned-retry--/) return 16
            if (s ~ /^bc02-rollback-complete--/) return 12
            return 0
        }
        if (artifact == "inventory-setup-before.tsv") {
            if (s ~ /incomplete-missing$/ ||
                s ~ /^bc02-healthy-retry--/) return 15
            return 17
        }
        if (artifact == "inventory-rollback-after.tsv") {
            if (s ~ /^bc02-complete-available--/) return 0
            if (s ~ /incomplete-missing$/ ||
                s ~ /^bc02-healthy-retry--/) return 15
            return 17
        }
        if (artifact == "inventory-correction-after.tsv")
            return s ~ /^bc02-healthy-retry--/ ? 17 : 0
        if (artifact == "inventory-retry-after.tsv")
            return s ~ /^bc02-(healthy-retry|poisoned-retry)--/ ? 24 : 0
        if (artifact == "inventory-success-after.tsv")
            return s ~ /^bc02-complete-available--/ ? 24 : 0
        if (artifact == "oracle-result.tsv" || artifact == "raw-seal.tsv") return 1
        if (artifact == "resolution-receipts.tsv") {
            if (s ~ /^bc02-(healthy-retry|poisoned-retry)--/) return 3
            return 2
        }
        if (artifact == "raw-observations.tsv" ||
            artifact == "coverage.tsv" ||
            artifact == "normalized-observations.tsv") return -1
        return -2
    }
    NR == FNR {
        step_count[scenario($1, $2)]++
        next
    }
    {
        n = expected($1, $2)
        if (n == -2 || (n >= 0 && ($4 + 0) != n)) exit 1
    }
' "$base_dir/bc02-steps.tsv" "$base_dir/bc02-artifact-cardinality.tsv" ||
    fail BC02_ARTIFACT_CARDINALITY_SEMANTICS_INVALID

awk -F '	' '
    NR == FNR {
        valid_scenario[$1] = 1
        next
    }
    {
        if (!($1 in valid_scenario) ||
            $2 !~ /^raw-[a-z0-9-]+-[0-9][0-9]$/ ||
            $3 !~ /^[a-z0-9-]+$/ ||
            $4 !~ /^[a-z0-9-]+$/) exit 1
        key = $1 SUBSEP $2
        if (seen[key]++) exit 1
        print $1 "	" $2
        count++
    }
    END { if (count != 206) exit 1 }
' "$tmp/scenarios" "$base_dir/bc02-raw-template.tsv" \
    > "$tmp/raw-endpoints.unsorted" ||
    fail BC02_RAW_CONTRACT_INVALID
sort "$tmp/raw-endpoints.unsorted" > "$tmp/raw-endpoints"

awk -F '	' \
    -v raw_file="$tmp/raw-endpoints" \
    -v norm_file="$base_dir/bc02-normalized-contract.tsv" '
    FILENAME == raw_file {
        raw[$1 SUBSEP $2] = 1
        next
    }
    FILENAME == norm_file {
        norm[$1 SUBSEP $2] = 1
        next
    }
    {
        raw_key = $1 SUBSEP $2
        norm_key = $4 SUBSEP $5
        expected_observation = $2
        sub(/^raw-/, "obs-", expected_observation)
        sub(/-[0-9][0-9]$/, "", expected_observation)
        if (!(raw_key in raw) || !(norm_key in norm) ||
            $1 != $4 || $5 != expected_observation ||
            $3 != "record" || $6 != "all") exit 1
        if (edge[raw_key SUBSEP norm_key]++) exit 1
        raw_seen[raw_key] = 1
        norm_seen[norm_key] = 1
        count++
    }
    END {
        if (count != 206) exit 1
        for (key in raw) if (!(key in raw_seen)) exit 1
        for (key in norm) if (!(key in norm_seen)) exit 1
    }
' "$tmp/raw-endpoints" "$base_dir/bc02-normalized-contract.tsv" \
    "$base_dir/bc02-coverage-template.tsv" ||
    fail BC02_COVERAGE_INVALID

awk -F '	' '
    BEGIN {
        expected["rule-direct-field"] = "action-receipt,correction-receipt,fault-activation-receipt,fault-trigger-receipt,command-receipt" SUBSEP "one" SUBSEP "exact-field-copy" SUBSEP "one" SUBSEP "normalized-field"
        expected["rule-resolution-field"] = "resolution-receipt" SUBSEP "one" SUBSEP "exact-stage-field" SUBSEP "one" SUBSEP "normalized-resolution"
        expected["rule-inventory-count"] = "inventory-repository" SUBSEP "one" SUBSEP "exact-semantic-row-count" SUBSEP "one" SUBSEP "normalized-count"
        expected["rule-inventory-equality"] = "inventory-repository" SUBSEP "two" SUBSEP "byte-equality" SUBSEP "one" SUBSEP "normalized-unchanged"
        expected["rule-inventory-delta"] = "correction-receipt,together-with-inventory-repository" SUBSEP "three" SUBSEP "exact-source-object-insert-delta" SUBSEP "one" SUBSEP "normalized-correction"
        expected["rule-data-version-equality"] = "data-version-receipt,together-with-observer-custody-receipt" SUBSEP "three" SUBSEP "same-held-observer-equality" SUBSEP "one" SUBSEP "normalized-no-commit"
        expected["rule-data-version-change"] = "data-version-receipt,together-with-observer-custody-receipt" SUBSEP "three" SUBSEP "same-held-observer-inequality" SUBSEP "one" SUBSEP "normalized-retry-commit"
        expected["rule-attempt-distinct"] = "action-receipt-or-fault-trigger-receipt" SUBSEP "two" SUBSEP "distinct-attempt-same-request-root" SUBSEP "one" SUBSEP "normalized-provenance"
        expected["rule-fault-trigger"] = "fault-configuration-receipt,together-with-fault-activation-receipt,fault-trigger-receipt,and-evidence-binding-receipt" SUBSEP "seven" SUBSEP "exact-binding-and-transient-shape" SUBSEP "one" SUBSEP "normalized-trigger"
        expected["rule-fault-rollback"] = "fault-trigger-receipt,together-with-inventory-repository" SUBSEP "two" SUBSEP "injected-error-and-rollback" SUBSEP "one" SUBSEP "normalized-fault-outcome"
        expected["rule-correction-isolation"] = "correction-write-guard-receipt,together-with-inventory-repository" SUBSEP "three" SUBSEP "insert-only-guard-and-exact-inventory-delta" SUBSEP "one" SUBSEP "normalized-correction-isolation"
        expected["rule-retry-hook-absent"] = "command-receipt" SUBSEP "one" SUBSEP "reviewed-argv-has-no-hook-phase" SUBSEP "one" SUBSEP "normalized-retry-hook"
    }
    {
        value = $2 SUBSEP $3 SUBSEP $4 SUBSEP $5 SUBSEP $6
        if (!($1 in expected) || value != expected[$1] || seen[$1]++) exit 1
    }
    END {
        for (id in expected) if (seen[id] != 1) exit 1
    }
' "$base_dir/bc02-normalization-rules.tsv" ||
    fail BC02_NORMALIZATION_RULE_INVALID

awk -F '	' '
    function is_fault(s) {
        return s ~ /^bc02-(partial-residue|poisoned-retry|rollback-complete)--/
    }
    function member(set_id, scenario, hook) {
        if (is_fault(scenario) && scenario ~ /after-root-header$/ &&
            hook != "hook-bc02-after-root-header") return 0
        if (is_fault(scenario) && scenario ~ /after-root-member$/ &&
            hook != "hook-bc02-after-root-member") return 0
        if (!is_fault(scenario) && hook != "-") return 0
        if (set_id == "set-all") return 1
        if (set_id == "set-complete") return scenario ~ /^bc02-complete-available--/
        if (set_id == "set-fault") return is_fault(scenario)
        if (set_id == "set-fault-header")
            return is_fault(scenario) && scenario ~ /after-root-header$/
        if (set_id == "set-fault-member")
            return is_fault(scenario) && scenario ~ /after-root-member$/
        if (set_id == "set-healthy") return scenario ~ /^bc02-healthy-retry--/
        if (set_id == "set-incomplete")
            return scenario ~ /^bc02-(healthy-retry|incomplete-as-complete)--/
        if (set_id == "set-partial") return scenario ~ /^bc02-partial-residue--/
        if (set_id == "set-poisoned") return scenario ~ /^bc02-poisoned-retry--/
        if (set_id == "set-retry")
            return scenario ~ /^bc02-(healthy-retry|poisoned-retry)--/
        if (set_id == "set-rollback") return scenario ~ /^bc02-rollback-complete--/
        if (set_id == "set-substitution")
            return scenario == "bc02-incomplete-as-complete--case-bc02-incomplete-substitution"
        return 0
    }
    NR == FNR {
        valid_scenario[$1] = 1
        next
    }
    {
        if ($1 !~ /^set-[a-z0-9-]+$/ || !($2 in valid_scenario)) exit 1
        if ($3 != "-" && $3 !~ /^hook-bc02-[a-z0-9-]+$/) exit 1
        if (!member($1, $2, $3)) exit 1
        if (seen[$1 SUBSEP $2 SUBSEP $3]++) exit 1
        set_seen[$1] = 1
        set_count[$1]++
    }
    END {
        if (set_count["set-all"] != 10 ||
            set_count["set-complete"] != 1 ||
            set_count["set-fault"] != 6 ||
            set_count["set-fault-header"] != 3 ||
            set_count["set-fault-member"] != 3 ||
            set_count["set-healthy"] != 1 ||
            set_count["set-incomplete"] != 3 ||
            set_count["set-partial"] != 2 ||
            set_count["set-poisoned"] != 2 ||
            set_count["set-retry"] != 3 ||
            set_count["set-rollback"] != 2 ||
            set_count["set-substitution"] != 1) exit 1
        for (id in set_seen) print id
    }
' "$tmp/scenarios" "$base_dir/bc02-mutant-applicability.tsv" \
    > "$tmp/applicability-sets.unsorted" ||
    fail BC02_MUTANT_APPLICABILITY_INVALID
sort "$tmp/applicability-sets.unsorted" > "$tmp/applicability-sets"

awk -F '	' '
    NR == FNR {
        valid_set[$1] = 1
        next
    }
    {
        if ($1 !~ /^(neg|harness)-bc02-[a-z0-9-]+$/ ||
            $3 !~ /^mutant-[a-z0-9-]+$/ ||
            $4 !~ /^BC02_[A-Z0-9_]+$/ ||
            !($5 in valid_set)) exit 1
        if (seen[$1]++ || mutant_seen[$3]++) exit 1
        used_set[$5] = 1
        count++
    }
    END {
        if (count != 46) exit 1
        for (id in used_set) print id
    }
' "$tmp/applicability-sets" "$base_dir/bc02-mutants.tsv" \
    > "$tmp/used-applicability-sets.unsorted" ||
    fail BC02_MUTANT_CONTRACT_INVALID
sort "$tmp/used-applicability-sets.unsorted" > "$tmp/used-applicability-sets"
cmp -s "$tmp/applicability-sets" "$tmp/used-applicability-sets" ||
    fail BC02_MUTANT_APPLICABILITY_UNUSED

awk -F '	' '
    function scenario(assertion, case_id, value) {
        value = tolower(assertion)
        gsub(/_/, "-", value)
        return value "--" case_id
    }
    {
        if (NF != 19 || $1 != "{run}" || $2 != "{namespace}" ||
            $8 != "request-02" || $9 != "root-02" || $10 != "3") exit 1
        id = scenario($3, $4)
        if ($5 == "attempt-retry") {
            if ($6 != "sut-retry-root" || $7 != "complete") exit 1
        } else if ($5 == "attempt-complete" || $5 == "attempt-initial") {
            if ($6 != "sut-form-root") exit 1
        } else exit 1
        if ($7 == "complete") {
            if ($11 != "3" || $12 != "3" || $13 != "genesis-02" ||
                $14 != "committed" || $16 != "-" || $17 != "-" ||
                $18 != "-" || $19 != "-") exit 1
        } else if ($7 == "root-unavailable") {
            if ($5 != "attempt-initial" || $11 != "2" || $12 != "0" ||
                $13 != "-" || $14 != "rolled-back" ||
                $16 != "error-bc02-incomplete" ||
                $17 != "LICIUM_BC02_ROOT_INCOMPLETE" ||
                $18 != "object-c" || $19 != "missing-required-member") exit 1
        } else exit 1
        count[id]++
        total++
    }
    END {
        if (total != 7 ||
            count["bc02-complete-available--case-bc02-complete"] != 1 ||
            count["bc02-healthy-retry--case-bc02-incomplete-corrected"] != 2 ||
            count["bc02-incomplete-as-complete--case-bc02-incomplete-missing"] != 1 ||
            count["bc02-incomplete-as-complete--case-bc02-incomplete-substitution"] != 1 ||
            count["bc02-poisoned-retry--case-bc02-after-root-header"] != 1 ||
            count["bc02-poisoned-retry--case-bc02-after-root-member"] != 1) exit 1
    }
' "$base_dir/bc02-root-action-receipt-template.tsv" ||
    fail BC02_ACTION_RECEIPT_SEMANTICS_INVALID

awk -F '	' '
    function validate(case_id, attempt, hook, phase, header, member, error_id, marker) {
        if (case_id == "case-bc02-after-root-header")
            return attempt == "attempt-fault-header" &&
                hook == "hook-bc02-after-root-header" &&
                phase == "after-root-header" && header == "1" && member == "0" &&
                error_id == "error-bc02-after-root-header" &&
                marker == "LICIUM_BC02_FAULT_AFTER_ROOT_HEADER"
        if (case_id == "case-bc02-after-root-member")
            return attempt == "attempt-fault-member" &&
                hook == "hook-bc02-after-root-member" &&
                phase == "after-root-member" && header == "1" && member == "1" &&
                error_id == "error-bc02-after-root-member" &&
                marker == "LICIUM_BC02_FAULT_AFTER_ROOT_MEMBER"
        return 0
    }
    {
        if (NF != 21 || $1 != "{run}" || $2 != "{namespace}" ||
            $3 != "{assertion}" || $6 != "sut-form-root" ||
            !validate($4, $5, $7, $8, $13, $14, $17, $18) ||
            $9 != "{nonce}" || $10 != "{implementation-revision}" ||
            $11 != "{activation-sha256}" || $12 != "true" ||
            $15 != "0" || $16 != "ok" ||
            $19 != "{raw-stderr-sha256}" ||
            $20 != "{parsed-literal-sha256}" ||
            $21 != "injected-rollback") exit 1
        seen[$4]++
        count++
    }
    END {
        if (count != 2 ||
            seen["case-bc02-after-root-header"] != 1 ||
            seen["case-bc02-after-root-member"] != 1) exit 1
    }
' "$base_dir/bc02-fault-trigger-template.tsv" ||
    fail BC02_FAULT_TRIGGER_SEMANTICS_INVALID

awk -F '	' '
    BEGIN {
        expected["case-bc02-after-root-header"] = "attempt-fault-header" SUBSEP "hook-bc02-after-root-header" SUBSEP "after-root-header"
        expected["case-bc02-after-root-member"] = "attempt-fault-member" SUBSEP "hook-bc02-after-root-member" SUBSEP "after-root-member"
    }
    {
        value = $5 SUBSEP $7 SUBSEP $8
        if (NF != 10 || $1 != "{run}" || $2 != "{namespace}" ||
            $3 != "{assertion}" || !($4 in expected) ||
            value != expected[$4] || $6 != "sut-form-root" ||
            $9 != "{nonce}" || $10 != "{implementation-revision}" ||
            seen[$4]++) exit 1
    }
    END { if (seen["case-bc02-after-root-header"] != 1 ||
              seen["case-bc02-after-root-member"] != 1) exit 1 }
' "$base_dir/bc02-fault-activation-template.tsv" ||
    fail BC02_FAULT_ACTIVATION_SEMANTICS_INVALID

awk -F '	' '
    function valid(case_id, hook, phase, trigger_name) {
        if (case_id == "case-bc02-after-root-header")
            return hook == "hook-bc02-after-root-header" &&
                phase == "after-root-header" &&
                trigger_name == "trigger-bc02-after-root-header"
        if (case_id == "case-bc02-after-root-member")
            return hook == "hook-bc02-after-root-member" &&
                phase == "after-root-member" &&
                trigger_name == "trigger-bc02-after-root-member"
        return 0
    }
    {
        if (NF != 14 || $1 != "{run}" || $2 != "{namespace}" ||
            $3 != "{assertion}" || !valid($4, $5, $6, $10) ||
            $7 != "{nonce}" || $8 != "{implementation-revision}" ||
            $9 != "{activation-sha256}" || $11 != "{ddl-sha256}" ||
            $12 != "{error-literal-sha256}" ||
            $13 != "{when-predicate-sha256}" || $14 != "configured" ||
            seen[$4]++) exit 1
    }
    END { if (seen["case-bc02-after-root-header"] != 1 ||
              seen["case-bc02-after-root-member"] != 1) exit 1 }
' "$base_dir/bc02-fault-configuration-template.tsv" ||
    fail BC02_FAULT_CONFIGURATION_SEMANTICS_INVALID

awk -F '	' '
    function valid(case_id, attempt, error_id, marker) {
        if (case_id == "case-bc02-after-root-header")
            return attempt == "attempt-fault-header" &&
                error_id == "error-bc02-after-root-header" &&
                marker == "LICIUM_BC02_FAULT_AFTER_ROOT_HEADER"
        if (case_id == "case-bc02-after-root-member")
            return attempt == "attempt-fault-member" &&
                error_id == "error-bc02-after-root-member" &&
                marker == "LICIUM_BC02_FAULT_AFTER_ROOT_MEMBER"
        return 0
    }
    {
        if (NF != 17 || $1 != "{run}" || $2 != "{namespace}" ||
            $3 != "{assertion}" || !valid($4, $5, $16, $17) ||
            $6 != "{nonce}" || $7 != "{activation-sha256}" ||
            $8 != "{configuration-sha256}" || $9 != "{trigger-sha256}" ||
            $10 != "{command-sha256}" ||
            $11 != "{before-inventory-sha256}" ||
            $12 != "{after-inventory-sha256}" ||
            $13 != "{resolution-sha256}" ||
            $14 != "{data-version-before-sha256}" ||
            $15 != "{data-version-after-sha256}" || seen[$4]++) exit 1
    }
    END { if (seen["case-bc02-after-root-header"] != 1 ||
              seen["case-bc02-after-root-member"] != 1) exit 1 }
' "$base_dir/bc02-fault-binding-template.tsv" ||
    fail BC02_FAULT_BINDING_SEMANTICS_INVALID

awk -F '	' '
    function valid(case_id, hook, phase) {
        if (case_id == "case-bc02-after-root-header")
            return hook == "hook-bc02-after-root-header" &&
                phase == "after-root-header"
        if (case_id == "case-bc02-after-root-member")
            return hook == "hook-bc02-after-root-member" &&
                phase == "after-root-member"
        return 0
    }
    {
        if (NF != 11 || $1 != "{assertion}" || $2 != "{run}" ||
            $4 != "{namespace}" || $5 != "{nonce}" ||
            $6 != "{implementation-revision}" ||
            !valid($3, $7, $8) || $9 != "true" ||
            $10 != "{before-inventory-sha256}" ||
            $11 != "{after-inventory-sha256}" || seen[$3]++) exit 1
    }
    END { if (seen["case-bc02-after-root-header"] != 1 ||
              seen["case-bc02-after-root-member"] != 1) exit 1 }
' "$base_dir/bc02-fault-marker-template.tsv" ||
    fail BC02_FAULT_MARKER_SEMANTICS_INVALID

awk -F '	' '
    BEGIN {
        expected["error-bc02-after-root-header"] = "LICIUM_BC02_FAULT_AFTER_ROOT_HEADER" SUBSEP "injected-rollback" SUBSEP "70"
        expected["error-bc02-after-root-member"] = "LICIUM_BC02_FAULT_AFTER_ROOT_MEMBER" SUBSEP "injected-rollback" SUBSEP "70"
        expected["error-bc02-incomplete"] = "LICIUM_BC02_ROOT_INCOMPLETE" SUBSEP "handled-root-unavailable" SUBSEP "0"
    }
    {
        value = $2 SUBSEP $3 SUBSEP $4
        if (!($1 in expected) || value != expected[$1] || seen[$1]++) exit 1
    }
    END { for (id in expected) if (seen[id] != 1) exit 1 }
' "$base_dir/bc02-error-identities.tsv" ||
    fail BC02_ERROR_IDENTITY_INVALID

awk -F '	' '
    {
        if (NF != 11 || $1 != "{run}" || $2 != "{namespace}" ||
            $3 != "BC02_HEALTHY_RETRY" ||
            $4 != "case-bc02-incomplete-corrected" ||
            $5 != "correction-correction-02" ||
            $6 != "sut-correct-root-input" || $7 != "applied" ||
            $8 != "object-c" || $9 != "request-02" ||
            $10 != "root-02" || $11 != "{nonce-correction}") exit 1
        count++
    }
    END { if (count != 1) exit 1 }
' "$base_dir/bc02-correction-receipt-template.tsv" ||
    fail BC02_CORRECTION_RECEIPT_SEMANTICS_INVALID

awk -F '	' '
    {
        if (NF != 13 || $1 != "{run}" || $2 != "{namespace}" ||
            $3 != "BC02_HEALTHY_RETRY" ||
            $4 != "case-bc02-incomplete-corrected" ||
            $5 != "correction-correction-02" ||
            $6 != "sut-correct-root-input" || $7 != "source_object" ||
            $8 != "object-c" || $9 != "insert-only" ||
            $10 != "{guard-revision}" || $11 != "{guard-ddl-sha256}" ||
            $12 != "enforced" || $13 != "{nonce-correction}") exit 1
        count++
    }
    END { if (count != 1) exit 1 }
' "$base_dir/bc02-correction-write-guard-template.tsv" ||
    fail BC02_CORRECTION_GUARD_SEMANTICS_INVALID

awk -F '	' '
    {
        if (NF != 13 || $1 != "{run}" || $2 != "{namespace}" ||
            $3 != "{assertion}" ||
            $4 !~ /^case-bc02-after-root-(header|member)$/ ||
            $5 != "observer-01" ||
            $6 != "{observer-process-occurrence}" ||
            $7 != "{connection-nonce}" || $8 != "before-fault" ||
            $9 != "001" || $10 != "002" ||
            $11 != "{retry-sequence-or-dash}" ||
            $12 != "{transcript-sha256}" ||
            $13 != "held-through-required-stages" || seen[$4]++) exit 1
    }
    END { if (seen["case-bc02-after-root-header"] != 1 ||
              seen["case-bc02-after-root-member"] != 1) exit 1 }
' "$base_dir/bc02-observer-custody-template.tsv" ||
    fail BC02_OBSERVER_CUSTODY_SEMANTICS_INVALID

awk -F '	' '
    {
        if (NF != 10 || $1 != "{run}" || $2 != "{namespace}" ||
            $4 !~ /^case-bc02-after-root-(header|member)$/ ||
            $5 != "observer-01" || $7 != "data-version" ||
            $10 != "held") exit 1
        if ($6 == "fault-before") {
            if ($3 != "{assertion}" || $8 != "{value-before}" || $9 != "001")
                exit 1
        } else if ($6 == "fault-after") {
            if ($3 != "{assertion}" || $8 != "{value-after}" || $9 != "002")
                exit 1
        } else if ($6 == "retry-commit") {
            if ($3 != "BC02_POISONED_RETRY" ||
                $8 != "{value-retry}" || $9 != "003") exit 1
        } else exit 1
        seen[$4 SUBSEP $6]++
        count++
    }
    END {
        if (count != 6) exit 1
        for (case_id in seen) if (seen[case_id] != 1) exit 1
    }
' "$base_dir/bc02-data-version-receipt-template.tsv" ||
    fail BC02_DATA_VERSION_SEMANTICS_INVALID

awk -F '	' '
    {
        if (NF != 10 || $1 != "{run}" || $2 != "{namespace}" ||
            $6 != "request-02" || $7 != "root-02") exit 1
        if ($8 == "available") {
            if ($9 != "3/3" || $10 != "genesis-02") exit 1
        } else if ($8 == "root-unavailable") {
            if ($9 != "0/3" || $10 != "-") exit 1
        } else exit 1
        key = $3 SUBSEP $4 SUBSEP $5
        if (seen[key]++) exit 1
        count++
    }
    END { if (count != 23) exit 1 }
' "$base_dir/bc02-resolution-receipt-template.tsv" ||
    fail BC02_RESOLUTION_SEMANTICS_INVALID

for inventory in "$base_dir"/bc02-inventory-*.tsv; do
    [ "$(basename "$inventory")" = "bc02-inventory-map.tsv" ] && continue
    awk -F '	' '
        NF != 6 || $1 != "{scenario}" ||
            $2 !~ /^[a-z0-9-]+$/ ||
            $6 !~ /^[0-9][0-9][0-9][0-9]$/ { exit 1 }
        {
            if (seen[$2 SUBSEP $3 SUBSEP $4 SUBSEP $5]++) exit 1
        }
    ' "$inventory" || fail BC02_INVENTORY_TEMPLATE_SEMANTICS_INVALID
done

echo BC02_CONTRACT_VALID
