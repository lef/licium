#!/bin/sh
set -eu

[ "$#" -eq 10 ] || {
    echo "usage: sut-bc09.sh DB RUN NS ASSERTION CASE OP MODE DELIVERY NONCE ATTEMPT" >&2
    exit 2
}

db=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
operation=$6
mode=$7
delivery=$8
nonce=$9
attempt=${10}
implementation_revision=impl-bc09-v0

sql()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

receipt()
{
    disposition=$1
    reason=$2
    repository_delta=$3
    printf '%s\t%s\t%s\t%s\tsut-apply-effect\t%s\teffect-1\tresult-1\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$assertion" "$case_id" "$delivery" \
        "$disposition" "$reason" "$repository_delta" "$nonce" \
        "$implementation_revision" "$attempt"
}

persist_attempt_mutant()
{
    disposition=$1
    reason=$2
    sql "
INSERT INTO attempt_artifact
VALUES ('$attempt','effect-1','$disposition','$reason');"
}

seed_case()
{
    completeness=complete
    disposition=accepted
    expected_revision=rev-1
    case "$case_id" in
        case-stale)
            expected_revision=rev-0
            ;;
        case-incomplete)
            completeness=incomplete
            ;;
        case-rejected|case-duplicate)
            disposition=rejected
            ;;
        case-fault)
            ;;
        *)
            exit 2
            ;;
    esac
    sql "
BEGIN IMMEDIATE;
INSERT INTO authoritative_state VALUES ('scope-1','rev-1');
INSERT INTO evaluation_result
    VALUES ('result-1','public-a','$completeness','$disposition');
INSERT INTO effect_request
    VALUES ('effect-1','result-1','scope-1','$expected_revision');
COMMIT;"
}

prepare_healthy()
{
    sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state SET revision_ref='rev-1'
 WHERE scope_ref='scope-1';
UPDATE evaluation_result
   SET completeness='complete', disposition='accepted'
 WHERE result_ref='result-1';
UPDATE effect_request SET expected_revision_ref='rev-1'
 WHERE effect_ref='effect-1';
DELETE FROM state_transition;
DELETE FROM decision_observation;
DELETE FROM view_header;
DELETE FROM current_view;
COMMIT;"
}

classification()
{
    if [ "$case_id" = case-duplicate ]; then
        printf '%s\n' duplicate
    elif [ "$(sql "
SELECT COUNT(*)
  FROM effect_request e
  JOIN authoritative_state s ON s.scope_ref=e.scope_ref
 WHERE e.effect_ref='effect-1'
   AND e.expected_revision_ref=s.revision_ref;")" != 1 ]; then
        printf '%s\n' stale
    elif [ "$(sql "
SELECT completeness FROM evaluation_result
 WHERE result_ref=(SELECT result_ref FROM effect_request
                    WHERE effect_ref='effect-1');")" != complete ]; then
        printf '%s\n' incomplete
    elif [ "$(sql "
SELECT disposition FROM evaluation_result
 WHERE result_ref=(SELECT result_ref FROM effect_request
                    WHERE effect_ref='effect-1');")" != accepted ]; then
        printf '%s\n' rejected
    else
        printf '%s\n' accepted
    fi
}

trigger_rejection_fault()
{
    kind=$1
    program="
BEGIN IMMEDIATE;
UPDATE fault_activation SET armed=armed
 WHERE armed=1
   AND effect_ref='effect-1'
   AND hook_id='hook-bc09-rejection-$kind'
   AND phase='rejection-$kind';
COMMIT;"
    set +e
    output=$(sql "$program" 2>&1)
    status=$?
    set -e
    [ "$status" -ne 0 ] || {
        echo BC09_FAULT_UNREACHED >&2
        exit 1
    }
    if [ "$mode" = mutant-persistent ]; then
        persist_attempt_mutant failed "injected-rejection-$kind"
    fi
    receipt failed "injected-rejection-$kind" 0
    printf '%s\n' "$output" >&2
    exit "$status"
}

apply_accepted()
{
    program="
BEGIN IMMEDIATE;
UPDATE authoritative_state SET revision_ref='rev-2'
 WHERE scope_ref='scope-1' AND revision_ref='rev-1';
INSERT INTO state_transition
    VALUES ('transition-1','effect-1','rev-1','rev-2');
INSERT INTO decision_observation
    VALUES ('observation-1','transition-1','result-1','root-1','view-1');
INSERT INTO view_header
    VALUES ('view-1','effect-1','result-1','root-1','rev-2','complete',2);
INSERT INTO current_view VALUES ('scope-1','view-1','rev-2');
COMMIT;"
    set +e
    output=$(sql "$program" 2>&1)
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        failure_reason=injected-rollback
        [ "$assertion" = BC09_FAILPOINT_PERSISTS ] &&
            failure_reason=injected-accepted-write
        if [ "$mode" = mutant-persistent ]; then
            persist_attempt_mutant failed "$failure_reason"
        fi
        receipt failed "$failure_reason" 0
        printf '%s\n' "$output" >&2
        exit "$status"
    fi
    if [ "$mode" = mutant-persistent ]; then
        persist_attempt_mutant accepted applied
    fi
    receipt accepted applied 4
}

case "$operation" in
    sut-setup-bc09)
        [ "$delivery" = setup ] && [ "$attempt" = setup ] || exit 2
        case "$mode" in
            ordinary)
                seed_case
                ;;
            healthy)
                prepare_healthy
                ;;
            *)
                exit 2
                ;;
        esac
        printf 'status\tsetup\taccepted\t%s\n' "$case_id"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    sut-apply-effect)
        case "$mode" in ordinary|fault|healthy|mutant-persistent) ;;
            *) exit 2 ;;
        esac
        if [ "$mode" = healthy ]; then
            kind=accepted
            [ "$kind" = accepted ] || {
                echo BC09_HEALTHY_PRECONDITION_INVALID >&2
                exit 1
            }
            apply_accepted
        else
            kind=$(classification)
            if [ "$kind" = accepted ]; then
                apply_accepted
            elif [ "$mode" = fault ] ||
                { [ "$mode" = mutant-persistent ] &&
                  [ "$(sql "SELECT COUNT(*) FROM fault_activation
                            WHERE armed=1 AND effect_ref='effect-1';")" = 1 ]; }
            then
                trigger_rejection_fault "$kind"
            else
                if [ "$mode" = mutant-persistent ]; then
                    case "$kind" in
                        stale) mutant_reason=stale-expected ;;
                        incomplete) mutant_reason=incomplete-result ;;
                        rejected) mutant_reason=result-rejected ;;
                        duplicate) mutant_reason=unaccepted-redelivery ;;
                        *) exit 2 ;;
                    esac
                    persist_attempt_mutant "$kind" "$mutant_reason"
                fi
                case "$kind" in
                    stale)
                        receipt rejected stale-expected 0
                        ;;
                    incomplete)
                        receipt rejected incomplete-result 0
                        ;;
                    rejected)
                        receipt rejected result-rejected 0
                        ;;
                    duplicate)
                        receipt duplicate unaccepted-redelivery 0
                        ;;
                    *)
                        exit 2
                        ;;
                esac
            fi
        fi
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    *)
        exit 2
        ;;
esac
