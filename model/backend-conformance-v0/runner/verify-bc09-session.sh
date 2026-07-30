#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

[ "$#" -eq 1 ] || exit 2
session_dir=$1

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
cases="$base_dir/bc09-cases.tsv"
runtime_verifier="$script_dir/verify-bc09-runtime.sh"
run_a="$session_dir/run-a"
run_b="$session_dir/run-b"

fail()
{
    echo "$1" >&2
    exit 1
}

[ -d "$run_a" ] && [ ! -L "$run_a" ] &&
    [ -d "$run_b" ] && [ ! -L "$run_b" ] ||
    fail BC09_SESSION_ARTIFACT_MISSING

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
: >"$tmp/canonical-a"
: >"$tmp/canonical-b"

awk -F '	' '!seen[$1]++ { print $1 }' "$cases" |
    while IFS= read -r assertion
    do
        name=$(printf '%s' "$assertion" | tr 'A-Z_' 'a-z-')
        scenario=$(
            awk -F '	' -v assertion="$assertion" '
                $1 == assertion { print $3 }
            ' "$base_dir/bc09-scenario-ids.tsv"
        )
        dir_a="$run_a/$name"
        dir_b="$run_b/$name"
        ns_a="ns-a-$name"
        ns_b="ns-b-$name"
        [ -d "$dir_a" ] && [ ! -L "$dir_a" ] &&
            [ -d "$dir_b" ] && [ ! -L "$dir_b" ] ||
            fail BC09_SESSION_ARTIFACT_MISSING

        awk -F '	' -v run=run-a -v ns="$ns_a" \
            -v assertion="$assertion" '
            NF != 14 || $1 != run || $2 != ns "-" substr($4, 6) ||
                $3 != assertion { exit 1 }
            { nonce[$12] = 1 }
            END { if (NR == 0 || length(nonce) == 0) exit 1 }
        ' "$dir_a/action-receipts.tsv" ||
            fail BC09_COPIED_RUN_DETECTED
        awk -F '	' -v run=run-b -v ns="$ns_b" \
            -v assertion="$assertion" '
            NF != 14 || $1 != run || $2 != ns "-" substr($4, 6) ||
                $3 != assertion { exit 1 }
            { nonce[$12] = 1 }
            END { if (NR == 0 || length(nonce) == 0) exit 1 }
        ' "$dir_b/action-receipts.tsv" ||
            fail BC09_COPIED_RUN_DETECTED
        nonce_a=$(awk -F '	' 'NR == 1 { print $12 }' \
            "$dir_a/action-receipts.tsv")
        nonce_b=$(awk -F '	' 'NR == 1 { print $12 }' \
            "$dir_b/action-receipts.tsv")
        [ "$nonce_a" != "$nonce_b" ] ||
            fail BC09_COPIED_RUN_DETECTED

        for relation in coverage.tsv inventory-after.tsv \
            inventory-before.tsv inventory-reopened.tsv \
            normalized-observations.tsv oracle-result.tsv \
            raw-observations.tsv fault-inventory-setup.tsv \
            fault-inventory-rollback.tsv fault-inventory-healthy.tsv \
            fault-inventory-reopened.tsv
        do
            printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
                >>"$tmp/canonical-a"
            sort "$dir_a/$relation" >>"$tmp/canonical-a"
            printf 'relation\t%s\t%s\n' "$assertion" "$relation" \
                >>"$tmp/canonical-b"
            sort "$dir_b/$relation" >>"$tmp/canonical-b"
        done

        if [ "$assertion" = BC09_FAILPOINT_PERSISTS ]; then
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
                    sort >>"$canonical"
                printf 'relation\t%s\tfault-configuration-receipts.tsv\n' \
                    "$assertion" >>"$canonical"
                awk -F '	' 'BEGIN { OFS=FS }
                    {$1="{run}"; $2="{namespace}"; $7="{nonce}";
                     $9="{activation-sha256}"; print}
                ' "$dir/fault-configuration-receipts.tsv" |
                    sort >>"$canonical"
                printf 'relation\t%s\tfault-trigger-receipts.tsv\n' \
                    "$assertion" >>"$canonical"
                awk -F '	' 'BEGIN { OFS=FS }
                    {$1="{run}"; $2="{namespace}"; $9="{nonce}";
                     $11="{activation-sha256}"; print}
                ' "$dir/fault-trigger-receipts.tsv" |
                    sort >>"$canonical"
                printf 'relation\t%s\tfault-markers.tsv\n' \
                    "$assertion" >>"$canonical"
                awk -F '	' 'BEGIN { OFS=FS }
                    {$2="{run}"; $4="{namespace}"; $5="{nonce}"; print}
                ' "$dir/fault-markers.tsv" |
                    sort >>"$canonical"
            done
        fi

        "$runtime_verifier" "$dir_a" run-a "$ns_a" "$assertion" \
            "$scenario" >/dev/null
        "$runtime_verifier" "$dir_b" run-b "$ns_b" "$assertion" \
            "$scenario" >/dev/null
    done

cmp -s "$tmp/canonical-a" "$tmp/canonical-b" ||
    fail BC09_SECOND_RUN_DRIFT_DETECTED

for run in run-a run-b
do
    awk -F '	' '
        NF != 2 || $2 != "BC09_RUNTIME_VALID" || seen[$1]++ { exit 1 }
        END { if (NR != 7) exit 1 }
    ' "$session_dir/$run/runtime-status.tsv" ||
        fail BC09_SESSION_ARTIFACT_INVALID
done

echo BC09_SESSION_VALID
