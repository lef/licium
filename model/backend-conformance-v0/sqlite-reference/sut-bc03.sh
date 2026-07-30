#!/bin/sh
set -eu

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc03.sh DB RUN NS SCENARIO CASE OP MODE OCCURRENCE NONCE" >&2
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
    error_class=$2
    root=$3
    publication=$4
    authority=$5
    decision=$6
    effect=$7
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$scenario" "$case_id" "$operation" \
        "$outcome" "$error_class" "$root" "$publication" "$authority" \
        "$decision" "$effect" "$nonce"
    printf 'pragma\tforeign-keys\t1\n' >&2
}

case "$operation" in
    sut-setup-bc03)
        [ "$mode" = ordinary ] && [ "$occurrence" = setup ] || exit 2
        case "$case_id" in
            case-bc03-accepted|case-bc03-rejected|case-bc03-stored)
                receipt accepted - - - - - unchanged
                ;;
            case-bc03-wrong-authority)
                sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('root-other','complete');
INSERT INTO publication
    VALUES ('pub-other','authority-other','root-other');
INSERT INTO publication_decision VALUES ('pub-other','accepted');
COMMIT;
"
                receipt accepted - root-other pub-other authority-other \
                    accepted inserted
                ;;
            *)
                exit 2
                ;;
        esac
        ;;
    sut-publish-root)
        [ "$occurrence" = action ] || exit 2
        case "$case_id:$mode" in
            case-bc03-accepted:ordinary)
                root=root-accepted
                publication=pub-accepted
                authority=authority-main
                decision=accepted
                ;;
            case-bc03-accepted:mutant-accepted-head-omission)
                root=root-accepted
                publication=pub-accepted
                authority=authority-main
                decision=rejected
                ;;
            case-bc03-accepted:mutant-publication-root-collapse)
                root=root-accepted
                publication=root-accepted
                authority=authority-main
                decision=accepted
                ;;
            case-bc03-rejected:ordinary)
                root=root-rejected
                publication=pub-rejected
                authority=authority-main
                decision=rejected
                ;;
            case-bc03-rejected:mutant-rejected-head-inclusion)
                root=root-rejected
                publication=pub-rejected
                authority=authority-main
                decision=accepted
                ;;
            *)
                exit 2
                ;;
        esac
        sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('$root','complete');
INSERT INTO publication VALUES ('$publication','$authority','$root');
INSERT INTO publication_decision VALUES ('$publication','$decision');
COMMIT;
"
        receipt accepted - "$root" "$publication" "$authority" \
            "$decision" inserted
        ;;
    sut-store-root)
        [ "$case_id" = case-bc03-stored ] &&
            [ "$occurrence" = action ] || exit 2
        root=root-stored
        case "$mode" in
            ordinary)
                sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('$root','complete');
COMMIT;
"
                publication=-
                authority=-
                decision=-
                ;;
            mutant-stored-root-head-inclusion)
                publication=pub-stored
                authority=authority-main
                decision=accepted
                sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('$root','complete');
INSERT INTO publication VALUES ('$publication','$authority','$root');
INSERT INTO publication_decision VALUES ('$publication','$decision');
COMMIT;
"
                ;;
            mutant-stored-root-publication-collapse)
                publication=root-stored
                authority=authority-main
                decision=rejected
                sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('$root','complete');
INSERT INTO publication VALUES ('$publication','$authority','$root');
INSERT INTO publication_decision VALUES ('$publication','$decision');
COMMIT;
"
                ;;
            *)
                exit 2
                ;;
        esac
        receipt accepted - "$root" "$publication" "$authority" \
            "$decision" inserted
        ;;
    sut-derive-heads)
        [ "$case_id" = case-bc03-wrong-authority ] &&
            [ "$occurrence" = action ] || exit 2
        case "$mode" in
            ordinary)
                ;;
            mutant-wrong-authority-head-inclusion)
                sql "
BEGIN IMMEDIATE;
UPDATE publication
SET authority_domain='authority-main'
WHERE publication_id='pub-other';
COMMIT;
"
                ;;
            *)
                exit 2
                ;;
        esac
        receipt accepted - root-other pub-other authority-main \
            accepted unchanged
        ;;
    *)
        exit 2
        ;;
esac
