#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
execution_map="$base_dir/execution-map.tsv"
fault_sets="$base_dir/fault-hook-sets.tsv"

fail() {
    echo "$1" >&2
    exit 1
}

[ "$#" -eq 2 ] || {
    echo "usage: verify-profile-report.sh PROFILE_TSV ASSERTIONS_TSV" >&2
    exit 2
}

profile=$1
assertions=$2

marker=$(
    LC_ALL=C awk -F '	' '
        FILENAME == ARGV[1] {
            if ($1 == "capability") {
                if (($4 != "planned" &&
                    $4 != "supported" &&
                    $4 != "unsupported") ||
                    capability_seen[$2]++) {
                    print "PROFILE_CAPABILITY_RESOLUTION_INVALID"
                    failed = 1
                    exit 1
                }
                status[$2] = $4
                capability_count++
            }
            if ($1 == "fault-hook") {
                if (($4 != "planned" && $4 != "supported") ||
                    hook_seen[$2]++) {
                    print "PROFILE_FAULT_RESOLUTION_INVALID"
                    failed = 1
                    exit 1
                }
                hook_status[$2] = $4
                hook_count++
            }
            next
        }
        FILENAME == ARGV[2] {
            if (expected_assertion[$1]++) {
                print "PROFILE_EXECUTION_MAP_INVALID"
                failed = 1
                exit 1
            }
            capability[$1] = $5
            fault_set[$1] = $12
            expected_count++
            if (!($5 in status)) {
                print "PROFILE_CAPABILITY_RESOLUTION_INVALID"
                failed = 1
                exit 1
            }
            next
        }
        FILENAME == ARGV[3] {
            if (!($2 in hook_status)) {
                print "PROFILE_FAULT_RESOLUTION_INVALID"
                failed = 1
                exit 1
            }
            if (hook_status[$2] == "planned")
                planned_fault_set[$1] = 1
            next
        }
        {
            if (!($3 in expected_assertion) || assertion_seen[$3]++) {
                print "PROFILE_ASSERTION_COVERAGE_INVALID"
                failed = 1
                exit 1
            }
            assertion_count++
            if (!(capability[$3] in status)) {
                print "PROFILE_CAPABILITY_RESOLUTION_INVALID"
                failed = 1
                exit 1
            }
            expected = status[capability[$3]]
            if (expected == "planned" && $5 != "UNTESTED") {
                print "PROFILE_PLANNED_DISPOSITION_INVALID"
                failed = 1
                exit 1
            }
            if (expected == "unsupported" && $5 != "UNAVAILABLE") {
                print "PROFILE_UNSUPPORTED_NOT_UNAVAILABLE"
                failed = 1
                exit 1
            }
            if (expected == "supported" &&
                fault_set[$3] != "-" &&
                planned_fault_set[fault_set[$3]] &&
                $5 != "UNTESTED") {
                print "PROFILE_FAULT_PLANNED_DISPOSITION_INVALID"
                failed = 1
                exit 1
            }
        }
        END {
            if (failed) exit 1
            if (capability_count != 12) {
                print "PROFILE_CAPABILITY_RESOLUTION_INVALID"
                exit 1
            }
            if (hook_count != 12) {
                print "PROFILE_FAULT_RESOLUTION_INVALID"
                exit 1
            }
            if (expected_count != 83 || assertion_count != expected_count) {
                print "PROFILE_ASSERTION_COVERAGE_INVALID"
                exit 1
            }
            for (id in expected_assertion)
                if (assertion_seen[id] != 1) {
                    print "PROFILE_ASSERTION_COVERAGE_INVALID"
                    exit 1
                }
        }
    ' "$profile" "$execution_map" "$fault_sets" "$assertions"
) || fail "$marker"

echo "PROFILE_DISPOSITIONS_VALID"
