#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
model_dir=$(CDPATH= cd -- "$base_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail()
{
    echo "$1" >&2
    exit 1
}

require_file()
{
    file=$1
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC07_REQUIREMENT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC07_REQUIREMENT_MODE_INVALID
}

require_fields()
{
    file=$1
    fields=$2
    marker=$3
    awk -F '	' -v fields="$fields" '
        NF != fields { exit 1 }
        END { if (NR == 0) exit 1 }
    ' "$file" || fail "$marker"
}

document="$model_dir/BC07-SQLITE-SLICE.md"
action_receipt="$base_dir/bc07-action-receipt-template.tsv"
cases="$base_dir/bc07-cases.tsv"
coverage="$base_dir/bc07-coverage-template.tsv"
inventory_after="$base_dir/bc07-inventory-after.tsv"
inventory_before="$base_dir/bc07-inventory-before.tsv"
inventory_reopened="$base_dir/bc07-inventory-reopened.tsv"
mutants="$base_dir/bc07-mutants.tsv"
normalized="$base_dir/bc07-normalized-contract.tsv"
raw_seal="$base_dir/bc07-raw-seal-template.tsv"
raw="$base_dir/bc07-raw-template.tsv"
artifacts="$base_dir/bc07-runtime-artifacts.tsv"
scenario_ids="$base_dir/bc07-scenario-ids.tsv"
steps="$base_dir/bc07-steps.tsv"

for file in "$document" "$action_receipt" "$cases" "$coverage" \
    "$inventory_after" "$inventory_before" "$inventory_reopened" \
    "$mutants" "$normalized" "$raw_seal" "$raw" "$artifacts" \
    "$scenario_ids" "$steps"
do
    require_file "$file"
done

require_fields "$action_receipt" 12 BC07_ACTION_RECEIPT_CONTRACT_INVALID
require_fields "$cases" 7 BC07_CASE_REGISTRY_INVALID
require_fields "$coverage" 6 BC07_COVERAGE_CONTRACT_INVALID
require_fields "$inventory_after" 6 BC07_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_before" 6 BC07_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_reopened" 6 BC07_INVENTORY_CONTRACT_INVALID
require_fields "$mutants" 4 BC07_MUTANT_REGISTRY_INVALID
require_fields "$normalized" 6 BC07_NORMALIZED_CONTRACT_INVALID
require_fields "$raw_seal" 9 BC07_RAW_SEAL_CONTRACT_INVALID
require_fields "$raw" 6 BC07_RAW_CONTRACT_INVALID
require_fields "$artifacts" 5 BC07_RUNTIME_ARTIFACT_REGISTRY_INVALID
require_fields "$scenario_ids" 3 BC07_SCENARIO_ID_REGISTRY_INVALID
require_fields "$steps" 5 BC07_STEP_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 == "BC07" {
        class[$3] = $4
        next
    }
    FILENAME == ARGV[2] && $2 == "BC07" {
        execution[$1] = $4 FS $6 FS $7 FS $10 FS $11 FS $14 FS $18
        next
    }
    FILENAME == ARGV[3] && $1 ~ /^neg-bc07-/ {
        negative[$1] = $2 FS $4
        next
    }
    FILENAME == ARGV[4] {
        oracle = "oracle-" tolower_hyphen($1)
        if (!($1 in class) || class[$1] != $2 ||
            !($1 in execution) ||
            execution[$1] != ($2 FS "sut-setup-bc07" FS $4 FS oracle FS "coverage-bc07" FS $7 FS $6) ||
            !($6 in negative) ||
            negative[$6] != ($1 FS mutant_name($1)) ||
            seen_assertion[$1]++ || seen_negative[$6]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    function mutant_name(value) {
        return value == "BC07_EFFECT_101" ? "detect-effect-axis-mismatch" :
            value == "BC07_OBSERVATION_WITHOUT_TRANSITION" ?
                "detect-orphan-observation" :
            value == "BC07_ORDINARY_000" ?
                "detect-ordinary-axis-write" :
            value == "BC07_RECORD_IMPLIES_EFFECT" ?
                "detect-record-state-effect" :
            value == "BC07_RECORD_ONLY_010" ?
                "detect-record-axis-mismatch" :
                "detect-effect-result-rewrite"
    }
    END { if (count != 6) exit 1 }
' "$base_dir/scenarios.tsv" "$base_dir/execution-map.tsv" \
    "$base_dir/negative-identities.tsv" "$cases" ||
    fail BC07_CASE_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] {
        expected[$1 FS $3] = tolower_hyphen($1) "--" $3
        next
    }
    {
        key = $1 FS $2
        if (!(key in expected) || $3 != expected[key] ||
            seen[$3]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END { if (count != 6) exit 1 }
' "$cases" "$scenario_ids" ||
    fail BC07_SCENARIO_ID_REGISTRY_INVALID

cat >"$tmp/expected-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt
020	setup	sut-setup-bc07	ordinary	action-receipt
030	inventory-before	profile-inventory-bc07	ordinary	inventory-before
040	action	case-action	case-mode	action-receipt
050	observe-after	profile-observe-bc07	ordinary	raw-observation
060	inventory-after	profile-inventory-bc07	ordinary	inventory-after
070	reopen	profile-reopen-namespace	normal	command-receipt
080	inventory-reopened	profile-inventory-bc07	ordinary	inventory-reopened
090	destroy	profile-destroy-namespace	normal	command-receipt
100	normalize	runner-normalize-bc07	ordinary	normalized-observation
110	oracle	runner-oracle-bc07	ordinary	oracle-result
EOF
cmp -s "$tmp/expected-steps" "$steps" ||
    fail BC07_STEP_REGISTRY_INVALID

cat >"$tmp/expected-mutants" <<'EOF'
harness-bc07-noop	harness-mutant	missing-action-receipt	BC07_SUT_ACTION_MISSING
harness-bc07-observer-synthesis	observer-mutant	normalized-without-raw	BC07_COVERAGE_INVALID
harness-bc07-raw-post-seal-tamper	evidence-mutant	raw-post-seal-tamper	BC07_RAW_SEAL_INVALID
neg-bc07-effect-101	sut-mutant	detect-effect-axis-mismatch	BC07_EFFECT_AXIS_MISMATCH_DETECTED
neg-bc07-observation-without-transition	sut-mutant	detect-orphan-observation	BC07_ORPHAN_OBSERVATION_DETECTED
neg-bc07-ordinary-000	sut-mutant	detect-ordinary-axis-write	BC07_ORDINARY_AXIS_WRITE_DETECTED
neg-bc07-record-implies-effect	sut-mutant	detect-record-state-effect	BC07_RECORD_STATE_EFFECT_DETECTED
neg-bc07-record-only-010	sut-mutant	detect-record-axis-mismatch	BC07_RECORD_AXIS_MISMATCH_DETECTED
neg-bc07-result-rewrite	sut-mutant	detect-effect-result-rewrite	BC07_RESULT_REWRITE_DETECTED
EOF
cmp -s "$tmp/expected-mutants" "$mutants" ||
    fail BC07_MUTANT_REGISTRY_INVALID

cat >"$tmp/expected-artifacts" <<'EOF'
action-receipts.tsv	12	1	bag	direct-sut-stdout
command-receipts.tsv	12	9	bag	runner-custody
coverage.tsv	6	8	set	runner-contract
exclusions.tsv	6	0	set	present-empty
fault-markers.tsv	6	0	bag	present-empty
inventory-after.tsv	6	case-contract	set	adapter-observer
inventory-before.tsv	6	case-contract	set	adapter-observer
inventory-reopened.tsv	6	case-contract	set	adapter-observer
normalized-observations.tsv	6	8	set	runner-normalizer
oracle-result.tsv	6	1	set	runner-oracle
pragma.tsv	6	8	bag	adapter-stderr
raw-observations.tsv	6	8	bag	adapter-and-sut
raw-seal.tsv	9	1	set	runner-custody
EOF
cmp -s "$tmp/expected-artifacts" "$artifacts" ||
    fail BC07_RUNTIME_ARTIFACT_REGISTRY_INVALID

[ "$(cat "$action_receipt")" = \
    '{run}	{namespace}	{scenario}	{operation}	{mode}	{request}	{result}	{effect}	{expected-revision}	{axis-vector}	accepted	{nonce}' ] ||
    fail BC07_ACTION_RECEIPT_CONTRACT_INVALID
[ "$(cat "$raw_seal")" = \
    'raw-observations.tsv	100644	{sha256}	{bytes}	{run}	{namespace}	{scenario}	{action-receipt-sha256}	sealed-before-normalization' ] ||
    fail BC07_RAW_SEAL_CONTRACT_INVALID

awk -F '	' '
    $1 != "{scenario}" || $2 != sprintf("raw-%03d", NR) { exit 1 }
    END { if (NR != 8) exit 1 }
' "$raw" || fail BC07_RAW_CONTRACT_INVALID

awk -F '	' '
    $1 != "{scenario}" || $2 != sprintf("raw-%03d", NR) ||
        $3 != "record" || $4 != "{scenario}" ||
        $5 != sprintf("obs-%03d", NR) || $6 != "all" { exit 1 }
    END { if (NR != 8) exit 1 }
' "$coverage" || fail BC07_COVERAGE_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] {
        valid[$3] = 1
        next
    }
    {
        if (!($1 in valid)) exit 1
        if ($2 != sprintf("obs-%03d", ++per[$1]) ||
            seen[$1 FS $2]++) exit 1
        count++
    }
    $2 == "obs-003" {
        expected = $1 ~ /(effect-101|observation-without-transition|result-rewrite)/ ?
            "101" : $1 ~ /ordinary-000/ ? "000" : "010"
        if ($6 != expected) exit 1
        vector[$1] = 1
    }
    $2 == "obs-007" && $1 ~ /(effect-101|observation-without-transition|result-rewrite)/ {
        if ($6 != "equal") exit 1
        result_equal[$1] = 1
    }
    $2 == "obs-008" && $1 ~ /(effect-101|observation-without-transition|result-rewrite)/ {
        if ($6 != "complete") exit 1
        linkage[$1] = 1
    }
    END {
        if (count != 48) exit 1
        for (item in per)
            if (per[item] != 8 || !vector[item]) exit 1
        if (length(result_equal) != 3 || length(linkage) != 3) exit 1
    }
' "$scenario_ids" "$normalized" ||
    fail BC07_NORMALIZED_CONTRACT_INVALID

LC_ALL=C sort -c "$inventory_before" 2>/dev/null &&
    LC_ALL=C sort -c "$inventory_after" 2>/dev/null &&
    cmp -s "$inventory_after" "$inventory_reopened" ||
    fail BC07_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { valid[$3] = 1; next }
    !($1 in valid) || seen[FILENAME FS $1 FS $2 FS $3 FS $4 FS $5 FS $6]++ {
        exit 1
    }
    FILENAME == ARGV[2] { before[$1]++; total_before++; next }
    FILENAME == ARGV[3] { after[$1]++; total_after++; next }
    END {
        if (total_before != 39 || total_after != 53) exit 1
        for (item in valid) {
            expected_before = item ~ /(effect-101|observation-without-transition|result-rewrite)/ ? 8 : 5
            expected_after = item ~ /(effect-101|observation-without-transition|result-rewrite)/ ? 12 :
                item ~ /(record-implies-effect|record-only-010)/ ? 6 : 5
            if (before[item] != expected_before || after[item] != expected_after)
                exit 1
        }
    }
' "$scenario_ids" "$inventory_before" "$inventory_after" ||
    fail BC07_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 ~ /(effect-101|observation-without-transition|result-rewrite)/ &&
        $2 == "evaluation-result" { before[$1 FS $3 FS $4 FS $5 FS $6] = 1; next }
    FILENAME == ARGV[2] && $1 ~ /(effect-101|observation-without-transition|result-rewrite)/ &&
        $2 == "evaluation-result" { after[$1 FS $3 FS $4 FS $5 FS $6] = 1; next }
    END {
        if (length(before) != 6 || length(after) != 6) exit 1
        for (key in before) if (!(key in after)) exit 1
        for (key in after) if (!(key in before)) exit 1
    }
' "$inventory_before" "$inventory_after" ||
    fail BC07_INVENTORY_CONTRACT_INVALID

grep -Fq '46 scenarios、42 `PASS`／41 `UNTESTED`' "$document" &&
    grep -Fq '40 + 6 = 46' "$document" &&
    grep -Fq '83 - 42 = 41' "$document" ||
    fail BC07_DOCUMENT_INVALID

echo BC07_REQUIREMENTS_VALID
