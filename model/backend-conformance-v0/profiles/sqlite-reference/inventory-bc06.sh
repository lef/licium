#!/bin/sh
set -eu

[ "$#" -eq 2 ] || exit 2
db=$1
scenario=$2

sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','authoritative-state','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','authoritative-state',scope_ref,'state-ref',state_ref,'0001'
FROM authoritative_state
UNION ALL
SELECT '$scenario','decision-observation','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','decision-observation',observation_ref,'request-ref',request_ref,'0001'
FROM decision_observation
UNION ALL
SELECT '$scenario','evaluation-request','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','evaluation-request',request_ref,'request-kind',request_kind,'0001'
FROM evaluation_request
UNION ALL
SELECT '$scenario','evaluation-request',request_ref,'source-object-ref',source_object_ref,'0001'
FROM evaluation_request
UNION ALL
SELECT '$scenario','result-store','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','result-store',result_ref,'request-ref',request_ref,'0001'
FROM result_store
UNION ALL
SELECT '$scenario','source-pair','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','source-pair',object_ref,'logical-id',logical_id,'0001'
FROM source_pair
UNION ALL
SELECT '$scenario','source-pair',object_ref,'logical-value',logical_value,'0001'
FROM source_pair
ORDER BY 1,2,3,4,5,6;
"
printf 'pragma\tforeign-keys\t1\n' >&2
