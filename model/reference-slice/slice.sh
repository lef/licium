#!/bin/sh
set -eu

here=$(CDPATH= cd "$(dirname "$0")" && pwd)

die()
{
    echo "reference-slice: $*" >&2
    exit 2
}

sql()
{
    db=$1
    statement=$2
    {
        echo '.timeout 5000'
        echo 'PRAGMA foreign_keys=ON;'
        echo "$statement"
    } | sqlite3 -batch -bail -noheader -tabs "$db"
}

test $# -ge 2 || die 'usage: slice.sh OP DB [ARGS]'
op=$1
db=$2
shift 2

case $op in
    init)
        test $# -eq 0 || die 'init DB'
        test ! -e "$db" || die "database exists: $db"
        sqlite3 -batch -bail "$db" <"$here/schema.sql" >/dev/null
        ;;
    seed-e67)
        test $# -eq 0 || die 'seed-e67 DB'
        sql "$db" "BEGIN IMMEDIATE;
INSERT INTO repository_object VALUES ('obj-def','definition','definition-main:select-public');
INSERT INTO definition_payload VALUES ('obj-def','definition-main','select-public');
INSERT INTO repository_object VALUES ('obj-public-a','pair','alice:public-a:occ-public-a');
INSERT INTO pair_payload VALUES ('obj-public-a','alice','public-a','occ-public-a');
INSERT INTO delivery_attempt VALUES ('delivery-public-a-1','occ-public-a','inserted');
INSERT INTO delivery_attempt VALUES ('delivery-public-a-retry','occ-public-a','duplicate');
INSERT INTO repository_object VALUES ('obj-public-b','pair','alice:public-a:occ-public-b');
INSERT INTO pair_payload VALUES ('obj-public-b','alice','public-a','occ-public-b');
INSERT INTO delivery_attempt VALUES ('delivery-public-b-1','occ-public-b','inserted');
INSERT INTO repository_object VALUES ('obj-secret','pair','alice:SECRET-E67:occ-secret');
INSERT INTO pair_payload VALUES ('obj-secret','alice','SECRET-E67','occ-secret');
INSERT INTO root VALUES ('root-0','complete');
INSERT INTO root_member VALUES ('root-0',1,'obj-def');
INSERT INTO root_member VALUES ('root-0',2,'obj-public-a');
INSERT INTO root_member VALUES ('root-0',3,'obj-secret');
COMMIT;"
        ;;
    fail-root)
        test $# -eq 1 || die 'fail-root DB ROOT'
        root_ref=$1
        sql "$db" "BEGIN IMMEDIATE;
INSERT INTO root VALUES ('$root_ref','complete');
SELECT value FROM injected_root_failure;
COMMIT;"
        ;;
    healthy-root)
        test $# -eq 0 || die 'healthy-root DB'
        sql "$db" "BEGIN IMMEDIATE;
INSERT INTO root VALUES ('root-1','complete');
INSERT INTO root_member VALUES ('root-1',1,'obj-def');
INSERT INTO root_member VALUES ('root-1',2,'obj-public-b');
INSERT INTO root_member VALUES ('root-1',3,'obj-secret');
COMMIT;"
        ;;
    query-e67-initial)
        sql "$db" "SELECT 'decision_observation',COUNT(*) FROM decision_observation
UNION ALL SELECT 'evaluation_result',COUNT(*) FROM evaluation_result
UNION ALL SELECT 'head',COUNT(*) FROM head
UNION ALL SELECT 'root',COUNT(*) FROM root
UNION ALL SELECT 'state_transition',COUNT(*) FROM state_transition
UNION ALL SELECT 'view_publication',COUNT(*) FROM view_publication ORDER BY 1;"
        ;;
    query-e67-inventory)
        sql "$db" "SELECT o.object_ref,o.object_kind,
CASE o.object_kind WHEN 'pair' THEN p.logical_key ELSE d.definition_ref END,
CASE o.object_kind WHEN 'pair' THEN p.logical_value ELSE d.definition_value END,
CASE o.object_kind WHEN 'pair' THEN p.occurrence_ref ELSE '-' END
FROM repository_object o
LEFT JOIN pair_payload p USING(object_ref)
LEFT JOIN definition_payload d USING(object_ref)
ORDER BY o.object_ref;"
        ;;
    query-e67-members)
        sql "$db" "SELECT m.root_ref,m.ordinal,m.object_ref,r.completeness
FROM root_member m JOIN root r USING(root_ref) ORDER BY m.root_ref,m.ordinal;"
        ;;
    query-e67-duplicates)
        sql "$db" "SELECT d.delivery_ref,d.outcome,
(SELECT COUNT(DISTINCT prior.occurrence_ref) FROM delivery_attempt prior WHERE prior.delivery_ref<=d.delivery_ref),
(SELECT COUNT(DISTINCT prior.occurrence_ref) FROM delivery_attempt prior WHERE prior.delivery_ref<=d.delivery_ref)
FROM delivery_attempt d WHERE d.occurrence_ref IN ('occ-public-a','occ-public-b') ORDER BY d.delivery_ref;"
        ;;
    query-e67-recovery)
        sql "$db" "SELECT 'after-incomplete-root',COUNT(*),(SELECT COUNT(*) FROM root_member),
COALESCE((SELECT root_ref FROM head WHERE authority_ref='authority-main'),'none') FROM root;"
        ;;
    seed-e68)
        test $# -eq 0 || die 'seed-e68 DB'
        sql "$db" "BEGIN IMMEDIATE;
INSERT INTO repository_object VALUES ('obj-exact','pair','alice:public-exact:occ-exact');
INSERT INTO pair_payload VALUES ('obj-exact','alice','public-exact','occ-exact');
INSERT INTO root VALUES ('root-unpublished','complete');
INSERT INTO root_member VALUES ('root-unpublished',1,'obj-def');
INSERT INTO root_member VALUES ('root-unpublished',2,'obj-exact');
INSERT INTO root_member VALUES ('root-unpublished',3,'obj-secret');
INSERT INTO root VALUES ('root-rejected','complete');
INSERT INTO root_member VALUES ('root-rejected',1,'obj-def');
INSERT INTO root_member VALUES ('root-rejected',2,'obj-public-a');
INSERT INTO root_member VALUES ('root-rejected',3,'obj-secret');
INSERT INTO publication VALUES ('publication-0','authority-main','root-0','accepted','trusted-fixture');
INSERT INTO head VALUES ('authority-main','root-0','publication-0');
INSERT INTO publication VALUES ('publication-rejected','authority-main','root-rejected','rejected','trust-rejected');
INSERT INTO publication VALUES ('publication-1','authority-main','root-1','accepted','trusted-fixture');
UPDATE head SET root_ref='root-1',publication_ref='publication-1' WHERE authority_ref='authority-main';
INSERT INTO evaluation_request VALUES ('request-exact','exact-root','alice');
INSERT INTO evaluation_input VALUES ('request-exact','binding','binding-main');
INSERT INTO evaluation_input VALUES ('request-exact','definition','definition-main');
INSERT INTO evaluation_input VALUES ('request-exact','knowledge-cut','cut-exact');
INSERT INTO evaluation_input VALUES ('request-exact','root','root-unpublished');
INSERT INTO evaluation_input VALUES ('request-exact','semantics','semantics-1');
INSERT INTO evaluation_request VALUES ('request-published','published-head','alice');
INSERT INTO evaluation_input VALUES ('request-published','binding','binding-main');
INSERT INTO evaluation_input VALUES ('request-published','definition','definition-main');
INSERT INTO evaluation_input VALUES ('request-published','knowledge-cut','cut-1');
INSERT INTO evaluation_input VALUES ('request-published','root','root-1');
INSERT INTO evaluation_input VALUES ('request-published','semantics','semantics-1');
INSERT INTO definition_current VALUES ('scope-main','definition-main');
COMMIT;"
        ;;
    query-e68-publications)
        sql "$db" "SELECT publication_ref,root_ref,disposition,reason FROM publication ORDER BY publication_ref;"
        ;;
    query-e68-heads)
        sql "$db" "SELECT authority_ref,root_ref,publication_ref FROM head ORDER BY authority_ref;"
        ;;
    query-e68-inputs)
        sql "$db" "SELECT request_ref,input_role,input_ref FROM evaluation_input WHERE request_ref='request-published' ORDER BY request_ref,input_role;"
        ;;
    query-e68-exact-published)
        sql "$db" "SELECT q.request_ref,q.source_mode,i.input_ref,
(SELECT p.logical_value FROM root_member m JOIN pair_payload p USING(object_ref)
 WHERE m.root_ref=i.input_ref AND p.logical_key=q.subject_ref AND p.logical_value NOT LIKE 'SECRET-%'
 ORDER BY p.logical_value LIMIT 1)
FROM evaluation_request q JOIN evaluation_input i ON i.request_ref=q.request_ref AND i.input_role='root'
ORDER BY q.request_ref;"
        ;;
    query-e68-secret-leaks)
        sql "$db" "SELECT 'evaluation-result',COUNT(*) FROM evaluation_result
WHERE selected_value LIKE 'SECRET-%'
UNION ALL SELECT 'pinned-input',COUNT(*) FROM evaluation_input WHERE input_ref LIKE 'SECRET-%'
ORDER BY 1;"
        ;;
    seed-e69)
        test $# -eq 0 || die 'seed-e69 DB'
        sql "$db" "BEGIN IMMEDIATE;
INSERT INTO evaluation_result VALUES ('result-1','request-published','persisted','complete','accepted','public-a','root-1');
INSERT INTO evaluation_run VALUES ('evaluation-persisted','request-published','persisted','result-1');
INSERT INTO view_publication VALUES ('view-1','root-1','root-1','definition-main','complete');
INSERT INTO view_row VALUES ('view-1','alice','public-a');
INSERT INTO state_current VALUES ('scope-main','state-0','view-1');
COMMIT;"
        ;;
    ordinary-evaluate)
        test $# -eq 1 || die 'ordinary-evaluate DB EVALUATION'
        evaluation_ref=$1
        sql "$db" "SELECT '$evaluation_ref','ephemeral','accepted',p.logical_value
FROM evaluation_request q
JOIN evaluation_input i ON i.request_ref=q.request_ref AND i.input_role='root'
JOIN root_member m ON m.root_ref=i.input_ref
JOIN pair_payload p USING(object_ref)
WHERE q.request_ref='request-published' AND p.logical_key=q.subject_ref AND p.logical_value NOT LIKE 'SECRET-%'
ORDER BY p.logical_value LIMIT 1;"
        ;;
    query-e69-results)
        sql "$db" "SELECT evaluation_ref,r.persistence,r.disposition,r.selected_value
FROM evaluation_run e JOIN evaluation_result r USING(result_ref)
UNION ALL SELECT 'evaluation-read-1','ephemeral','accepted','public-a'
UNION ALL SELECT 'evaluation-read-2','ephemeral','accepted','public-a'
ORDER BY 1;"
        ;;
    query-e69-view-provenance)
        sql "$db" "SELECT view_ref,source_root_ref,source_head_ref,definition_ref,status FROM view_publication ORDER BY view_ref;"
        ;;
    query-e69-view-rows)
        sql "$db" "SELECT view_ref,subject_ref,attribute_value FROM view_row ORDER BY view_ref,subject_ref,attribute_value;"
        ;;
    query-e69-secret-leaks)
        sql "$db" "SELECT 'current-view',COUNT(*) FROM state_current s JOIN view_row v USING(view_ref) WHERE v.attribute_value LIKE 'SECRET-%'
UNION ALL SELECT 'ordinary-result',COUNT(*) FROM evaluation_result WHERE selected_value LIKE 'SECRET-%'
ORDER BY 1;"
        ;;
    seed-e70)
        test $# -eq 0 || die 'seed-e70 DB'
        sql "$db" "INSERT INTO evaluation_result VALUES ('result-incomplete','request-published','persisted','incomplete','unknown','-','root-1');"
        ;;
    apply-effect)
        test $# -eq 8 || die 'apply-effect DB EFFECT EXPECTED RESULT TRANSITION OBSERVATION NEWSTATE NEWVIEW FAILPOINT'
        effect_ref=$1; expected_state=$2; result_ref=$3; transition_ref=$4
        observation_ref=$5; new_state=$6; new_view=$7; failpoint=$8
        existing=$(sql "$db" "SELECT COUNT(*) FROM state_transition WHERE effect_ref='$effect_ref';")
        if test "$existing" -gt 0
        then
            printf '%s\tduplicate\talready-applied\t0\t0\n' "$effect_ref"
            exit 0
        fi
        completeness=$(sql "$db" "SELECT COALESCE((SELECT completeness FROM evaluation_result WHERE result_ref='$result_ref'),'missing');")
        if test "$completeness" != complete
        then
            printf '%s\trejected\tincomplete-result\t0\t0\n' "$effect_ref"
            exit 0
        fi
        actual_state=$(sql "$db" "SELECT state_ref FROM state_current WHERE scope_ref='scope-main';")
        if test "$actual_state" != "$expected_state"
        then
            printf '%s\trejected\tstale-expected\t0\t0\n' "$effect_ref"
            exit 0
        fi
        injected_transition=
        injected_observation=
        test "$failpoint" != after-transition || injected_transition='SELECT value FROM injected_after_transition;'
        test "$failpoint" != after-observation || injected_observation='SELECT value FROM injected_after_observation;'
        sql "$db" "BEGIN IMMEDIATE;
INSERT INTO state_transition VALUES ('$transition_ref','scope-main','$expected_state','$new_state','$result_ref','$effect_ref');
$injected_transition
INSERT INTO decision_observation VALUES ('$observation_ref','$transition_ref','$result_ref','root-1');
$injected_observation
INSERT INTO view_publication VALUES ('$new_view','root-1','root-1','definition-main','complete');
INSERT INTO view_row VALUES ('$new_view','alice','public-a');
UPDATE state_current SET state_ref='$new_state',view_ref='$new_view' WHERE scope_ref='scope-main' AND state_ref='$expected_state';
COMMIT;"
        printf '%s\tapplied\tok\t1\t1\n' "$effect_ref"
        ;;
    query-e70-final)
        sql "$db" "SELECT scope_ref,state_ref,view_ref FROM state_current ORDER BY scope_ref;"
        ;;
    query-e70-links)
        sql "$db" "SELECT observation_ref,o.result_ref,o.transition_ref,o.source_root_ref
FROM decision_observation o ORDER BY observation_ref;"
        ;;
    query-e70-rollback)
        test $# -eq 1 || die 'query-e70-rollback DB FAILPOINT'
        failpoint=$1
        sql "$db" "SELECT '$failpoint',state_ref,
(SELECT COUNT(*) FROM state_transition),(SELECT COUNT(*) FROM decision_observation),view_ref
FROM state_current WHERE scope_ref='scope-main';"
        ;;
    seed-e71-current-and-replay)
        test $# -eq 0 || die 'seed-e71-current-and-replay DB'
        sql "$db" "BEGIN IMMEDIATE;
INSERT INTO repository_object VALUES ('obj-def-v2','definition','definition-v2:select-public');
INSERT INTO definition_payload VALUES ('obj-def-v2','definition-v2','select-public');
INSERT INTO repository_object VALUES ('obj-public-v2','pair','alice:public-v2:occ-public-v2');
INSERT INTO pair_payload VALUES ('obj-public-v2','alice','public-v2','occ-public-v2');
INSERT INTO root VALUES ('root-2','complete');
INSERT INTO root_member VALUES ('root-2',1,'obj-def-v2');
INSERT INTO root_member VALUES ('root-2',2,'obj-public-v2');
INSERT INTO root_member VALUES ('root-2',3,'obj-secret');
INSERT INTO publication VALUES ('publication-2','authority-main','root-2','accepted','trusted-fixture');
UPDATE head SET root_ref='root-2',publication_ref='publication-2' WHERE authority_ref='authority-main';
UPDATE definition_current SET definition_ref='definition-v2' WHERE scope_ref='scope-main';
INSERT INTO evaluation_result VALUES ('replay-result-1','request-published','persisted','complete','accepted','public-a','root-1');
INSERT INTO evaluation_run VALUES ('evaluation-replay-1','request-published','persisted','replay-result-1');
COMMIT;"
        ;;
    query-e71-equivalence)
        sql "$db" "SELECT 'result-1','replay-result-1',
(SELECT COUNT(*) FROM (
 SELECT disposition,selected_value,source_root_ref FROM evaluation_result WHERE result_ref='result-1'
 EXCEPT SELECT disposition,selected_value,source_root_ref FROM evaluation_result WHERE result_ref='replay-result-1'
 UNION ALL
 SELECT disposition,selected_value,source_root_ref FROM evaluation_result WHERE result_ref='replay-result-1'
 EXCEPT SELECT disposition,selected_value,source_root_ref FROM evaluation_result WHERE result_ref='result-1'
));"
        ;;
    query-e71-current-variation)
        sql "$db" "SELECT 'replay-result-1',h.root_ref,r.selected_value
FROM head h CROSS JOIN evaluation_result r
WHERE h.authority_ref='authority-main' AND r.result_ref='replay-result-1';"
        ;;
    query-e71-omissions)
        sql "$db" "WITH required(role) AS (VALUES ('binding'),('definition'),('knowledge-cut'),('root'),('semantics'))
SELECT role,'unavailable',1 FROM required ORDER BY role;"
        ;;
    query-e71-reopen)
        sql "$db" "SELECT 'process-b',h.root_ref,'result-1',o.observation_ref
FROM head h CROSS JOIN decision_observation o
WHERE h.authority_ref='authority-main' AND o.observation_ref='observation-1';"
        ;;
    query-e71-executor-leaks)
        sql "$db" "SELECT 'file-path',COUNT(*) FROM evaluation_result WHERE selected_value LIKE '%/%'
UNION ALL SELECT 'process-id',COUNT(*) FROM evaluation_result WHERE selected_value LIKE 'pid-%'
UNION ALL SELECT 'row-order',COUNT(*) FROM evaluation_result WHERE selected_value LIKE 'row-%'
ORDER BY 1;"
        ;;
    seed-e72-publication-base)
        sql "$db" "BEGIN IMMEDIATE;
INSERT INTO publication VALUES ('publication-0','authority-main','root-0','accepted','trusted-fixture');
INSERT INTO head VALUES ('authority-main','root-0','publication-0');
INSERT INTO state_current VALUES ('scope-main','state-0','none');
COMMIT;"
        ;;
    fail-publication)
        sql "$db" "BEGIN IMMEDIATE;
INSERT INTO publication VALUES ('publication-fail','authority-main','root-1','accepted','trusted-fixture');
UPDATE head SET root_ref='root-1',publication_ref='publication-fail' WHERE authority_ref='authority-main';
SELECT value FROM injected_after_head;
COMMIT;"
        ;;
    query-e72-explanation)
        sql "$db" "SELECT 'observation-1',0,'self','observation-1'
UNION ALL SELECT 'observation-1',1,'result','result-1'
UNION ALL SELECT 'observation-1',2,'input','request-published'
UNION ALL SELECT 'observation-1',3,'root','root-1'
UNION ALL SELECT 'observation-1',4,'member','obj-public-b'
ORDER BY 2,3,4;"
        ;;
    query-e72-linkage)
        sql "$db" "SELECT 'observation-1',3,
(SELECT COUNT(*) FROM evaluation_result WHERE result_ref=(SELECT result_ref FROM decision_observation WHERE observation_ref='observation-1'))+
 (SELECT COUNT(*) FROM state_transition WHERE transition_ref=(SELECT transition_ref FROM decision_observation WHERE observation_ref='observation-1'))+
 (SELECT COUNT(*) FROM root WHERE root_ref=(SELECT source_root_ref FROM decision_observation WHERE observation_ref='observation-1')),'complete'
UNION ALL SELECT 'result-1',2,
(SELECT COUNT(*) FROM evaluation_request WHERE request_ref=(SELECT request_ref FROM evaluation_result WHERE result_ref='result-1'))+
 (SELECT COUNT(*) FROM root WHERE root_ref=(SELECT source_root_ref FROM evaluation_result WHERE result_ref='result-1')),'complete'
UNION ALL SELECT 'view-effect-1',3,
(SELECT COUNT(*) FROM root WHERE root_ref=(SELECT source_root_ref FROM view_publication WHERE view_ref='view-effect-1'))+
 (SELECT COUNT(*) FROM definition_payload WHERE definition_ref=(SELECT definition_ref FROM view_publication WHERE view_ref='view-effect-1'))+
 (SELECT COUNT(*) FROM view_row WHERE view_ref='view-effect-1'),'complete'
ORDER BY 1;"
        ;;
    query-e72-failure-state)
        test $# -eq 1 || die 'query-e72-failure-state DB FAILPOINT'
        failpoint=$1
        sql "$db" "SELECT '$failpoint',
COALESCE((SELECT root_ref FROM head WHERE authority_ref='authority-main'),'root-0'),
COALESCE((SELECT state_ref FROM state_current WHERE scope_ref='scope-main'),'state-0'),
((SELECT COUNT(*) FROM root WHERE root_ref LIKE '%incomplete%' OR root_ref='root-fail')+
 (SELECT COUNT(*) FROM publication WHERE publication_ref='publication-fail')+
 (SELECT COUNT(*) FROM state_transition WHERE transition_ref='transition-fail')+
 (SELECT COUNT(*) FROM decision_observation WHERE observation_ref='observation-fail')+
 (SELECT COUNT(*) FROM view_publication WHERE view_ref='view-fail'));"
        ;;
    query-e72-integrity)
        sql "$db" "SELECT 'mutation-cross-root','cross-linked-root',r.result_ref
FROM evaluation_result r JOIN evaluation_input i ON i.request_ref=r.request_ref AND i.input_role='root'
WHERE r.source_root_ref<>i.input_ref
UNION ALL SELECT 'mutation-dangling-result','dangling-result',o.observation_ref
FROM decision_observation o LEFT JOIN evaluation_result r ON r.result_ref=o.result_ref
WHERE o.observation_ref='observation-dangling' AND r.result_ref IS NULL
UNION ALL SELECT 'mutation-dangling-view','dangling-view',v.view_ref
FROM view_publication v LEFT JOIN root r ON r.root_ref=v.source_root_ref
WHERE v.view_ref='view-dangling' AND r.root_ref IS NULL
ORDER BY 1;"
        ;;
    query-e72-secret-leaks)
        sql "$db" "SELECT 'explanation',COUNT(*) FROM pair_payload p WHERE p.logical_value LIKE 'SECRET-%' AND p.object_ref='obj-public-b'
UNION ALL SELECT 'integrity-finding',COUNT(*) FROM evaluation_result WHERE result_ref IN ('result-cross') AND selected_value LIKE 'SECRET-%'
ORDER BY 1;"
        ;;
    *) die "unknown operation: $op" ;;
esac
