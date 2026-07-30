#!/bin/sh
set -eu

[ "$#" -eq 3 ] || {
    echo "usage: observe-bc10.sh DB SCENARIO SURFACE" >&2
    exit 2
}

db=$1
scenario=$2
surface=$3

case "$scenario:$surface" in
    bc10-result-*--case-bc10-result-*:result|\
    bc10-view-*--case-bc10-view-*:view|\
    bc10-replay-*--case-bc10-replay-*:replay|\
    bc10-explanation-*--case-bc10-explanation-*:explanation) ;;
    *) exit 2 ;;
esac

query()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

case "$surface" in
    result)
        query "
SELECT '$scenario','raw-001','surface','result','completeness',
       COALESCE((SELECT completeness FROM result_output
                 WHERE result_ref='result-action-1'),'missing')
UNION ALL
SELECT '$scenario','raw-002','provenance','result','request',
       COALESCE((SELECT request_ref FROM result_output
                 WHERE result_ref='result-action-1'),'missing')
UNION ALL
SELECT '$scenario','raw-003','pinned-input','result','binding',
       COALESCE((SELECT input_ref FROM evaluation_input
                 WHERE request_ref='request-1' AND input_role='binding'),
                'missing')
UNION ALL
SELECT '$scenario','raw-004','pinned-input','result','definition',
       COALESCE((SELECT definition_ref FROM result_output
                 WHERE result_ref='result-action-1'),'missing')
UNION ALL
SELECT '$scenario','raw-005','pinned-input','result','knowledge-cut',
       COALESCE((SELECT input_ref FROM evaluation_input
                 WHERE request_ref='request-1'
                   AND input_role='knowledge-cut'),'missing')
UNION ALL
SELECT '$scenario','raw-006','pinned-input','result','source-root',
       COALESCE((SELECT source_root_ref FROM result_output
                 WHERE result_ref='result-action-1'),'missing')
UNION ALL
SELECT '$scenario','raw-007','pinned-input','result','semantics',
       COALESCE((SELECT input_ref FROM evaluation_input
                 WHERE request_ref='request-1' AND input_role='semantics'),
                'missing')
UNION ALL
SELECT '$scenario','raw-008','selection','result','member',
       COALESCE((SELECT selected_member_ref FROM result_output
                 WHERE result_ref='result-action-1'),'missing')
UNION ALL
SELECT '$scenario','raw-009','selection','result','value',
       COALESCE((SELECT selected_value FROM result_output
                 WHERE result_ref='result-action-1'),'missing')
UNION ALL
SELECT '$scenario','raw-010','leak','result','secret-count',
       CAST((SELECT COUNT(*) FROM result_output
             WHERE result_ref='result-action-1'
               AND selected_value='SECRET-BC10-CLOSURE') AS TEXT);"
        ;;
    view)
        query "
SELECT '$scenario','raw-001','surface','view','completeness',
       CASE
         WHEN (SELECT completeness FROM view_output
               WHERE view_ref='view-1')='complete'
          AND (SELECT COUNT(*) FROM view_row
               WHERE view_ref='view-1' AND member_ref='member-public'
                 AND selected_value='public-a')=1
         THEN 'complete' ELSE 'incomplete' END
UNION ALL
SELECT '$scenario','raw-002','provenance','view','source-root',
       COALESCE((SELECT source_root_ref FROM view_output
                 WHERE view_ref='view-1'),'missing')
UNION ALL
SELECT '$scenario','raw-003','provenance','view','source-head',
       COALESCE((SELECT source_head_ref FROM view_output
                 WHERE view_ref='view-1'),'missing')
UNION ALL
SELECT '$scenario','raw-004','provenance','view','definition',
       COALESCE((SELECT definition_ref FROM view_output
                 WHERE view_ref='view-1'),'missing')
UNION ALL
SELECT '$scenario','raw-005','selection','view','member',
       COALESCE((SELECT member_ref FROM view_row
                 WHERE view_ref='view-1' AND ordinal=1),'missing')
UNION ALL
SELECT '$scenario','raw-006','selection','view','value',
       COALESCE((SELECT selected_value FROM view_row
                 WHERE view_ref='view-1' AND ordinal=1),'missing')
UNION ALL
SELECT '$scenario','raw-007','leak','view','secret-count',
       CAST((SELECT COUNT(*) FROM view_row
             WHERE view_ref='view-1'
               AND selected_value='SECRET-BC10-CLOSURE') AS TEXT);"
        ;;
    replay)
        query "
SELECT '$scenario','raw-001','surface','replay','completeness',
       COALESCE((SELECT completeness FROM replay_output
                 WHERE replay_ref='replay-result-1'),'missing')
UNION ALL
SELECT '$scenario','raw-002','provenance','replay','original-result',
       COALESCE((SELECT original_result_ref FROM replay_output
                 WHERE replay_ref='replay-result-1'),'missing')
UNION ALL
SELECT '$scenario','raw-003','pinned-input','replay','binding',
       COALESCE((SELECT input_ref FROM evaluation_input
                 WHERE request_ref='request-1' AND input_role='binding'),
                'missing')
UNION ALL
SELECT '$scenario','raw-004','pinned-input','replay','definition',
       COALESCE((SELECT definition_ref FROM replay_output
                 WHERE replay_ref='replay-result-1'),'missing')
UNION ALL
SELECT '$scenario','raw-005','pinned-input','replay','knowledge-cut',
       COALESCE((SELECT input_ref FROM evaluation_input
                 WHERE request_ref='request-1'
                   AND input_role='knowledge-cut'),'missing')
UNION ALL
SELECT '$scenario','raw-006','pinned-input','replay','source-root',
       COALESCE((SELECT source_root_ref FROM replay_output
                 WHERE replay_ref='replay-result-1'),'missing')
UNION ALL
SELECT '$scenario','raw-007','pinned-input','replay','semantics',
       COALESCE((SELECT input_ref FROM evaluation_input
                 WHERE request_ref='request-1' AND input_role='semantics'),
                'missing')
UNION ALL
SELECT '$scenario','raw-008','selection','replay','value',
       COALESCE((SELECT selected_value FROM replay_output
                 WHERE replay_ref='replay-result-1'),'missing')
UNION ALL
SELECT '$scenario','raw-009','replay','result','symmetric-difference',
       CAST(CASE WHEN
         (SELECT selected_value FROM replay_output
          WHERE replay_ref='replay-result-1') =
         (SELECT selected_value FROM result_output
          WHERE result_ref='result-1')
         THEN 0 ELSE 1 END AS TEXT)
UNION ALL
SELECT '$scenario','raw-010','leak','replay','file-path-count',
       CAST((SELECT COUNT(*) FROM replay_metadata
             WHERE replay_ref='replay-result-1'
               AND metadata_class='file-path') AS TEXT)
UNION ALL
SELECT '$scenario','raw-011','leak','replay','process-id-count',
       CAST((SELECT COUNT(*) FROM replay_metadata
             WHERE replay_ref='replay-result-1'
               AND metadata_class='process-id') AS TEXT)
UNION ALL
SELECT '$scenario','raw-012','leak','replay','row-order-count',
       CAST((SELECT COUNT(*) FROM replay_metadata
             WHERE replay_ref='replay-result-1'
               AND metadata_class='row-order') AS TEXT)
UNION ALL
SELECT '$scenario','raw-013','provenance','replay','replayed-result',
       COALESCE((SELECT replay_ref FROM replay_output
                 WHERE replay_ref='replay-result-1'),'missing');"
        ;;
    explanation)
        query "
SELECT '$scenario','raw-001','surface','explanation','completeness',
       CASE
         WHEN (SELECT completeness FROM explanation_output
               WHERE explanation_ref='explanation-1')='complete'
          AND (SELECT COUNT(*) FROM explanation_edge
               WHERE explanation_ref='explanation-1'
                 AND ordinal BETWEEN 1 AND 5)=5
         THEN 'complete' ELSE 'incomplete' END
UNION ALL
SELECT '$scenario','raw-002','explanation','observation','edge',
       COALESCE((SELECT target_ref FROM explanation_edge
                 WHERE explanation_ref='explanation-1'
                   AND edge_role='observation'),'missing')
UNION ALL
SELECT '$scenario','raw-003','explanation','result','edge',
       COALESCE((SELECT target_ref FROM explanation_edge
                 WHERE explanation_ref='explanation-1'
                   AND edge_role='result'),'missing')
UNION ALL
SELECT '$scenario','raw-004','explanation','request','edge',
       COALESCE((SELECT target_ref FROM explanation_edge
                 WHERE explanation_ref='explanation-1'
                   AND edge_role='request'),'missing')
UNION ALL
SELECT '$scenario','raw-005','explanation','source-root','edge',
       COALESCE((SELECT target_ref FROM explanation_edge
                 WHERE explanation_ref='explanation-1'
                   AND edge_role='source-root'),'missing')
UNION ALL
SELECT '$scenario','raw-006','explanation','selected-member','edge',
       COALESCE((SELECT target_ref FROM explanation_edge
                 WHERE explanation_ref='explanation-1'
                   AND edge_role='selected-member'),'missing')
UNION ALL
SELECT '$scenario','raw-007','leak','explanation','secret-count',
       CAST((SELECT COUNT(*) FROM explanation_edge
             WHERE explanation_ref='explanation-1'
               AND target_ref='member-secret') AS TEXT);"
        ;;
esac

printf 'pragma\tforeign-keys\t1\n' >&2
