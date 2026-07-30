#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
profile_dir="$base_dir/profiles/sqlite-reference"
profile="$profile_dir/profile.tsv"
verify="$script_dir/verify-profile.sh"
verify_report="$script_dir/verify-profile-report.sh"
materialize="$script_dir/materialize-untested-report.sh"
materialize_full="$script_dir/materialize-sqlite-partial-assertions.sh"
bc06_cases="$base_dir/bc06-cases.tsv"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$verify" "$profile_dir" >/dev/null
"$materialize" "$tmp/baseline"
"$verify_report" "$profile" "$tmp/baseline/assertions.tsv" >/dev/null
echo "ok PROFILE_STRUCTURAL_BASELINE"

awk -F '	' -v OFS='	' '
    NR == FNR { bc06[$1] = $4; next }
    $3 in bc06 {
        $5 = "PASS"
        $6 = "ok"
        $7 = "bc06-sealed-runtime"
        if ($4 == "control") $8 = bc06[$3]
    }
    { print }
' "$bc06_cases" "$tmp/baseline/assertions.tsv" \
    >"$tmp/bc06-partial-assertions.tsv"
"$verify_report" "$profile" "$tmp/bc06-partial-assertions.tsv" >/dev/null
echo "ok PROFILE_BC06_PARTIAL_DISPOSITIONS"

"$materialize_full" "$tmp/full-assertions.tsv"
"$verify_report" "$profile" "$tmp/full-assertions.tsv" >/dev/null
echo "ok PROFILE_BC01_BC12_FULL_DISPOSITIONS"

empty_profile="$tmp/empty-profile.tsv"
: >"$empty_profile"
output=$("$verify_report" "$empty_profile" "$tmp/baseline/assertions.tsv" 2>&1) && {
    echo "empty profile disposition mapping unexpectedly passed" >&2
    exit 1
}
[ "$output" = "PROFILE_CAPABILITY_RESOLUTION_INVALID" ] || {
    echo "wrong empty-profile marker: $output" >&2
    exit 1
}
echo "ok PROFILE_CAPABILITY_RESOLUTION_INVALID"

empty_assertions="$tmp/empty-assertions.tsv"
: >"$empty_assertions"
output=$("$verify_report" "$profile" "$empty_assertions" 2>&1) && {
    echo "empty assertion coverage unexpectedly passed" >&2
    exit 1
}
[ "$output" = "PROFILE_ASSERTION_COVERAGE_INVALID" ] || {
    echo "wrong empty-assertion marker: $output" >&2
    exit 1
}
echo "ok PROFILE_ASSERTION_COVERAGE_INVALID"

sed -n '1p' "$tmp/baseline/assertions.tsv" >"$tmp/partial-assertions.tsv"
output=$("$verify_report" "$profile" "$tmp/partial-assertions.tsv" 2>&1) && {
    echo "partial assertion coverage unexpectedly passed" >&2
    exit 1
}
[ "$output" = "PROFILE_ASSERTION_COVERAGE_INVALID" ] || {
    echo "wrong partial-assertion marker: $output" >&2
    exit 1
}
echo "ok PROFILE_ASSERTION_COVERAGE_INVALID_PARTIAL"

sed -n '1p;1,$p' "$tmp/baseline/assertions.tsv" >"$tmp/duplicate-assertions.tsv"
output=$("$verify_report" "$profile" "$tmp/duplicate-assertions.tsv" 2>&1) && {
    echo "duplicate assertion coverage unexpectedly passed" >&2
    exit 1
}
[ "$output" = "PROFILE_ASSERTION_COVERAGE_INVALID" ] || {
    echo "wrong duplicate-assertion marker: $output" >&2
    exit 1
}
echo "ok PROFILE_ASSERTION_COVERAGE_INVALID_DUPLICATE"

cp -R "$base_dir" "$tmp/closure-base"
printf 'unlisted transitive runner file\n' \
    >"$tmp/closure-base/runner/closure-omission-mutant.tmp"
output=$(
    "$tmp/closure-base/runner/verify-profile.sh" \
        "$tmp/closure-base/profiles/sqlite-reference" 2>&1
) && {
    echo "unlisted closure file unexpectedly passed" >&2
    exit 1
}
[ "$output" = "PROFILE_CLOSURE_COVERAGE_INVALID" ] || {
    echo "wrong closure coverage marker: $output" >&2
    exit 1
}
echo "ok PROFILE_CLOSURE_COVERAGE_INVALID"

cp -R "$base_dir" "$tmp/closure-drift"
closure_digest="$tmp/closure-drift/runner/closure-digest.sh"
before=$("$closure_digest" closure-manifests/sut.paths)
sed '$a# profile self-test BC09 closure drift' \
    "$tmp/closure-drift/sqlite-reference/sut-bc09.sh" \
    >"$tmp/closure-drift/sut-bc09.mutant"
mv "$tmp/closure-drift/sut-bc09.mutant" \
    "$tmp/closure-drift/sqlite-reference/sut-bc09.sh"
after=$("$closure_digest" closure-manifests/sut.paths)
[ "$before" != "$after" ] || {
    echo "BC09 SUT bytes did not change SUT closure digest" >&2
    exit 1
}
"$tmp/closure-drift/runner/verify-profile.sh" \
    "$tmp/closure-drift/profiles/sqlite-reference" >/dev/null
echo "ok PROFILE_BC09_CLOSURE_DRIFT_BOUND"

expect_profile_marker() {
    marker=$1
    mutant=$2
    output=$(LICIUM_PROFILE_FILE="$mutant" "$verify" "$profile_dir" 2>&1) && {
        echo "profile mutant unexpectedly passed: $marker" >&2
        exit 1
    }
    [ "$output" = "$marker" ] || {
        echo "wrong profile marker: expected $marker, got $output" >&2
        exit 1
    }
    echo "ok $marker"
}

mutant="$tmp/missing-capability.tsv"
sed '/cap-bc12-placement/d' "$profile" >"$mutant"
expect_profile_marker PROFILE_CAPABILITY_INVENTORY_INVALID "$mutant"

mutant="$tmp/duplicate-capability.tsv"
sed -n '1p;1,$p' "$profile" >"$mutant"
expect_profile_marker PROFILE_SHAPE_INVALID "$mutant"

mutant="$tmp/unknown-capability.tsv"
sed '1s/cap-bc01-delivery/cap-unknown/' "$profile" |
    LC_ALL=C sort >"$mutant"
expect_profile_marker PROFILE_CAPABILITY_INVENTORY_INVALID "$mutant"

mutant="$tmp/order-invalid.tsv"
awk 'NR == 1 { first = $0; next } NR == 2 { print; print first; next } { print }' \
    "$profile" >"$mutant"
expect_profile_marker PROFILE_ORDER_INVALID "$mutant"

mutant="$tmp/unsupported.tsv"
sed 's/cap-bc01-delivery	status	supported/cap-bc01-delivery	status	unsupported/' \
    "$profile" >"$mutant"
output=$("$verify_report" "$mutant" "$tmp/baseline/assertions.tsv" 2>&1) && {
    echo "unsupported capability remained UNTESTED" >&2
    exit 1
}
[ "$output" = "PROFILE_UNSUPPORTED_NOT_UNAVAILABLE" ] || {
    echo "wrong unsupported marker: $output" >&2
    exit 1
}
echo "ok PROFILE_UNSUPPORTED_NOT_UNAVAILABLE"

awk -F '	' 'BEGIN { OFS = FS }
    $1 == "BC01" { $5 = "UNAVAILABLE"; $6 = "capability-unsupported" }
    { print }
' "$tmp/baseline/assertions.tsv" >"$tmp/unsupported-assertions.tsv"
"$verify_report" "$mutant" "$tmp/unsupported-assertions.tsv" >/dev/null
echo "ok PROFILE_UNSUPPORTED_UNAVAILABLE"

awk -F '	' 'BEGIN { OFS = FS }
    NR == 1 { $5 = "PASS"; $6 = "ok"; $7 = "evidence-placeholder" }
    { print }
' "$tmp/baseline/assertions.tsv" >"$tmp/planned-pass.tsv"
planned_profile="$tmp/planned-capability.tsv"
sed 's/cap-bc01-delivery	status	supported/cap-bc01-delivery	status	planned/' \
    "$profile" >"$planned_profile"
output=$("$verify_report" "$planned_profile" "$tmp/planned-pass.tsv" 2>&1) && {
    echo "planned capability passed" >&2
    exit 1
}
[ "$output" = "PROFILE_PLANNED_DISPOSITION_INVALID" ] || {
    echo "wrong planned marker: $output" >&2
    exit 1
}
echo "ok PROFILE_PLANNED_DISPOSITION_INVALID"

supported_fault_profile="$tmp/supported-cap-planned-fault.tsv"
sed 's/hook-bc02-after-root-header	status	supported/hook-bc02-after-root-header	status	planned/' \
    "$profile" >"$supported_fault_profile"
awk -F '	' 'BEGIN { OFS = FS }
    $3 == "BC02_PARTIAL_RESIDUE" {
        $5 = "PASS"
        $6 = "ok"
        $7 = "evidence-placeholder"
        $8 = "control-trigger"
    }
    { print }
' "$tmp/baseline/assertions.tsv" >"$tmp/planned-fault-pass.tsv"
output=$("$verify_report" "$supported_fault_profile" "$tmp/planned-fault-pass.tsv" 2>&1) && {
    echo "planned fault hook allowed PASS" >&2
    exit 1
}
[ "$output" = "PROFILE_FAULT_PLANNED_DISPOSITION_INVALID" ] || {
    echo "wrong planned-fault marker: $output" >&2
    exit 1
}
echo "ok PROFILE_FAULT_PLANNED_DISPOSITION_INVALID"

adapter="$profile_dir/run.sh"
adapter_db="$tmp/profile-adapter.db"
set +e
"$adapter" create namespace-a "$adapter_db" \
    >"$tmp/profile-create.out" 2>"$tmp/profile-create.err"
status=$?
set -e
[ "$status" -eq 0 ] || {
    echo "BC06-capable create wrong status: $status" >&2
    exit 1
}
[ "$(cat "$tmp/profile-create.out")" = \
    "status	create	accepted	namespace-a" ] || {
    echo "wrong create marker" >&2
    exit 1
}
[ "$(cat "$tmp/profile-create.err")" = "pragma	foreign-keys	1" ] || {
    echo "wrong create pragma marker" >&2
    exit 1
}
"$adapter" destroy namespace-a "$adapter_db" >/dev/null
echo "ok PROFILE_BC06_LIFECYCLE_AVAILABLE"

set +e
output=$(
    "$adapter" fault-operation "$tmp/fault.db" run-a namespace-a \
        BC02_PARTIAL_RESIDUE hook-bc02-after-root-header nonce-a 2>&1
)
status=$?
set -e
[ "$status" -eq 3 ] || {
    echo "planned fault-operation wrong status: $status" >&2
    exit 1
}
[ "$output" = \
    "status	fault-operation	planned	profile-operation-unimplemented" ] || {
    echo "wrong planned fault-operation marker: $output" >&2
    exit 1
}
echo "ok PROFILE_FIXED_VERB_PLANNED"

for unsafe in -x ../escape '/tmp/db;escape'
do
    set +e
    "$adapter" create namespace-a "$unsafe" >/dev/null 2>&1
    status=$?
    set -e
    [ "$status" -eq 2 ] || {
        echo "unsafe path wrong status: $unsafe -> $status" >&2
        exit 1
    }
done
echo "ok PROFILE_PATH_REJECTED"

set +e
"$adapter" unknown >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || {
    echo "unknown verb wrong status: $status" >&2
    exit 1
}
echo "ok PROFILE_UNKNOWN_VERB_REJECTED"

echo "profile controls passed"
