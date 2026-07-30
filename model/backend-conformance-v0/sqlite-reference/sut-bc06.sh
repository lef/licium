#!/bin/sh
set -eu

[ "$#" -eq 8 ] || {
    echo "usage: sut-bc06.sh DB RUN NS ASSERTION OP MODE OCCURRENCE NONCE" >&2
    exit 2
}

db=$1
run=$2
namespace=$3
assertion=$4
operation=$5
mode=$6
occurrence=$7
nonce=$8

pragma_receipt()
{
    printf 'pragma\tforeign-keys\t1\n' >&2
}

sql()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

case "$operation" in
    sut-setup-bc06)
        [ "$mode" = "ordinary" ] && [ "$occurrence" = "setup" ] || exit 2
        sql "
BEGIN IMMEDIATE;
INSERT INTO source_pair VALUES ('pair-06','alice','public-a');
INSERT INTO evaluation_request
    VALUES ('request-06','ordinary','pair-06');
INSERT INTO authoritative_state VALUES ('scope-06','state-0');
COMMIT;
"
        printf 'status\tsetup\taccepted\t%s\n' "$assertion"
        pragma_receipt
        ;;
    sut-evaluate-pure)
        case "$occurrence" in occurrence-1|occurrence-2) ;; *) exit 2 ;; esac
        case "$mode" in
            ordinary)
                ;;
            mutant-state-write)
                sql "
BEGIN IMMEDIATE;
INSERT INTO authoritative_state VALUES ('scope-mutant','state-mutant');
COMMIT;
"
                ;;
            mutant-result-write)
                sql "
BEGIN IMMEDIATE;
INSERT INTO result_store VALUES ('result-mutant','request-06');
COMMIT;
"
                ;;
            mutant-observation-write)
                sql "
BEGIN IMMEDIATE;
INSERT INTO decision_observation
    VALUES ('observation-mutant','request-06');
COMMIT;
"
                ;;
            mutant-all-three-axis-write)
                sql "
BEGIN IMMEDIATE;
INSERT INTO authoritative_state VALUES ('scope-mutant','state-mutant');
INSERT INTO result_store VALUES ('result-mutant','request-06');
INSERT INTO decision_observation
    VALUES ('observation-mutant','request-06');
COMMIT;
"
                ;;
            mutant-repository-drift)
                sql "
BEGIN IMMEDIATE;
UPDATE source_pair
SET logical_value='public-b'
WHERE object_ref='pair-06';
COMMIT;
"
                ;;
            mutant-noop)
                printf '%s\t%s\t%s\t%s\t%s\taccepted\trequest-06\talice\tpair-06\t-\t%s\n' \
                    "$run" "$namespace" "$assertion" "$occurrence" \
                    "$operation" "$nonce"
                pragma_receipt
                exit 0
                ;;
            *)
                exit 2
                ;;
        esac

        sql "
SELECT '$run',
       '$namespace',
       '$assertion',
       '$occurrence',
       '$operation',
       'accepted',
       q.request_ref,
       p.logical_id,
       p.object_ref,
       p.logical_value,
       '$nonce'
FROM evaluation_request AS q
JOIN source_pair AS p ON p.object_ref=q.source_object_ref
WHERE q.request_ref='request-06'
  AND q.request_kind='ordinary';
"
        pragma_receipt
        ;;
    *)
        exit 2
        ;;
esac
