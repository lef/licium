#!/bin/sh
set -eu

[ "$#" -eq 3 ] || {
    echo "usage: observe-bc11.sh DB SCENARIO SURFACE" >&2
    exit 2
}

db=$1
scenario=$2
surface=$3

case "$scenario:$surface" in
    bc11-replay-*--case-bc11-replay-*:replay|\
    bc11-latest-*--case-bc11-latest-*:replay|\
    bc11-missing-*--case-bc11-missing-*:replay|\
    bc11-explanation-*--case-bc11-explanation-*:explanation|\
    bc11-finding-*--case-bc11-finding-*:integrity|\
    bc11-silent-*--case-bc11-silent-*:integrity) ;;
    *) exit 2 ;;
esac

query()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

case "$scenario" in
    bc11-replay-result--case-bc11-replay-result)
        query "
SELECT '$scenario','raw-001','surface','replay','completeness',
       COALESCE((SELECT disposition FROM replay_output
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
SELECT '$scenario','raw-010','provenance','replay','replayed-result',
       COALESCE((SELECT replay_ref FROM replay_output
                 WHERE replay_ref='replay-result-1'),'missing');"
        ;;
    bc11-latest-substitution--case-bc11-latest-substitution)
        query "
SELECT '$scenario','raw-001','surface','replay','completeness',
       COALESCE((SELECT disposition FROM replay_output
                 WHERE replay_ref='replay-result-1'),'missing')
UNION ALL
SELECT '$scenario','raw-002','provenance','replay','original-result',
       COALESCE((SELECT original_result_ref FROM replay_output
                 WHERE replay_ref='replay-result-1'),'missing')
UNION ALL
SELECT '$scenario','raw-003','pinned-input','replay','binding',
       (SELECT input_ref FROM evaluation_input
        WHERE request_ref='request-1' AND input_role='binding')
UNION ALL
SELECT '$scenario','raw-004','pinned-input','replay','definition',
       (SELECT definition_ref FROM replay_output
        WHERE replay_ref='replay-result-1')
UNION ALL
SELECT '$scenario','raw-005','pinned-input','replay','knowledge-cut',
       (SELECT input_ref FROM evaluation_input
        WHERE request_ref='request-1' AND input_role='knowledge-cut')
UNION ALL
SELECT '$scenario','raw-006','pinned-input','replay','source-root',
       (SELECT source_root_ref FROM replay_output
        WHERE replay_ref='replay-result-1')
UNION ALL
SELECT '$scenario','raw-007','pinned-input','replay','ambient-root',
       (SELECT root_ref FROM ambient_current WHERE slot='default')
UNION ALL
SELECT '$scenario','raw-008','pinned-input','replay','semantics',
       (SELECT input_ref FROM evaluation_input
        WHERE request_ref='request-1' AND input_role='semantics')
UNION ALL
SELECT '$scenario','raw-009','selection','replay','value',
       (SELECT selected_value FROM replay_output
        WHERE replay_ref='replay-result-1')
UNION ALL
SELECT '$scenario','raw-010','replay','result','symmetric-difference',
       CAST(CASE WHEN
         (SELECT selected_value FROM replay_output
          WHERE replay_ref='replay-result-1')='public-a'
         THEN 0 ELSE 1 END AS TEXT)
UNION ALL
SELECT '$scenario','raw-011','provenance','replay','replayed-result',
       (SELECT replay_ref FROM replay_output
        WHERE replay_ref='replay-result-1');"
        ;;
    bc11-missing-as-empty--case-bc11-missing-as-empty)
        query "
WITH roles(role,ordinal) AS (
  VALUES ('binding',1),('definition',2),('knowledge-cut',3),
         ('source-root',4),('semantics',5)
), rows AS (
  SELECT o.omitted_role,o.input_role,o.input_status,o.disposition,
         o.difference_count,
         CASE o.omitted_role
           WHEN 'binding' THEN 0 WHEN 'definition' THEN 7
           WHEN 'knowledge-cut' THEN 14 WHEN 'source-root' THEN 21
           ELSE 28 END AS base,
         r.ordinal
  FROM replay_omission o JOIN roles r ON r.role=o.input_role
)
SELECT '$scenario',
       printf('raw-%03d',base+ordinal),
       'input-status','omission-' || omitted_role,input_role,input_status
FROM rows
UNION ALL
SELECT '$scenario',printf('raw-%03d',base+6),
       'replay','omission-' || omitted_role,'disposition',disposition
FROM rows WHERE ordinal=1
UNION ALL
SELECT '$scenario',printf('raw-%03d',base+7),
       'replay','omission-' || omitted_role,'difference-count',
       CAST(difference_count AS TEXT)
FROM rows WHERE ordinal=1
ORDER BY 2;"
        ;;
    bc11-explanation-closure--case-bc11-explanation-closure)
        query "
SELECT '$scenario','raw-001','surface','explanation','completeness',
       CASE WHEN
         (SELECT completeness FROM explanation_output
          WHERE explanation_ref='explanation-1')='complete'
         AND (SELECT COUNT(*) FROM explanation_edge
              WHERE explanation_ref='explanation-1')=5
       THEN 'complete' ELSE 'incomplete' END
UNION ALL
SELECT '$scenario',printf('raw-%03d',ordinal+1),
       'explanation',edge_role,'edge',target_ref
FROM explanation_edge
WHERE explanation_ref='explanation-1'
ORDER BY 2;"
        ;;
    bc11-finding-cross-link--case-bc11-finding-cross-link|\
    bc11-silent-cross-link--case-bc11-silent-cross-link)
        silent=0
        [ "$scenario" != \
          bc11-silent-cross-link--case-bc11-silent-cross-link ] ||
            silent=1
        query "
SELECT '$scenario','raw-001','surface','integrity','completeness',
       CASE WHEN EXISTS (
         SELECT 1 FROM validation_inventory
         WHERE validation_ref='validation-cross'
       ) THEN 'complete' ELSE 'missing' END
UNION ALL
SELECT '$scenario','raw-002','integrity','finding','kind',
       COALESCE((SELECT finding_kind FROM integrity_finding
                 WHERE validation_ref='validation-cross'),'missing')
UNION ALL
SELECT '$scenario','raw-003','integrity','finding','source',
       COALESCE((SELECT source_ref FROM integrity_finding
                 WHERE validation_ref='validation-cross'),'missing')
UNION ALL
SELECT '$scenario','raw-004','integrity','finding','target',
       COALESCE((SELECT target_ref FROM integrity_finding
                 WHERE validation_ref='validation-cross'),'missing')
UNION ALL
SELECT '$scenario','raw-005','integrity','selection','member',
       COALESCE((SELECT member_ref FROM integrity_subject
                 WHERE subject_ref='cross-link-1'),'missing')
UNION ALL
SELECT '$scenario','raw-006','integrity','summary','finding-count',
       CAST((SELECT COUNT(*) FROM integrity_finding
             WHERE validation_ref='validation-cross') AS TEXT)
$(if [ "$silent" -eq 1 ]; then
printf '%s' "
UNION ALL
SELECT '$scenario','raw-007','inventory','before',
       'source-record-digest',
       CASE WHEN before_digest=after_digest
            THEN 'digest-cross-link-1' ELSE 'digest-cross-link-before' END
FROM validation_inventory WHERE validation_ref='validation-cross'
UNION ALL
SELECT '$scenario','raw-008','inventory','after',
       'source-record-digest',
       CASE WHEN before_digest=after_digest
            THEN 'digest-cross-link-1' ELSE 'digest-cross-link-after' END
FROM validation_inventory WHERE validation_ref='validation-cross'
UNION ALL
SELECT '$scenario','raw-009','inventory','validation','repair-count',
       CAST(repair_count AS TEXT)
FROM validation_inventory WHERE validation_ref='validation-cross'"
fi);"
        ;;
    bc11-finding-dangling--case-bc11-finding-dangling|\
    bc11-silent-dangling--case-bc11-silent-dangling)
        silent=0
        [ "$scenario" != \
          bc11-silent-dangling--case-bc11-silent-dangling ] ||
            silent=1
        query "
SELECT '$scenario','raw-001','surface','integrity','completeness',
       CASE WHEN EXISTS (
         SELECT 1 FROM validation_inventory
         WHERE validation_ref='validation-dangling'
       ) THEN 'complete' ELSE 'missing' END
UNION ALL
SELECT '$scenario','raw-002','integrity','finding','kind',
       COALESCE((SELECT finding_kind FROM integrity_finding
                 WHERE validation_ref='validation-dangling'
                   AND ordinal=1),'missing')
UNION ALL
SELECT '$scenario','raw-003','integrity','finding','kind',
       COALESCE((SELECT finding_kind FROM integrity_finding
                 WHERE validation_ref='validation-dangling'
                   AND ordinal=2),'missing')
UNION ALL
SELECT '$scenario','raw-004','integrity','selection','target',
       COALESCE((SELECT result_ref FROM result_output
                 WHERE result_ref='result-1'),'missing')
UNION ALL
SELECT '$scenario','raw-005','integrity','selection','member',
       COALESCE((SELECT selected_value FROM result_output
                 WHERE result_ref='result-1'),'missing')
UNION ALL
SELECT '$scenario','raw-006','integrity','summary','finding-count',
       CAST((SELECT COUNT(*) FROM integrity_finding
             WHERE validation_ref='validation-dangling') AS TEXT)
$(if [ "$silent" -eq 1 ]; then
printf '%s' "
UNION ALL
SELECT '$scenario','raw-007','inventory','before',
       'source-record-digest',
       CASE WHEN before_digest=after_digest
            THEN 'digest-dangling-1' ELSE 'digest-dangling-before' END
FROM validation_inventory WHERE validation_ref='validation-dangling'
UNION ALL
SELECT '$scenario','raw-008','inventory','after',
       'source-record-digest',
       CASE WHEN before_digest=after_digest
            THEN 'digest-dangling-1' ELSE 'digest-dangling-after' END
FROM validation_inventory WHERE validation_ref='validation-dangling'
UNION ALL
SELECT '$scenario','raw-009','inventory','validation','repair-count',
       CAST(repair_count AS TEXT)
FROM validation_inventory WHERE validation_ref='validation-dangling'"
fi);"
        ;;
    *) exit 2 ;;
esac

printf 'pragma\tforeign-keys\t1\n' >&2
