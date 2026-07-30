#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases="$base_dir/bc08-cases.tsv"
runtime_verifier="$script_dir/verify-bc08-runtime.sh"

[ "$#" -eq 1 ] || exit 2
session_dir=$1
run_a="$session_dir/run-a"
run_b="$session_dir/run-b"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -d "$run_a" ] && [ -d "$run_b" ] ||
    fail BC08_SESSION_ARTIFACT_MISSING
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: >"$tmp/canonical-a"
: >"$tmp/canonical-b"

while IFS='	' read -r assertion _ case_id _ _ _ _
do
    name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
    scenario=$(awk -F '	' -v assertion="$assertion" \
        '$1 == assertion { print $3 }' "$base_dir/bc08-scenario-ids.tsv")
    dir_a="$run_a/$name"
    dir_b="$run_b/$name"
    ns_a="ns-a-$name"
    ns_b="ns-b-$name"
    [ -d "$dir_a" ] && [ -d "$dir_b" ] ||
        fail BC08_SESSION_ARTIFACT_MISSING

    awk -F '	' -v run=run-a -v ns="$ns_a" -v scenario="$scenario" '
        NF != 15 || $1 != run || $2 != ns || $3 != scenario { exit 1 }
        END { if (NR != 2) exit 1 }
    ' "$dir_a/action-receipts.tsv" || fail BC08_COPIED_RUN_DETECTED
    awk -F '	' -v run=run-b -v ns="$ns_b" -v scenario="$scenario" '
        NF != 15 || $1 != run || $2 != ns || $3 != scenario { exit 1 }
        END { if (NR != 2) exit 1 }
    ' "$dir_b/action-receipts.tsv" || fail BC08_COPIED_RUN_DETECTED
    nonce_a=$(awk -F '	' 'NR == 1 { print $14 }' \
        "$dir_a/action-receipts.tsv")
    nonce_b=$(awk -F '	' 'NR == 1 { print $14 }' \
        "$dir_b/action-receipts.tsv")
    [ "$nonce_a" != "$nonce_b" ] || fail BC08_COPIED_RUN_DETECTED

    for relation in coverage.tsv inventory-after.tsv inventory-before.tsv \
        inventory-reopened.tsv normalized-observations.tsv \
        oracle-result.tsv raw-observations.tsv fault-inventory-setup.tsv \
        fault-inventory-rollback.tsv fault-inventory-healthy.tsv \
        fault-inventory-reopened.tsv
    do
        printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
            >>"$tmp/canonical-a"
        LC_ALL=C sort "$dir_a/$relation" >>"$tmp/canonical-a"
        printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
            >>"$tmp/canonical-b"
        LC_ALL=C sort "$dir_b/$relation" >>"$tmp/canonical-b"
    done

    if [ "$assertion" = BC08_MID_BOUNDARY_FAILURE ]; then
        for side in a b
        do
            if [ "$side" = a ]; then
                dir=$dir_a
            else
                dir=$dir_b
            fi
            canonical="$tmp/canonical-$side"
            printf 'relation\t%s\tfault-activation-receipts.tsv\n' \
                "$assertion" >>"$canonical"
            awk -F '	' 'BEGIN { OFS=FS }
                {$1="{run}"; $2="{namespace}"; $9="{nonce}"; print}
            ' "$dir/fault-activation-receipts.tsv" |
                LC_ALL=C sort >>"$canonical"
            printf 'relation\t%s\tfault-configuration-receipts.tsv\n' \
                "$assertion" >>"$canonical"
            awk -F '	' 'BEGIN { OFS=FS }
                {$1="{run}"; $2="{namespace}"; $7="{nonce}";
                 $9="{activation-sha256}"; print}
            ' "$dir/fault-configuration-receipts.tsv" |
                LC_ALL=C sort >>"$canonical"
            printf 'relation\t%s\tfault-trigger-receipts.tsv\n' \
                "$assertion" >>"$canonical"
            awk -F '	' 'BEGIN { OFS=FS }
                {$1="{run}"; $2="{namespace}"; $9="{nonce}";
                 $11="{activation-sha256}"; print}
            ' "$dir/fault-trigger-receipts.tsv" |
                LC_ALL=C sort >>"$canonical"
            printf 'relation\t%s\tfault-markers.tsv\n' \
                "$assertion" >>"$canonical"
            awk -F '	' 'BEGIN { OFS=FS }
                {$2="{run}"; $4="{namespace}"; $5="{nonce}"; print}
            ' "$dir/fault-markers.tsv" |
                LC_ALL=C sort >>"$canonical"
        done
    fi

    "$runtime_verifier" "$dir_a" run-a "$ns_a" "$assertion" "$case_id" \
        "$scenario" "$dir_a/nonexistent.db" ordinary >/dev/null
    "$runtime_verifier" "$dir_b" run-b "$ns_b" "$assertion" "$case_id" \
        "$scenario" "$dir_b/nonexistent.db" ordinary >/dev/null
done <"$cases"

cmp -s "$tmp/canonical-a" "$tmp/canonical-b" ||
    fail BC08_SECOND_RUN_DRIFT_DETECTED

for run in run-a run-b
do
    awk -F '	' '
        NF != 2 || $2 != "BC08_RUNTIME_VALID" || seen[$1]++ { exit 1 }
        END { if (NR != 7) exit 1 }
    ' "$session_dir/$run/runtime-status.tsv" ||
        fail BC08_SESSION_ARTIFACT_INVALID
done

echo BC08_SESSION_VALID
