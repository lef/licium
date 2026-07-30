#!/bin/sh
set -eu

[ "$#" -eq 4 ] || exit 2
db=$1
scenario=$2
case_id=$3
receipt=$4

[ -f "$receipt" ] && [ ! -L "$receipt" ] || exit 2

row=$(awk -F '	' '
    NF == 13 && $5 != "sut-setup-bc05" {
        print $6 "\t" $7 "\t" $8 "\t" $9 "\t" $10 "\t" $11 "\t" $12
    }
' "$receipt")
IFS='	' read -r outcome missing_role _request pinned_cut selected ambient effect <<EOF
$row
EOF
[ -n "$outcome" ] && [ -n "$effect" ] || exit 1

query()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

emit()
{
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$scenario" "$1" "$2" "$3" "$4" "$5"
}

object_kind()
{
    value=$(query "
SELECT object_kind FROM logical_object
 WHERE object_ref='$1';")
    if [ -n "$value" ]; then printf '%s\n' "$value"
    else printf '%s\n' missing
    fi
}

binding_state()
{
    ref=$1
    present=$(query "
SELECT count(*) FROM logical_object
 WHERE object_ref='$ref' AND object_kind='binding';")
    if [ "$present" = 0 ]; then
        printf '%s\n' missing
        return
    fi
    members=$(query "
SELECT count(*) FROM binding_value WHERE binding_ref='$ref';")
    if [ "$members" = 0 ]; then printf '%s\n' present-empty
    else printf '%s\n' present-nonempty
    fi
}

dependency_kind()
{
    parent=$1
    child=$2
    query "
SELECT e.dependency_kind
  FROM dependency_edge e
  JOIN logical_object o
    ON o.object_ref=e.child_ref AND o.object_kind='dependency'
 WHERE e.parent_ref='$parent' AND e.child_ref='$child';"
}

result_writes=$(query "SELECT count(*) FROM result_store;")

case "$case_id" in
    case-bc05-ambient)
        before=cut-a
        [ "$missing_role" = ambient-substitution ] &&
            ambient_members=1 || ambient_members=0
        [ "$pinned_cut" = "$ambient" ] &&
            equality=true || equality=false
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 closure-request action cut-ref "$pinned_cut"
        emit raw-003 ambient-cut before scope-main "$before"
        emit raw-004 ambient-cut after scope-main "$ambient"
        emit raw-005 closure-selection after closure-a "$selected"
        emit raw-006 resolved-members after ambient-member-count \
            "$ambient_members"
        emit raw-007 cut-comparison after pinned-vs-ambient "$equality"
        emit raw-008 result-store after write-count "$result_writes"
        ;;
    case-bc05-binding)
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 logical-object after root-a "$(object_kind root-a)"
        emit raw-003 logical-object after definition-a \
            "$(object_kind definition-a)"
        emit raw-004 logical-object after semantics-a \
            "$(object_kind semantics-a)"
        emit raw-005 object-presence after bindings-missing \
            "$(binding_state bindings-missing)"
        emit raw-006 missing-input after bindings-missing binding
        emit raw-007 fallback-resolution after bindings-missing absent
        emit raw-008 result-store after write-count "$result_writes"
        ;;
    case-bc05-complete)
        direct=$(dependency_kind closure-a dependency-direct)
        leaf=$(dependency_kind dependency-direct dependency-leaf)
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 logical-object after root-a "$(object_kind root-a)"
        emit raw-003 logical-object after definition-a \
            "$(object_kind definition-a)"
        emit raw-004 logical-object after semantics-a \
            "$(object_kind semantics-a)"
        emit raw-005 binding-state after bindings-main \
            "$(binding_state bindings-main)"
        emit raw-006 dependency-object after dependency-direct "$direct"
        emit raw-007 dependency-object after dependency-leaf "$leaf"
        emit raw-008 closure-selection after closure-a "$selected"
        emit raw-009 result-store after write-count "$result_writes"
        ;;
    case-bc05-definition)
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 logical-object after root-a "$(object_kind root-a)"
        emit raw-003 object-presence after definition-missing \
            "$(object_kind definition-missing)"
        emit raw-004 logical-object after semantics-a \
            "$(object_kind semantics-a)"
        emit raw-005 binding-state after bindings-main \
            "$(binding_state bindings-main)"
        emit raw-006 missing-input after definition-missing definition
        emit raw-007 fallback-resolution after definition-missing absent
        emit raw-008 result-store after write-count "$result_writes"
        ;;
    case-bc05-empty)
        empty_state=$(binding_state bindings-empty)
        empty_count=$(query "
SELECT count(*) FROM binding_value WHERE binding_ref='bindings-empty';")
        missing_state=$(binding_state bindings-missing)
        empty_outcome=${outcome%%+*}
        missing_outcome=${outcome#*+}
        [ "$empty_outcome" = "$missing_outcome" ] &&
            equality=true || equality=false
        emit raw-001 action-receipt action request-empty "$empty_outcome"
        emit raw-002 binding-state after bindings-empty "$empty_state"
        emit raw-003 closure-selection after request-empty "$empty_count"
        emit raw-004 action-receipt action request-missing "$missing_outcome"
        emit raw-005 object-presence after bindings-missing "$missing_state"
        emit raw-006 closure-selection after request-missing 0
        emit raw-007 empty-missing-comparison after request-pair "$equality"
        emit raw-008 result-store after write-count "$result_writes"
        ;;
    case-bc05-cut)
        closure=$(query "
SELECT closure_ref FROM cut_closure
 WHERE definition_ref='definition-a' AND cut_ref='$pinned_cut';")
        candidate=$(query "
SELECT selected_value FROM closure_selection
 WHERE closure_ref='closure-b' ORDER BY selected_value LIMIT 1;")
        [ "$missing_role" = ambient-substitution ] &&
            ambient_members=1 || ambient_members=0
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 closure-request action cut-ref "$pinned_cut"
        emit raw-003 ambient-cut after scope-main "$ambient"
        emit raw-004 cut-closure after request-cut-a "$closure"
        emit raw-005 closure-selection after closure-a "$selected"
        emit raw-006 closure-selection after closure-b "$candidate"
        emit raw-007 resolved-members after ambient-member-count \
            "$ambient_members"
        emit raw-008 pinned-result after request-cut-a "$selected"
        emit raw-009 result-store after write-count "$result_writes"
        ;;
    case-bc05-root)
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 object-presence after root-missing \
            "$(object_kind root-missing)"
        emit raw-003 logical-object after definition-a \
            "$(object_kind definition-a)"
        emit raw-004 logical-object after semantics-a \
            "$(object_kind semantics-a)"
        emit raw-005 binding-state after bindings-main \
            "$(binding_state bindings-main)"
        emit raw-006 missing-input after root-missing root
        emit raw-007 fallback-resolution after root-missing absent
        emit raw-008 result-store after write-count "$result_writes"
        ;;
    case-bc05-semantics)
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 logical-object after root-a "$(object_kind root-a)"
        emit raw-003 logical-object after definition-a \
            "$(object_kind definition-a)"
        emit raw-004 object-presence after semantics-missing \
            "$(object_kind semantics-missing)"
        emit raw-005 binding-state after bindings-main \
            "$(binding_state bindings-main)"
        emit raw-006 missing-input after semantics-missing semantics
        emit raw-007 fallback-resolution after semantics-missing absent
        emit raw-008 result-store after write-count "$result_writes"
        ;;
    case-bc05-transitive)
        emit raw-001 action-receipt action result "$outcome"
        emit raw-002 logical-object after root-a "$(object_kind root-a)"
        emit raw-003 logical-object after definition-a \
            "$(object_kind definition-a)"
        emit raw-004 logical-object after semantics-a \
            "$(object_kind semantics-a)"
        emit raw-005 binding-state after bindings-main \
            "$(binding_state bindings-main)"
        emit raw-006 dependency-object after dependency-direct \
            "$(dependency_kind closure-a dependency-direct)"
        emit raw-007 object-presence after dependency-missing \
            "$(object_kind dependency-missing)"
        emit raw-008 missing-input after dependency-missing \
            transitive-dependency
        emit raw-009 result-store after write-count "$result_writes"
        ;;
    *)
        exit 2
        ;;
esac
printf 'pragma\tforeign-keys\t1\n' >&2
