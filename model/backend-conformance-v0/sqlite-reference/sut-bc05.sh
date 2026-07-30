#!/bin/sh
set -eu

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc05.sh DB RUN NS SCENARIO CASE OP MODE OCCURRENCE NONCE" >&2
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
    missing_role=$2
    request=$3
    pinned_cut=$4
    selected_value=$5
    ambient=$6
    effect=$7
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$scenario" "$case_id" "$operation" \
        "$outcome" "$missing_role" "$request" "$pinned_cut" \
        "$selected_value" "$ambient" "$effect" "$nonce"
    printf 'pragma\tforeign-keys\t1\n' >&2
}

seed_common()
{
    request=$1
    root=$2
    definition=$3
    semantics=$4
    binding=$5
    leaf=$6
    sql "
BEGIN IMMEDIATE;
INSERT INTO logical_object VALUES ('$root','root','root-payload');
INSERT INTO logical_object
    VALUES ('$definition','definition','definition-payload');
INSERT INTO logical_object
    VALUES ('$semantics','semantics','semantics-payload');
INSERT INTO logical_object VALUES ('$binding','binding','binding-payload');
INSERT INTO logical_object
    VALUES ('dependency-direct','dependency','direct-payload');
INSERT INTO logical_object
    VALUES ('$leaf','dependency','leaf-payload');
INSERT INTO closure_request VALUES
    ('$request','$root','$definition','$semantics','$binding','cut-a');
INSERT INTO cut_closure VALUES ('$definition','cut-a','closure-a');
INSERT INTO dependency_edge
    VALUES ('closure-a','dependency-direct','direct');
INSERT INTO dependency_edge
    VALUES ('dependency-direct','$leaf','transitive');
INSERT INTO binding_value
    VALUES ('$binding','department:engineering');
INSERT INTO closure_selection
    VALUES ('closure-a','department:engineering');
INSERT INTO ambient_cut VALUES ('scope-main','cut-a');
COMMIT;"
}

seed_advance()
{
    request=$1
    sql "
BEGIN IMMEDIATE;
INSERT INTO logical_object VALUES
    ('root-a','root','root-payload'),
    ('definition-a','definition','definition-payload'),
    ('semantics-a','semantics','semantics-payload'),
    ('bindings-main','binding','binding-payload'),
    ('dependency-direct-a','dependency','direct-a-payload'),
    ('dependency-leaf-a','dependency','leaf-a-payload'),
    ('dependency-direct-b','dependency','direct-b-payload'),
    ('dependency-leaf-b','dependency','leaf-b-payload');
INSERT INTO closure_request VALUES
    ('$request','root-a','definition-a','semantics-a',
     'bindings-main','cut-a');
INSERT INTO cut_closure VALUES
    ('definition-a','cut-a','closure-a'),
    ('definition-a','cut-b','closure-b');
INSERT INTO dependency_edge VALUES
    ('closure-a','dependency-direct-a','direct'),
    ('dependency-direct-a','dependency-leaf-a','transitive'),
    ('closure-b','dependency-direct-b','direct'),
    ('dependency-direct-b','dependency-leaf-b','transitive');
INSERT INTO binding_value
    VALUES ('bindings-main','department:engineering');
INSERT INTO closure_selection VALUES
    ('closure-a','department:engineering'),
    ('closure-b','department:security');
INSERT INTO ambient_cut VALUES ('scope-main','cut-a');
COMMIT;"
}

seed_empty_missing()
{
    sql "
BEGIN IMMEDIATE;
INSERT INTO logical_object VALUES
    ('root-a','root','root-payload'),
    ('definition-empty','definition','definition-empty-payload'),
    ('semantics-a','semantics','semantics-payload'),
    ('bindings-empty','binding','binding-empty-payload'),
    ('dependency-direct','dependency','direct-payload'),
    ('dependency-leaf','dependency','leaf-payload');
INSERT INTO closure_request VALUES
    ('request-empty','root-a','definition-empty','semantics-a',
     'bindings-empty','cut-a'),
    ('request-missing','root-a','definition-empty','semantics-a',
     'bindings-missing','cut-a');
INSERT INTO cut_closure
    VALUES ('definition-empty','cut-a','closure-empty-a');
INSERT INTO dependency_edge VALUES
    ('closure-empty-a','dependency-direct','direct'),
    ('dependency-direct','dependency-leaf','transitive');
INSERT INTO ambient_cut VALUES ('scope-main','cut-a');
COMMIT;"
}

resolve_row()
{
    request=$1
    sql "
WITH
r AS (
    SELECT * FROM closure_request WHERE request_ref='$request'
),
c AS (
    SELECT cc.closure_ref
    FROM r JOIN cut_closure cc
      ON cc.definition_ref=r.definition_ref AND cc.cut_ref=r.cut_ref
),
d AS (
    SELECT e.child_ref
    FROM c JOIN dependency_edge e
      ON e.parent_ref=c.closure_ref AND e.dependency_kind='direct'
    ORDER BY e.child_ref LIMIT 1
),
t AS (
    SELECT e.child_ref
    FROM d JOIN dependency_edge e
      ON e.parent_ref=d.child_ref AND e.dependency_kind='transitive'
    ORDER BY e.child_ref LIMIT 1
),
resolved AS (
    SELECT
      CASE
        WHEN NOT EXISTS (
          SELECT 1 FROM r JOIN logical_object o
            ON o.object_ref=r.root_ref AND o.object_kind='root'
        ) THEN 'root'
        WHEN NOT EXISTS (
          SELECT 1 FROM r JOIN logical_object o
            ON o.object_ref=r.definition_ref
           AND o.object_kind='definition'
        ) THEN 'definition'
        WHEN NOT EXISTS (
          SELECT 1 FROM r JOIN logical_object o
            ON o.object_ref=r.semantics_ref
           AND o.object_kind='semantics'
        ) THEN 'semantics'
        WHEN NOT EXISTS (
          SELECT 1 FROM r JOIN logical_object o
            ON o.object_ref=r.binding_ref AND o.object_kind='binding'
        ) THEN 'binding'
        WHEN NOT EXISTS (
          SELECT 1 FROM d JOIN logical_object o
            ON o.object_ref=d.child_ref AND o.object_kind='dependency'
        ) OR NOT EXISTS (
          SELECT 1 FROM t JOIN logical_object o
            ON o.object_ref=t.child_ref AND o.object_kind='dependency'
        ) THEN 'transitive-dependency'
        ELSE '-'
      END AS missing_role
)
SELECT
  CASE
    WHEN missing_role != '-' THEN 'unavailable'
    WHEN NOT EXISTS (
      SELECT 1 FROM r JOIN binding_value b
        ON b.binding_ref=r.binding_ref
    ) THEN 'complete-empty'
    ELSE 'complete'
  END,
  missing_role,
  COALESCE((SELECT cut_ref FROM r),'-'),
  COALESCE((
    SELECT s.selected_value FROM c
    JOIN closure_selection s USING (closure_ref)
    ORDER BY s.selected_value LIMIT 1
  ),'-'),
  COALESCE((
    SELECT cut_ref FROM ambient_cut WHERE scope_ref='scope-main'
  ),'-')
FROM resolved;"
}

case "$operation" in
    sut-setup-bc05)
        [ "$mode" = ordinary ] && [ "$occurrence" = setup ] || exit 2
        case "$case_id" in
            case-bc05-ambient)
                seed_advance request-ambient
                ;;
            case-bc05-binding)
                seed_common request-binding-missing root-a definition-a \
                    semantics-a bindings-missing dependency-leaf
                sql "BEGIN IMMEDIATE;
DELETE FROM binding_value
 WHERE binding_ref='bindings-missing';
DELETE FROM logical_object
 WHERE object_ref='bindings-missing';
COMMIT;"
                ;;
            case-bc05-complete)
                seed_common request-complete root-a definition-a \
                    semantics-a bindings-main dependency-leaf
                ;;
            case-bc05-definition)
                seed_common request-definition-missing root-a \
                    definition-missing semantics-a bindings-main \
                    dependency-leaf
                sql "BEGIN IMMEDIATE;
DELETE FROM logical_object
 WHERE object_ref='definition-missing';
COMMIT;"
                ;;
            case-bc05-empty)
                seed_empty_missing
                ;;
            case-bc05-cut)
                seed_advance request-cut-a
                ;;
            case-bc05-root)
                seed_common request-root-missing root-missing \
                    definition-a semantics-a bindings-main dependency-leaf
                sql "BEGIN IMMEDIATE;
DELETE FROM logical_object WHERE object_ref='root-missing';
COMMIT;"
                ;;
            case-bc05-semantics)
                seed_common request-semantics-missing root-a definition-a \
                    semantics-missing bindings-main dependency-leaf
                sql "BEGIN IMMEDIATE;
DELETE FROM logical_object
 WHERE object_ref='semantics-missing';
COMMIT;"
                ;;
            case-bc05-transitive)
                seed_common request-transitive-missing root-a definition-a \
                    semantics-a bindings-main dependency-missing
                sql "BEGIN IMMEDIATE;
DELETE FROM logical_object
 WHERE object_ref='dependency-missing';
COMMIT;"
                ;;
            *)
                exit 2
                ;;
        esac
        receipt accepted - - - - - setup
        ;;
    sut-resolve-pinned-closure|sut-advance-and-resolve)
        [ "$occurrence" = action ] || exit 2
        case "$operation:$case_id" in
            sut-advance-and-resolve:case-bc05-ambient)
                request='request-ambient'
                ;;
            sut-advance-and-resolve:case-bc05-cut)
                request='request-cut-a'
                ;;
            sut-resolve-pinned-closure:case-bc05-binding)
                request='request-binding-missing'
                ;;
            sut-resolve-pinned-closure:case-bc05-complete)
                request='request-complete'
                ;;
            sut-resolve-pinned-closure:case-bc05-definition)
                request='request-definition-missing'
                ;;
            sut-resolve-pinned-closure:case-bc05-root)
                request='request-root-missing'
                ;;
            sut-resolve-pinned-closure:case-bc05-semantics)
                request='request-semantics-missing'
                ;;
            sut-resolve-pinned-closure:case-bc05-transitive)
                request='request-transitive-missing'
                ;;
            sut-resolve-pinned-closure:case-bc05-empty)
                empty_row=$(resolve_row request-empty)
                missing_row=$(resolve_row request-missing)
                empty_outcome=${empty_row%%	*}
                missing_outcome=${missing_row%%	*}
                missing_detail=${missing_row#*	}
                missing_role=${missing_detail%%	*}
                case "$mode" in
                    ordinary)
                        ;;
                    mutant-missing-as-empty)
                        missing_outcome='complete-empty'
                        missing_role=collapsed
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                receipt "$empty_outcome+$missing_outcome" "$missing_role" \
                    request-empty+request-missing cut-a - cut-a unchanged
                exit
                ;;
            *)
                exit 2
                ;;
        esac

        effect=unchanged
        if [ "$operation" = sut-advance-and-resolve ]; then
            sql "BEGIN IMMEDIATE;
UPDATE ambient_cut SET cut_ref='cut-b' WHERE scope_ref='scope-main';
COMMIT;"
            effect='ambient-only'
        fi
        row=$(resolve_row "$request")
IFS='	' read -r outcome missing_role pinned_cut selected ambient <<EOF
$row
EOF
        [ "$outcome" != unavailable ] || selected=-

        case "$mode" in
            ordinary)
                ;;
            mutant-ambient-closure-substitution)
                [ "$case_id" = case-bc05-ambient ] || exit 2
                selected=department:security
                missing_role='ambient-substitution'
                ;;
            mutant-binding-omission)
                [ "$case_id" = case-bc05-binding ] || exit 2
                outcome=complete
                missing_role=-
                selected=department:engineering
                ;;
            mutant-incomplete-closure-success)
                [ "$case_id" = case-bc05-complete ] || exit 2
                selected=incomplete-closure
                missing_role=transitive-dependency
                ;;
            mutant-definition-omission)
                [ "$case_id" = case-bc05-definition ] || exit 2
                outcome=complete
                missing_role=-
                ;;
            mutant-knowledge-cut-drift)
                [ "$case_id" = case-bc05-cut ] || exit 2
                pinned_cut=cut-b
                selected=department:security
                missing_role='ambient-substitution'
                ;;
            mutant-root-omission)
                [ "$case_id" = case-bc05-root ] || exit 2
                outcome=complete
                missing_role=-
                ;;
            mutant-semantics-omission)
                [ "$case_id" = case-bc05-semantics ] || exit 2
                outcome=complete
                missing_role=-
                ;;
            mutant-transitive-omission)
                [ "$case_id" = case-bc05-transitive ] || exit 2
                outcome=complete
                missing_role=-
                ;;
            *)
                exit 2
                ;;
        esac
        receipt "$outcome" "$missing_role" "$request" "$pinned_cut" \
            "$selected" "$ambient" "$effect"
        ;;
    *)
        exit 2
        ;;
esac
