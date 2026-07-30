#!/bin/sh
set -eu

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc11.sh DB RUN NS SCENARIO ASSERTION SURFACE OP MODE NONCE" >&2
    exit 2
}

db=$1
run=$2
namespace=$3
scenario=$4
assertion=$5
surface=$6
operation=$7
mode=$8
nonce=$9

sql()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

setup()
{
    sql "
BEGIN IMMEDIATE;
INSERT INTO source_object VALUES
    ('definition-object','definition','definition-1'),
    ('member-public','value','public-a'),
    ('member-current','value','public-b');
INSERT INTO root VALUES
    ('root-1','complete'),
    ('root-2','complete');
INSERT INTO root_member VALUES
    ('root-1',1,'definition-object',0),
    ('root-1',2,'member-public',1),
    ('root-2',1,'definition-object',0),
    ('root-2',2,'member-current',1);
INSERT INTO ambient_current VALUES ('default','root-2');
INSERT INTO evaluation_request VALUES ('request-1','subject-1');
INSERT INTO evaluation_input VALUES
    ('request-1','binding','binding-1'),
    ('request-1','definition','definition-1'),
    ('request-1','knowledge-cut','cut-1'),
    ('request-1','source-root','root-1'),
    ('request-1','semantics','semantics-1');
WITH roles(role) AS (
  VALUES ('binding'),('definition'),('knowledge-cut'),
         ('source-root'),('semantics')
)
INSERT INTO evaluation_request
SELECT 'request-missing-' || role,'subject-1' FROM roles;
WITH roles(role) AS (
  VALUES ('binding'),('definition'),('knowledge-cut'),
         ('source-root'),('semantics')
)
INSERT INTO evaluation_input
SELECT 'request-missing-' || omitted.role,
       source.input_role,source.input_ref
FROM roles omitted
CROSS JOIN evaluation_input source
WHERE source.request_ref='request-1'
  AND source.input_role != omitted.role;
INSERT INTO result_output
VALUES ('result-1','request-1','root-1','definition-1',
        'member-public','public-a','complete');
INSERT INTO integrity_subject VALUES
    ('cross-link-1','cross-link','root-1','root','root-2','root-2',
     'member-public'),
    ('dangling-result-1','dangling','root-1','result','missing-result',
     'root-1','public-a'),
    ('dangling-view-1','dangling','root-1','view','missing-view',
     'root-1','public-a');
COMMIT;"
    printf 'status\tsetup\taccepted\t%s\n' "$scenario"
}

apply_replay()
{
    value=$(sql "
SELECT selected_value FROM result_output WHERE result_ref='result-1';")
    source_root=$(sql "
SELECT source_root_ref FROM result_output WHERE result_ref='result-1';")
    definition=$(sql "
SELECT definition_ref FROM result_output WHERE result_ref='result-1';")
    disposition=complete
    case "$assertion:$mode" in
        BC11_REPLAY_RESULT:ordinary) ;;
        BC11_REPLAY_RESULT:mutant-detect-replay-result-drift) value=public-drift ;;
        BC11_LATEST_SUBSTITUTION:ordinary) ;;
        BC11_LATEST_SUBSTITUTION:mutant-detect-latest-replay-substitution)
            source_root=$(sql "
SELECT root_ref FROM ambient_current WHERE slot='default';")
            value=$(sql "
SELECT s.object_value
FROM root_member m JOIN source_object s ON s.object_ref=m.object_ref
WHERE m.root_ref='$source_root' AND m.selected=1;")
            ;;
        BC11_MISSING_AS_EMPTY:ordinary|\
        BC11_MISSING_AS_EMPTY:mutant-detect-replay-missing-as-empty)
            mutant=0
            [ "$mode" != mutant-detect-replay-missing-as-empty ] ||
                mutant=1
            sql "
WITH roles(role, ordinal) AS (
  VALUES ('binding',1),('definition',2),('knowledge-cut',3),
         ('source-root',4),('semantics',5)
)
INSERT INTO replay_omission
SELECT 'replay-missing', omitted.role, input.role,
       CASE
         WHEN EXISTS (
           SELECT 1 FROM evaluation_input e
           WHERE e.request_ref='request-missing-' || omitted.role
             AND e.input_role=input.role
         ) THEN 'available'
         ELSE 'unavailable'
       END,
       CASE WHEN $mutant=1 AND omitted.role='binding'
            THEN 'complete'
            WHEN (SELECT COUNT(*) FROM evaluation_input e
                  WHERE e.request_ref='request-missing-' || omitted.role)=4
             AND NOT EXISTS (
                 SELECT 1 FROM evaluation_input e
                 WHERE e.request_ref='request-missing-' || omitted.role
                   AND e.input_role=omitted.role
             )
            THEN 'unavailable' ELSE 'invalid' END,
       CASE WHEN $mutant=1 AND omitted.role='binding' THEN 0
            WHEN (SELECT COUNT(*) FROM evaluation_input e
                  WHERE e.request_ref='request-missing-' || omitted.role)=4
            THEN 1 ELSE -1 END
FROM roles omitted CROSS JOIN roles input;"
            return
            ;;
        *) exit 2 ;;
    esac
    sql "
INSERT INTO replay_output
VALUES ('replay-result-1','result-1','request-1','$source_root',
        '$definition','$value','$disposition');"
}

apply_explanation()
{
    case "$mode" in ordinary|mutant-detect-explanation-member-loss) ;; *) exit 2 ;; esac
    sql "
BEGIN IMMEDIATE;
INSERT INTO explanation_output VALUES ('explanation-1','complete');
INSERT INTO explanation_edge VALUES
    ('explanation-1',1,'observation','observation-1'),
    ('explanation-1',2,'result','result-1'),
    ('explanation-1',3,'request','request-1'),
    ('explanation-1',4,'source-root','root-1');
COMMIT;"
    [ "$mode" = mutant-detect-explanation-member-loss ] || sql "
INSERT INTO explanation_edge
VALUES ('explanation-1',5,'selected-member','member-public');"
}

serialized_inventory()
{
    sql "
SELECT group_concat(
           subject_ref || ':' || subject_kind || ':' ||
           source_root_ref || ':' || target_kind || ':' ||
           target_ref || ':' || target_root_ref || ':' || member_ref,
           '|')
FROM (SELECT * FROM integrity_subject ORDER BY subject_ref);"
}

apply_integrity()
{
    before_serialized=$(serialized_inventory)
    before=$(printf '%s' "$before_serialized" | sha256sum |
        awk '{ print $1 }')
    case "$assertion" in
        BC11_FINDING_CROSS_LINK|BC11_SILENT_CROSS_LINK)
            validation=validation-cross
            [ "$mode" = mutant-detect-missing-cross-link-finding ] || sql "
INSERT INTO integrity_finding
SELECT '$validation',1,'cross-linked-root',source_root_ref,target_root_ref
FROM integrity_subject
WHERE target_kind='root' AND target_root_ref != source_root_ref;"
            [ "$mode" != mutant-detect-silent-cross-link-repair ] || sql "
DELETE FROM integrity_subject WHERE subject_ref='cross-link-1';"
            ;;
        BC11_FINDING_DANGLING|BC11_SILENT_DANGLING)
            validation=validation-dangling
            [ "$mode" = mutant-detect-missing-dangling-finding ] || sql "
INSERT INTO integrity_finding
SELECT '$validation',
       CASE target_kind WHEN 'result' THEN 1 ELSE 2 END,
       'dangling-' || target_kind,source_root_ref,target_ref
FROM integrity_subject
WHERE (target_kind='result' AND NOT EXISTS (
         SELECT 1 FROM result_output r
         WHERE r.result_ref=integrity_subject.target_ref
       ))
   OR (target_kind='view' AND NOT EXISTS (
         SELECT 1 FROM view_output v
         WHERE v.view_ref=integrity_subject.target_ref
       ))
ORDER BY subject_ref;"
            [ "$mode" != mutant-detect-silent-dangling-repair ] || sql "
DELETE FROM integrity_subject
WHERE subject_ref IN ('dangling-result-1','dangling-view-1');"
            ;;
        *) exit 2 ;;
    esac
    after_serialized=$(serialized_inventory)
    after=$(printf '%s' "$after_serialized" | sha256sum |
        awk '{ print $1 }')
    repair_count=0
    [ "$before" = "$after" ] || repair_count=1
    sql "
INSERT INTO validation_inventory
VALUES ('$validation','$before','$after',$repair_count);"
}

if [ "$operation" = sut-setup-bc11 ]; then
    [ "$mode" = ordinary ] || exit 2
    setup
    printf 'pragma\tforeign-keys\t1\n' >&2
    exit 0
fi

case "$surface:$operation" in
    replay:sut-replay-result) apply_replay ;;
    explanation:sut-explain-result) apply_explanation ;;
    integrity:sut-validate-integrity) apply_integrity ;;
    *) exit 2 ;;
esac

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\trequest-1\troot-1\tdefinition-1\taccepted\t%s\n' \
    "$run" "$namespace" "$scenario" "$assertion" "$surface" \
    "$operation" "$mode" "$nonce"
printf 'pragma\tforeign-keys\t1\n' >&2
