#!/bin/sh
set -eu

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc08.sh DB RUN NS SCENARIO CASE OP MODE OCCURRENCE NONCE" >&2
    exit 2
}

db=$1
run=$2
namespace=$3
scenario=$4
case_id=$5
operation=$6
mode=$7
occurrence=$8
nonce=$9

sql()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

receipt()
{
    outcome=$1
    delivery=$2
    printf '%s\t%s\t%s\tsut-apply-effect\t%s\teffect-1\tresult-1\ttransition-1\tobservation-1\tview-1\trev-2\t%s\t5\t%s\t%s\n' \
        "$run" "$namespace" "$scenario" "$mode" "$outcome" "$nonce" \
        "$delivery"
    printf 'pragma\tforeign-keys\t1\n' >&2
}

complete_effect_sql()
{
    cat <<'SQL'
BEGIN IMMEDIATE;
UPDATE authoritative_state
   SET revision_ref='rev-2', state_payload='state-after'
 WHERE scope_ref='scope-1'
   AND revision_ref=(
       SELECT expected_revision_ref FROM effect_request
        WHERE effect_ref='effect-1'
   )
   AND EXISTS (
       SELECT 1
         FROM effect_request e
         JOIN evaluation_result r ON r.result_ref=e.result_ref
        WHERE e.effect_ref='effect-1'
          AND r.completeness='complete'
   );
INSERT INTO state_transition
SELECT 'transition-1','effect-1','scope-1','rev-1','rev-2'
 WHERE changes()=1;
INSERT INTO decision_observation
SELECT 'observation-1','effect-1','transition-1','result-1','root-1','view-1'
 WHERE EXISTS (
     SELECT 1 FROM state_transition
      WHERE transition_ref='transition-1'
 );
INSERT INTO view_header
SELECT 'view-1','effect-1','result-1','root-1','rev-2','building'
 WHERE EXISTS (
     SELECT 1 FROM decision_observation
      WHERE observation_ref='observation-1'
 );
INSERT INTO view_row
SELECT 'view-1',1,'department','engineering'
 WHERE EXISTS (SELECT 1 FROM view_header WHERE view_ref='view-1');
INSERT INTO view_row
SELECT 'view-1',2,'clearance','standard'
 WHERE EXISTS (SELECT 1 FROM view_header WHERE view_ref='view-1');
UPDATE view_header
   SET completeness='complete'
 WHERE view_ref='view-1'
   AND (SELECT COUNT(*) FROM view_row WHERE view_ref='view-1')=2;
INSERT INTO current_view
SELECT 'scope-1','view-1','rev-2'
 WHERE EXISTS (
     SELECT 1 FROM view_header
      WHERE view_ref='view-1' AND completeness='complete'
 );
COMMIT;
SQL
}

apply_complete()
{
    program=$(complete_effect_sql)
    set +e
    output=$(sql "$program" 2>&1)
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "$output" >&2
        exit "$status"
    fi
    [ "$(accepted_set_count)" = 1 ] || {
        echo BC08_EFFECT_PRECONDITION_FAILED >&2
        exit 1
    }
}

accepted_set_count()
{
    sql "
SELECT COUNT(*)
  FROM state_transition t
  JOIN decision_observation o
    ON o.transition_ref=t.transition_ref
   AND o.effect_ref=t.effect_ref
  JOIN evaluation_result r
    ON r.result_ref=o.result_ref
   AND r.completeness='complete'
  JOIN view_header h
    ON h.view_ref=o.view_ref
   AND h.effect_ref=t.effect_ref
   AND h.result_ref=r.result_ref
   AND h.source_root_ref=o.source_root_ref
   AND h.completeness='complete'
  JOIN current_view c
    ON c.view_ref=h.view_ref
   AND c.revision_ref=t.after_revision_ref
  JOIN authoritative_state s
    ON s.scope_ref=t.scope_ref
   AND s.revision_ref=t.after_revision_ref
 WHERE t.effect_ref='effect-1'
   AND t.before_revision_ref=(
       SELECT expected_revision_ref FROM effect_request
        WHERE effect_ref=t.effect_ref
   )
   AND (SELECT COUNT(*) FROM view_row v
         WHERE v.view_ref=h.view_ref)=2;
"
}

case "$operation" in
    sut-setup-bc08)
        [ "$mode" = ordinary ] && [ "$occurrence" = setup ] || exit 2
        case "$case_id" in
            case-bc08-complete|case-bc08-boundary|case-bc08-current|\
            case-bc08-observation|case-bc08-result|case-bc08-transition|\
            case-bc08-view) ;;
            *) exit 2 ;;
        esac
        sql "
BEGIN IMMEDIATE;
INSERT INTO evaluation_result
    VALUES ('result-1','request-1','root-1','public-a',
            'digest-result-1','complete');
INSERT INTO authoritative_state
    VALUES ('scope-1','rev-1','state-before');
INSERT INTO effect_request
    VALUES ('effect-1','result-1','scope-1','rev-1');
COMMIT;"
        printf 'status\tsetup\taccepted\t%s\n' "$case_id"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    sut-apply-effect)
        case "$occurrence" in action|retry|fault-action|healthy-action) ;; *) exit 2 ;; esac
        existing=$(sql "SELECT COUNT(*) FROM state_transition
                         WHERE effect_ref='effect-1';")
        if [ "$existing" != 0 ]; then
            [ "$existing" = 1 ] && [ "$(accepted_set_count)" = 1 ] || {
                echo BC08_RETRY_INCOMPLETE_SET >&2
                exit 1
            }
            receipt accepted second
            exit 0
        fi
        [ "$(sql "
SELECT COUNT(*)
  FROM effect_request e
  JOIN evaluation_result r ON r.result_ref=e.result_ref
  JOIN authoritative_state s ON s.scope_ref=e.scope_ref
 WHERE e.effect_ref='effect-1'
   AND r.completeness='complete'
   AND s.revision_ref=e.expected_revision_ref;
")" = 1 ] || {
            echo BC08_EFFECT_PRECONDITION_FAILED >&2
            exit 1
        }
        case "$mode" in
            ordinary|retry|fault)
                apply_complete
                ;;
            mutant-incomplete-effect-set)
                sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state SET revision_ref='rev-2',
    state_payload='state-after' WHERE scope_ref='scope-1';
INSERT INTO state_transition
    VALUES ('transition-1','effect-1','scope-1','rev-1','rev-2');
COMMIT;"
                ;;
            mutant-mid-boundary-partial-effect)
                sql "
UPDATE authoritative_state SET revision_ref='rev-2',
    state_payload='state-after' WHERE scope_ref='scope-1';
INSERT INTO state_transition
    VALUES ('transition-1','effect-1','scope-1','rev-1','rev-2');"
                ;;
            mutant-missing-current)
                sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state SET revision_ref='rev-2',
    state_payload='state-after' WHERE scope_ref='scope-1';
INSERT INTO state_transition
    VALUES ('transition-1','effect-1','scope-1','rev-1','rev-2');
INSERT INTO decision_observation
    VALUES ('observation-1','effect-1','transition-1','result-1','root-1','view-1');
INSERT INTO view_header
    VALUES ('view-1','effect-1','result-1','root-1','rev-2','complete');
INSERT INTO view_row VALUES ('view-1',1,'department','engineering');
INSERT INTO view_row VALUES ('view-1',2,'clearance','standard');
COMMIT;"
                ;;
            mutant-missing-observation)
                sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state SET revision_ref='rev-2',
    state_payload='state-after' WHERE scope_ref='scope-1';
INSERT INTO state_transition
    VALUES ('transition-1','effect-1','scope-1','rev-1','rev-2');
INSERT INTO view_header
    VALUES ('view-1','effect-1','result-1','root-1','rev-2','complete');
INSERT INTO view_row VALUES ('view-1',1,'department','engineering');
INSERT INTO view_row VALUES ('view-1',2,'clearance','standard');
INSERT INTO current_view VALUES ('scope-1','view-1','rev-2');
COMMIT;"
                ;;
            mutant-missing-result)
                sql "
BEGIN IMMEDIATE;
DELETE FROM evaluation_result WHERE result_ref='result-1';
UPDATE authoritative_state SET revision_ref='rev-2',
    state_payload='state-after' WHERE scope_ref='scope-1';
INSERT INTO state_transition
    VALUES ('transition-1','effect-1','scope-1','rev-1','rev-2');
INSERT INTO decision_observation
    VALUES ('observation-1','effect-1','transition-1','result-1','root-1','view-1');
INSERT INTO view_header
    VALUES ('view-1','effect-1','result-1','root-1','rev-2','complete');
INSERT INTO view_row VALUES ('view-1',1,'department','engineering');
INSERT INTO view_row VALUES ('view-1',2,'clearance','standard');
INSERT INTO current_view VALUES ('scope-1','view-1','rev-2');
COMMIT;"
                ;;
            mutant-missing-transition)
                sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state SET revision_ref='rev-2',
    state_payload='state-after' WHERE scope_ref='scope-1';
INSERT INTO decision_observation
    VALUES ('observation-1','effect-1','transition-1','result-1','root-1','view-1');
INSERT INTO view_header
    VALUES ('view-1','effect-1','result-1','root-1','rev-2','complete');
INSERT INTO view_row VALUES ('view-1',1,'department','engineering');
INSERT INTO view_row VALUES ('view-1',2,'clearance','standard');
INSERT INTO current_view VALUES ('scope-1','view-1','rev-2');
COMMIT;"
                ;;
            mutant-missing-view)
                sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state SET revision_ref='rev-2',
    state_payload='state-after' WHERE scope_ref='scope-1';
INSERT INTO state_transition
    VALUES ('transition-1','effect-1','scope-1','rev-1','rev-2');
INSERT INTO decision_observation
    VALUES ('observation-1','effect-1','transition-1','result-1','root-1','view-1');
INSERT INTO current_view VALUES ('scope-1','view-1','rev-2');
COMMIT;"
                ;;
            *) exit 2 ;;
        esac
        receipt accepted first
        ;;
    *)
        exit 2
        ;;
esac
