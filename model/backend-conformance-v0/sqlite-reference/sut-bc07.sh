#!/bin/sh
set -eu

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc07.sh DB RUN NS SCENARIO CASE OP MODE OCCURRENCE NONCE" >&2
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

case_suffix()
{
    case "$case_id" in
        case-bc07-effect) printf 'effect\n' ;;
        case-bc07-orphan) printf 'orphan\n' ;;
        case-bc07-ordinary) printf 'ordinary\n' ;;
        case-bc07-record-effect) printf 'record-effect\n' ;;
        case-bc07-record) printf 'record\n' ;;
        case-bc07-rewrite) printf 'rewrite\n' ;;
        *) exit 2 ;;
    esac
}

receipt()
{
    request=$1
    result=$2
    effect=$3
    expected_revision=$4
    vector=$5
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\taccepted\t%s\n' \
        "$run" "$namespace" "$scenario" "$operation" "$mode" \
        "$request" "$result" "$effect" "$expected_revision" "$vector" \
        "$nonce"
    printf 'pragma\tforeign-keys\t1\n' >&2
}

suffix=$(case_suffix)
request="request-$suffix"
scope="scope-$suffix"
result="result-$suffix"
effect="effect-$suffix"
transition="transition-$suffix"
observation="observation-$suffix"

case "$operation" in
    sut-setup-bc07)
        [ "$mode" = ordinary ] && [ "$occurrence" = setup ] || exit 2
        request_kind=ordinary
        case "$case_id" in
            case-bc07-effect|case-bc07-orphan|case-bc07-rewrite)
                request_kind='effect-targeting' ;;
            case-bc07-record-effect|case-bc07-record)
                request_kind=record ;;
        esac
        sql "
BEGIN IMMEDIATE;
INSERT INTO authoritative_state
    VALUES ('$scope','state-0','payload-0');
INSERT INTO evaluation_request
    VALUES ('$request','input-$suffix','$request_kind');
COMMIT;"
        case "$case_id" in
            case-bc07-effect|case-bc07-orphan|case-bc07-rewrite)
                sql "
BEGIN IMMEDIATE;
INSERT INTO evaluation_result
    VALUES ('$result','$request','accepted','digest-$suffix');
INSERT INTO effect_request
    VALUES ('$effect','$result','state-0');
COMMIT;"
                ;;
        esac
        printf 'status\tsetup\taccepted\t%s\n' "$case_id"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    sut-evaluate-pure)
        [ "$occurrence" = action ] || exit 2
        case "$mode" in
            ordinary)
                ;;
            mutant-ordinary-axis-write)
                sql "
INSERT INTO evaluation_result
    VALUES ('result-ordinary','$request','accepted','digest-ordinary');"
                ;;
            *) exit 2 ;;
        esac
        receipt "$request" - - - 000
        ;;
    sut-record-result)
        [ "$occurrence" = action ] || exit 2
        case "$mode" in
            ordinary)
                sql "
INSERT INTO evaluation_result
    VALUES ('$result','$request','accepted','digest-$suffix');"
                ;;
            mutant-record-state-effect)
                sql "
BEGIN IMMEDIATE;
INSERT INTO evaluation_result
    VALUES ('$result','$request','accepted','digest-$suffix');
INSERT INTO effect_request
    VALUES ('$effect','$result','state-0');
UPDATE authoritative_state
   SET revision_ref='state-1', state_payload='payload-1'
 WHERE scope_ref='$scope';
INSERT INTO state_transition
    VALUES ('$transition','$scope','state-0','state-1','$effect');
INSERT INTO decision_observation
    VALUES ('$observation','$transition','$result','$effect');
COMMIT;"
                ;;
            mutant-record-axis-mismatch)
                ;;
            *) exit 2 ;;
        esac
        receipt "$request" "$result" - - 010
        ;;
    sut-apply-effect)
        [ "$occurrence" = action ] || exit 2
        case "$mode" in
            ordinary)
                sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state
   SET revision_ref='state-1', state_payload='payload-1'
 WHERE scope_ref='$scope'
   AND revision_ref=(
       SELECT expected_revision_ref FROM effect_request
        WHERE effect_ref='$effect'
   );
INSERT INTO state_transition
SELECT '$transition','$scope','state-0','state-1','$effect'
 WHERE changes()=1;
INSERT INTO decision_observation
SELECT '$observation','$transition','$result','$effect'
 WHERE EXISTS (
     SELECT 1 FROM state_transition
      WHERE transition_ref='$transition'
 );
COMMIT;"
                ;;
            mutant-effect-axis-mismatch)
                sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state
   SET revision_ref='state-1', state_payload='payload-1'
 WHERE scope_ref='$scope'
   AND revision_ref=(
       SELECT expected_revision_ref FROM effect_request
        WHERE effect_ref='$effect'
   );
INSERT INTO state_transition
SELECT '$transition','$scope','state-0','state-1','$effect'
 WHERE changes()=1;
COMMIT;"
                ;;
            mutant-orphan-observation)
                sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state
   SET revision_ref='state-1', state_payload='payload-1'
 WHERE scope_ref='$scope'
   AND revision_ref=(
       SELECT expected_revision_ref FROM effect_request
        WHERE effect_ref='$effect'
   );
INSERT INTO state_transition
SELECT '$transition','$scope','state-0','state-1','$effect'
 WHERE changes()=1;
INSERT INTO decision_observation
SELECT '$observation','transition-forged','$result','$effect'
 WHERE EXISTS (
     SELECT 1 FROM state_transition
      WHERE transition_ref='$transition'
 );
COMMIT;"
                ;;
            mutant-effect-result-rewrite)
                sql "
BEGIN IMMEDIATE;
UPDATE authoritative_state
   SET revision_ref='state-1', state_payload='payload-1'
 WHERE scope_ref='$scope'
   AND revision_ref=(
       SELECT expected_revision_ref FROM effect_request
        WHERE effect_ref='$effect'
   );
INSERT INTO state_transition
SELECT '$transition','$scope','state-0','state-1','$effect'
 WHERE changes()=1;
UPDATE evaluation_result
   SET result_payload='rewritten', result_digest='digest-forged'
 WHERE result_ref='$result'
   AND EXISTS (
       SELECT 1 FROM state_transition
        WHERE transition_ref='$transition'
   );
INSERT INTO decision_observation
SELECT '$observation','$transition','$result','$effect'
 WHERE EXISTS (
     SELECT 1 FROM state_transition
      WHERE transition_ref='$transition'
 );
COMMIT;"
                ;;
            *) exit 2 ;;
        esac
        [ "$(sql "
SELECT COUNT(*) FROM state_transition
 WHERE transition_ref='$transition'
   AND effect_ref='$effect';")" = 1 ] || {
            echo BC07_EXPECTED_REVISION_MISMATCH >&2
            exit 1
        }
        receipt "$request" "$result" "$effect" state-0 101
        ;;
    *)
        exit 2
        ;;
esac
