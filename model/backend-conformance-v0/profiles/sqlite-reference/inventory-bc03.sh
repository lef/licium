#!/bin/sh
set -eu

[ "$#" -eq 2 ] || exit 2
db=$1
scenario=$2

sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
WITH facts(role, reference, field, value) AS (
    SELECT 'repository','@relation','presence','present'
    UNION ALL
    SELECT 'stored-root',root_id,'availability',availability
    FROM stored_root
    UNION ALL
    SELECT 'publication',publication_id,'authority-domain',authority_domain
    FROM publication
    UNION ALL
    SELECT 'publication',publication_id,'proposed-root',proposed_root
    FROM publication
    UNION ALL
    SELECT 'publication-decision',publication_id,'state',decision
    FROM publication_decision
),
numbered AS (
    SELECT role, reference, field, value,
           row_number() OVER (
               PARTITION BY role, reference
               ORDER BY field, value
           ) AS occurrence
    FROM facts
)
SELECT '$scenario',role,reference,field,value,
       printf('%04d', occurrence)
FROM numbered
ORDER BY 1,2,3,4,5,6;
"
printf 'pragma\tforeign-keys\t1\n' >&2
