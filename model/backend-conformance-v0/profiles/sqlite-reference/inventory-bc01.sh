#!/bin/sh
set -eu

[ "$#" -eq 2 ] || exit 2
db=$1
scenario=$2

sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
WITH facts(role, reference, field, value) AS (
    SELECT 'association','@relation','presence','present'
    UNION ALL
    SELECT 'association',subject,'logical-value',logical_value
    FROM logical_association
    UNION ALL
    SELECT 'delivery','@relation','presence','present'
    UNION ALL
    SELECT 'delivery',delivery_ref,'logical-value',logical_value
    FROM delivery
    UNION ALL
    SELECT 'delivery',delivery_ref,'occurrence-ref',occurrence_ref
    FROM delivery
    UNION ALL
    SELECT 'delivery',delivery_ref,'subject',subject
    FROM delivery
    UNION ALL
    SELECT 'occurrence','@relation','presence','present'
    UNION ALL
    SELECT 'occurrence',occurrence_ref,'delivery-ref',delivery_ref
    FROM association_occurrence
    UNION ALL
    SELECT 'occurrence',occurrence_ref,'logical-value',logical_value
    FROM association_occurrence
    UNION ALL
    SELECT 'occurrence',occurrence_ref,'subject',subject
    FROM association_occurrence
),
numbered AS (
    SELECT role, reference, field, value,
           row_number() OVER (
               PARTITION BY role, reference, field, value
               ORDER BY role, reference, field, value
           ) AS occurrence
    FROM facts
)
SELECT '$scenario',role,reference,field,value,
       printf('%04d', occurrence)
FROM numbered
ORDER BY 1,2,3,4,5,6;
"
printf 'pragma\tforeign-keys\t1\n' >&2
