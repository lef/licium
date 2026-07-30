#!/bin/sh
set -eu

[ "$#" -eq 3 ] || {
    echo "usage: observe-bc12.sh DB SCENARIO SURFACE" >&2
    exit 2
}

db=$1
scenario=$2
surface=$3
[ "$surface" = placement ] || exit 2

query()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

case "$scenario" in
    bc12-archive-bypass--case-bc12-archive-bypass)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL SELECT '$scenario','raw-002','decision','r-unverified','after',
  COALESCE((SELECT decision FROM placement_decision
            WHERE phase='after' AND root_ref='r-unverified'),'missing')
UNION ALL SELECT '$scenario','raw-003','decision','r-unverified','blocker',
  COALESCE((SELECT blocker FROM placement_decision
            WHERE phase='after' AND root_ref='r-unverified'),'missing')
UNION ALL SELECT '$scenario','raw-004','archive','r-unverified','state',
  COALESCE((SELECT archive_status FROM archive_state
            WHERE root_ref='r-unverified'),'missing')
UNION ALL SELECT '$scenario','raw-005','inventory','r-unverified',
  'canonical-present',CAST(EXISTS(SELECT 1 FROM canonical_object
                                  WHERE root_ref='r-unverified') AS TEXT);"
        ;;
    bc12-canonical-unchanged--case-bc12-canonical-unchanged)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL SELECT '$scenario','raw-002','inventory','before',
  'canonical-digest',
  CASE WHEN before_digest=after_digest THEN 'digest-canonical-1'
       ELSE 'digest-canonical-before' END
  FROM inventory_validation WHERE validation_ref='validation-1'
UNION ALL SELECT '$scenario','raw-003','inventory','after',
  'canonical-digest',
  CASE WHEN before_digest=after_digest THEN 'digest-canonical-1'
       ELSE 'digest-canonical-after' END
  FROM inventory_validation WHERE validation_ref='validation-1'
UNION ALL SELECT '$scenario','raw-004','inventory','comparison',
  'symmetric-difference',CAST(difference_count AS TEXT)
  FROM inventory_validation WHERE validation_ref='validation-1'
UNION ALL SELECT '$scenario','raw-005','inventory','r-forgotten',
  'canonical-present',CAST(EXISTS(SELECT 1 FROM canonical_object
                                  WHERE root_ref='r-forgotten') AS TEXT);"
        ;;
    bc12-decision-provenance--case-bc12-decision-provenance)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL SELECT '$scenario','raw-002','decision','r-forgotten','after',
  COALESCE((SELECT decision FROM placement_decision
            WHERE phase='after' AND root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-003','decision','r-forgotten','blocker',
  COALESCE((SELECT blocker FROM placement_decision
            WHERE phase='after' AND root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-004','provenance','r-forgotten','forget',
  COALESCE((SELECT source_ref FROM decision_provenance
            WHERE phase='after' AND root_ref='r-forgotten'
              AND source_kind='forget'),'missing')
UNION ALL SELECT '$scenario','raw-005','provenance','r-forgotten','archive',
  COALESCE((SELECT source_ref FROM decision_provenance
            WHERE phase='after' AND root_ref='r-forgotten'
              AND source_kind='archive'),'missing')
UNION ALL SELECT '$scenario','raw-006','provenance','r-forgotten',
  'policy-phase',COALESCE((SELECT source_ref FROM decision_provenance
                           WHERE phase='after' AND root_ref='r-forgotten'
                             AND source_kind='policy-phase'),'missing')
UNION ALL SELECT '$scenario','raw-007','decision','r-conflict','after',
  COALESCE((SELECT decision FROM placement_decision
            WHERE phase='after' AND root_ref='r-conflict'),'missing')
UNION ALL SELECT '$scenario','raw-008','provenance','r-conflict','conflict',
  COALESCE((SELECT source_ref FROM decision_provenance
            WHERE phase='after' AND root_ref='r-conflict'
              AND source_kind='conflict'),'missing')
UNION ALL SELECT '$scenario','raw-009','decision','r-inflight','after',
  COALESCE((SELECT decision FROM placement_decision
            WHERE phase='after' AND root_ref='r-inflight'),'missing')
UNION ALL SELECT '$scenario','raw-010','provenance','r-inflight','publication',
  COALESCE((SELECT source_ref FROM decision_provenance
            WHERE phase='after' AND root_ref='r-inflight'
              AND source_kind='publication'),'missing');"
        ;;
    bc12-derived-protection--case-bc12-derived-protection)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL
SELECT '$scenario',printf('raw-%03d',ROW_NUMBER() OVER (
         ORDER BY root_ref,reason,source_kind,source_ref)+1),
       'protection',root_ref,reason,source_kind || ':' || source_ref
FROM derived_protection
ORDER BY 2;"
        ;;
    bc12-eligibility-delete--case-bc12-eligibility-delete)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL SELECT '$scenario','raw-002','decision','r-forgotten','after',
  COALESCE((SELECT decision FROM placement_decision
            WHERE phase='after' AND root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-003','inventory','r-forgotten',
  'canonical-present',CAST(EXISTS(SELECT 1 FROM canonical_object
                                  WHERE root_ref='r-forgotten') AS TEXT)
UNION ALL SELECT '$scenario','raw-004','inventory','comparison',
  'symmetric-difference',CAST(difference_count AS TEXT)
  FROM inventory_validation WHERE validation_ref='validation-1';"
        ;;
    bc12-forget-bypass--case-bc12-forget-bypass)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL SELECT '$scenario','raw-002','forget','forget-root','status',
  COALESCE((SELECT event_state FROM forget_event
            WHERE event_ref='forget-root'),'missing')
UNION ALL SELECT '$scenario','raw-003','archive','r-forgotten','state',
  COALESCE((SELECT archive_status FROM archive_state
            WHERE root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-004','decision','r-forgotten','after',
  COALESCE((SELECT decision FROM placement_decision
            WHERE phase='after' AND root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-005','decision','r-forgotten','blocker',
  COALESCE((SELECT blocker FROM placement_decision
            WHERE phase='after' AND root_ref='r-forgotten'),'missing');"
        ;;
    bc12-forget-consumed--case-bc12-forget-consumed)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL SELECT '$scenario','raw-002','forget','forget-root','status',
  COALESCE((SELECT event_state FROM forget_event
            WHERE event_ref='forget-root'),'missing')
UNION ALL SELECT '$scenario','raw-003','decision','r-forgotten','after',
  COALESCE((SELECT decision FROM placement_decision
            WHERE phase='after' AND root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-004','provenance','r-forgotten','forget',
  COALESCE((SELECT source_ref FROM decision_provenance
            WHERE phase='after' AND root_ref='r-forgotten'
              AND source_kind='forget'),'missing')
UNION ALL SELECT '$scenario','raw-005','inventory','r-forgotten',
  'canonical-present',CAST(EXISTS(SELECT 1 FROM canonical_object
                                  WHERE root_ref='r-forgotten') AS TEXT);"
        ;;
    bc12-noop-evaluator--case-bc12-noop-evaluator)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL SELECT '$scenario','raw-002','relation-family','protection',
  'row-count',CAST((SELECT COUNT(*) FROM derived_protection) AS TEXT)
UNION ALL SELECT '$scenario','raw-003','relation-family','decision',
  'row-count',CAST((SELECT COUNT(*) FROM placement_decision) AS TEXT)
UNION ALL SELECT '$scenario','raw-004','relation-family','forget',
  'row-count',CAST((SELECT COUNT(*) FROM forget_event
                    WHERE event_state='accepted') AS TEXT)
UNION ALL SELECT '$scenario','raw-005','relation-family','archive',
  'row-count',CAST((SELECT COUNT(*) FROM archive_state) AS TEXT)
UNION ALL SELECT '$scenario','raw-006','relation-family','inventory',
  'row-count',CAST((SELECT COUNT(DISTINCT root_ref)
                    FROM canonical_object) AS TEXT);"
        ;;
    bc12-placement-decision--case-bc12-placement-decision)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL
SELECT '$scenario',printf('raw-%03d',ROW_NUMBER() OVER (
         ORDER BY CASE phase WHEN 'after' THEN 1 WHEN 'before' THEN 2 ELSE 3 END,
                  root_ref)+1),
       'decision',root_ref,phase,decision || ':' || blocker
FROM placement_decision
ORDER BY 2;"
        ;;
    bc12-protection-bypass--case-bc12-protection-bypass)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL SELECT '$scenario','raw-002','protection','r-audit','audit_hold',
  COALESCE((SELECT source_kind || ':' || source_ref
            FROM derived_protection WHERE root_ref='r-audit'
              AND reason='audit_hold'),'missing')
UNION ALL SELECT '$scenario','raw-003','forget','forget-audit','status',
  COALESCE((SELECT event_state FROM forget_event
            WHERE event_ref='forget-audit'),'missing')
UNION ALL SELECT '$scenario','raw-004','archive','r-audit','state',
  COALESCE((SELECT archive_status FROM archive_state
            WHERE archive_ref='archive-audit'),'missing')
UNION ALL SELECT '$scenario','raw-005','decision','r-audit','after',
  COALESCE((SELECT decision || ':' || blocker FROM placement_decision
            WHERE phase='after' AND root_ref='r-audit'),'missing')
UNION ALL SELECT '$scenario','raw-006','protection','r-conflict',
  'unresolved-conflict',
  COALESCE((SELECT source_kind || ':' || source_ref
            FROM derived_protection WHERE root_ref='r-conflict'
              AND reason='unresolved-conflict'),'missing')
UNION ALL SELECT '$scenario','raw-007','forget','forget-conflict','status',
  COALESCE((SELECT event_state FROM forget_event
            WHERE event_ref='forget-conflict'),'missing')
UNION ALL SELECT '$scenario','raw-008','archive','r-conflict','state',
  COALESCE((SELECT archive_status FROM archive_state
            WHERE archive_ref='archive-conflict'),'missing')
UNION ALL SELECT '$scenario','raw-009','decision','r-conflict','after',
  COALESCE((SELECT decision || ':' || blocker FROM placement_decision
            WHERE phase='after' AND root_ref='r-conflict'),'missing')
UNION ALL SELECT '$scenario','raw-010','protection','r-inflight',
  'pending-publication',
  COALESCE((SELECT source_kind || ':' || source_ref
            FROM derived_protection WHERE root_ref='r-inflight'
              AND reason='pending-publication'),'missing')
UNION ALL SELECT '$scenario','raw-011','forget','forget-inflight','status',
  COALESCE((SELECT event_state FROM forget_event
            WHERE event_ref='forget-inflight'),'missing')
UNION ALL SELECT '$scenario','raw-012','archive','r-inflight','state',
  COALESCE((SELECT archive_status FROM archive_state
            WHERE archive_ref='archive-inflight'),'missing')
UNION ALL SELECT '$scenario','raw-013','decision','r-inflight','after',
  COALESCE((SELECT decision || ':' || blocker FROM placement_decision
            WHERE phase='after' AND root_ref='r-inflight'),'missing');"
        ;;
    bc12-window-bypass--case-bc12-window-bypass)
        query "
SELECT '$scenario','raw-001','surface','placement','completeness','complete'
UNION ALL SELECT '$scenario','raw-002','decision','r-forgotten','before',
  COALESCE((SELECT decision || ':' || blocker FROM placement_decision
            WHERE phase='before' AND root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-003','decision','r-forgotten','boundary',
  COALESCE((SELECT decision || ':' || blocker FROM placement_decision
            WHERE phase='boundary' AND root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-004','decision','r-forgotten','after',
  COALESCE((SELECT decision || ':' || blocker FROM placement_decision
            WHERE phase='after' AND root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-005','forget','forget-root','status',
  COALESCE((SELECT event_state FROM forget_event
            WHERE event_ref='forget-root'),'missing')
UNION ALL SELECT '$scenario','raw-006','archive','r-forgotten','state',
  COALESCE((SELECT archive_status FROM archive_state
            WHERE root_ref='r-forgotten'),'missing')
UNION ALL SELECT '$scenario','raw-007','protection','r-forgotten',
  'active-count',CAST((SELECT COUNT(*) FROM derived_protection
                       WHERE root_ref='r-forgotten') AS TEXT);"
        ;;
    *) exit 2 ;;
esac

printf 'pragma\tforeign-keys\t1\n' >&2
