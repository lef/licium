#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

[ "$#" -eq 6 ] || exit 2
artifact_dir=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
scenario=$6

case "$assertion:$case_id" in
    BC08_COMPLETE_EFFECT:case-bc08-complete)
        marker=BC08_INCOMPLETE_EFFECT_DETECTED ;;
    BC08_MID_BOUNDARY_FAILURE:case-bc08-boundary)
        marker=BC08_PARTIAL_EFFECT_DETECTED ;;
    BC08_MISSING_CURRENT:case-bc08-current)
        marker=BC08_MISSING_CURRENT_DETECTED ;;
    BC08_MISSING_OBSERVATION:case-bc08-observation)
        marker=BC08_MISSING_OBSERVATION_DETECTED ;;
    BC08_MISSING_RESULT:case-bc08-result)
        marker=BC08_MISSING_RESULT_DETECTED ;;
    BC08_MISSING_TRANSITION:case-bc08-transition)
        marker=BC08_MISSING_TRANSITION_DETECTED ;;
    BC08_MISSING_VIEW:case-bc08-view)
        marker=BC08_MISSING_VIEW_DETECTED ;;
    *) exit 2 ;;
esac

fail()
{
    echo "$marker" >&2
    exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for stage in before after reopened
do
    awk -F '	' -v scenario="$scenario" '$1 == scenario' \
        "$base_dir/bc08-inventory-$stage.tsv" |
        LC_ALL=C sort >"$tmp/inventory-$stage.expected"
    LC_ALL=C sort "$artifact_dir/inventory-$stage.tsv" \
        >"$tmp/inventory-$stage.actual"
    cmp -s "$tmp/inventory-$stage.expected" \
        "$tmp/inventory-$stage.actual" || fail
done

for relation in raw-observations normalized-observations
do
    source="$base_dir/bc08-normalized-contract.tsv"
    prefix=obs
    [ "$relation" = raw-observations ] && prefix=raw
    awk -F '	' -v OFS='	' -v scenario="$scenario" -v prefix="$prefix" '
        $1 == scenario {
            sub(/^obs-/, prefix "-", $2)
            print
        }
    ' "$source" | LC_ALL=C sort >"$tmp/$relation.expected"
    LC_ALL=C sort "$artifact_dir/$relation.tsv" >"$tmp/$relation.actual"
    cmp -s "$tmp/$relation.expected" "$tmp/$relation.actual" || fail
done

awk -F '	' -v run="$run" -v ns="$namespace" -v scenario="$scenario" '
    NF != 15 || $1 != run || $2 != ns || $3 != scenario ||
        $4 != "sut-apply-effect" || $6 != "effect-1" ||
        $7 != "result-1" || $8 != "transition-1" ||
        $9 != "observation-1" || $10 != "view-1" ||
        $11 != "rev-2" || $12 != "accepted" || $13 != 5 { exit 1 }
    NR == 1 {
        if ($5 != "ordinary" || $15 != "first") exit 1
    }
    NR == 2 {
        if ($5 != "retry" || $15 != "second") exit 1
    }
    END { if (NR != 2) exit 1 }
' "$artifact_dir/action-receipts.tsv" || fail

if [ "$assertion" = BC08_MID_BOUNDARY_FAILURE ]; then
    for stage in setup rollback healthy reopened
    do
        expected_name=$stage
        [ "$stage" = setup ] || [ "$stage" = rollback ] ||
            expected_name=$stage
        LC_ALL=C sort "$base_dir/bc08-fault-inventory-$expected_name.tsv" \
            >"$tmp/fault-$stage.expected"
        LC_ALL=C sort "$artifact_dir/fault-inventory-$stage.tsv" \
            >"$tmp/fault-$stage.actual"
        cmp -s "$tmp/fault-$stage.expected" \
            "$tmp/fault-$stage.actual" || fail
    done
    for specification in \
        "fault-activation-receipts.tsv:10:5" \
        "fault-configuration-receipts.tsv:14:5" \
        "fault-trigger-receipts.tsv:21:5" \
        "fault-markers.tsv:11:5"
    do
        file=${specification%%:*}
        rest=${specification#*:}
        fields=${rest%%:*}
        rows=${rest#*:}
        awk -F '	' -v fields="$fields" -v rows="$rows" \
            'NF != fields { exit 1 }
             END { if (NR != rows) exit 1 }' \
            "$artifact_dir/$file" || fail
    done
else
    for file in fault-activation-receipts.tsv \
        fault-configuration-receipts.tsv fault-trigger-receipts.tsv \
        fault-markers.tsv fault-inventory-setup.tsv \
        fault-inventory-rollback.tsv fault-inventory-healthy.tsv \
        fault-inventory-reopened.tsv
    do
        [ ! -s "$artifact_dir/$file" ] || fail
    done
fi

printf '%s\toracle-%s\tPASS\tnorm-bc08-observation\tnormal\t-\n' \
    "$assertion" "$(printf '%s' "$assertion" |
        tr '[:upper:]_' '[:lower:]-')"
