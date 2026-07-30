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
        fail BC04_REQUIREMENT_MISSING
    [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC04_REQUIREMENT_MODE_INVALID
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

document="$model_dir/BC04-SQLITE-SLICE.md"
cases="$base_dir/bc04-cases.tsv"
coverage="$base_dir/bc04-coverage-template.tsv"
inventory_after="$base_dir/bc04-inventory-after.tsv"
inventory_before="$base_dir/bc04-inventory-before.tsv"
inventory_reopened="$base_dir/bc04-inventory-reopened.tsv"
mutants="$base_dir/bc04-mutants.tsv"
normalized="$base_dir/bc04-normalized-contract.tsv"
raw="$base_dir/bc04-raw-template.tsv"
artifacts="$base_dir/bc04-runtime-artifacts.tsv"
scenario_ids="$base_dir/bc04-scenario-ids.tsv"
steps="$base_dir/bc04-steps.tsv"

for file in \
    "$document" "$cases" "$coverage" "$inventory_after" \
    "$inventory_before" "$inventory_reopened" "$mutants" \
    "$normalized" "$raw" "$artifacts" "$scenario_ids" "$steps"
do
    require_file "$file"
done

require_fields "$cases" 7 BC04_CASE_REGISTRY_INVALID
require_fields "$scenario_ids" 3 BC04_SCENARIO_ID_REGISTRY_INVALID
require_fields "$steps" 5 BC04_STEP_REGISTRY_INVALID
require_fields "$mutants" 4 BC04_MUTANT_REGISTRY_INVALID
require_fields "$artifacts" 5 BC04_RUNTIME_ARTIFACT_REGISTRY_INVALID
require_fields "$raw" 6 BC04_RAW_CONTRACT_INVALID
require_fields "$normalized" 6 BC04_NORMALIZED_CONTRACT_INVALID
require_fields "$coverage" 6 BC04_COVERAGE_CONTRACT_INVALID
require_fields "$inventory_before" 6 BC04_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_after" 6 BC04_INVENTORY_CONTRACT_INVALID
require_fields "$inventory_reopened" 6 BC04_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 == "BC04" {
        class[$3] = $4
        next
    }
    FILENAME == ARGV[2] && $2 == "BC04" {
        execution[$1] = $4 FS $6 FS $7 FS $10 FS $11 FS $14 FS $18
        next
    }
    FILENAME == ARGV[3] && $1 ~ /^neg-bc04-/ {
        negative[$1] = $2
        next
    }
    FILENAME == ARGV[4] {
        if (!($1 in class) || class[$1] != $2 ||
            !($1 in execution) ||
            execution[$1] != ($2 FS "sut-setup-bc04" FS $4 FS "oracle-" tolower_hyphen($1) FS "coverage-bc04" FS $7 FS $6) ||
            !($6 in negative) || negative[$6] != $1 ||
            seen_assertion[$1]++ || seen_negative[$6]++) exit 1
        count++
    }
    function tolower_hyphen(value) {
        value = tolower(value)
        gsub(/_/, "-", value)
        return value
    }
    END { if (count != 5) exit 1 }
' "$base_dir/scenarios.tsv" "$base_dir/execution-map.tsv" \
    "$base_dir/negative-identities.tsv" "$cases" ||
    fail BC04_CASE_REGISTRY_INVALID

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
        if (count != 5) exit 1
        for (key in expected)
            if (expected[key] != "" && !seen[expected[key]]) exit 1
    }
' "$cases" "$scenario_ids" ||
    fail BC04_SCENARIO_ID_REGISTRY_INVALID

cat >"$tmp/expected-steps" <<'EOF'
010	create	profile-create-namespace	normal	command-receipt
020	setup	sut-setup-bc04	ordinary	action-receipt
030	inventory-before	profile-inventory-bc04	ordinary	inventory-before
040	action	case-action	case-mode	action-receipt
050	observe-after	profile-observe-bc04	ordinary	raw-observation
060	inventory-after	profile-inventory-bc04	ordinary	inventory-after
070	reopen	profile-reopen-namespace	normal	command-receipt
080	inventory-reopened	profile-inventory-bc04	ordinary	inventory-reopened
090	destroy	profile-destroy-namespace	normal	command-receipt
100	normalize	runner-normalize-bc04	ordinary	normalized-observation
110	oracle	runner-oracle-bc04	ordinary	oracle-result
EOF
cmp -s "$tmp/expected-steps" "$steps" ||
    fail BC04_STEP_REGISTRY_INVALID

cat >"$tmp/expected-mutants" <<'EOF'
harness-bc04-noop	harness-mutant	missing-action-receipt	BC04_SUT_ACTION_MISSING
harness-bc04-observer-synthesis	observer-mutant	normalized-without-raw	BC04_COVERAGE_INVALID
harness-bc04-raw-post-seal-tamper	evidence-mutant	raw-post-seal-tamper	BC04_RAW_SEAL_INVALID
neg-bc04-ambient-fallback	counterfactual	detect-ambient-read-fallback	BC04_AMBIENT_FALLBACK_DETECTED
neg-bc04-exact-published-collapse	sut-mutant	detect-read-mode-collapse	BC04_EXACT_PUBLISHED_COLLAPSE_DETECTED
neg-bc04-exact-read	sut-mutant	detect-exact-read-substitution	BC04_EXACT_READ_SUBSTITUTED
neg-bc04-published-read	sut-mutant	detect-published-read-substitution	BC04_PUBLISHED_READ_SUBSTITUTED
neg-bc04-unaccepted-available	counterfactual	detect-unaccepted-read-availability	BC04_UNACCEPTED_AVAILABLE_DETECTED
EOF
cmp -s "$tmp/expected-mutants" "$mutants" ||
    fail BC04_MUTANT_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] && $1 ~ /^neg-bc04-/ {
        expected[$1] = $3 FS $4
        next
    }
    FILENAME == ARGV[2] && $1 ~ /^neg-bc04-/ {
        if (!($1 in expected) || ($2 FS $3) != expected[$1] ||
            seen[$1]++) exit 1
        count++
    }
    END { if (count != 5) exit 1 }
' "$base_dir/negative-identities.tsv" "$mutants" ||
    fail BC04_MUTANT_REGISTRY_INVALID

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
    fail BC04_RUNTIME_ARTIFACT_REGISTRY_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { scenario[$3] = 1; next }
    !($1 in scenario) || $2 !~ /^raw-[0-9][0-9][0-9]$/ ||
        seen[$1 FS $2]++ { exit 1 }
    { count++; per[$1]++ }
    END {
        if (count != 31) exit 1
        for (item in scenario) {
            expected = item ~ /unaccepted-available/ ? 7 : 6
            if (per[item] != expected) exit 1
        }
    }
' "$scenario_ids" "$raw" || fail BC04_RAW_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { scenario[$3] = 1; next }
    !($1 in scenario) || $2 !~ /^obs-[0-9][0-9][0-9]$/ ||
        seen[$1 FS $2]++ { exit 1 }
    { count++; per[$1]++ }
    END {
        if (count != 30) exit 1
        for (item in scenario) if (per[item] != 6) exit 1
    }
' "$scenario_ids" "$normalized" ||
    fail BC04_NORMALIZED_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { raw[$1 FS $2] = 1; next }
    FILENAME == ARGV[2] { normalized[$1 FS $2] = 1; next }
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
        if (count != 37) exit 1
        for (key in raw) if (!(key in raw_seen)) exit 1
        for (key in normalized)
            if (!(key in normalized_seen)) exit 1
    }
' "$raw" "$normalized" "$coverage" ||
    fail BC04_COVERAGE_CONTRACT_INVALID

awk -F '	' '
    FILENAME == ARGV[1] { scenario[$3] = 1; next }
    {
        if (!($1 in scenario) ||
            $2 !~ /^(repository|stored-root|root-value|publication|publication-decision)$/ ||
            seen[$1 FS $2 FS $3 FS $4 FS $5 FS $6]++) exit 1
        per[$1]++
        count++
    }
    END {
        if (count != 26) exit 1
        for (item in scenario) {
            expected = item ~ /collapse/ ? 8 :
                item ~ /(published-read|unaccepted-available)/ ? 6 : 3
            if (per[item] != expected) exit 1
        }
    }
' "$scenario_ids" "$inventory_before" ||
    fail BC04_INVENTORY_CONTRACT_INVALID
cmp -s "$inventory_before" "$inventory_after" ||
    fail BC04_INVENTORY_CONTRACT_INVALID
cmp -s "$inventory_before" "$inventory_reopened" ||
    fail BC04_INVENTORY_CONTRACT_INVALID

awk -F '	' '
    $1 ~ /ambient-fallback/ && $3 == "ambient-fallback" &&
        $4 == "root-ambient" && $6 == "absent" { ambient++ }
    $1 ~ /exact-published-collapse/ && $3 == "separation" &&
        $4 == "exact-published" && $6 == "false" { collapse++ }
    $1 ~ /exact-read/ && $3 == "read-result" &&
        $4 == "root-exact" && $6 == "exact-value" { exact++ }
    $1 ~ /published-read/ && $3 == "read-result" &&
        $4 == "root-published" && $6 == "published-value" { published++ }
    $1 ~ /unaccepted-available/ && $3 == "published-result" &&
        $6 == "absent" { unaccepted++ }
    $1 ~ /unaccepted-available/ && $3 == "published-secret-leaks" &&
        $6 == "0" { leaks++ }
    $3 == "persistent-effect" && $6 == "0" { unchanged++ }
    END {
        if (ambient != 1 || collapse != 1 || exact != 1 ||
            published != 1 || unaccepted != 1 || leaks != 1 ||
            unchanged != 4) exit 1
    }
' "$normalized" || fail BC04_NORMALIZED_CONTRACT_INVALID

if ! grep -F 'ReadExact(root)' "$document" >/dev/null ||
    ! grep -F 'ReadPublished(authority)' "$document" >/dev/null ||
    ! grep -F 'ambient current' "$document" >/dev/null ||
    ! grep -F 'conformance evidence' "$document" >/dev/null ||
    ! grep -F '三時点inventory' "$document" >/dev/null ||
    ! grep -F '83／83 full conformanceを主張しない' "$document" >/dev/null
then
    fail BC04_DOCUMENT_INVALID
fi

echo BC04_REQUIREMENTS_VALID
