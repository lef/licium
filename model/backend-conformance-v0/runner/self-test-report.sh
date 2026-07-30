#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
materialize="$script_dir/materialize-untested-report.sh"
verify="$script_dir/verify-report.sh"
full_gate="$script_dir/verify-full-gate.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

make_case() {
    name=$1
    dir="$tmp/$name"
    mkdir -p "$dir"
    "$materialize" "$dir"
    printf '%s\n' "$dir"
}

expect_marker() {
    marker=$1
    dir=$2
    output=$("$verify" "$dir" 2>&1) && {
        echo "self-test unexpectedly passed: $marker" >&2
        exit 1
    }
    [ "$output" = "$marker" ] || {
        echo "self-test wrong marker: expected $marker, got $output" >&2
        exit 1
    }
    echo "ok $marker"
}

make_all_pass() {
    dir=$1
    awk -F '	' 'BEGIN { OFS = FS }
        {
            $5 = "PASS"
            $6 = "ok"
            $7 = "evidence-placeholder"
            if ($4 == "control") $8 = "control-trigger"
            print
        }
    ' "$dir/assertions.tsv" >"$dir/assertions.new"
    mv "$dir/assertions.new" "$dir/assertions.tsv"
    {
        printf 'count\tglobal\tassertion-count\t83\n'
        printf 'count\tdisposition\tPASS\t83\n'
        printf 'count\tdisposition\tFAIL\t0\n'
        printf 'count\tdisposition\tUNTESTED\t0\n'
        printf 'count\tdisposition\tUNAVAILABLE\t0\n'
        printf 'count\tdisposition\tINVALID\t0\n'
        for bc in BC01 BC02 BC03 BC04 BC05 BC06 BC07 BC08 BC09 BC10 BC11 BC12
        do
            printf 'group\t%s\tdisposition\tPASS\n' "$bc"
        done
        printf 'overall\tglobal\tdisposition\tPASS\n'
    } >"$dir/report.tsv"
}

baseline=$(make_case baseline)
"$verify" "$baseline" >/dev/null
full_output=$("$full_gate" "$baseline" 2>&1) && {
    echo "all-UNTESTED full gate unexpectedly passed" >&2
    exit 1
}
[ "$full_output" = "FULL_GATE_NONPASS" ] || {
    echo "wrong full-gate marker: $full_output" >&2
    exit 1
}
echo "ok FULL_GATE_NONPASS"

dir=$(make_case all-pass-fail-closed)
make_all_pass "$dir"
"$verify" "$dir" >/dev/null
full_output=$("$full_gate" "$dir" 2>&1) && {
    echo "all-PASS report bypassed unimplemented evidence validator" >&2
    exit 1
}
[ "$full_output" = "FULL_GATE_SESSION_INVALID" ] || {
    echo "wrong all-PASS full-gate marker: $full_output" >&2
    exit 1
}
echo "ok FULL_GATE_SESSION_INVALID"

dir=$(make_case report-extension)
printf 'binding\tglobal\tprofile-sha256\tdeadbeef\n' >>"$dir/report.tsv"
"$verify" "$dir" >/dev/null
echo "ok REPORT_EXTENSION"

schema_mutant="$tmp/report-schema-mutant.tsv"
cp "$script_dir/../report-schema.tsv" "$schema_mutant"
sed 's/report.tsv	4/report.tsv	2/' "$schema_mutant" >"$schema_mutant.new"
mv "$schema_mutant.new" "$schema_mutant"
schema_output=$(LICIUM_REPORT_SCHEMA="$schema_mutant" "$verify" "$baseline" 2>&1) && {
    echo "schema mutant unexpectedly passed" >&2
    exit 1
}
[ "$schema_output" = "REPORT_SCHEMA_INVALID" ] || {
    echo "wrong schema marker: $schema_output" >&2
    exit 1
}
echo "ok REPORT_SCHEMA_INVALID"

dir=$(make_case report-missing)
rm -f "$dir/report.tsv"
expect_marker REPORT_MISSING "$dir"

dir=$(make_case assertion-missing)
sed -n '2,$p' "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_ASSERTION_MISSING "$dir"

dir=$(make_case assertion-duplicate)
sed -n '1p;1,$p' "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_ASSERTION_DUPLICATE "$dir"

dir=$(make_case assertion-unknown)
sed '1s/BC01_ASSOCIATION_IDEMPOTENT/BC01_UNKNOWN/' "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_ASSERTION_UNKNOWN "$dir"

dir=$(make_case order-invalid)
awk 'NR == 1 { first = $0; next } NR == 2 { print; print first; next } { print }' \
    "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_ORDER_INVALID "$dir"

dir=$(make_case matrix-mismatch)
sed '1s/^BC01/BC12/' "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_MATRIX_MISMATCH "$dir"

dir=$(make_case disposition-invalid)
sed '1s/UNTESTED/BROKEN/' "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_DISPOSITION_INVALID "$dir"

dir=$(make_case reason-missing)
awk -F '	' 'BEGIN { OFS = FS } NR == 1 { $6 = "" } { print }' \
    "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_REASON_MISSING "$dir"

dir=$(make_case pass-without-evidence)
awk -F '	' 'BEGIN { OFS = FS } NR == 1 { $5 = "PASS"; $6 = "ok" } { print }' \
    "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_PASS_WITHOUT_EVIDENCE "$dir"

dir=$(make_case control-without-trigger)
awk -F '	' 'BEGIN { OFS = FS }
    $4 == "control" && !changed {
        $5 = "PASS"
        $6 = "ok"
        $7 = "evidence-placeholder"
        changed = 1
    }
    { print }
' "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_CONTROL_WITHOUT_TRIGGER "$dir"

dir=$(make_case expected-pass-leak)
awk -F '	' 'BEGIN { OFS = FS } { $5 = "PASS"; print }' \
    "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_EXPECTED_PASS_LEAK "$dir"

dir=$(make_case aggregate-mismatch)
sed '$s/UNTESTED/PASS/' "$dir/report.tsv" >"$dir/report.new"
mv "$dir/report.new" "$dir/report.tsv"
expect_marker REPORT_AGGREGATE_MISMATCH "$dir"

dir=$(make_case failfast-omission)
printf 'driver-error\n' >"$dir/driver-failure.tsv"
sed -n '1p' "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker REPORT_FAILFAST_OMISSION "$dir"

dir=$(make_case unsupported-pass)
printf 'cap-bc01-delivery\n' >"$dir/unsupported-capabilities.tsv"
awk -F '	' 'BEGIN { OFS = FS }
    $1 == "BC01" {
        $5 = "PASS"
        $6 = "ok"
        $7 = "evidence-placeholder"
        if ($4 == "control") $8 = "control-trigger"
    }
    { print }
' "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
expect_marker PROFILE_UNSUPPORTED_PASS "$dir"

dir=$(make_case aggregate-precedence)
make_all_pass "$dir"
awk -F '	' 'BEGIN { OFS = FS }
    NR == 1 { $5 = "UNTESTED"; $6 = "precedence-untested" }
    NR == 2 { $5 = "UNAVAILABLE"; $6 = "precedence-unavailable" }
    NR == 3 { $5 = "FAIL"; $6 = "precedence-fail" }
    NR == 4 { $5 = "INVALID"; $6 = "precedence-invalid" }
    { print }
' "$dir/assertions.tsv" >"$dir/assertions.new"
mv "$dir/assertions.new" "$dir/assertions.tsv"
{
    printf 'count\tglobal\tassertion-count\t83\n'
    printf 'count\tdisposition\tPASS\t79\n'
    printf 'count\tdisposition\tFAIL\t1\n'
    printf 'count\tdisposition\tUNTESTED\t1\n'
    printf 'count\tdisposition\tUNAVAILABLE\t1\n'
    printf 'count\tdisposition\tINVALID\t1\n'
    printf 'group\tBC01\tdisposition\tINVALID\n'
    for bc in BC02 BC03 BC04 BC05 BC06 BC07 BC08 BC09 BC10 BC11 BC12
    do
        printf 'group\t%s\tdisposition\tPASS\n' "$bc"
    done
    printf 'overall\tglobal\tdisposition\tINVALID\n'
} >"$dir/report.tsv"
"$verify" "$dir" >/dev/null
echo "ok REPORT_AGGREGATE_PRECEDENCE"

echo "15 report mutations detected"
