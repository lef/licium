#!/bin/sh
set -eu

[ "$#" -eq 5 ] || exit 2
db=$1
scenario=$2
receipt=$3
retry_receipt=$4
triggered_hooks=$5

outcome=$(awk -F '	' 'NR == 1 { print $12 }' "$receipt")
effect=$(awk -F '	' 'NR == 1 { print $6 }' "$receipt")
result=$(awk -F '	' 'NR == 1 { print $7 }' "$receipt")
transition=$(awk -F '	' 'NR == 1 { print $8 }' "$receipt")
observation=$(awk -F '	' 'NR == 1 { print $9 }' "$receipt")
view=$(awk -F '	' 'NR == 1 { print $10 }' "$receipt")
retry_effect=$(awk -F '	' 'NR == 1 { print $6 }' "$retry_receipt")

values=$(sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT
  COALESCE((SELECT result_digest FROM evaluation_result
             WHERE result_ref='$result'),'missing'),
  (SELECT COUNT(*) FROM state_transition
    WHERE transition_ref='$transition'),
  (SELECT COUNT(*) FROM decision_observation
    WHERE observation_ref='$observation'),
  (SELECT COUNT(*) FROM view_header WHERE view_ref='$view'),
  (SELECT COUNT(*) FROM view_row WHERE view_ref='$view'),
  (SELECT COUNT(*) FROM current_view WHERE scope_ref='scope-1'),
  CASE WHEN
    (SELECT COUNT(*) FROM evaluation_result
      WHERE result_ref='$result' AND completeness='complete')=1 AND
    (SELECT COUNT(*) FROM state_transition
      WHERE transition_ref='$transition' AND effect_ref='$effect')=1 AND
    (SELECT COUNT(*) FROM decision_observation
      WHERE observation_ref='$observation' AND transition_ref='$transition'
        AND result_ref='$result' AND view_ref='$view')=1 AND
    (SELECT COUNT(*) FROM view_header
      WHERE view_ref='$view' AND effect_ref='$effect'
        AND result_ref='$result' AND completeness='complete')=1 AND
    (SELECT COUNT(*) FROM view_row WHERE view_ref='$view')=2 AND
    (SELECT COUNT(*) FROM current_view
      WHERE scope_ref='scope-1' AND view_ref='$view'
        AND revision_ref='rev-2')=1
  THEN 'complete' ELSE 'incomplete' END;
")
IFS='	' read -r digest transitions observations headers rows currents completeness <<EOF
$values
EOF

if [ "$transitions:$observations:$headers:$rows:$currents" = "1:1:1:2:1" ]; then
    retry_cardinality=no-duplicate
else
    retry_cardinality=duplicate-or-incomplete
fi

printf '%s\traw-001\teffect\t%s\toutcome\t%s\n' "$scenario" "$effect" "$outcome"
printf '%s\traw-002\tevaluation-result\t%s\tdigest\t%s\n' "$scenario" "$result" "$digest"
printf '%s\traw-003\tstate-transition\t%s\tcardinality\t%s\n' "$scenario" "$transition" "$transitions"
printf '%s\traw-004\tdecision-observation\t%s\tcardinality\t%s\n' "$scenario" "$observation" "$observations"
printf '%s\traw-005\tview-header\t%s\tcardinality\t%s\n' "$scenario" "$view" "$headers"
printf '%s\traw-006\tview-row\t%s\tcardinality\t%s\n' "$scenario" "$view" "$rows"
printf '%s\traw-007\tcurrent-view\tscope-1\tcardinality\t%s\n' "$scenario" "$currents"
printf '%s\traw-008\teffect-set\t%s\tcompleteness\t%s\n' "$scenario" "$effect" "$completeness"
printf '%s\traw-009\tretry\t%s\teffect-ref\t%s\n' "$scenario" "$effect" \
    "$([ "$effect" = "$retry_effect" ] && printf same || printf different)"
printf '%s\traw-010\tretry\t%s\tartifact-cardinality\t%s\n' "$scenario" "$effect" "$retry_cardinality"
printf '%s\traw-011\tfault-set\t%s\ttriggered-hooks\t%s\n' "$scenario" "$effect" "$triggered_hooks"
if [ "$triggered_hooks" = 5 ]; then
    printf '%s\traw-012\tfault-set\t%s\tpartial-artifacts\t0\n' "$scenario" "$effect"
else
    printf '%s\traw-012\tfault-set\t%s\tpartial-artifacts\tnot-applicable\n' "$scenario" "$effect"
fi
printf 'pragma\tforeign-keys\t1\n' >&2
