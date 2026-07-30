#!/bin/sh
set -eu

[ "$#" -eq 4 ] || exit 2
db=$1
scenario=$2
case_id=$3
phase=$4

case "$case_id:$phase" in
    case-bc01-retry:before)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-004','delivery','before',delivery_ref,occurrence_ref
FROM delivery WHERE delivery_ref='delivery-a'
UNION ALL
SELECT '$scenario','raw-006','occurrence','before',occurrence_ref,delivery_ref
FROM association_occurrence WHERE occurrence_ref='occurrence-a'
ORDER BY 1,2,3,4,5,6;
"
        ;;
    case-bc01-retry:after)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-005','delivery','after',delivery_ref,occurrence_ref
FROM delivery WHERE delivery_ref='delivery-a'
UNION ALL
SELECT '$scenario',
       CASE occurrence_ref
           WHEN 'occurrence-a' THEN 'raw-007'
           ELSE 'raw-mutant-occurrence-' || occurrence_ref
       END,
       'occurrence','after',occurrence_ref,delivery_ref
FROM association_occurrence
UNION ALL
SELECT '$scenario',
       CASE association_ref
           WHEN (SELECT min(association_ref) FROM logical_association)
           THEN 'raw-008'
           ELSE 'raw-mutant-association-' || association_ref
       END,
       'association-projection','after',subject,logical_value
FROM logical_association
UNION ALL
SELECT '$scenario',
       CASE occurrence_ref
           WHEN 'occurrence-a' THEN 'raw-009'
           ELSE 'raw-mutant-provenance-' || occurrence_ref
       END,
       'provenance','after',occurrence_ref,delivery_ref
FROM association_occurrence
ORDER BY 1,2,3,4,5,6;
"
        ;;
    case-bc01-distinct:before)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-004','delivery','before',delivery_ref,occurrence_ref
FROM delivery WHERE delivery_ref='delivery-a'
UNION ALL
SELECT '$scenario','raw-007','occurrence','before',occurrence_ref,delivery_ref
FROM association_occurrence WHERE occurrence_ref='occurrence-a'
ORDER BY 1,2,3,4,5,6;
"
        ;;
    case-bc01-distinct:after)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario',
       CASE delivery_ref WHEN 'delivery-a' THEN 'raw-005' ELSE 'raw-006' END,
       'delivery','after',delivery_ref,occurrence_ref
FROM delivery
UNION ALL
SELECT '$scenario',
       CASE occurrence_ref WHEN 'occurrence-a' THEN 'raw-008' ELSE 'raw-009' END,
       'occurrence','after',occurrence_ref,delivery_ref
FROM association_occurrence
UNION ALL
SELECT '$scenario','raw-010','association-projection','after',subject,logical_value
FROM logical_association
UNION ALL
SELECT '$scenario',
       CASE occurrence_ref WHEN 'occurrence-a' THEN 'raw-011' ELSE 'raw-012' END,
       'provenance','after',occurrence_ref,delivery_ref
FROM association_occurrence
UNION ALL
SELECT '$scenario',
       CASE occurrence_ref WHEN 'occurrence-a' THEN 'raw-013' ELSE 'raw-015' END,
       'occurrence-subject','after',occurrence_ref,subject
FROM association_occurrence
UNION ALL
SELECT '$scenario',
       CASE occurrence_ref WHEN 'occurrence-a' THEN 'raw-014' ELSE 'raw-016' END,
       'occurrence-logical-value','after',occurrence_ref,logical_value
FROM association_occurrence
ORDER BY 1,2,3,4,5,6;
"
        ;;
    case-bc01-payload-collision:before)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-005','delivery','before',delivery_ref,occurrence_ref
FROM delivery WHERE delivery_ref='delivery-a'
UNION ALL
SELECT '$scenario','raw-007','occurrence','before',occurrence_ref,delivery_ref
FROM association_occurrence WHERE occurrence_ref='occurrence-a'
ORDER BY 1,2,3,4,5,6;
"
        ;;
    case-bc01-payload-collision:after)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-006','delivery','after',delivery_ref,occurrence_ref
FROM delivery WHERE delivery_ref='delivery-a'
UNION ALL
SELECT '$scenario','raw-008','occurrence','after',occurrence_ref,delivery_ref
FROM association_occurrence WHERE occurrence_ref='occurrence-a'
UNION ALL
SELECT '$scenario','raw-009','association-projection','after',subject,logical_value
FROM logical_association
UNION ALL
SELECT '$scenario','raw-010','provenance','after',occurrence_ref,delivery_ref
FROM association_occurrence WHERE occurrence_ref='occurrence-a'
UNION ALL
SELECT '$scenario','raw-011','accepted-collision','after','delivery-a',
       CAST(count(*) AS TEXT)
FROM delivery
WHERE delivery_ref='delivery-a' AND logical_value='public-x'
UNION ALL
SELECT '$scenario','raw-012','delivery-logical-value','after',
       delivery_ref,logical_value
FROM delivery WHERE delivery_ref='delivery-a'
ORDER BY 1,2,3,4,5,6;
"
        ;;
    *)
        exit 2
        ;;
esac
printf 'pragma\tforeign-keys\t1\n' >&2
