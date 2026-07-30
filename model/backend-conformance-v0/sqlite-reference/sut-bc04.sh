#!/bin/sh
set -eu

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc04.sh DB RUN NS SCENARIO CASE OP MODE OCCURRENCE NONCE" >&2
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
    root=$2
    value=$3
    authority=$4
    read_mode=$5
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$scenario" "$case_id" "$operation" \
        "$outcome" - "$root" "$value" "$authority" "$read_mode" \
        unchanged "$nonce"
    printf 'pragma\tforeign-keys\t1\n' >&2
}

case "$operation" in
    sut-setup-bc04)
        [ "$mode" = ordinary ] && [ "$occurrence" = setup ] || exit 2
        case "$case_id" in
            case-bc04-exact)
                sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('root-exact','complete');
INSERT INTO root_value VALUES ('root-exact','x','exact-value');
COMMIT;"
                ;;
            case-bc04-published)
                sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('root-published','complete');
INSERT INTO root_value VALUES ('root-published','x','published-value');
INSERT INTO publication VALUES
    ('pub-published','authority-main','root-published');
INSERT INTO publication_decision VALUES ('pub-published','accepted');
COMMIT;"
                ;;
            case-bc04-collapse)
                sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('root-exact','complete');
INSERT INTO root_value VALUES ('root-exact','x','exact-value');
INSERT INTO stored_root VALUES ('root-published','complete');
INSERT INTO root_value VALUES ('root-published','x','published-value');
INSERT INTO publication VALUES
    ('pub-collapse','authority-main','root-published');
INSERT INTO publication_decision VALUES ('pub-collapse','accepted');
COMMIT;"
                ;;
            case-bc04-ambient)
                sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('root-ambient','complete');
INSERT INTO root_value VALUES ('root-ambient','x','ambient-value');
COMMIT;"
                ;;
            case-bc04-unaccepted)
                sql "
BEGIN IMMEDIATE;
INSERT INTO stored_root VALUES ('root-private','complete');
INSERT INTO root_value
    VALUES ('root-private','x','must-not-leak-unaccepted');
INSERT INTO publication VALUES
    ('pub-private','authority-main','root-private');
INSERT INTO publication_decision VALUES ('pub-private','rejected');
COMMIT;"
                ;;
            *)
                exit 2
                ;;
        esac
        receipt accepted - - - setup
        ;;
    sut-read-exact)
        [ "$case_id" = case-bc04-exact ] &&
            [ "$occurrence" = action ] || exit 2
        case "$mode" in
            ordinary)
                row=$(sql "
SELECT r.root_id,v.value
FROM stored_root r JOIN root_value v USING (root_id)
WHERE r.root_id='root-exact' AND r.availability='complete'
ORDER BY v.value_key LIMIT 1;")
                ;;
            mutant-exact-read-substitution)
                row='root-forged	forged-value'
                ;;
            *)
                exit 2
                ;;
        esac
        root=${row%%	*}
        value=${row#*	}
        receipt available "$root" "$value" - exact
        ;;
    sut-read-published)
        [ "$occurrence" = action ] || exit 2
        case "$mode" in
            ordinary)
                row=$(sql "
SELECT p.proposed_root,v.value
FROM publication p
JOIN publication_decision d USING (publication_id)
JOIN stored_root r ON r.root_id=p.proposed_root
JOIN root_value v ON v.root_id=r.root_id
WHERE p.authority_domain='authority-main'
  AND d.decision='accepted'
  AND r.availability='complete'
ORDER BY p.publication_id,v.value_key LIMIT 1;")
                ;;
            mutant-ambient-read-fallback)
                [ "$case_id" = case-bc04-ambient ] || exit 2
                row='root-ambient	ambient-value'
                ;;
            mutant-read-mode-collapse)
                [ "$case_id" = case-bc04-collapse ] || exit 2
                row='root-exact	exact-value'
                ;;
            mutant-published-read-substitution)
                [ "$case_id" = case-bc04-published ] || exit 2
                row='root-forged	forged-value'
                ;;
            mutant-unaccepted-read-availability)
                [ "$case_id" = case-bc04-unaccepted ] || exit 2
                row='root-private	must-not-leak-unaccepted'
                ;;
            *)
                exit 2
                ;;
        esac
        if [ -n "$row" ]; then
            root=${row%%	*}
            value=${row#*	}
            receipt available "$root" "$value" authority-main published
        else
            receipt unavailable - - authority-main published
        fi
        ;;
    *)
        exit 2
        ;;
esac
