#!/bin/sh
set -eu

[ "$#" -eq 4 ] || exit 2
db=$1
scenario=$2
before=$3
receipt=$4
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
after=$(mktemp)
trap 'rm -f "$after"' EXIT HUP INT TERM
"$script_dir/inventory-bc07.sh" "$db" "$scenario" >"$after" 2>/dev/null

operation=$(awk -F '	' 'NR == 1 { print $4 }' "$receipt")
mode=$(awk -F '	' 'NR == 1 { print $5 }' "$receipt")
result=$(awk -F '	' 'NR == 1 { print $7 }' "$receipt")

relation_changed()
{
    role=$1
    before_part=$(mktemp)
    after_part=$(mktemp)
    awk -F '	' -v role="$role" '$2 == role' "$before" >"$before_part"
    awk -F '	' -v role="$role" '$2 == role' "$after" >"$after_part"
    if cmp -s "$before_part" "$after_part"; then
        printf '0\n'
    else
        printf '1\n'
    fi
    rm -f "$before_part" "$after_part"
}

state_axis=$(relation_changed authoritative-state)
result_axis=$(relation_changed evaluation-result)
observation_axis=$(relation_changed decision-observation)
vector="${state_axis}${result_axis}${observation_axis}"

if [ "$result" = - ]; then
    result_integrity=absent
elif awk -F '	' -v result="$result" \
    '$2 == "evaluation-result" && $3 == result { found = 1 }
     END { exit !found }' "$before"; then
    before_result=$(awk -F '	' -v result="$result" \
        '$2 == "evaluation-result" && $3 == result' "$before")
    after_result=$(awk -F '	' -v result="$result" \
        '$2 == "evaluation-result" && $3 == result' "$after")
    if [ "$before_result" = "$after_result" ]; then
        result_integrity=equal
    else
        result_integrity=rewritten
    fi
else
    result_integrity=added
fi

observation=$(awk -F '	' \
    '$2 == "decision-observation" && $3 != "@relation" {
        print $3; exit
    }' "$after")
if [ -z "$observation" ]; then
    observation=-
    linkage=absent
else
    transition_ref=$(awk -F '	' -v observation="$observation" \
        '$2 == "decision-observation" && $3 == observation &&
         $4 == "transition-ref" { print $5 }' "$after")
    result_ref=$(awk -F '	' -v observation="$observation" \
        '$2 == "decision-observation" && $3 == observation &&
         $4 == "result-ref" { print $5 }' "$after")
    effect_ref=$(awk -F '	' -v observation="$observation" \
        '$2 == "decision-observation" && $3 == observation &&
         $4 == "effect-ref" { print $5 }' "$after")
    if awk -F '	' -v transition="$transition_ref" \
        '$2 == "state-transition" && $3 == transition &&
         $4 == "effect-ref" { found = 1 }
         END { exit !found }' "$after" &&
        ! awk -F '	' -v transition="$transition_ref" \
        '$2 == "state-transition" && $3 == transition { found = 1 }
         END { exit !found }' "$before" &&
        [ "$result_ref" = "$result" ] &&
        [ "$effect_ref" = "$(awk -F '	' 'NR == 1 { print $8 }' "$receipt")" ]
    then
        linkage=complete
    else
        linkage=incomplete
    fi
fi

printf '%s\traw-001\texecution\taction\toperation\t%s\n' \
    "$scenario" "$operation"
printf '%s\traw-002\texecution\taction\tmode\t%s\n' \
    "$scenario" "$mode"
printf '%s\traw-003\tpersistent-write\taction\taxis-vector\t%s\n' \
    "$scenario" "$vector"
printf '%s\traw-004\tpersistent-write\tauthoritative-state\tchange\t%s\n' \
    "$scenario" "$state_axis"
printf '%s\traw-005\tpersistent-write\tresult-store\tchange\t%s\n' \
    "$scenario" "$result_axis"
printf '%s\traw-006\tpersistent-write\tdecision-observation\tchange\t%s\n' \
    "$scenario" "$observation_axis"
printf '%s\traw-007\tresult-integrity\t%s\tbefore-after\t%s\n' \
    "$scenario" "$result" "$result_integrity"
printf '%s\traw-008\tlinkage\t%s\ttransition-result-effect\t%s\n' \
    "$scenario" "$observation" "$linkage"
printf 'pragma\tforeign-keys\t1\n' >&2
