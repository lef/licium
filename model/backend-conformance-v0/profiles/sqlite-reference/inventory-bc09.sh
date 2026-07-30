#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: inventory-bc09.sh DB CASE" >&2
    exit 2
}

db=$1
case_id=$2

sqlite3 -batch -bail -noheader -tabs "$db" <<SQL | LC_ALL=C sort
PRAGMA foreign_keys=ON;
SELECT '$case_id','authoritative-state',scope_ref,'revision',revision_ref,'0001'
  FROM authoritative_state;
SELECT '$case_id','current-view',scope_ref,'binding',
       view_ref || ',' || revision_ref,'0001'
  FROM current_view;
SELECT '$case_id','decision-observation',observation_ref,'binding',
       transition_ref || ',' || result_ref || ',' || source_root_ref || ',' ||
       view_ref,'0001'
  FROM decision_observation;
SELECT '$case_id','effect-request',effect_ref,'binding',
       result_ref || ',' || scope_ref || ',' || expected_revision_ref,'0001'
  FROM effect_request;
SELECT '$case_id','evaluation-result',result_ref,'completeness',
       completeness,'0001'
  FROM evaluation_result;
SELECT '$case_id','evaluation-result',result_ref,'disposition',
       disposition,'0001'
  FROM evaluation_result;
SELECT '$case_id','evaluation-result',result_ref,'payload',
       result_payload,'0001'
  FROM evaluation_result;
SELECT '$case_id','persistent-attempt',attempt_ref,'binding',
       effect_ref || ',' || disposition || ',' || reason,'0001'
  FROM attempt_artifact;
SELECT '$case_id','state-transition',transition_ref,'binding',
       effect_ref || ',' || before_revision_ref || ',' || after_revision_ref,
       '0001'
  FROM state_transition;
SELECT '$case_id','view-header',view_ref,'binding',
       effect_ref || ',' || result_ref || ',' || source_root_ref || ',' ||
       revision_ref || ',' || completeness || ',' || row_count,'0001'
  FROM view_header;
SQL

printf 'pragma\tforeign-keys\t1\n' >&2
