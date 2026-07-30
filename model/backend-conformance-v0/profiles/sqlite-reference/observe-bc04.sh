#!/bin/sh
set -eu

[ "$#" -eq 4 ] || exit 2
db=$1
scenario=$2
case_id=$3
receipt=$4

[ -f "$receipt" ] && [ ! -L "$receipt" ] || exit 2

row=$(awk -F '	' '
    NF == 13 && $5 != "sut-setup-bc04" {
        print $6 "\t" $8 "\t" $9 "\t" $10 "\t" $11
    }
' "$receipt")
IFS='	' read -r outcome result_root result_value authority read_mode <<EOF
$row
EOF
[ -n "$outcome" ] && [ -n "$read_mode" ] || exit 1

emit()
{
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$scenario" "$1" "$2" "$3" "$4" "$5"
}

case "$case_id" in
    case-bc04-exact)
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 selector action mode "$read_mode"
        emit raw-003 selector action root root-exact
        emit raw-004 read-result after root "$result_root"
        emit raw-005 read-result after value "$result_value"
        emit raw-006 publication-state after root-exact unpublished
        ;;
    case-bc04-published)
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 selector action mode "$read_mode"
        emit raw-003 selector action authority-domain "$authority"
        emit raw-004 read-result after root "$result_root"
        emit raw-005 read-result after value "$result_value"
        decision=$(sqlite3 -batch -bail -noheader -tabs "$db" \
            "PRAGMA foreign_keys=ON;
             SELECT decision FROM publication_decision
             WHERE publication_id='pub-published';")
        emit raw-006 publication-decision after state "$decision"
        ;;
    case-bc04-collapse)
        exact_value=$(sqlite3 -batch -bail -noheader -tabs "$db" \
            "PRAGMA foreign_keys=ON;
             SELECT value FROM root_value
             WHERE root_id='root-exact' AND value_key='x';")
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 selector action mode "$read_mode"
        emit raw-003 exact-candidate:root-exact after value "$exact_value"
        emit raw-004 published-result after root "$result_root"
        emit raw-005 published-result after value "$result_value"
        if [ "$result_root" = root-published ]; then distinct=distinct
        else distinct=collapsed
        fi
        emit raw-006 selector-comparison after roots "$distinct"
        ;;
    case-bc04-ambient)
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 selector action mode "$read_mode"
        emit raw-003 selector action authority-domain "$authority"
        emit raw-004 ambient-candidate after root root-ambient
        if [ "$outcome" = unavailable ]; then
            emit raw-005 published-result after root absent
            emit raw-006 ambient-fallback after root-ambient absent
        else
            emit raw-005 published-result after root "$result_root"
            emit raw-006 ambient-fallback after root-ambient present
        fi
        ;;
    case-bc04-unaccepted)
        decision=$(sqlite3 -batch -bail -noheader -tabs "$db" \
            "PRAGMA foreign_keys=ON;
             SELECT decision FROM publication_decision
             WHERE publication_id='pub-private';")
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 selector action mode "$read_mode"
        emit raw-003 selector action authority-domain "$authority"
        emit raw-004 stored-root after root-private complete
        emit raw-005 publication-decision after state "$decision"
        if [ "$outcome" = unavailable ]; then
            emit raw-006 published-result after root absent
            emit raw-007 published-secret-leaks after count 0
        else
            emit raw-006 published-result after root "$result_root"
            if [ "$result_value" = must-not-leak-unaccepted ]; then leaks=1
            else leaks=0
            fi
            emit raw-007 published-secret-leaks after count "$leaks"
        fi
        ;;
    *)
        exit 2
        ;;
esac
printf 'pragma\tforeign-keys\t1\n' >&2
