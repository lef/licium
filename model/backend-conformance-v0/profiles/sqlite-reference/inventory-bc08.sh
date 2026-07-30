#!/bin/sh
set -eu

[ "$#" -eq 2 ] || exit 2
db=$1
subject=$2

sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$subject','authoritative-state',scope_ref,'revision',revision_ref,'0001'
  FROM authoritative_state
UNION ALL
SELECT '$subject','current-view',scope_ref,'binding',
       view_ref || ',' || revision_ref,'0001'
  FROM current_view
UNION ALL
SELECT '$subject','decision-observation',observation_ref,'binding',
       transition_ref || ',' || result_ref || ',' || source_root_ref || ',' ||
       view_ref,'0001'
  FROM decision_observation
UNION ALL
SELECT '$subject','effect-request',effect_ref,'binding',
       result_ref || ',' || scope_ref || ',' || expected_revision_ref,'0001'
  FROM effect_request
UNION ALL
SELECT '$subject','evaluation-result',result_ref,'digest',result_digest,'0001'
  FROM evaluation_result
UNION ALL
SELECT '$subject','evaluation-result',result_ref,'payload',result_payload,'0001'
  FROM evaluation_result
UNION ALL
SELECT '$subject','state-transition',transition_ref,'binding',
       effect_ref || ',' || before_revision_ref || ',' || after_revision_ref,
       '0001'
  FROM state_transition
UNION ALL
SELECT '$subject','view-header',h.view_ref,'binding',
       h.effect_ref || ',' || h.result_ref || ',' || h.source_root_ref || ',' ||
       h.revision_ref || ',' || h.completeness || ',' ||
       CAST((SELECT COUNT(*) FROM view_row r
              WHERE r.view_ref=h.view_ref) AS TEXT),
       '0001'
  FROM view_header h
ORDER BY 1,2,3,4,5,6;
"
printf 'pragma\tforeign-keys\t1\n' >&2
