#!/bin/sh
set -eu

[ "$#" -eq 6 ] || exit 2
db=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
stage=$6

sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
WITH
required(count) AS (
    SELECT COUNT(*)
    FROM root_required_member
    WHERE request_ref='request-02'
),
matched(count) AS (
    SELECT COUNT(*)
    FROM root_member AS member
    JOIN root_required_member AS expected
      ON expected.request_ref='request-02'
     AND expected.ordinal=member.ordinal
     AND expected.object_ref=member.object_ref
    WHERE member.root_ref='root-02'
),
valid(value) AS (
    SELECT CASE WHEN
        EXISTS (
            SELECT 1 FROM root
            WHERE root_ref='root-02'
              AND request_ref='request-02'
              AND status='complete'
        )
        AND (SELECT count FROM required) > 0
        AND (SELECT count FROM matched) = (SELECT count FROM required)
        AND NOT EXISTS (
            SELECT 1
            FROM root_member AS member
            LEFT JOIN root_required_member AS expected
              ON expected.request_ref='request-02'
             AND expected.ordinal=member.ordinal
             AND expected.object_ref=member.object_ref
            WHERE member.root_ref='root-02'
              AND expected.request_ref IS NULL
        )
        AND EXISTS (
            SELECT 1
            FROM root_ancestry
            WHERE root_ref='root-02'
              AND boundary_ref='genesis-02'
              AND boundary_kind='genesis'
        )
        THEN 1 ELSE 0 END
)
SELECT '$run',
       '$namespace',
       '$assertion',
       '$case_id',
       '$stage',
       'request-02',
       'root-02',
       CASE WHEN valid.value=1 THEN 'available' ELSE 'root-unavailable' END,
       CASE WHEN valid.value=1
            THEN printf('%d/%d', matched.count, required.count)
            ELSE printf('0/%d', required.count)
       END,
       CASE WHEN valid.value=1 THEN 'genesis-02' ELSE '-' END
FROM required, matched, valid;
"
printf 'pragma\tforeign-keys\t1\n' >&2
