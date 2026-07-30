#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

fail()
{
    echo "$1" >&2
    exit 1
}

required_files='
bc12-action-receipt-template.tsv
bc12-cases.tsv
bc12-command-receipt-template.tsv
bc12-coverage-template.tsv
bc12-mutants.tsv
bc12-normalized-template.tsv
bc12-oracle-contract.tsv
bc12-protection-subcases.tsv
bc12-raw-seal-template.tsv
bc12-raw-template.tsv
bc12-runtime-artifacts.tsv
bc12-scenario-ids.tsv
bc12-steps.tsv'

for name in $required_files
do
    file="$base_dir/$name"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC12_REQUIREMENT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC12_REQUIREMENT_MODE_INVALID
done

cases="$base_dir/bc12-cases.tsv"
scenario_ids="$base_dir/bc12-scenario-ids.tsv"
raw="$base_dir/bc12-raw-template.tsv"
normalized="$base_dir/bc12-normalized-template.tsv"
coverage="$base_dir/bc12-coverage-template.tsv"
mutants="$base_dir/bc12-mutants.tsv"
oracle="$base_dir/bc12-oracle-contract.tsv"
protection_subcases="$base_dir/bc12-protection-subcases.tsv"

awk -F '	' '
    NR == FNR {
        if ($1 == "BC12") global[$3] = $4
        next
    }
    NF != 8 || !($1 in global) || $2 !~ /^(positive|control)$/ ||
        $3 != "placement" || $4 != "sut-evaluate-placement" ||
        $8 !~ /^[13]$/ || seen[$1]++ { exit 1 }
    {
        expected = tolower($1)
        gsub(/_/, "-", expected)
        if ($5 != "oracle-" expected || $6 != "neg-" expected) exit 1
        if (global[$1] != $2) exit 1
        count++
    }
    $1 == "BC12_PROTECTION_BYPASS" && $8 == 3 { protection_subcases++ }
    END {
        if (count != 11 || protection_subcases != 1) exit 1
    }
' "$base_dir/scenarios.tsv" "$cases" ||
    fail BC12_CASE_REGISTRY_INVALID
LC_ALL=C sort -c "$cases" 2>/dev/null ||
    fail BC12_CASE_REGISTRY_INVALID

awk -F '	' '
    NR == FNR { case_id[$1] = "case-" tolower($1); next }
    NF != 3 || !($1 in case_id) || seen[$1]++ { exit 1 }
    {
        expected = tolower($1)
        gsub(/_/, "-", expected)
        if ($2 != "case-" expected ||
            $3 != expected "--case-" expected) exit 1
        count++
    }
    END { if (count != 11) exit 1 }
' "$cases" "$scenario_ids" ||
    fail BC12_SCENARIO_ID_REGISTRY_INVALID
LC_ALL=C sort -c "$scenario_ids" 2>/dev/null ||
    fail BC12_SCENARIO_ID_REGISTRY_INVALID

awk -F '	' '
    BEGIN {
        expected["witness"]="r-audit" FS "audit_hold" FS "witness" FS "w-audit" FS "forget-audit" FS "archive-audit" FS "mutant-detect-protection-bypass-witness" FS "BC12_PROTECTION_BYPASS_NOT_DETECTED"
        expected["conflict"]="r-conflict" FS "unresolved-conflict" FS "conflict" FS "conflict-1" FS "forget-conflict" FS "archive-conflict" FS "mutant-detect-protection-bypass-conflict" FS "BC12_PROTECTION_BYPASS_NOT_DETECTED"
        expected["publication"]="r-inflight" FS "pending-publication" FS "publication" FS "publication-1" FS "forget-inflight" FS "archive-inflight" FS "mutant-detect-protection-bypass-publication" FS "BC12_PROTECTION_BYPASS_NOT_DETECTED"
    }
    NF != 9 || $1 !~ /^(witness|conflict|publication)$/ ||
        $2 == "" || $3 == "" || $4 != $1 || $5 == "" ||
        $6 == "" || $7 == "" ||
        $8 != "mutant-detect-protection-bypass-" $1 ||
        $9 != "BC12_PROTECTION_BYPASS_NOT_DETECTED" ||
        seen[$1]++ || seen_root[$2]++ { exit 1 }
    {
        row[$1]=$2 FS $3 FS $4 FS $5 FS $6 FS $7 FS $8 FS $9
        count++
    }
    END {
        if (count != 3 || seen["witness"] != 1 ||
            seen["conflict"] != 1 || seen["publication"] != 1 ||
            row["witness"] != expected["witness"] ||
            row["conflict"] != expected["conflict"] ||
            row["publication"] != expected["publication"]) exit 1
    }
' "$protection_subcases" || fail BC12_PROTECTION_SUBCASE_REGISTRY_INVALID
LC_ALL=C sort -c "$protection_subcases" 2>/dev/null ||
    fail BC12_PROTECTION_SUBCASE_REGISTRY_INVALID

awk -F '	' '
    NF != 5 || $1 != sprintf("%03d", NR * 10) || seen[$2]++ { exit 1 }
    NR == 1 && ($2 != "create" || $3 != "profile-create-namespace") { exit 1 }
    NR == 2 && ($2 != "setup" || $3 != "sut-setup-bc12") { exit 1 }
    NR == 3 && ($2 != "action" || $3 != "case-operation" ||
        $4 != "case-mode" || $5 != "action-receipt") { exit 1 }
    NR == 4 && ($2 != "reopen" || $3 != "profile-reopen-namespace") { exit 1 }
    NR == 5 && ($2 != "observe" || $3 != "profile-observe-bc12") { exit 1 }
    NR == 6 && ($2 != "destroy" || $3 != "profile-destroy-namespace") { exit 1 }
    NR == 7 && ($2 != "normalize" || $3 != "runner-normalize-bc12") { exit 1 }
    NR == 8 && ($2 != "oracle" || $3 != "runner-oracle-bc12") { exit 1 }
    END { if (NR != 8) exit 1 }
' "$base_dir/bc12-steps.tsv" || fail BC12_STEP_REGISTRY_INVALID

[ "$(cat "$base_dir/bc12-action-receipt-template.tsv")" = \
    '{run}	{namespace}	{scenario}	{assertion}	{surface}	{operation}	{mode}	{evaluation-1}	{root-set-1}	{policy-input-1}	accepted	{nonce}' ] ||
    fail BC12_ACTION_RECEIPT_CONTRACT_INVALID
[ "$(cat "$base_dir/bc12-command-receipt-template.tsv")" = \
    '{run}	{namespace}	{assertion}	{phase}	{operation}	{mode}	{status}	{stdout-sha256}	{stdout-bytes}	{stderr-sha256}	{stderr-bytes}	{argv-sha256}' ] ||
    fail BC12_COMMAND_RECEIPT_CONTRACT_INVALID
[ "$(cat "$base_dir/bc12-raw-seal-template.tsv")" = \
    'raw-observations.tsv	100644	{sha256}	{bytes}	{run}	{namespace}	{scenario}	{action-receipt-sha256}	sealed-before-normalization' ] ||
    fail BC12_RAW_SEAL_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] {
        if (NF != 6 || $2 != sprintf("raw-%03d", ++raw_count[$1]) ||
            seen_raw[$1 FS $2]++) exit 1
        raw[$1 FS substr($2,5)] = $3 FS $4 FS $5 FS $6
        total_raw++
        next
    }
    FILENAME == ARGV[2] {
        if (NF != 6 || $2 != sprintf("obs-%03d", ++norm_count[$1]) ||
            seen_norm[$1 FS $2]++) exit 1
        norm[$1 FS substr($2,5)] = $3 FS $4 FS $5 FS $6
        total_norm++
        next
    }
    {
        key=$1 FS substr($2,5)
        norm_key=$4 FS substr($5,5)
        if (NF != 6 || !(key in raw) || !(norm_key in norm) ||
            key != norm_key || raw[key] != norm[norm_key] ||
            $3 != "record" || $6 != "all" || seen_cov[key]++) exit 1
        total_cov++
    }
    END {
        if (total_raw != 76 || total_norm != 76 || total_cov != 76 ||
            length(raw_count) != 11 || length(norm_count) != 11) exit 1
        for (key in raw)
            if (!(key in norm) || raw[key] != norm[key] ||
                seen_cov[key] != 1) exit 1
        for (scenario in raw_count) {
            expected = scenario ~ /-archive-bypass--/ ? 5 :
                scenario ~ /-canonical-unchanged--/ ? 5 :
                scenario ~ /-decision-provenance--/ ? 10 :
                scenario ~ /-derived-protection--/ ? 8 :
                scenario ~ /-eligibility-delete--/ ? 4 :
                scenario ~ /-forget-(bypass|consumed)--/ ? 5 :
                scenario ~ /-noop-evaluator--/ ? 6 :
                scenario ~ /-placement-decision--/ ? 8 :
                scenario ~ /-protection-bypass--/ ? 13 :
                scenario ~ /-window-bypass--/ ? 7 : -1
            if (raw_count[scenario] != expected ||
                norm_count[scenario] != expected) exit 1
        }
    }
' "$raw" "$normalized" "$coverage" ||
    fail BC12_COVERAGE_CONTRACT_INVALID

awk -F '	' '
    { rows[$1]++ }
    $3 == "surface" && $4 == "placement" &&
        $5 == "completeness" && $6 == "complete" { complete[$1]++ }

    $1 ~ /-archive-bypass--/ && $3 == "decision" &&
        $4 == "r-unverified" && $5 == "after" && $6 == "retain" { ab_decision++ }
    $1 ~ /-archive-bypass--/ && $3 == "decision" &&
        $4 == "r-unverified" && $5 == "blocker" &&
        $6 == "archive-unverified" { ab_blocker++ }
    $1 ~ /-archive-bypass--/ && $3 == "archive" &&
        $4 == "r-unverified" && $5 == "state" && $6 == "unverified" { ab_archive++ }

    $1 ~ /-canonical-unchanged--/ && $3 == "inventory" &&
        $4 == "before" && $5 == "canonical-digest" { before=$6; before_n++ }
    $1 ~ /-canonical-unchanged--/ && $3 == "inventory" &&
        $4 == "after" && $5 == "canonical-digest" { after=$6; after_n++ }
    $1 ~ /-canonical-unchanged--/ && $3 == "inventory" &&
        $4 == "comparison" && $5 == "symmetric-difference" && $6 == 0 { diff_zero++ }

    $1 ~ /-decision-provenance--/ && $3 == "provenance" &&
        $4 == "r-forgotten" && $5 == "forget" && $6 == "forget-root" { prov_forget++ }
    $1 ~ /-decision-provenance--/ && $3 == "provenance" &&
        $4 == "r-forgotten" && $5 == "archive" &&
        $6 == "archive-forgotten" { prov_archive++ }
    $1 ~ /-decision-provenance--/ && $3 == "provenance" &&
        $4 == "r-forgotten" && $5 == "policy-phase" && $6 == "after" { prov_phase++ }
    $1 ~ /-decision-provenance--/ && $3 == "provenance" &&
        $4 == "r-conflict" && $5 == "conflict" && $6 == "conflict-1" { prov_conflict++ }
    $1 ~ /-decision-provenance--/ && $3 == "provenance" &&
        $4 == "r-inflight" && $5 == "publication" &&
        $6 == "publication-1" { prov_publication++ }

    $1 ~ /-derived-protection--/ && $3 == "protection" {
        derived[$4 FS $5 FS $6]++
        derived_count++
    }

    $1 ~ /-eligibility-delete--/ && $3 == "decision" &&
        $4 == "r-forgotten" && $5 == "after" &&
        $6 == "release-eligible" { eligible++ }
    $1 ~ /-eligibility-delete--/ && $3 == "inventory" &&
        $4 == "r-forgotten" && $5 == "canonical-present" && $6 == 1 { eligible_present++ }

    $1 ~ /-forget-bypass--/ && $3 == "forget" &&
        $4 == "forget-root" && $5 == "status" && $6 == "rejected" { forget_rejected++ }
    $1 ~ /-forget-bypass--/ && $3 == "decision" &&
        $4 == "r-forgotten" && $5 == "after" && $6 == "retain" { forget_retain++ }
    $1 ~ /-forget-consumed--/ && $3 == "forget" &&
        $4 == "forget-root" && $5 == "status" && $6 == "accepted" { forget_accepted++ }
    $1 ~ /-forget-consumed--/ && $3 == "provenance" &&
        $4 == "r-forgotten" && $5 == "forget" && $6 == "forget-root" { forget_provenance++ }

    $1 ~ /-noop-evaluator--/ && $3 == "relation-family" {
        family[$4]=$6
        family_count++
    }
    $1 ~ /-placement-decision--/ && $3 == "decision" {
        decisions[$4 FS $5 FS $6]++
        decision_count++
    }
    $1 ~ /-protection-bypass--/ && $3 == "protection" {
        protected[$4 FS $5 FS $6]++
        protected_count++
    }
    $1 ~ /-protection-bypass--/ && $3 == "decision" {
        protected_decision[$4 FS $5 FS $6]++
        protected_decision_count++
    }
    $1 ~ /-protection-bypass--/ && $3 == "forget" &&
        $5 == "status" && $6 == "accepted" {
        protected_forget[$4]++
        protected_forget_count++
    }
    $1 ~ /-protection-bypass--/ && $3 == "archive" &&
        $5 == "state" && $6 == "verified" {
        protected_archive[$4]++
        protected_archive_count++
    }
    $1 ~ /-window-bypass--/ && $3 == "decision" {
        window[$5 FS $6]++
        window_count++
    }
    END {
        if (length(rows) != 11) exit 1
        for (s in rows) if (complete[s] != 1) exit 1
        if (ab_decision != 1 || ab_blocker != 1 || ab_archive != 1) exit 1
        if (before_n != 1 || after_n != 1 || before != after ||
            diff_zero != 1) exit 1
        if (prov_forget != 1 || prov_archive != 1 || prov_phase != 1 ||
            prov_conflict != 1 || prov_publication != 1) exit 1
        if (derived_count != 7 ||
            derived["r-audit" FS "audit_hold" FS "witness:w-audit"] != 1 ||
            derived["r-backup" FS "backup_hold" FS "witness:w-backup"] != 1 ||
            derived["r-conflict" FS "unresolved-conflict" FS "conflict:conflict-1"] != 1 ||
            derived["r-current" FS "current" FS "witness:w-current"] != 1 ||
            derived["r-inflight" FS "pending-publication" FS "publication:publication-1"] != 1 ||
            derived["r-pin" FS "pinned" FS "witness:w-pin"] != 1 ||
            derived["r-read" FS "read_grace" FS "witness:w-read"] != 1) exit 1
        if (eligible != 1 || eligible_present != 1 ||
            forget_rejected != 1 || forget_retain != 1 ||
            forget_accepted != 1 || forget_provenance != 1) exit 1
        if (family_count != 5 || family["protection"] != 7 ||
            family["decision"] != 7 || family["forget"] != 2 ||
            family["archive"] != 4 || family["inventory"] != 10) exit 1
        if (decision_count != 7 ||
            decisions["r-audit" FS "after" FS "retain:audit_hold"] != 1 ||
            decisions["r-conflict" FS "after" FS "retain:unresolved-conflict"] != 1 ||
            decisions["r-forgotten" FS "after" FS "release-eligible:-"] != 1 ||
            decisions["r-inflight" FS "after" FS "retain:pending-publication"] != 1 ||
            decisions["r-unverified" FS "after" FS "retain:archive-unverified"] != 1 ||
            decisions["r-forgotten" FS "before" FS "retain:policy-window"] != 1 ||
            decisions["r-forgotten" FS "boundary" FS "retain:policy-window"] != 1) exit 1
        if (protected_count != 3 || protected_decision_count != 3 ||
            protected_forget_count != 3 || protected_archive_count != 3 ||
            protected["r-audit" FS "audit_hold" FS "witness:w-audit"] != 1 ||
            protected["r-conflict" FS "unresolved-conflict" FS "conflict:conflict-1"] != 1 ||
            protected["r-inflight" FS "pending-publication" FS "publication:publication-1"] != 1 ||
            protected_decision["r-audit" FS "after" FS "retain:audit_hold"] != 1 ||
            protected_decision["r-conflict" FS "after" FS "retain:unresolved-conflict"] != 1 ||
            protected_decision["r-inflight" FS "after" FS "retain:pending-publication"] != 1 ||
            protected_forget["forget-audit"] != 1 ||
            protected_forget["forget-conflict"] != 1 ||
            protected_forget["forget-inflight"] != 1 ||
            protected_archive["r-audit"] != 1 ||
            protected_archive["r-conflict"] != 1 ||
            protected_archive["r-inflight"] != 1) exit 1
        if (window_count != 3 ||
            window["before" FS "retain:policy-window"] != 1 ||
            window["boundary" FS "retain:policy-window"] != 1 ||
            window["after" FS "release-eligible:-"] != 1) exit 1
    }
' "$normalized" || fail BC12_NORMALIZED_CONTRACT_INVALID

awk -F '	' '
    NR == FNR {
        if ($1 ~ /^neg-bc12-/) {
            expected_class[$1] = $3
            expected_mutation[$1] = $4
        }
        next
    }
    NF != 5 || $1 !~ /^(harness|neg)-bc12-/ || seen[$1]++ ||
        $3 !~ /^(harness-mutant|observer-mutant|evidence-mutant|sut-mutant|counterfactual)$/ ||
        $4 == "" || $5 == "" { exit 1 }
    $1 ~ /^neg-/ && ($2 != $1 || !($1 in expected_class) ||
        expected_class[$1] != $3 || expected_mutation[$1] != $4) { exit 1 }
    $1 ~ /^harness-/ && $2 != "-" { exit 1 }
    { count++ }
    END { if (count != 14) exit 1 }
' "$base_dir/negative-identities.tsv" "$mutants" ||
    fail BC12_MUTANT_REGISTRY_INVALID
LC_ALL=C sort -c "$mutants" 2>/dev/null ||
    fail BC12_MUTANT_REGISTRY_INVALID

awk -F '	' '
    NR == FNR { expected[$1] = $5; next }
    NF != 2 || !($1 in expected) || $2 != expected[$1] || seen[$1]++ { exit 1 }
    { count++ }
    END { if (count != 11) exit 1 }
' "$cases" "$oracle" || fail BC12_ORACLE_CONTRACT_INVALID
LC_ALL=C sort -c "$oracle" 2>/dev/null ||
    fail BC12_ORACLE_CONTRACT_INVALID

awk -F '	' '
    BEGIN {
        expected["action-receipts.tsv"]="12" FS "1" FS "bag" FS "direct-sut-stdout"
        expected["command-receipts.tsv"]="12" FS "6" FS "bag" FS "runner-custody"
        expected["coverage.tsv"]="6" FS "case-contract" FS "set" FS "runner-contract"
        expected["exclusions.tsv"]="6" FS "0" FS "set" FS "present-empty"
        expected["fault-markers.tsv"]="6" FS "0" FS "bag" FS "present-empty"
        expected["normalized-observations.tsv"]="6" FS "case-contract" FS "set" FS "runner-normalizer"
        expected["oracle-result.tsv"]="6" FS "1" FS "set" FS "runner-oracle"
        expected["pragma.tsv"]="6" FS "5" FS "bag" FS "adapter-stderr"
        expected["raw-observations.tsv"]="6" FS "case-contract" FS "bag" FS "adapter-and-sut"
        expected["raw-seal.tsv"]="9" FS "1" FS "set" FS "runner-custody"
    }
    NF != 5 || seen[$1]++ || $2 !~ /^(6|9|12)$/ ||
        $3 !~ /^(0|1|5|6|case-contract)$/ ||
        $4 !~ /^(bag|set)$/ || $5 == "" || !($1 in expected) ||
        ($2 FS $3 FS $4 FS $5) != expected[$1] { exit 1 }
    { count++ }
    END { if (count != 10) exit 1 }
' "$base_dir/bc12-runtime-artifacts.tsv" ||
    fail BC12_RUNTIME_ARTIFACT_REGISTRY_INVALID

echo BC12_REQUIREMENTS_VALID
