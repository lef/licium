#!/bin/sh
set -eu

[ "$#" -eq 3 ] || exit 2
db=$1
scenario=$2
case_id=$3

case "$case_id" in
    case-bc03-accepted)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-002','stored-root','after','root-id',
       root_id FROM stored_root ORDER BY root_id LIMIT 1;
SELECT '$scenario','raw-003','stored-root','after','availability',
       availability FROM stored_root ORDER BY root_id LIMIT 1;
SELECT '$scenario','raw-004','publication','after','publication-id',
       publication_id FROM publication ORDER BY publication_id LIMIT 1;
SELECT '$scenario','raw-005','publication','after','authority-domain',
       authority_domain FROM publication ORDER BY publication_id LIMIT 1;
SELECT '$scenario','raw-006','publication','after','proposed-root',
       proposed_root FROM publication ORDER BY publication_id LIMIT 1;
SELECT '$scenario','raw-007','publication-decision','after','decision',
       decision FROM publication_decision ORDER BY publication_id LIMIT 1;
SELECT '$scenario','raw-008','derived-head:authority-main','after',
       'root-accepted',
       CASE WHEN EXISTS (
           SELECT 1 FROM publication p
           JOIN publication_decision d USING (publication_id)
           WHERE p.authority_domain='authority-main'
             AND p.proposed_root='root-accepted'
             AND d.decision='accepted'
       ) THEN 'present' ELSE 'absent' END;
"
        ;;
    case-bc03-rejected)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-002','stored-root','after','root-id',
       root_id FROM stored_root ORDER BY root_id LIMIT 1;
SELECT '$scenario','raw-003','stored-root','after','availability',
       availability FROM stored_root ORDER BY root_id LIMIT 1;
SELECT '$scenario','raw-004','publication','after','publication-id',
       publication_id FROM publication ORDER BY publication_id LIMIT 1;
SELECT '$scenario','raw-005','publication','after','authority-domain',
       authority_domain FROM publication ORDER BY publication_id LIMIT 1;
SELECT '$scenario','raw-006','publication','after','proposed-root',
       proposed_root FROM publication ORDER BY publication_id LIMIT 1;
SELECT '$scenario','raw-007','publication-decision','after','decision',
       decision FROM publication_decision ORDER BY publication_id LIMIT 1;
SELECT '$scenario','raw-008','derived-head:authority-main','after',
       'root-rejected',
       CASE WHEN EXISTS (
           SELECT 1 FROM publication p
           JOIN publication_decision d USING (publication_id)
           WHERE p.authority_domain='authority-main'
             AND p.proposed_root='root-rejected'
             AND d.decision='accepted'
       ) THEN 'present' ELSE 'absent' END;
"
        ;;
    case-bc03-stored)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-002','stored-root','after','root-id',
       root_id FROM stored_root ORDER BY root_id LIMIT 1;
SELECT '$scenario','raw-003','stored-root','after','availability',
       availability FROM stored_root ORDER BY root_id LIMIT 1;
SELECT '$scenario','raw-004','publication-by-root','after','root-stored',
       CASE WHEN EXISTS (
           SELECT 1 FROM publication WHERE proposed_root='root-stored'
       ) THEN 'present' ELSE 'absent' END;
SELECT '$scenario','raw-005','derived-head:authority-main','after',
       'root-stored',
       CASE WHEN EXISTS (
           SELECT 1 FROM publication p
           JOIN publication_decision d USING (publication_id)
           WHERE p.authority_domain='authority-main'
             AND p.proposed_root='root-stored'
             AND d.decision='accepted'
       ) THEN 'present' ELSE 'absent' END;
"
        ;;
    case-bc03-wrong-authority)
        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','raw-002','stored-root','after','root-id',
       root_id FROM stored_root WHERE root_id='root-other';
SELECT '$scenario','raw-003','stored-root','after','availability',
       availability FROM stored_root WHERE root_id='root-other';
SELECT '$scenario','raw-004','publication','after','publication-id',
       publication_id FROM publication WHERE publication_id='pub-other';
SELECT '$scenario','raw-005','publication','after','authority-domain',
       authority_domain FROM publication WHERE publication_id='pub-other';
SELECT '$scenario','raw-006','publication','after','proposed-root',
       proposed_root FROM publication WHERE publication_id='pub-other';
SELECT '$scenario','raw-007','publication-decision','after','decision',
       decision FROM publication_decision WHERE publication_id='pub-other';
SELECT '$scenario','raw-008','derived-head:authority-other','after',
       'root-other',
       CASE WHEN EXISTS (
           SELECT 1 FROM publication p
           JOIN publication_decision d USING (publication_id)
           WHERE p.authority_domain='authority-other'
             AND p.proposed_root='root-other'
             AND d.decision='accepted'
       ) THEN 'present' ELSE 'absent' END;
SELECT '$scenario','raw-009','derived-head:authority-main','after',
       'root-other',
       CASE WHEN EXISTS (
           SELECT 1 FROM publication p
           JOIN publication_decision d USING (publication_id)
           WHERE p.authority_domain='authority-main'
             AND p.proposed_root='root-other'
             AND d.decision='accepted'
       ) THEN 'present' ELSE 'absent' END;
"
        ;;
    *)
        exit 2
        ;;
esac
printf 'pragma\tforeign-keys\t1\n' >&2
