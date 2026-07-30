#!/bin/sh
set -eu

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc01.sh DB RUN NS SCENARIO CASE OP MODE OCCURRENCE NONCE" >&2
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

pragma_receipt()
{
    printf 'pragma\tforeign-keys\t1\n' >&2
}

sql()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

receipt()
{
    outcome=$1
    error_class=$2
    delivery_ref=$3
    occurrence_ref=$4
    subject=$5
    logical_value=$6
    effect=$7
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$scenario" "$case_id" "$operation" \
        "$outcome" "$error_class" "$delivery_ref" "$occurrence_ref" \
        "$subject" "$logical_value" "$effect" "$nonce"
    pragma_receipt
}

case "$operation" in
    sut-setup-bc01)
        [ "$mode" = "ordinary" ] && [ "$occurrence" = "setup" ] || exit 2
        sql "
BEGIN IMMEDIATE;
INSERT INTO delivery
    VALUES ('delivery-a','occurrence-a','alice','public-a');
INSERT INTO association_occurrence
    VALUES ('occurrence-a','delivery-a','alice','public-a');
INSERT INTO logical_association(subject, logical_value)
    VALUES ('alice','public-a');
COMMIT;
"
        receipt accepted - delivery-a occurrence-a alice public-a inserted
        ;;
    sut-retry-delivery)
        [ "$case_id" = "case-bc01-retry" ] || exit 2
        case "$mode" in
            ordinary)
                receipt duplicate - delivery-a occurrence-a alice \
                    public-a unchanged
                ;;
            mutant-association-duplication)
                sql "
BEGIN IMMEDIATE;
INSERT INTO logical_association(subject, logical_value)
    VALUES ('alice','public-a');
COMMIT;
"
                receipt accepted - delivery-a occurrence-a alice \
                    public-a inserted
                ;;
            mutant-retry-duplication)
                sql "
BEGIN IMMEDIATE;
INSERT INTO association_occurrence
    VALUES ('occurrence-b','delivery-a','alice','public-a');
COMMIT;
"
                receipt accepted - delivery-a occurrence-b alice \
                    public-a inserted
                ;;
            *)
                exit 2
                ;;
        esac
        ;;
    sut-deliver-distinct)
        [ "$case_id" = "case-bc01-distinct" ] || exit 2
        case "$mode" in
            ordinary)
                sql "
BEGIN IMMEDIATE;
INSERT INTO delivery
    VALUES ('delivery-b','occurrence-b','alice','public-a');
INSERT INTO association_occurrence
    VALUES ('occurrence-b','delivery-b','alice','public-a');
COMMIT;
"
                receipt accepted - delivery-b occurrence-b alice \
                    public-a inserted
                ;;
            mutant-distinct-collapse)
                receipt duplicate - delivery-a occurrence-a alice \
                    public-a unchanged
                ;;
            mutant-occurrence-collapse)
                sql "
BEGIN IMMEDIATE;
INSERT INTO delivery
    VALUES ('delivery-b','occurrence-a','alice','public-a');
COMMIT;
"
                receipt accepted - delivery-b occurrence-a alice \
                    public-a inserted
                ;;
            *)
                exit 2
                ;;
        esac
        ;;
    sut-deliver-collision)
        [ "$case_id" = "case-bc01-payload-collision" ] || exit 2
        case "$mode" in
            ordinary)
                receipt collision payload-mismatch delivery-a occurrence-a \
                    alice public-x unchanged
                ;;
            mutant-payload-collision-acceptance)
                sql "
BEGIN IMMEDIATE;
UPDATE delivery SET logical_value='public-x'
WHERE delivery_ref='delivery-a';
UPDATE association_occurrence SET logical_value='public-x'
WHERE occurrence_ref='occurrence-a';
UPDATE logical_association SET logical_value='public-x'
WHERE subject='alice' AND logical_value='public-a';
COMMIT;
"
                receipt accepted - delivery-a occurrence-a alice \
                    public-x inserted
                ;;
            *)
                exit 2
                ;;
        esac
        ;;
    *)
        exit 2
        ;;
esac
