#!/bin/sh
set -eu

[ "$#" -eq 2 ] || exit 2
db=$1
scenario=$2

sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT '$scenario','root','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','root',root_ref,'request-ref',request_ref,'0001'
FROM root
UNION ALL
SELECT '$scenario','root',root_ref,'status',status,'0001'
FROM root
UNION ALL
SELECT '$scenario','root-ancestry','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','root-ancestry',root_ref,'boundary-kind',boundary_kind,'0001'
FROM root_ancestry
UNION ALL
SELECT '$scenario','root-ancestry',root_ref,'boundary-ref',boundary_ref,'0001'
FROM root_ancestry
UNION ALL
SELECT '$scenario','root-member','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','root-member',
       root_ref || '/' || printf('%04d', ordinal),
       'object-ref',object_ref,'0001'
FROM root_member
UNION ALL
SELECT '$scenario','root-request','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','root-request',request_ref,
       'ancestry-boundary-ref',ancestry_boundary_ref,'0001'
FROM root_request
UNION ALL
SELECT '$scenario','root-request',request_ref,
       'target-root-ref',target_root_ref,'0001'
FROM root_request
UNION ALL
SELECT '$scenario','root-required-member',
       '@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','root-required-member',
       request_ref || '/' || printf('%04d', ordinal),
       'object-ref',object_ref,'0001'
FROM root_required_member
UNION ALL
SELECT '$scenario','source-object','@relation','presence','present','0001'
UNION ALL
SELECT '$scenario','source-object',object_ref,'kind',object_kind,'0001'
FROM source_object
UNION ALL
SELECT '$scenario','source-object',object_ref,'value',logical_value,'0001'
FROM source_object
ORDER BY 1,2,3,4,5,6;
"
printf 'pragma\tforeign-keys\t1\n' >&2
