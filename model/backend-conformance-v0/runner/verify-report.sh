#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
matrix="$base_dir/scenarios.tsv"
execution_map="$base_dir/execution-map.tsv"
schema=${LICIUM_REPORT_SCHEMA:-"$base_dir/report-schema.tsv"}

fail() {
    echo "$1" >&2
    exit 1
}

[ "$#" -eq 1 ] || {
    echo "usage: verify-report.sh ARTIFACT_DIR" >&2
    exit 2
}

artifact_dir=$1
assertions="$artifact_dir/assertions.tsv"
report="$artifact_dir/report.tsv"

[ -f "$schema" ] || fail "REPORT_SCHEMA_MISSING"
schema_marker=$(
    LC_ALL=C awk -F '	' '
        {
            actual[$0]++
            count++
        }
        END {
            required["assertions.tsv\t8\tbc-core-assertion-kind-disposition-reason-evidence-control"] = 1
            required["report.tsv\t4\trecord-scope-name-value"] = 1
            if (count != 2) exit 1
            for (row in required) if (actual[row] != 1) exit 1
            for (row in actual) if (!(row in required)) exit 1
        }
    ' "$schema"
) || fail "REPORT_SCHEMA_INVALID${schema_marker:+: $schema_marker}"

[ -f "$assertions" ] || fail "REPORT_ASSERTIONS_MISSING"
[ -f "$report" ] || fail "REPORT_MISSING"

driver_failure=0
[ ! -f "$artifact_dir/driver-failure.tsv" ] || driver_failure=1
marker=$(
    LC_ALL=C awk -F '	' '
        function die(message) {
            print message
            failed = 1
            exit 1
        }
        NR == FNR {
            expected_id[NR] = $3
            expected_bc[$3] = $1
            expected_cc[$3] = $2
            expected_kind[$3] = $4
            matrix_count++
            next
        }
        {
            if (NF != 8) die("REPORT_ROW_SHAPE_INVALID")
            if (!($3 in expected_bc)) die("REPORT_ASSERTION_UNKNOWN")
            if (seen[$3]++) die("REPORT_ASSERTION_DUPLICATE")
            row_count++
            for (field = 1; field <= 8; field++)
                value[row_count, field] = $field
        }
        END {
            if (failed) exit 1
            if (row_count != matrix_count) {
                if (driver_failure == 1)
                    die("REPORT_FAILFAST_OMISSION")
                die("REPORT_ASSERTION_MISSING")
            }
            for (id in expected_bc)
                if (seen[id] != 1) die("REPORT_ASSERTION_MISSING")
            for (row = 1; row <= row_count; row++) {
                id = value[row, 3]
                disposition = value[row, 5]
                reason = value[row, 6]
                evidence = value[row, 7]
                control = value[row, 8]
                if (id != expected_id[row]) die("REPORT_ORDER_INVALID")
                if (value[row, 1] != expected_bc[id] ||
                    value[row, 2] != expected_cc[id] ||
                    value[row, 4] != expected_kind[id])
                    die("REPORT_MATRIX_MISMATCH")
                if (disposition != "PASS" &&
                    disposition != "FAIL" &&
                    disposition != "UNTESTED" &&
                    disposition != "UNAVAILABLE" &&
                    disposition != "INVALID")
                    die("REPORT_DISPOSITION_INVALID")
                if (disposition == "PASS" && reason == "not-executed")
                    die("REPORT_EXPECTED_PASS_LEAK")
                if (disposition == "PASS" && reason != "ok")
                    die("REPORT_PASS_REASON_INVALID")
                if (disposition != "PASS" && reason == "")
                    die("REPORT_REASON_MISSING")
                if (disposition != "PASS" && reason == "ok")
                    die("REPORT_NONPASS_REASON_INVALID")
                if (reason !~ /^[a-z0-9][a-z0-9-]*$/)
                    die("REPORT_REASON_INVALID")
                if (evidence != "-" &&
                    evidence !~ /^[a-z0-9][a-z0-9-]*$/)
                    die("REPORT_EVIDENCE_REFERENCE_INVALID")
                if (control != "-" &&
                    control !~ /^[a-z0-9][a-z0-9-]*$/)
                    die("REPORT_CONTROL_REFERENCE_INVALID")
                if (disposition == "PASS" && evidence == "-")
                    die("REPORT_PASS_WITHOUT_EVIDENCE")
                if (disposition == "PASS" &&
                    value[row, 4] == "control" &&
                    control == "-")
                    die("REPORT_CONTROL_WITHOUT_TRIGGER")
            }
        }
    ' driver_failure="$driver_failure" "$matrix" "$assertions"
) || fail "$marker"

if [ -f "$artifact_dir/unsupported-capabilities.tsv" ]; then
    marker=$(
        LC_ALL=C awk -F '	' '
            NR == FNR {
                if (NF != 1 || $1 !~ /^[a-z0-9][a-z0-9-]*$/) {
                    print "PROFILE_UNSUPPORTED_SHAPE"
                    exit 1
                }
                unsupported[$1] = 1
                next
            }
            FILENAME == ARGV[2] {
                capability[$1] = $5
                next
            }
            $5 == "PASS" && (capability[$3] in unsupported) {
                print "PROFILE_UNSUPPORTED_PASS"
                exit 1
            }
        ' "$artifact_dir/unsupported-capabilities.tsv" "$execution_map" "$assertions"
    ) || fail "$marker"
fi

derived=$(mktemp)
projection=$(mktemp)
trap 'rm -f "$derived" "$projection"' EXIT HUP INT TERM

LC_ALL=C awk -F '	' '
    function die() { failed = 1; exit 1 }
    {
        if (NF != 4) die()
        key = $1 SUBSEP $2 SUBSEP $3
        if (seen[key]++) die()
        if ($1 == "count") {
            if (($2 != "global" && $2 != "disposition") ||
                $3 !~ /^(assertion-count|PASS|FAIL|UNTESTED|UNAVAILABLE|INVALID)$/ ||
                $4 !~ /^(0|[1-9][0-9]*)$/) die()
        } else if ($1 == "group") {
            if ($2 !~ /^BC(0[1-9]|1[0-2])$/ ||
                $3 != "disposition" ||
                $4 !~ /^(PASS|FAIL|UNTESTED|UNAVAILABLE|INVALID)$/) die()
        } else if ($1 == "overall") {
            if ($2 != "global" ||
                $3 != "disposition" ||
                $4 !~ /^(PASS|FAIL|UNTESTED|UNAVAILABLE|INVALID)$/) die()
        } else if ($1 == "meta" || $1 == "binding") {
            if ($2 !~ /^[a-z0-9][a-z0-9-]*$/ ||
                $3 !~ /^[a-z0-9][a-z0-9-]*$/ ||
                $4 == "") die()
        } else {
            die()
        }
        if ($1 == "count" || $1 == "group" || $1 == "overall")
            print
    }
    END { if (failed) exit 1 }
' "$report" >"$projection" || fail "REPORT_SHAPE_INVALID"

LC_ALL=C awk -F '	' '
    BEGIN {
        rank["PASS"] = 0
        rank["UNTESTED"] = 1
        rank["UNAVAILABLE"] = 2
        rank["FAIL"] = 3
        rank["INVALID"] = 4
        disposition[1] = "PASS"
        disposition[2] = "FAIL"
        disposition[3] = "UNTESTED"
        disposition[4] = "UNAVAILABLE"
        disposition[5] = "INVALID"
    }
    {
        count[$5]++
        total++
        if (!($1 in group_rank) || rank[$5] > group_rank[$1]) {
            group_rank[$1] = rank[$5]
            group_status[$1] = $5
        }
        if (!overall_seen || rank[$5] > overall_rank) {
            overall_rank = rank[$5]
            overall_status = $5
            overall_seen = 1
        }
    }
    END {
        print "count\tglobal\tassertion-count\t" total
        for (i = 1; i <= 5; i++)
            print "count\tdisposition\t" disposition[i] "\t" (count[disposition[i]] + 0)
        for (i = 1; i <= 12; i++) {
            bc = sprintf("BC%02d", i)
            print "group\t" bc "\tdisposition\t" group_status[bc]
        }
        print "overall\tglobal\tdisposition\t" overall_status
    }
' "$assertions" >"$derived"

cmp -s "$derived" "$projection" || fail "REPORT_AGGREGATE_MISMATCH"

echo "REPORT_STRUCTURALLY_VALID"
