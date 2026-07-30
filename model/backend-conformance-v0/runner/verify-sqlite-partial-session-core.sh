#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
canonical="$script_dir/materialize-sqlite-partial-canonical.sh"
run_verifier="$script_dir/verify-sqlite-partial-run.sh"

[ "$#" -ge 2 ] && [ "$#" -le 3 ] || {
    echo "usage: verify-sqlite-partial-session-core.sh SESSION_DIR preseal|sealed [control-probe]" >&2
    exit 2
}

session_dir=$1
stage=$2
mode=${3:-full}
case "$stage" in preseal|sealed) ;; *) exit 2 ;; esac
case "$mode" in full|control-probe) ;; *) exit 2 ;; esac
run_a="$session_dir/run-a"
run_b="$session_dir/run-b"
lifecycle="$session_dir/lifecycle"

fail()
{
    echo "$1" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

find "$session_dir" -type l -print | awk 'NR == 1 { exit 1 }' ||
    fail SQLITE_PARTIAL_SESSION_LAYOUT_INVALID

{
    printf '%s\n' aggregate-dispositions.tsv assertions.tsv \
        canonical-comparison.tsv control-receipts.tsv \
        lifecycle-command-receipt.tsv run-metadata.tsv
    [ "$stage" = preseal ] ||
        printf '%s\n' outer-receipt.tsv payload-manifest.tsv report.tsv
} | LC_ALL=C sort >"$tmp/expected-root-files"
find "$session_dir" -type f -print |
    awk -v root="$session_dir/" '
        index($0, root) == 1 {
            relative = substr($0, length(root) + 1)
            if (relative !~ /\//) print relative
        }
    ' | LC_ALL=C sort >"$tmp/actual-root-files"
cmp -s "$tmp/expected-root-files" "$tmp/actual-root-files" ||
    fail SQLITE_PARTIAL_SESSION_LAYOUT_INVALID

printf '%s\n' lifecycle run-a run-b | LC_ALL=C sort \
    >"$tmp/expected-root-dirs"
find "$session_dir" -type d -print |
    awk -v root="$session_dir/" '
        index($0, root) == 1 {
            relative = substr($0, length(root) + 1)
            if (relative != "" && relative !~ /\//) print relative
        }
    ' | LC_ALL=C sort >"$tmp/actual-root-dirs"
cmp -s "$tmp/expected-root-dirs" "$tmp/actual-root-dirs" ||
    fail SQLITE_PARTIAL_SESSION_LAYOUT_INVALID
[ -d "$lifecycle/run-a" ] && [ -d "$lifecycle/run-b" ] &&
    [ -f "$lifecycle/run-a/sentinel-a" ] &&
    [ ! -e "$lifecycle/run-b/sentinel-a" ] ||
    fail SQLITE_PARTIAL_SENTINEL_LEAK_DETECTED

[ "$(cat "$session_dir/lifecycle-command-receipt.tsv")" = \
    "status	lifecycle-sentinel	put	run-a	sentinel-a" ] ||
    fail SQLITE_PARTIAL_SENTINEL_LEAK_DETECTED

while IFS='	' read -r ordinal suite assertion case_id scenario \
    runner_path verifier_path evidence_policy
do
    case "$suite" in
        BC01)
            fields=13
            receipt_name=action-receipts.tsv
            ;;
        BC02)
            fields=12
            receipt_name=command-receipts.tsv
            ;;
        BC03)
            fields=13
            receipt_name=action-receipts.tsv
            ;;
        BC04)
            fields=13
            receipt_name=action-receipts.tsv
            ;;
        BC05)
            fields=13
            receipt_name=action-receipts.tsv
            ;;
        BC06)
            fields=11
            receipt_name=action-receipts.tsv
            ;;
        BC07)
            fields=12
            receipt_name=action-receipts.tsv
            ;;
        BC08)
            fields=15
            receipt_name=action-receipts.tsv
            ;;
        BC09)
            fields=14
            receipt_name=action-receipts.tsv
            ;;
        BC10)
            fields=12
            receipt_name=action-receipts.tsv
            ;;
        BC11)
            fields=12
            receipt_name=action-receipts.tsv
            ;;
        BC12)
            fields=12
            receipt_name=action-receipts.tsv
            ;;
        *) exit 1 ;;
    esac
    for side in a b
    do
        run_id="run-$side"
        namespace="ns-$side-$scenario"
        receipt="$session_dir/$run_id/$scenario/$receipt_name"
        awk -F '	' -v fields="$fields" -v run="$run_id" \
            -v ns="$namespace" -v suite="$suite" \
            -v assertion="$assertion" '
            NF != fields || $1 != run ||
                (suite == "BC09" ?
                    $2 != ns "-" substr($4, 6) :
                    $2 != ns) { exit 1 }
            suite == "BC09" {
                expected = "action-" run "-" $4
                if (assertion == "BC09_FAILPOINT_PERSISTS" ||
                    ((assertion == "BC09_DIAGNOSTIC_EPHEMERAL" ||
                      assertion == "BC09_FAILURE_NO_PERSISTENT_ARTIFACT") &&
                     $4 == "case-fault"))
                    expected = "fault-" run "-" substr($4, 6)
                if ($14 == "healthy")
                    expected = "healthy-" $4
                if ($12 != expected) exit 1
            }
            suite == "BC10" && $12 != "action-" run { exit 1 }
            suite == "BC11" && $12 != "action-" run { exit 1 }
            suite == "BC12" && $12 != "action-" run { exit 1 }
            { count++ }
            END { if (count < 1) exit 1 }
        ' "$receipt" || fail SQLITE_PARTIAL_COPIED_RUN_DETECTED
    done
done <"$script_dir/../sqlite-partial-scenarios.tsv"

[ "$(cat "$run_a/namespace-inventory.tsv")" = \
    "run-a	lifecycle-sentinel	sentinel-a	present" ] &&
    [ "$(cat "$run_b/namespace-inventory.tsv")" = \
    "run-b	lifecycle-sentinel	sentinel-a	absent" ] ||
    fail SQLITE_PARTIAL_SENTINEL_LEAK_DETECTED

"$canonical" "$run_a" "$tmp/canonical-a.tsv"
"$canonical" "$run_b" "$tmp/canonical-b.tsv"
if ! cmp -s "$tmp/canonical-a.tsv" "$tmp/canonical-b.tsv"; then
    differing_suite=$(
        awk -F '	' '
            NR == FNR { a[$1 FS $2 FS $3] = $4 FS $5; next }
            a[$1 FS $2 FS $3] != ($4 FS $5) { print $1; exit }
        ' "$tmp/canonical-a.tsv" "$tmp/canonical-b.tsv"
    )
    case "$differing_suite" in
        BC01) fail SQLITE_PARTIAL_BC01_DRIFT_DETECTED ;;
        BC02) fail SQLITE_PARTIAL_BC02_DRIFT_DETECTED ;;
        BC03) fail SQLITE_PARTIAL_BC03_DRIFT_DETECTED ;;
        BC04) fail SQLITE_PARTIAL_BC04_DRIFT_DETECTED ;;
        BC05) fail SQLITE_PARTIAL_BC05_DRIFT_DETECTED ;;
        BC06) fail SQLITE_PARTIAL_BC06_DRIFT_DETECTED ;;
        BC07) fail SQLITE_PARTIAL_BC07_DRIFT_DETECTED ;;
        BC08) fail SQLITE_PARTIAL_BC08_DRIFT_DETECTED ;;
        BC09) fail SQLITE_PARTIAL_BC09_DRIFT_DETECTED ;;
        BC10) fail SQLITE_PARTIAL_BC10_DRIFT_DETECTED ;;
        BC11) fail SQLITE_PARTIAL_BC11_DRIFT_DETECTED ;;
        BC12) fail SQLITE_PARTIAL_BC12_DRIFT_DETECTED ;;
        *) fail SQLITE_PARTIAL_CANONICAL_INVALID ;;
    esac
fi
cmp -s "$tmp/canonical-a.tsv" "$session_dir/canonical-comparison.tsv" ||
    fail SQLITE_PARTIAL_CANONICAL_INVALID

cmp -s "$run_a/assertions.tsv" "$run_b/assertions.tsv" &&
    cmp -s "$run_a/assertions.tsv" "$session_dir/assertions.tsv" ||
    fail SQLITE_PARTIAL_SESSION_ASSERTIONS_INVALID
{
    awk -F '	' -v OFS='	' '{ print "run-a",$0 }' \
        "$run_a/assertions.tsv"
    awk -F '	' -v OFS='	' '{ print "run-b",$0 }' \
        "$run_b/assertions.tsv"
} >"$tmp/aggregate.tsv"
cmp -s "$tmp/aggregate.tsv" "$session_dir/aggregate-dispositions.tsv" ||
    fail SQLITE_PARTIAL_SESSION_AGGREGATE_INVALID
awk -F '	' 'NF != 9 { exit 1 } { count++ }
    END { if (count != 166) exit 1 }' \
    "$session_dir/aggregate-dispositions.tsv" ||
    fail SQLITE_PARTIAL_SESSION_AGGREGATE_INVALID

{
    printf 'meta\tglobal\tartifact-kind\tsqlite-partial-session\n'
    printf 'binding\tsession\trun-a-outer-sha256\t%s\n' \
        "$(sha256sum "$run_a/outer-receipt.tsv" | awk '{ print $1 }')"
    printf 'binding\tsession\trun-b-outer-sha256\t%s\n' \
        "$(sha256sum "$run_b/outer-receipt.tsv" | awk '{ print $1 }')"
    printf 'binding\tsession\tcanonical-comparison-sha256\t%s\n' \
        "$(sha256sum "$session_dir/canonical-comparison.tsv" |
            awk '{ print $1 }')"
    printf 'binding\tsession\taggregate-dispositions-sha256\t%s\n' \
        "$(sha256sum "$session_dir/aggregate-dispositions.tsv" |
            awk '{ print $1 }')"
} >"$tmp/expected-run-metadata.tsv"
cmp -s "$tmp/expected-run-metadata.tsv" "$session_dir/run-metadata.tsv" ||
    fail SQLITE_PARTIAL_SESSION_REPORT_BINDING_INVALID

if [ "$mode" = full ]; then
    "$run_verifier" "$run_a" run-a a "$lifecycle" sealed >/dev/null
    "$run_verifier" "$run_b" run-b b "$lifecycle" sealed >/dev/null
fi

echo SQLITE_PARTIAL_SESSION_CORE_VALID
