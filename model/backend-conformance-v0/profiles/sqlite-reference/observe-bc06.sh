#!/bin/sh
set -eu

[ "$#" -eq 3 ] || exit 2
db=$1
scenario=$2
phase=$3

case "$phase" in
    before)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-001','authoritative-state','before','@relation','present'
UNION ALL
SELECT '$scenario','raw-002','authoritative-state','before',scope_ref,state_ref
FROM authoritative_state
UNION ALL
SELECT '$scenario','raw-005','decision-observation','before','@relation','present'
UNION ALL
SELECT '$scenario','raw-before-observation-' || observation_ref,
       'decision-observation','before',observation_ref,request_ref
FROM decision_observation
UNION ALL
SELECT '$scenario','raw-008','result-store','before','@relation','present'
UNION ALL
SELECT '$scenario','raw-before-result-' || result_ref,
       'result-store','before',result_ref,request_ref
FROM result_store
ORDER BY 1,2,3,4,5,6;
"
        ;;
    after)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-003','authoritative-state','after','@relation','present'
UNION ALL
SELECT '$scenario','raw-004','authoritative-state','after',scope_ref,state_ref
FROM authoritative_state
UNION ALL
SELECT '$scenario','raw-006','decision-observation','after','@relation','present'
UNION ALL
SELECT '$scenario','raw-after-observation-' || observation_ref,
       'decision-observation','after',observation_ref,request_ref
FROM decision_observation
UNION ALL
SELECT '$scenario','raw-009','result-store','after','@relation','present'
UNION ALL
SELECT '$scenario','raw-after-result-' || result_ref,
       'result-store','after',result_ref,request_ref
FROM result_store
ORDER BY 1,2,3,4,5,6;
"
        ;;
    *)
        exit 2
        ;;
esac
printf 'pragma\tforeign-keys\t1\n' >&2
