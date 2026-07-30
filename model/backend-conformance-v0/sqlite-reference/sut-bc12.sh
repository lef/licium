#!/bin/sh
set -eu

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc12.sh DB RUN NS SCENARIO ASSERTION SURFACE OP MODE NONCE" >&2
    exit 2
}

db=$1
run=$2
namespace=$3
scenario=$4
assertion=$5
surface=$6
operation=$7
mode=$8
nonce=$9

sql()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

setup()
{
    sql "
BEGIN IMMEDIATE;
INSERT INTO root VALUES
 ('r-audit'),('r-backup'),('r-conflict'),('r-current'),('r-forgotten'),
 ('r-inflight'),('r-pin'),('r-read'),('r-resolved'),('r-unverified');
INSERT INTO canonical_object VALUES
 ('r-audit','object-audit'),('r-backup','object-backup'),
 ('r-conflict','object-conflict'),('r-current','object-current-a'),
 ('r-current','object-current-b'),('r-forgotten','object-forgotten'),
 ('r-inflight','object-inflight'),('r-pin','object-pin'),
 ('r-read','object-read'),('r-resolved','object-resolved'),
 ('r-unverified','object-unverified');
INSERT INTO witness VALUES
 ('w-audit','r-audit','audit_hold','active'),
 ('w-backup','r-backup','backup_hold','active'),
 ('w-current','r-current','current','active'),
 ('w-forgotten','r-forgotten','expired','released'),
 ('w-pin','r-pin','pinned','active'),
 ('w-read','r-read','read_grace','active');
INSERT INTO conflict VALUES
 ('conflict-1','r-conflict','unresolved'),
 ('conflict-2','r-resolved','resolved');
INSERT INTO publication VALUES
 ('publication-1','r-inflight','pending'),
 ('publication-2','r-current','accepted');
INSERT INTO forget_event VALUES
 ('forget-audit','r-audit','accepted'),
 ('forget-root','r-forgotten','accepted');
INSERT INTO archive_state VALUES
 ('archive-audit','r-audit','verified'),
 ('archive-backup','r-backup','verified'),
 ('archive-forgotten','r-forgotten','verified'),
 ('archive-unverified','r-unverified','unverified');
INSERT INTO policy_phase VALUES ('after'),('before'),('boundary');
COMMIT;"
    printf 'status\tsetup\taccepted\t%s\n' "$scenario"
}

serialized_inventory()
{
    sql "
SELECT group_concat(root_ref || ':' || object_ref,'|')
FROM (SELECT root_ref,object_ref FROM canonical_object
      ORDER BY root_ref,object_ref);"
}

derive()
{
    before_serialized=$(serialized_inventory)
    before=$(printf '%s' "$before_serialized" | sha256sum |
        awk '{ print $1 }')

    case "$assertion" in
        BC12_ARCHIVE_BYPASS|BC12_PLACEMENT_DECISION)
            sql "INSERT INTO forget_event
                 VALUES ('forget-unverified','r-unverified','accepted');"
            ;;
        BC12_FORGET_BYPASS)
            sql "UPDATE forget_event SET event_state='rejected'
                 WHERE event_ref='forget-root';"
            ;;
        BC12_PROTECTION_BYPASS)
            sql "
INSERT INTO forget_event VALUES
 ('forget-conflict','r-conflict','accepted'),
 ('forget-inflight','r-inflight','accepted');
INSERT INTO archive_state VALUES
 ('archive-conflict','r-conflict','verified'),
 ('archive-inflight','r-inflight','verified');"
            ;;
    esac

    [ "$mode" = mutant-detect-noop-placement-evaluator ] || sql "
BEGIN IMMEDIATE;
INSERT INTO derived_protection
SELECT root_ref,reason,'witness',witness_ref
FROM witness WHERE witness_state='active';
INSERT INTO derived_protection
SELECT root_ref,'unresolved-conflict','conflict',conflict_ref
FROM conflict WHERE conflict_state='unresolved';
INSERT INTO derived_protection
SELECT root_ref,'pending-publication','publication',publication_ref
FROM publication WHERE publication_state='pending';

WITH targets(phase,root_ref) AS (
  VALUES ('after','r-audit'),('after','r-conflict'),
         ('after','r-forgotten'),('after','r-inflight'),
         ('after','r-unverified'),('before','r-forgotten'),
         ('boundary','r-forgotten')
)
INSERT INTO placement_decision
SELECT phase,root_ref,
       CASE
         WHEN phase != 'after' THEN 'retain'
         WHEN EXISTS (SELECT 1 FROM derived_protection p
                      WHERE p.root_ref=targets.root_ref) THEN 'retain'
         WHEN NOT EXISTS (SELECT 1 FROM forget_event f
                          WHERE f.root_ref=targets.root_ref
                            AND f.event_state='accepted') THEN 'retain'
         WHEN NOT EXISTS (SELECT 1 FROM archive_state a
                          WHERE a.root_ref=targets.root_ref
                            AND a.archive_status='verified') THEN 'retain'
         ELSE 'release-eligible'
       END,
       CASE
         WHEN phase != 'after' THEN 'policy-window'
         WHEN EXISTS (SELECT 1 FROM derived_protection p
                      WHERE p.root_ref=targets.root_ref)
           THEN (SELECT reason FROM derived_protection p
                 WHERE p.root_ref=targets.root_ref ORDER BY reason LIMIT 1)
         WHEN NOT EXISTS (SELECT 1 FROM forget_event f
                          WHERE f.root_ref=targets.root_ref
                            AND f.event_state='accepted')
           THEN 'forget-not-accepted'
         WHEN NOT EXISTS (SELECT 1 FROM archive_state a
                          WHERE a.root_ref=targets.root_ref
                            AND a.archive_status='verified')
           THEN 'archive-unverified'
         ELSE '-'
       END
FROM targets;

INSERT INTO decision_provenance
SELECT phase,root_ref,'policy-phase',phase FROM placement_decision;
INSERT INTO decision_provenance
SELECT d.phase,d.root_ref,p.source_kind,p.source_ref
FROM placement_decision d JOIN derived_protection p
  ON p.root_ref=d.root_ref;
INSERT INTO decision_provenance
SELECT d.phase,d.root_ref,'forget',f.event_ref
FROM placement_decision d JOIN forget_event f
  ON f.root_ref=d.root_ref AND f.event_state='accepted';
INSERT INTO decision_provenance
SELECT d.phase,d.root_ref,'archive',a.archive_ref
FROM placement_decision d JOIN archive_state a
  ON a.root_ref=d.root_ref;
COMMIT;"

    case "$mode" in
        ordinary) ;;
        mutant-detect-archive-state-bypass)
            sql "UPDATE placement_decision
                 SET decision='release-eligible',blocker='-'
                 WHERE phase='after' AND root_ref='r-unverified';"
            ;;
        mutant-detect-placement-inventory-change)
            sql "DELETE FROM canonical_object
                 WHERE root_ref='r-current' AND object_ref='object-current-b';"
            ;;
        mutant-detect-decision-provenance-loss)
            sql "DELETE FROM decision_provenance
                 WHERE phase='after' AND root_ref='r-forgotten'
                   AND source_kind='forget';"
            ;;
        mutant-detect-protection-derivation-loss)
            sql "DELETE FROM derived_protection
                 WHERE source_kind='conflict' AND source_ref='conflict-1';"
            ;;
        mutant-detect-eligibility-as-delete)
            sql "DELETE FROM canonical_object WHERE root_ref='r-forgotten';"
            ;;
        mutant-detect-forget-bypass)
            sql "UPDATE placement_decision
                 SET decision='release-eligible',blocker='-'
                 WHERE phase='after' AND root_ref='r-forgotten';"
            ;;
        mutant-detect-unconsumed-forget)
            sql "UPDATE forget_event SET event_state='rejected'
                 WHERE event_ref='forget-root';"
            ;;
        mutant-detect-noop-placement-evaluator) ;;
        mutant-detect-placement-decision-loss)
            sql "DELETE FROM placement_decision
                 WHERE phase='after' AND root_ref='r-audit';"
            ;;
        mutant-detect-protection-bypass-witness)
            sql "UPDATE placement_decision
                 SET decision='release-eligible',blocker='-'
                 WHERE phase='after' AND root_ref='r-audit';"
            ;;
        mutant-detect-protection-bypass-conflict)
            sql "UPDATE placement_decision
                 SET decision='release-eligible',blocker='-'
                 WHERE phase='after' AND root_ref='r-conflict';"
            ;;
        mutant-detect-protection-bypass-publication)
            sql "UPDATE placement_decision
                 SET decision='release-eligible',blocker='-'
                 WHERE phase='after' AND root_ref='r-inflight';"
            ;;
        mutant-detect-policy-window-bypass)
            sql "UPDATE placement_decision
                 SET decision='release-eligible',blocker='-'
                 WHERE root_ref='r-forgotten' AND phase != 'after';"
            ;;
        *) exit 2 ;;
    esac

    after_serialized=$(serialized_inventory)
    after=$(printf '%s' "$after_serialized" | sha256sum |
        awk '{ print $1 }')
    difference=0
    [ "$before" = "$after" ] || difference=1
    sql "INSERT INTO inventory_validation
         VALUES ('validation-1','$before','$after',$difference);"
}

if [ "$operation" = sut-setup-bc12 ]; then
    [ "$mode" = ordinary ] || exit 2
    setup
    printf 'pragma\tforeign-keys\t1\n' >&2
    exit 0
fi

[ "$surface:$operation" = placement:sut-evaluate-placement ] || exit 2
derive

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\tevaluation-1\troot-set-1\tpolicy-input-1\taccepted\t%s\n' \
    "$run" "$namespace" "$scenario" "$assertion" "$surface" \
    "$operation" "$mode" "$nonce"
printf 'pragma\tforeign-keys\t1\n' >&2
