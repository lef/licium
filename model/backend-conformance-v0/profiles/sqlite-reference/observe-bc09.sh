#!/bin/sh
set -eu

[ "$#" -eq 8 ] || {
    echo "usage: observe-bc09.sh SCENARIO CASE ACTIONS BEFORE AFTER REOPENED TRIGGERS OUTPUT" >&2
    exit 2
}

scenario=$1
case_id=$2
actions=$3
before=$4
after=$5
reopened=$6
trigger_count=$7
output=$8

for file in "$actions" "$before" "$after" "$reopened"
do
    [ -f "$file" ] && [ ! -L "$file" ] || exit 2
done
case "$trigger_count" in 0|1) ;; *) exit 2 ;; esac

last=$(
    awk -F '	' -v case_id="$case_id" '
        $4 == case_id && $14 != "healthy" { line = $0 }
        END {
            if (line == "") exit 1
            print line
        }
    ' "$actions"
)
disposition=$(printf '%s\n' "$last" | awk -F '	' '{ print $9 }')
reason=$(printf '%s\n' "$last" | awk -F '	' '{ print $10 }')
delivery_count=$(
    awk -F '	' -v case_id="$case_id" '
        $4 == case_id && $14 != "healthy" { count++ }
        END { print count + 0 }
    ' "$actions"
)

inventory_equal=false
if cmp -s "$before" "$after" && cmp -s "$before" "$reopened"; then
    inventory_equal=true
fi

delta()
{
    relation=$1
    before_count=$(
        awk -F '	' -v relation="$relation" '$2 == relation { count++ }
            END { print count + 0 }' "$before"
    )
    after_count=$(
        awk -F '	' -v relation="$relation" '$2 == relation { count++ }
            END { print count + 0 }' "$after"
    )
    printf '%s\n' "$((after_count - before_count))"
}

transition_delta=$(delta state-transition)
observation_delta=$(delta decision-observation)
view_delta=$(delta view-header)
current_delta=$(delta current-view)
attempt_delta=$(delta persistent-attempt)

{
    printf '%s\traw-%s-001\tdiagnostic\tdisposition\tresult\t%s\n' \
        "$scenario" "$case_id" "$disposition"
    printf '%s\traw-%s-002\tdiagnostic\treason\tresult\t%s\n' \
        "$scenario" "$case_id" "$reason"
    printf '%s\traw-%s-003\trepository\tinventory-equal\tresult\t%s\n' \
        "$scenario" "$case_id" "$inventory_equal"
    printf '%s\traw-%s-004\tstate-transition\tdelta\tresult\t%s\n' \
        "$scenario" "$case_id" "$transition_delta"
    printf '%s\traw-%s-005\tdecision-observation\tdelta\tresult\t%s\n' \
        "$scenario" "$case_id" "$observation_delta"
    printf '%s\traw-%s-006\tview\tdelta\tresult\t%s\n' \
        "$scenario" "$case_id" "$view_delta"
    printf '%s\traw-%s-007\tcurrent\tdelta\tresult\t%s\n' \
        "$scenario" "$case_id" "$current_delta"
    printf '%s\traw-%s-008\tpersistent-attempt\tdelta\tresult\t%s\n' \
        "$scenario" "$case_id" "$attempt_delta"
    printf '%s\traw-%s-009\tdelivery\tcount\tresult\t%s\n' \
        "$scenario" "$case_id" "$delivery_count"
    printf '%s\traw-%s-010\tfault-hook\ttriggered-count\tresult\t%s\n' \
        "$scenario" "$case_id" "$trigger_count"
} >"$output"
