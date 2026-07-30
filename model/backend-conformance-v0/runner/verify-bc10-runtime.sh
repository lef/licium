#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

[ "$#" -eq 5 ] || {
    echo "usage: verify-bc10-runtime.sh ARTIFACT_DIR RUN NS ASSERTION SCENARIO" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
scenario=$5

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail()
{
    echo "$1" >&2
    exit 1
}

[ -d "$artifact_dir" ] && [ ! -L "$artifact_dir" ] ||
    fail BC10_ARTIFACT_SET_INVALID

cat >"$tmp/expected-files" <<'EOF'
action-receipts.tsv
command-receipts.tsv
coverage.tsv
exclusions.tsv
fault-markers.tsv
normalized-observations.tsv
oracle-result.tsv
pragma.tsv
raw-observations.tsv
raw-seal.tsv
EOF
find "$artifact_dir" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' |
    LC_ALL=C sort >"$tmp/actual-files"
cmp -s "$tmp/expected-files" "$tmp/actual-files" ||
    fail BC10_ARTIFACT_SET_INVALID

while IFS= read -r name
do
    file="$artifact_dir/$name"
    [ ! -L "$file" ] && [ "$(stat -c '%a' "$file")" = 644 ] ||
        fail BC10_ARTIFACT_MODE_INVALID
done <"$tmp/expected-files"

expected_scenario=$(
    awk -F '	' -v assertion="$assertion" '
        $1 == assertion { print $3; found++ }
        END { if (found != 1) exit 1 }
    ' "$base_dir/bc10-scenario-ids.tsv"
) || fail BC10_SCENARIO_ID_INVALID
[ "$scenario" = "$expected_scenario" ] ||
    fail BC10_SCENARIO_ID_INVALID

case_row=$(
    awk -F '	' -v assertion="$assertion" '
        $1 == assertion { print $3 FS $4; found++ }
        END { if (found != 1) exit 1 }
    ' "$base_dir/bc10-cases.tsv"
) || fail BC10_CASE_COVERAGE_INVALID
surface=${case_row%%	*}
operation=${case_row#*	}

case "$surface" in
    result) rows=10 ;;
    replay) rows=13 ;;
    view|explanation) rows=7 ;;
    *) fail BC10_CASE_COVERAGE_INVALID ;;
esac

check_shape()
{
    name=$1
    fields=$2
    expected_rows=$3
    marker=$4
    awk -F '	' -v fields="$fields" -v rows="$expected_rows" '
        NF != fields { exit 1 }
        END { if (NR != rows) exit 1 }
    ' "$artifact_dir/$name" || fail "$marker"
}

check_shape action-receipts.tsv 12 1 BC10_SUT_ACTION_MISSING
check_shape raw-seal.tsv 9 1 BC10_RAW_SEAL_INVALID

# Validate the seal before any downstream command-output comparison so a
# post-seal raw mutation retains its dedicated evidence marker.
raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
awk -F '	' -v raw_sha="$raw_sha" -v raw_bytes="$raw_bytes" \
    -v run="$run" -v ns="$namespace" -v scenario="$scenario" \
    -v receipt_sha="$receipt_sha" '
    $1 != "raw-observations.tsv" || $2 != "100644" ||
        $3 != raw_sha || $4 != raw_bytes || $5 != run ||
        $6 != ns || $7 != scenario || $8 != receipt_sha ||
        $9 != "sealed-before-normalization" { exit 1 }
' "$artifact_dir/raw-seal.tsv" || fail BC10_RAW_SEAL_INVALID

# Coverage is checked before normalized cardinality.  A synthesized normalized
# row therefore fails as missing raw provenance, not as a generic row-count
# error.
awk -F '	' '
    FILENAME == ARGV[1] { raw[$1 FS $2]++; next }
    FILENAME == ARGV[2] { normalized[$1 FS $2]++; next }
    {
        if ($3 != "record" || $6 != "all") exit 1
        raw_key=$1 FS $2
        normalized_key=$4 FS $5
        if (!(raw_key in raw) || !(normalized_key in normalized) ||
            seen_raw[raw_key]++ || seen_normalized[normalized_key]++)
            exit 1
    }
    END {
        for (key in raw) if (raw[key] != 1 || seen_raw[key] != 1) exit 1
        for (key in normalized)
            if (normalized[key] != 1 || seen_normalized[key] != 1) exit 1
    }
' "$artifact_dir/raw-observations.tsv" \
    "$artifact_dir/normalized-observations.tsv" \
    "$artifact_dir/coverage.tsv" || fail BC10_COVERAGE_INVALID

check_shape command-receipts.tsv 12 6 BC10_COMMAND_CUSTODY_INVALID
check_shape coverage.tsv 6 "$rows" BC10_COVERAGE_INVALID
check_shape exclusions.tsv 6 0 BC10_EXCLUSION_INVALID
check_shape fault-markers.tsv 6 0 BC10_FAULT_EVIDENCE_INVALID
check_shape normalized-observations.tsv 6 "$rows" \
    BC10_NORMALIZED_CONTRACT_INVALID
check_shape oracle-result.tsv 6 1 BC10_ORACLE_INVALID
check_shape pragma.tsv 6 5 BC10_PRAGMA_EVIDENCE_INVALID
check_shape raw-observations.tsv 6 "$rows" BC10_RAW_CONTRACT_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" -v scenario="$scenario" \
    -v assertion="$assertion" -v surface="$surface" \
    -v operation="$operation" '
    $1 != run || $2 != ns || $3 != scenario || $4 != assertion ||
        $5 != surface || $6 != operation || $7 != "ordinary" ||
        $8 != "request-1" || $9 != "root-1" ||
        $10 != "definition-1" || $11 != "accepted" ||
        $12 != "action-" run { exit 1 }
' "$artifact_dir/action-receipts.tsv" ||
    fail BC10_ACTION_RECEIPT_CONTRACT_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" \
    -v operation="$operation" '
    $1 != run || $2 != ns || $3 != assertion ||
        $4 == "" || $5 == "" || $6 == "" || $7 != 0 ||
        $8 !~ /^[0-9a-f]+$/ || length($8) != 64 ||
        $9 !~ /^[0-9]+$/ ||
        $10 !~ /^[0-9a-f]+$/ || length($10) != 64 ||
        $11 !~ /^[0-9]+$/ ||
        $12 !~ /^[0-9a-f]+$/ || length($12) != 64 ||
        seen[$4]++ { exit 1 }
    $4 == "action" && ($5 != operation || $6 != "ordinary") { exit 1 }
    END {
        required["create"]; required["setup"]; required["action"]
        required["reopen"]; required["observe"]; required["destroy"]
        for (phase in required) if (seen[phase] != 1) exit 1
    }
' "$artifact_dir/command-receipts.tsv" ||
    fail BC10_COMMAND_CUSTODY_INVALID

action_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
action_bytes=$(wc -c <"$artifact_dir/action-receipts.tsv" | tr -d ' ')
raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
awk -F '	' -v action_sha="$action_sha" -v action_bytes="$action_bytes" \
    -v raw_sha="$raw_sha" -v raw_bytes="$raw_bytes" '
    $4 == "action" && ($8 != action_sha || $9 != action_bytes) { exit 1 }
    $4 == "observe" && ($8 != raw_sha || $9 != raw_bytes) { exit 1 }
' "$artifact_dir/command-receipts.tsv" ||
    fail BC10_COMMAND_CUSTODY_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" '
    $1 != run || $2 != ns || $3 != assertion ||
        $5 != "foreign-keys" || $6 != 1 || seen[$4]++ { exit 1 }
    END {
        required["create"]; required["setup"]; required["action"]
        required["reopen"]; required["observe"]
        for (phase in required) if (seen[phase] != 1) exit 1
    }
' "$artifact_dir/pragma.tsv" || fail BC10_PRAGMA_EVIDENCE_INVALID

"$script_dir/normalize-bc10.sh" "$artifact_dir/raw-observations.tsv" \
    "$scenario" >"$tmp/normalized" ||
    fail BC10_NORMALIZED_CONTRACT_INVALID
cmp -s "$tmp/normalized" "$artifact_dir/normalized-observations.tsv" ||
    fail BC10_NORMALIZED_CONTRACT_INVALID

awk -F '	' 'BEGIN { OFS=FS }
    {
        normalized=$2
        sub(/^raw-/, "obs-", normalized)
        print $1,$2,"record",$1,normalized,"all"
    }
' "$artifact_dir/raw-observations.tsv" >"$tmp/coverage"
cmp -s "$tmp/coverage" "$artifact_dir/coverage.tsv" ||
    fail BC10_COVERAGE_INVALID

"$script_dir/oracle-bc10.sh" \
    "$artifact_dir/normalized-observations.tsv" "$assertion" "$scenario" \
    ordinary "$tmp/oracle" 2>"$tmp/oracle.err" ||
    fail BC10_ORACLE_INVALID
cmp -s "$tmp/oracle" "$artifact_dir/oracle-result.tsv" ||
    fail BC10_ORACLE_INVALID

[ ! -e "$artifact_dir/$namespace.db" ] ||
    fail BC10_DATABASE_CLEANUP_INVALID

echo BC10_RUNTIME_CONTRACT_VALID
