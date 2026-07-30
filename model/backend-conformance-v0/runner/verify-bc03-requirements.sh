#!/bin/sh
set -eu

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
        fail BC03_REQUIREMENT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC03_REQUIREMENT_MODE_INVALID
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

document="$model_dir/BC03-SQLITE-SLICE.md"
cases="$base_dir/bc03-cases.tsv"
coverage="$base_dir/bc03-coverage-template.tsv"
inventory_after="$base_dir/bc03-inventory-after.tsv"
inventory_before="$base_dir/bc03-inventory-before.tsv"
inventory_reopened="$base_dir/bc03-inventory-reopened.tsv"
mutants="$base_dir/bc03-mutants.tsv"
normalized="$base_dir/bc03-normalized-contract.tsv"
raw="$base_dir/bc03-raw-template.tsv"
artifacts="$base_dir/bc03-runtime-artifacts.tsv"
scenario_ids="$base_dir/bc03-scenario-ids.tsv"
steps="$base_dir/bc03-steps.tsv"

for file in \
    "$document" "$cases" "$coverage" "$inventory_after" \
    "$inventory_before" "$inventory_reopened" "$mutants" \
    "$normalized" "$raw" "$artifacts" "$scenario_ids" "$steps"
do
    require_file "$file"
done

require_fields "$cases" 7 BC03_CASE_REGISTRY_INVALID
require_fields "$scenario_ids" 3 BC03_SCENARIO_ID_REGISTRY_INVALID
require_fields "$steps" 5 BC03_STEP_REGISTRY_INVALID
require_fields "$mutants" 4 BC03_MUTANT_REGISTRY_INVALID
require_fields "$artifacts" 5 BC03_RUNTIME_ARTIFACT_REGISTRY_INVALID
require_fields "$raw" 6 BC03_RAW_CONTRACT_INVALID
require_fields "$normalized" 6 BC03_NORMALIZED_CONTRACT_INVALID
require_fields "$coverage" 6 BC03_COVERAGE_CONTRACT_INVALID
require_fields "$inventory_before" 6 BC03_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_after" 6 BC03_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_reopened" 6 BC03_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 == "BC03" {
        class[$3] = $4
        next
    }
    FILENAME == ARGV[2] && $2 == "BC03" {
        execution[$1] = $4 FS $6 FS $7 FS $10 FS $11 FS $14 FS $18
        next
    }
    FILENAME == ARGV[3] && $1 ~ /^neg-bc03-/ {
        negative[$1] = $2
        next
    }
    FILENAME == ARGV[4] {
        if (!($1 in class) || class[$1] != $2 ||
            !($1 in execution) ||
            execution[$1] != ($2 FS "sut-setup-bc03" FS $4 FS "oracle-" tolower_hyphen($1) FS "coverage-bc03" FS $7 FS $6) ||
            !($6 in negative) || negative[$6] != $1 ||
            seen_assertion[$1]++ || seen_negative[$6]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END { if (count != 6) exit 1 }
' "$base_dir/scenarios.tsv" "$base_dir/execution-map.tsv" \
    "$base_dir/negative-identities.tsv" "$cases" ||
    fail BC03_CASE_REGISTRY_INVALID

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
    END {
        if (count != 6) exit 1
        for (key in expected)
            if (expected[key] != "" && !seen[expected[key]]) exit 1
    }
' "$cases" "$scenario_ids" ||
    fail BC03_SCENARIO_ID_REGISTRY_INVALID

cat >"$tmp/expected-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt
020	setup	sut-setup-bc03	ordinary	action-receipt
030	inventory-before	profile-inventory-bc03	ordinary	inventory-before
040	action	case-action	case-mode	action-receipt
050	observe-after	profile-observe-bc03	ordinary	raw-observation
060	inventory-after	profile-inventory-bc03	ordinary	inventory-after
070	reopen	profile-reopen-namespace	normal	command-receipt
080	inventory-reopened	profile-inventory-bc03	ordinary	inventory-reopened
090	destroy	profile-destroy-namespace	normal	command-receipt
100	normalize	runner-normalize-bc03	ordinary	normalized-observation
110	oracle	runner-oracle-bc03	ordinary	oracle-result
EOF
cmp -s "$tmp/expected-steps" "$steps" ||
    fail BC03_STEP_REGISTRY_INVALID

cat >"$tmp/expected-mutants" <<'EOF'
harness-bc03-noop	harness-mutant	missing-action-receipt	BC03_SUT_ACTION_MISSING
harness-bc03-observer-synthesis	observer-mutant	normalized-without-raw	BC03_COVERAGE_INVALID
harness-bc03-raw-post-seal-tamper	evidence-mutant	raw-post-seal-tamper	BC03_RAW_SEAL_INVALID
neg-bc03-accepted-head	sut-mutant	detect-missing-accepted-head	BC03_ACCEPTED_HEAD_MISSING
neg-bc03-publication-separate	sut-mutant	detect-publication-root-collapse	BC03_PUBLICATION_ROOT_COLLAPSE_DETECTED
neg-bc03-rejected-is-head	counterfactual	detect-rejected-head	BC03_REJECTED_HEAD_DETECTED
neg-bc03-stored-is-head	counterfactual	detect-stored-only-head	BC03_STORED_ROOT_HEAD_DETECTED
neg-bc03-stored-root-separate	sut-mutant	detect-stored-root-publication-collapse	BC03_STORED_ROOT_PUBLICATION_COLLAPSE_DETECTED
neg-bc03-wrong-authority-head	counterfactual	detect-wrong-authority-head	BC03_WRONG_AUTHORITY_HEAD_DETECTED
EOF
cmp -s "$tmp/expected-mutants" "$mutants" ||
    fail BC03_MUTANT_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 ~ /^neg-bc03-/ {
        expected[$1] = $3 FS $4
        next
    }
    FILENAME == ARGV[2] && $1 ~ /^neg-bc03-/ {
        if (!($1 in expected) || ($2 FS $3) != expected[$1] ||
            seen[$1]++) exit 1
        count++
    }
    END { if (count != 6) exit 1 }
' "$base_dir/negative-identities.tsv" "$mutants" ||
    fail BC03_MUTANT_REGISTRY_INVALID

cat >"$tmp/expected-artifacts" <<'EOF'
action-receipts.tsv	13	2	bag	direct-sut-stdout
command-receipts.tsv	12	9	bag	runner-custody
coverage.tsv	6	case-contract	set	runner-contract
exclusions.tsv	6	0	set	present-empty
fault-markers.tsv	6	0	bag	present-empty
inventory-after.tsv	6	case-contract	set	adapter-observer
inventory-before.tsv	6	case-contract	set	adapter-observer
inventory-reopened.tsv	6	case-contract	set	adapter-observer
normalized-observations.tsv	6	case-contract	set	runner-normalizer
oracle-result.tsv	6	1	set	runner-oracle
pragma.tsv	6	8	bag	adapter-stderr
raw-observations.tsv	6	case-contract	bag	adapter-and-sut
raw-seal.tsv	9	1	set	runner-custody
EOF
cmp -s "$tmp/expected-artifacts" "$artifacts" ||
    fail BC03_RUNTIME_ARTIFACT_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { scenario[$3] = 1; next }
    !($1 in scenario) || $2 !~ /^raw-[0-9][0-9][0-9]$/ ||
        seen[$1 FS $2]++ { exit 1 }
    { count++ }
    END { if (count != 43) exit 1 }
' "$scenario_ids" "$raw" || fail BC03_RAW_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { scenario[$3] = 1; next }
    !($1 in scenario) || $2 !~ /^obs-[0-9][0-9][0-9]$/ ||
        seen[$1 FS $2]++ { exit 1 }
    { count++ }
    END { if (count != 43) exit 1 }
' "$scenario_ids" "$normalized" ||
    fail BC03_NORMALIZED_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] {
        raw[$1 FS $2] = 1
        next
    }
    FILENAME == ARGV[2] {
        normalized[$1 FS $2] = 1
        next
    }
    {
        raw_key = $1 FS $2
        normalized_key = $4 FS $5
        if (!(raw_key in raw) || !(normalized_key in normalized) ||
            $3 != "record" || $6 != "all" ||
            seen[raw_key FS normalized_key]++) exit 1
        raw_seen[raw_key] = 1
        normalized_seen[normalized_key] = 1
        count++
    }
    END {
        if (count != 51) exit 1
        for (key in raw) if (!(key in raw_seen)) exit 1
        for (key in normalized)
            if (!(key in normalized_seen)) exit 1
    }
' "$raw" "$normalized" "$coverage" ||
    fail BC03_COVERAGE_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { scenario[$3] = 1; next }
    FILENAME == ARGV[2] {
        if (!($1 in scenario) || $2 == "authority-head" ||
            seen_before[$1 FS $2 FS $3 FS $4 FS $5 FS $6]++)
            exit 1
        before_by_scenario[$1]++
        before++
        next
    }
    {
        if (!($1 in scenario) || $2 == "authority-head" ||
            seen_after[$1 FS $2 FS $3 FS $4 FS $5 FS $6]++)
            exit 1
        after_by_scenario[$1]++
        after++
    }
    END {
        if (before != 10 || after != 24) exit 1
        for (item in scenario) {
            expected = item ~ /accepted-head|publication-separate|rejected-is-head|wrong-authority-head/ ? 5 : 2
            if (after_by_scenario[item] != expected) exit 1
            before_expected = item ~ /wrong-authority-head/ ? 5 : 1
            if (before_by_scenario[item] != before_expected) exit 1
        }
    }
' "$scenario_ids" "$inventory_before" "$inventory_after" ||
    fail BC03_INVENTORY_CONTRACT_INVALID
cmp -s "$inventory_after" "$inventory_reopened" ||
    fail BC03_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    $1 == "bc03-accepted-head--case-bc03-accepted" &&
        $3 == "authority-head" && $4 == "authority-main" &&
        $5 == "root" && $6 == "root-accepted" { accepted++ }
    $1 == "bc03-publication-separate--case-bc03-accepted" &&
        $3 == "separation" && $5 == "object-kind" {
        separation[$6]++
    }
    $1 == "bc03-rejected-is-head--case-bc03-rejected" &&
        $3 == "publication-decision" && $6 == "rejected" { rejected++ }
    $1 == "bc03-stored-root-separate--case-bc03-stored" &&
        $3 == "publication-by-root" && $6 == "absent" { stored++ }
    $1 == "bc03-wrong-authority-head--case-bc03-wrong-authority" &&
        $3 == "authority-head" && $4 == "authority-other" &&
        $6 == "root-other" { other++ }
    $3 == "authority-head" && $4 == "authority-main" &&
        ($6 == "root-rejected" || $6 == "root-stored" ||
         $6 == "root-other") { forbidden++ }
    END {
        if (accepted != 1 || separation["stored-root"] != 1 ||
            separation["publication"] != 1 || rejected != 1 ||
            stored != 1 || other != 1 || forbidden != 0) exit 1
    }
' "$normalized" || fail BC03_NORMALIZED_CONTRACT_INVALID

if ! grep -F 'stored Root' "$document" >/dev/null ||
    ! grep -F 'authority-scoped Head' "$document" >/dev/null ||
    ! grep -F 'このsliceでは永続tableにしない' "$document" >/dev/null ||
    ! grep -F 'conformance evidenceとして流用しない' "$document" >/dev/null ||
    ! grep -F 'canonical' "$document" >/dev/null ||
    ! grep -F '83／83 full conformanceを主張しない' "$document" >/dev/null
then
    fail BC03_DOCUMENT_INVALID
fi

echo BC03_REQUIREMENTS_VALID
