#!/bin/sh
set -eu

[ "$#" -eq 2 ] || exit 2
db=$1
scenario=$2

sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','authoritative-state',scope_ref,'revision',revision_ref,'0001'
FROM authoritative_state
UNION ALL
SELECT '$scenario','decision-observation','@relation','presence','present','0001'
WHERE NOT EXISTS (SELECT 1 FROM decision_observation)
UNION ALL
SELECT '$scenario','decision-observation',observation_ref,'effect-ref',effect_ref,'0001'
FROM decision_observation
UNION ALL
SELECT '$scenario','decision-observation',observation_ref,'result-ref',result_ref,'0001'
FROM decision_observation
UNION ALL
SELECT '$scenario','decision-observation',observation_ref,'transition-ref',transition_ref,'0001'
FROM decision_observation
UNION ALL
SELECT '$scenario','effect-request',effect_ref,'expected-revision',expected_revision_ref,'0001'
FROM effect_request
UNION ALL
SELECT '$scenario','effect-request',effect_ref,'result-ref',result_ref,'0001'
FROM effect_request
UNION ALL
SELECT '$scenario','evaluation-request',request_ref,'request-kind',request_kind,'0001'
FROM evaluation_request
UNION ALL
SELECT '$scenario','evaluation-result','@relation','presence','present','0001'
WHERE NOT EXISTS (SELECT 1 FROM evaluation_result)
UNION ALL
SELECT '$scenario','evaluation-result',result_ref,'result-digest',result_digest,'0001'
FROM evaluation_result
UNION ALL
SELECT '$scenario','evaluation-result',result_ref,'result-payload',result_payload,'0001'
FROM evaluation_result
UNION ALL
SELECT '$scenario','state-transition','@relation','presence','present','0001'
WHERE NOT EXISTS (SELECT 1 FROM state_transition)
UNION ALL
SELECT '$scenario','state-transition',transition_ref,'after-revision',after_revision_ref,'0001'
FROM state_transition
UNION ALL
SELECT '$scenario','state-transition',transition_ref,'before-revision',before_revision_ref,'0001'
FROM state_transition
UNION ALL
SELECT '$scenario','state-transition',transition_ref,'effect-ref',effect_ref,'0001'
FROM state_transition
ORDER BY 1,2,3,4,5,6;
"
printf 'pragma\tforeign-keys\t1\n' >&2
