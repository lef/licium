#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

[ "$#" -eq 4 ] || {
    echo "usage: oracle-bc06.sh ARTIFACT_DIR RUN NS ASSERTION" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
before="$artifact_dir/inventory-before.tsv"
after="$artifact_dir/inventory-after.tsv"
receipts="$artifact_dir/action-receipts.tsv"
raw="$artifact_dir/raw-observations.tsv"
seal="$artifact_dir/raw-seal.tsv"
normalized="$artifact_dir/normalized-observations.tsv"

fail()
{
    echo "$1" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

[ -f "$raw" ] && [ -f "$seal" ] && [ -f "$receipts" ] ||
    fail BC06_REQUIRED_ARTIFACT_MISSING

actual_raw_sha=$(sha256sum "$raw" | awk '{ print $1 }')
actual_raw_bytes=$(wc -c <"$raw" | tr -d ' ')
actual_receipt_sha=$(sha256sum "$receipts" | awk '{ print $1 }')
awk -F '	' -v raw_sha="$actual_raw_sha" -v raw_bytes="$actual_raw_bytes" \
    -v receipt_sha="$actual_receipt_sha" -v run="$run" \
    -v ns="$namespace" -v assertion="$assertion" '
    NF != 9 { exit 1 }
    $1 != "raw-observations.tsv" || $2 != "100644" { exit 1 }
    $3 != raw_sha || $4 != raw_bytes || $5 != run { exit 1 }
    $6 != ns || $7 != assertion || $8 != receipt_sha { exit 1 }
    $9 != "sealed-before-normalization" { exit 1 }
    { count++ }
    END { if (count != 1) exit 1 }
' "$seal" || fail BC06_RAW_SEAL_INVALID

for role in authoritative-state decision-observation result-store
do
    awk -F '	' -v role="$role" '$2 == role' "$before" |
        LC_ALL=C sort >"$tmp/$role.before"
    awk -F '	' -v role="$role" '$2 == role' "$after" |
        LC_ALL=C sort >"$tmp/$role.after"
done

state_changed=0
observation_changed=0
result_changed=0
cmp -s "$tmp/authoritative-state.before" "$tmp/authoritative-state.after" ||
    state_changed=1
cmp -s "$tmp/decision-observation.before" "$tmp/decision-observation.after" ||
    observation_changed=1
cmp -s "$tmp/result-store.before" "$tmp/result-store.after" ||
    result_changed=1

case "$assertion" in
    BC06_STATE_WRITE)
        [ "$state_changed" -eq 0 ] || fail BC06_STATE_WRITE_DETECTED
        ;;
    BC06_RESULT_WRITE)
        [ "$result_changed" -eq 0 ] || fail BC06_RESULT_WRITE_DETECTED
        ;;
    BC06_OBSERVATION_WRITE)
        [ "$observation_changed" -eq 0 ] ||
            fail BC06_OBSERVATION_WRITE_DETECTED
        ;;
    BC06_PURE_ZERO_AXES)
        [ "$state_changed" -eq 0 ] &&
            [ "$observation_changed" -eq 0 ] &&
            [ "$result_changed" -eq 0 ] ||
            fail BC06_AXIS_WRITE_DETECTED
        ;;
    BC06_REPOSITORY_UNCHANGED)
        ;;
    *)
        fail BC06_ASSERTION_INVALID
        ;;
esac

if [ "$state_changed" -ne 0 ] ||
    [ "$observation_changed" -ne 0 ] ||
    [ "$result_changed" -ne 0 ]
then
    fail BC06_AXIS_WRITE_DETECTED
fi

cmp -s "$before" "$after" || fail BC06_REPOSITORY_DRIFT_DETECTED

marker=$(
    LC_ALL=C awk -F '	' -v run="$run" -v ns="$namespace" \
        -v assertion="$assertion" '
        function die(message) {
            print message
            failed = 1
            exit 1
        }
        NF != 11 { die("BC06_ACTION_RECEIPT_INVALID") }
        $1 != run || $2 != ns || $3 != assertion {
            die("BC06_ACTION_RECEIPT_INVALID")
        }
        $4 !~ /^occurrence-[12]$/ || occurrence[$4]++ {
            die("BC06_ACTION_RECEIPT_INVALID")
        }
        $5 != "sut-evaluate-pure" || $6 != "accepted" ||
        $7 != "request-06" || $8 != "alice" || $9 != "pair-06" {
            die("BC06_ACTION_RECEIPT_INVALID")
        }
        $10 == "-" { die("BC06_SUT_OUTCOME_MISSING") }
        $10 != "public-a" { die("BC06_ACTION_RECEIPT_INVALID") }
        $11 == "" || nonce[$11]++ { die("BC06_ACTION_RECEIPT_INVALID") }
        { count++ }
        END {
            if (failed) exit 1
            if (count != 2 ||
                occurrence["occurrence-1"] != 1 ||
                occurrence["occurrence-2"] != 1) {
                print "BC06_SUT_OUTCOME_MISSING"
                exit 1
            }
        }
    ' "$receipts"
) || fail "$marker"

awk -F '	' -v assertion="$assertion" '
    NF != 6 || $1 != assertion { exit 1 }
    {
        row[$2] = $3 FS $4 FS $5 FS $6
        count++
    }
    END {
        if (count != 10) exit 1
        if (row["obs-001"] != "evaluation-outcome" FS "occurrence-1" FS "accepted" FS "public-a") exit 1
        if (row["obs-005"] != "evaluation-outcome" FS "occurrence-2" FS "accepted" FS "public-a") exit 1
        if (row["obs-008"] != "execution" FS "occurrence-1" FS "sut-evaluate-pure" FS "accepted") exit 1
        if (row["obs-009"] != "execution" FS "occurrence-2" FS "sut-evaluate-pure" FS "accepted") exit 1
        if (row["obs-002"] != "persistent-write" FS "authoritative-state" FS "unchanged" FS "0") exit 1
        if (row["obs-003"] != "persistent-write" FS "decision-observation" FS "unchanged" FS "0") exit 1
        if (row["obs-004"] != "persistent-write" FS "result-store" FS "unchanged" FS "0") exit 1
        if (row["obs-006"] != "provenance" FS "subject" FS "alice" FS "bound") exit 1
        if (row["obs-007"] != "provenance" FS "pinned-source" FS "pair-06" FS "bound") exit 1
        if (row["obs-010"] != "provenance" FS "request" FS "request-06" FS "bound") exit 1
    }
' "$normalized" || fail BC06_NORMALIZED_OBSERVATION_INVALID

case "$assertion" in
    BC06_OBSERVATION_WRITE)
        oracle=oracle-bc06-observation-write
        evidence=norm-bc06-observation
        ;;
    BC06_PURE_ZERO_AXES)
        oracle=oracle-bc06-pure-zero-axes
        evidence=norm-bc06-observation
        ;;
    BC06_REPOSITORY_UNCHANGED)
        oracle=oracle-bc06-repository-unchanged
        evidence=inventory-repository
        ;;
    BC06_RESULT_WRITE)
        oracle=oracle-bc06-result-write
        evidence=norm-bc06-observation
        ;;
    BC06_STATE_WRITE)
        oracle=oracle-bc06-state-write
        evidence=norm-bc06-observation
        ;;
esac

printf '%s\t%s\tPASS\t%s\tnormal\t-\n' \
    "$assertion" "$oracle" "$evidence"
