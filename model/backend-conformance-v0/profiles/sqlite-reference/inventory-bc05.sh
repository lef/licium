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
    SELECT 'result-store','@relation','presence','present'
    UNION ALL
    SELECT 'logical-object',object_ref,'kind',object_kind
      FROM logical_object
    UNION ALL
    SELECT 'closure-request',request_ref,'root-ref',root_ref
      FROM closure_request
    UNION ALL
    SELECT 'closure-request',request_ref,'definition-ref',definition_ref
      FROM closure_request
    UNION ALL
    SELECT 'closure-request',request_ref,'semantics-ref',semantics_ref
      FROM closure_request
    UNION ALL
    SELECT 'closure-request',request_ref,'binding-ref',binding_ref
      FROM closure_request
    UNION ALL
    SELECT 'closure-request',request_ref,'cut-ref',cut_ref
      FROM closure_request
    UNION ALL
    SELECT 'cut-closure',definition_ref || '/' || cut_ref,
           'closure-ref',closure_ref
      FROM cut_closure
    UNION ALL
    SELECT 'dependency-edge',parent_ref || '/' || child_ref,
           'kind',dependency_kind
      FROM dependency_edge
    UNION ALL
    SELECT 'binding-value',binding_ref || '/' || selected_value,
           'selected-value',selected_value
      FROM binding_value
    UNION ALL
    SELECT 'closure-selection',closure_ref || '/' || selected_value,
           'selected-value',selected_value
      FROM closure_selection
    UNION ALL
    SELECT 'ambient-cut',scope_ref,'cut',cut_ref
      FROM ambient_cut
),
numbered AS (
    SELECT role,reference,field,value,
           row_number() OVER (
               PARTITION BY role,reference ORDER BY field,value
           ) AS occurrence
      FROM facts
)
SELECT '$scenario',role,reference,field,value,printf('%04d',occurrence)
  FROM (
    SELECT role,reference,field,value,
           CASE
             WHEN role='closure-request' AND field='root-ref' THEN 1
             WHEN role='closure-request' AND field='definition-ref' THEN 2
             WHEN role='closure-request' AND field='semantics-ref' THEN 3
             WHEN role='closure-request' AND field='binding-ref' THEN 4
             WHEN role='closure-request' AND field='cut-ref' THEN 5
             ELSE occurrence
           END AS occurrence
      FROM numbered
  )
 ORDER BY 1,2,3,4,5,6;
"
printf 'pragma\tforeign-keys\t1\n' >&2
