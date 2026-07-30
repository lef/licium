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
        fail BC10_REQUIREMENT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC10_REQUIREMENT_MODE_INVALID
}

require_fields()
{
    file=$1
    fields=$2
    rows=$3
    marker=$4
    awk -F '	' -v fields="$fields" -v rows="$rows" '
        NF != fields { exit 1 }
        {
            for (field = 1; field <= NF; field++)
                if ($field == "") exit 1
        }
        END { if (NR != rows) exit 1 }
    ' "$file" || fail "$marker"
}

document="$model_dir/BC10-SQLITE-SLICE.md"
action_receipt="$base_dir/bc10-action-receipt-template.tsv"
cases="$base_dir/bc10-cases.tsv"
command_receipt="$base_dir/bc10-command-receipt-template.tsv"
coverage="$base_dir/bc10-coverage-template.tsv"
mutants="$base_dir/bc10-mutants.tsv"
normalized="$base_dir/bc10-normalized-template.tsv"
oracle="$base_dir/bc10-oracle-contract.tsv"
raw="$base_dir/bc10-raw-template.tsv"
raw_seal="$base_dir/bc10-raw-seal-template.tsv"
runtime_artifacts="$base_dir/bc10-runtime-artifacts.tsv"
scenario_ids="$base_dir/bc10-scenario-ids.tsv"
steps="$base_dir/bc10-steps.tsv"

for file in "$document" "$action_receipt" "$cases" "$command_receipt" \
    "$coverage" "$mutants" "$normalized" "$oracle" "$raw" "$raw_seal" \
    "$runtime_artifacts" "$scenario_ids" "$steps"
do
    require_file "$file"
done

require_fields "$action_receipt" 12 1 BC10_ACTION_RECEIPT_CONTRACT_INVALID
require_fields "$cases" 8 8 BC10_CASE_REGISTRY_INVALID
require_fields "$command_receipt" 12 1 BC10_COMMAND_RECEIPT_CONTRACT_INVALID
require_fields "$coverage" 6 74 BC10_COVERAGE_CONTRACT_INVALID
require_fields "$mutants" 5 12 BC10_MUTANT_REGISTRY_INVALID
require_fields "$normalized" 6 74 BC10_NORMALIZED_CONTRACT_INVALID
require_fields "$oracle" 7 9 BC10_ORACLE_CONTRACT_INVALID
require_fields "$raw" 6 74 BC10_RAW_CONTRACT_INVALID
require_fields "$raw_seal" 9 1 BC10_RAW_SEAL_CONTRACT_INVALID
require_fields "$runtime_artifacts" 5 10 BC10_RUNTIME_ARTIFACT_REGISTRY_INVALID
require_fields "$scenario_ids" 3 8 BC10_SCENARIO_ID_REGISTRY_INVALID
require_fields "$steps" 5 8 BC10_STEP_REGISTRY_INVALID

# Bind every local case to the accepted global scenario, execution, and
# negative-identity registries.  The local source-evidence label is descriptive
# traceability; the executable operation/oracle/negative tuple is exact.
awk -F '	' '
    FILENAME == ARGV[1] && $1 == "BC10" {
        class[$3] = $4
        next
    }
    FILENAME == ARGV[2] && $2 == "BC10" {
        execution[$1] = $4 FS $6 FS $7 FS $10 FS $11 FS $14 FS $17 FS $18
        next
    }
    FILENAME == ARGV[3] && $1 ~ /^neg-bc10-/ {
        negative[$1] = $2 FS $3 FS $4
        next
    }
    FILENAME == ARGV[4] {
        expected = $2 FS "sut-setup-bc10" FS $4 FS $5 FS \
            "coverage-bc10" FS "PASS" FS negative_type($1) FS $6
        if (!($1 in class) || class[$1] != $2 ||
            !($1 in execution) ||
            execution[$1] != expected ||
            !($6 in negative) ||
            negative[$6] != ($1 FS negative_type($1) FS negative_name($1)) ||
            $3 !~ /^(explanation|replay|result|view)$/ ||
            $7 == "" ||
            $8 != ($1 == "BC10_VIEW_LEAK" ? 2 : 1) ||
            seen_assertion[$1]++ || seen_negative[$6]++) exit 1
        count++
    }
    function negative_type(assertion) {
        return assertion ~ /_LEAK$/ ? "observer-mutant" : "sut-mutant"
    }
    function negative_name(assertion) {
        return assertion == "BC10_EXPLANATION_CLOSED" ?
            "detect-explanation-closure-loss" :
            assertion == "BC10_EXPLANATION_LEAK" ?
            "detect-filtered-explanation-leak" :
            assertion == "BC10_REPLAY_CLOSED" ?
            "detect-replay-closure-loss" :
            assertion == "BC10_REPLAY_LEAK" ?
            "detect-filtered-replay-leak" :
            assertion == "BC10_RESULT_CLOSED" ?
            "detect-result-closure-loss" :
            assertion == "BC10_RESULT_LEAK" ?
            "detect-filtered-result-leak" :
            assertion == "BC10_VIEW_CLOSED" ?
            "detect-view-closure-loss" :
            "detect-filtered-view-leak"
    }
    END {
        if (count != 8 || length(seen_assertion) != 8 ||
            length(seen_negative) != 8) exit 1
    }
' "$base_dir/scenarios.tsv" "$base_dir/execution-map.tsv" \
    "$base_dir/negative-identities.tsv" "$cases" ||
    fail BC10_CASE_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 == "BC10" { valid[$3] = 1; next }
    FILENAME == ARGV[2] {
        expected_case = "case-" tolower_hyphen($1)
        expected_scenario = tolower_hyphen($1) "--" expected_case
        if (!($1 in valid) || $2 != expected_case ||
            $3 != expected_scenario || seen[$1]++ || seen_id[$3]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END { if (count != 8) exit 1 }
' "$base_dir/scenarios.tsv" "$scenario_ids" ||
    fail BC10_SCENARIO_ID_REGISTRY_INVALID

cat >"$tmp/expected-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt
020	setup	sut-setup-bc10	ordinary	command-receipt
030	action	case-operation	case-mode	action-receipt
040	reopen	profile-reopen-namespace	normal	command-receipt
050	observe	profile-observe-bc10	ordinary	raw-observation
060	destroy	profile-destroy-namespace	normal	command-receipt
070	normalize	runner-normalize-bc10	ordinary	normalized-observation
080	oracle	runner-oracle-bc10	ordinary	oracle-result
EOF
cmp -s "$tmp/expected-steps" "$steps" ||
    fail BC10_STEP_REGISTRY_INVALID

[ "$(cat "$action_receipt")" = \
    '{run}	{namespace}	{scenario}	{assertion}	{surface}	{operation}	{mode}	request-1	root-1	definition-1	accepted	{nonce}' ] ||
    fail BC10_ACTION_RECEIPT_CONTRACT_INVALID
[ "$(cat "$command_receipt")" = \
    '{run}	{namespace}	{assertion}	{phase}	{operation}	{mode}	{status}	{stdout-sha256}	{stdout-bytes}	{stderr-sha256}	{stderr-bytes}	{argv-sha256}' ] ||
    fail BC10_COMMAND_RECEIPT_CONTRACT_INVALID
[ "$(cat "$raw_seal")" = \
    'raw-observations.tsv	100644	{sha256}	{bytes}	{run}	{namespace}	{scenario}	{action-receipt-sha256}	sealed-before-normalization' ] ||
    fail BC10_RAW_SEAL_CONTRACT_INVALID

# Raw and normalized contracts are nonempty surface projections.  Coverage is
# an exact one-to-one identity mapping and therefore cannot hide an extra leak
# row or synthesize missing provenance.
awk -F '	' '
    FILENAME == ARGV[1] {
        if ($2 != sprintf("raw-%03d", ++raw_count[$1]) ||
            seen_raw[$1 FS $2]++) exit 1
        raw[$1 FS substr($2, 5)] = $3 FS $4 FS $5 FS $6
        total_raw++
        next
    }
    FILENAME == ARGV[2] {
        if ($2 != sprintf("obs-%03d", ++normalized_count[$1]) ||
            seen_normalized[$1 FS $2]++) exit 1
        normalized[$1 FS substr($2, 5)] = $3 FS $4 FS $5 FS $6
        total_normalized++
        next
    }
    {
        key = $1 FS substr($2, 5)
        normalized_key = $4 FS substr($5, 5)
        if (!(key in raw) || !(normalized_key in normalized) ||
            key != normalized_key || raw[key] != normalized[normalized_key] ||
            $3 != "record" || $6 != "all" ||
            seen_coverage[key]++) exit 1
        total_coverage++
    }
    END {
        if (total_raw != 74 || total_normalized != 74 ||
            total_coverage != 74) exit 1
        for (key in raw)
            if (!(key in normalized) || raw[key] != normalized[key] ||
                seen_coverage[key] != 1) exit 1
        for (key in normalized) if (!(key in raw)) exit 1
        for (scenario in raw_count) {
            expected = scenario ~ /replay-/ ? 13 :
                scenario ~ /result-/ ? 10 : 7
            if (raw_count[scenario] != expected ||
                normalized_count[scenario] != expected) exit 1
        }
        if (length(raw_count) != 8 || length(normalized_count) != 8)
            exit 1
    }
' "$raw" "$normalized" "$coverage" ||
    fail BC10_COVERAGE_CONTRACT_INVALID

awk -F '	' '
    $3 == "surface" && $5 == "completeness" && $6 == "complete" {
        complete[$1]++
    }
    $3 == "leak" {
        if ($6 != 0) exit 1
        leak[$1]++
    }
    $1 ~ /result-/ && $3 == "pinned-input" { result_role[$1]++ }
    $1 ~ /result-/ && $3 == "selection" && $5 == "member" &&
        $6 == "member-public" { result_member[$1]++ }
    $1 ~ /result-/ && $3 == "selection" && $5 == "value" &&
        $6 == "public-a" { result_value[$1]++ }
    $1 ~ /view-/ && $3 == "provenance" { view_provenance[$1]++ }
    $1 ~ /view-/ && $3 == "selection" && $5 == "member" &&
        $6 == "member-public" { view_member[$1]++ }
    $1 ~ /view-/ && $3 == "selection" && $5 == "value" &&
        $6 == "public-a" { view_value[$1]++ }
    $1 ~ /replay-/ && $3 == "pinned-input" { replay_role[$1]++ }
    $1 ~ /replay-/ && $3 == "replay" &&
        $5 == "symmetric-difference" && $6 == 0 { replay_equal[$1]++ }
    $1 ~ /replay-/ && $3 == "selection" && $6 == "public-a" {
        replay_value[$1]++
    }
    $1 ~ /replay-/ && $3 == "provenance" &&
        $5 == "replayed-result" && $6 == "replay-result-1" {
        replayed_result[$1]++
    }
    $1 ~ /explanation-/ && $3 == "explanation" && $5 == "edge" {
        explanation_edge[$1]++
    }
    END {
        for (scenario in complete) {
            if (complete[scenario] != 1 || leak[scenario] < 1) exit 1
            if (scenario ~ /result-/ &&
                (result_role[scenario] != 5 ||
                 result_member[scenario] != 1 ||
                 result_value[scenario] != 1)) exit 1
            if (scenario ~ /view-/ &&
                (view_provenance[scenario] != 3 ||
                 view_member[scenario] != 1 ||
                 view_value[scenario] != 1)) exit 1
            if (scenario ~ /replay-/ &&
                (replay_role[scenario] != 5 ||
                 replay_equal[scenario] != 1 ||
                 replay_value[scenario] != 1 ||
                 replayed_result[scenario] != 1 ||
                 leak[scenario] != 3)) exit 1
            if (scenario ~ /explanation-/ &&
                explanation_edge[scenario] != 5) exit 1
        }
        if (length(complete) != 8) exit 1
    }
' "$normalized" || fail BC10_NORMALIZED_CONTRACT_INVALID

cat >"$tmp/expected-mutants" <<'EOF'
harness-bc10-noop	-	harness-mutant	missing-action-receipt	BC10_SUT_ACTION_MISSING
harness-bc10-observer-synthesis	-	observer-mutant	normalized-without-raw	BC10_COVERAGE_INVALID
harness-bc10-raw-post-seal	-	evidence-mutant	raw-post-seal-tamper	BC10_RAW_SEAL_INVALID
neg-bc10-explanation-closed	neg-bc10-explanation-closed	sut-mutant	explanation-member-loss	BC10_EXPLANATION_CLOSURE_LOSS_DETECTED
neg-bc10-explanation-leak	neg-bc10-explanation-leak	observer-mutant	explanation-secret-leak	BC10_EXPLANATION_SECRET_LEAK_DETECTED
neg-bc10-replay-closed	neg-bc10-replay-closed	sut-mutant	replay-closure-loss	BC10_REPLAY_CLOSURE_LOSS_DETECTED
neg-bc10-replay-leak	neg-bc10-replay-leak	observer-mutant	replay-executor-metadata	BC10_REPLAY_METADATA_LEAK_DETECTED
neg-bc10-result-closed	neg-bc10-result-closed	sut-mutant	result-closure-loss	BC10_RESULT_CLOSURE_LOSS_DETECTED
neg-bc10-result-leak	neg-bc10-result-leak	observer-mutant	result-secret-leak	BC10_RESULT_SECRET_LEAK_DETECTED
neg-bc10-view-closed	neg-bc10-view-closed	sut-mutant	view-member-loss	BC10_VIEW_CLOSURE_LOSS_DETECTED
neg-bc10-view-leak-provenance	neg-bc10-view-leak	observer-mutant	view-provenance-loss	BC10_VIEW_PROVENANCE_LOSS_DETECTED
neg-bc10-view-leak-secret	neg-bc10-view-leak	observer-mutant	view-secret-leak	BC10_VIEW_SECRET_LEAK_DETECTED
EOF
cmp -s "$tmp/expected-mutants" "$mutants" ||
    fail BC10_MUTANT_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] {
        mutant[$1] = $5
        next
    }
    {
        if (!($6 in mutant) || mutant[$6] != $7 ||
            $2 != "oracle-" tolower_hyphen($1) ||
            $3 !~ /^(closure|exact|zero)$/ ||
            seen[$6]++) exit 1
        assertion[$1]++
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END {
        if (count != 9 || assertion["BC10_VIEW_LEAK"] != 2 ||
            length(assertion) != 8) exit 1
    }
' "$mutants" "$oracle" || fail BC10_ORACLE_CONTRACT_INVALID

cat >"$tmp/expected-artifacts" <<'EOF'
action-receipts.tsv	12	1	bag	direct-sut-stdout
command-receipts.tsv	12	6	bag	runner-custody
coverage.tsv	6	case-contract	set	runner-contract
exclusions.tsv	6	0	set	present-empty
fault-markers.tsv	6	0	bag	present-empty
normalized-observations.tsv	6	case-contract	set	runner-normalizer
oracle-result.tsv	6	1	set	runner-oracle
pragma.tsv	6	5	bag	adapter-stderr
raw-observations.tsv	6	case-contract	bag	adapter-and-sut
raw-seal.tsv	9	1	set	runner-custody
EOF
cmp -s "$tmp/expected-artifacts" "$runtime_artifacts" ||
    fail BC10_RUNTIME_ARTIFACT_REGISTRY_INVALID

for file in "$cases" "$coverage" "$mutants" "$normalized" "$oracle" "$raw" \
    "$runtime_artifacts" "$scenario_ids" "$steps"
do
    LC_ALL=C sort -c "$file" 2>/dev/null ||
        fail BC10_REQUIREMENT_ORDER_INVALID
done

grep -Fq '68 scenarios、64 `PASS`／19 `UNTESTED`' "$document" &&
    grep -Fq '60 + 8 = 68' "$document" &&
    grep -Fq '83 - 64 = 19' "$document" &&
    grep -Fq 'semantic control receiptsは九件' "$document" ||
    fail BC10_DOCUMENT_INVALID

echo BC10_REQUIREMENTS_VALID
