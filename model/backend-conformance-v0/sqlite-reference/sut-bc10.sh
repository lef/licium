#!/bin/sh
set -eu

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc10.sh DB RUN NS SCENARIO ASSERTION SURFACE OP MODE NONCE" >&2
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
INSERT INTO source_object VALUES
    ('definition-object','definition','definition-1'),
    ('member-public','value','public-a'),
    ('member-secret','value','SECRET-BC10-CLOSURE');
INSERT INTO root VALUES ('root-1','complete');
INSERT INTO root_member VALUES
    ('root-1',1,'definition-object',0),
    ('root-1',2,'member-public',1),
    ('root-1',3,'member-secret',0);
INSERT INTO publication
VALUES ('publication-1','authority-1','root-1','accepted');
INSERT INTO authority_head
VALUES ('authority-1','root-1','publication-1');
INSERT INTO evaluation_request VALUES ('request-1','subject-1');
INSERT INTO evaluation_input VALUES
    ('request-1','binding','binding-1'),
    ('request-1','definition','definition-1'),
    ('request-1','knowledge-cut','cut-1'),
    ('request-1','source-root','root-1'),
    ('request-1','semantics','semantics-1');
INSERT INTO result_output
VALUES ('result-1','request-1','root-1','definition-1',
        'member-public','public-a','complete');
COMMIT;"
    printf 'status\tsetup\taccepted\t%s\n' "$scenario"
}

apply_result()
{
    member=member-public
    value=public-a
    case "$mode" in
        ordinary) ;;
        mutant-result-closure-loss) member=missing-member ;;
        mutant-result-secret-leak) value=SECRET-BC10-CLOSURE ;;
        *) exit 2 ;;
    esac
    sql "
INSERT INTO result_output
VALUES ('result-action-1','request-1','root-1','definition-1',
        '$member','$value','complete');"
}

apply_view()
{
    definition=definition-1
    case "$mode" in
        ordinary|mutant-view-member-loss|mutant-view-secret-leak) ;;
        mutant-view-provenance-loss) definition=missing-definition ;;
        *) exit 2 ;;
    esac
    sql "
BEGIN IMMEDIATE;
INSERT INTO view_output
VALUES ('view-1','root-1','root-1','$definition','complete');
COMMIT;"
    [ "$mode" = mutant-view-member-loss ] || sql "
INSERT INTO view_row VALUES ('view-1',1,'member-public','public-a');"
    [ "$mode" != mutant-view-secret-leak ] || sql "
INSERT INTO view_row
VALUES ('view-1',2,'member-secret','SECRET-BC10-CLOSURE');"
}

apply_replay()
{
    value=public-a
    case "$mode" in
        ordinary|mutant-replay-executor-metadata) ;;
        mutant-replay-closure-loss) value=public-drift ;;
        *) exit 2 ;;
    esac
    sql "
INSERT INTO replay_output
VALUES ('replay-result-1','result-1','request-1','root-1',
        'definition-1','$value','complete');"
    [ "$mode" != mutant-replay-executor-metadata ] || sql "
INSERT INTO replay_metadata VALUES
    ('replay-result-1','file-path','/tmp/replay.db'),
    ('replay-result-1','process-id','pid-123'),
    ('replay-result-1','row-order','row-7');"
}

apply_explanation()
{
    sql "
BEGIN IMMEDIATE;
INSERT INTO explanation_output VALUES ('explanation-1','complete');
INSERT INTO explanation_edge VALUES
    ('explanation-1',1,'observation','observation-1'),
    ('explanation-1',2,'result','result-1'),
    ('explanation-1',3,'request','request-1'),
    ('explanation-1',4,'source-root','root-1');
COMMIT;"
    [ "$mode" = mutant-explanation-member-loss ] || sql "
INSERT INTO explanation_edge
VALUES ('explanation-1',5,'selected-member','member-public');"
    [ "$mode" != mutant-explanation-secret-leak ] || sql "
INSERT INTO explanation_edge
VALUES ('explanation-1',6,'secret-member','member-secret');"
    case "$mode" in
        ordinary|mutant-explanation-member-loss|\
mutant-explanation-secret-leak) ;;
        *) exit 2 ;;
    esac
}

if [ "$operation" = sut-setup-bc10 ]; then
    [ "$mode" = ordinary ] || exit 2
    setup
    printf 'pragma\tforeign-keys\t1\n' >&2
    exit 0
fi

case "$surface:$operation" in
    result:sut-evaluate-output) apply_result ;;
    view:sut-materialize-view) apply_view ;;
    replay:sut-replay-result) apply_replay ;;
    explanation:sut-explain-result) apply_explanation ;;
    *) exit 2 ;;
esac

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\trequest-1\troot-1\tdefinition-1\taccepted\t%s\n' \
    "$run" "$namespace" "$scenario" "$assertion" "$surface" \
    "$operation" "$mode" "$nonce"
printf 'pragma\tforeign-keys\t1\n' >&2
