#!/bin/sh
set -eu

[ "$#" -eq 11 ] || {
    echo "usage: configure-fault-bc02.sh DB RUN NS ASSERTION CASE HOOK PHASE ATTEMPT NONCE REVISION ACTIVATION_SHA" >&2
    exit 2
}

db=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
hook=$6
phase=$7
attempt=$8
nonce=$9
revision=${10}
activation_sha=${11}

token()
{
    case "$1" in
        ''|*[!a-zA-Z0-9._-]*) return 1 ;;
        *) return 0 ;;
    esac
}

for value in "$run" "$namespace" "$assertion" "$case_id" "$hook" "$phase" \
    "$attempt" "$nonce" "$revision"
do
    token "$value" || exit 2
done
case "$activation_sha" in
    *[!0-9a-f]*|'') exit 2 ;;
esac
[ "${#activation_sha}" -eq 64 ] || exit 2

operation=sut-form-root
case "$assertion:$case_id:$hook:$phase:$attempt" in
    BC02_PARTIAL_RESIDUE:case-bc02-after-root-header:hook-bc02-after-root-header:after-root-header:attempt-fault-header|\
    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-header:hook-bc02-after-root-header:after-root-header:attempt-fault-header|\
    BC02_POISONED_RETRY:case-bc02-after-root-header:hook-bc02-after-root-header:after-root-header:attempt-fault-header)
        trigger=trigger-bc02-after-root-header
        error_id=error-bc02-after-root-header
        marker=LICIUM_BC02_FAULT_AFTER_ROOT_HEADER
        header_count=1
        member_count=0
        ancestry_count=0
        event="AFTER INSERT ON root"
        subject="NEW.root_ref='root-02' AND NEW.request_ref='request-02' AND NEW.status='forming'"
        ;;
    BC02_PARTIAL_RESIDUE:case-bc02-after-root-member:hook-bc02-after-root-member:after-root-member:attempt-fault-member|\
    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-member:hook-bc02-after-root-member:after-root-member:attempt-fault-member|\
    BC02_POISONED_RETRY:case-bc02-after-root-member:hook-bc02-after-root-member:after-root-member:attempt-fault-member)
        trigger=trigger-bc02-after-root-member
        error_id=error-bc02-after-root-member
        marker=LICIUM_BC02_FAULT_AFTER_ROOT_MEMBER
        header_count=1
        member_count=1
        ancestry_count=0
        event="AFTER INSERT ON root_member"
        subject="NEW.root_ref='root-02' AND NEW.ordinal=1 AND NEW.object_ref='object-a'"
        ;;
    *)
        exit 2
        ;;
esac

literal="$marker|$run|$namespace|$assertion|$case_id|$attempt|$operation|$hook|$phase|$nonce|$revision|$activation_sha|$header_count|$member_count|$ancestry_count"
activation_match="EXISTS(SELECT 1 FROM fault_activation WHERE run_id='$run' AND namespace_id='$namespace' AND assertion_id='$assertion' AND case_id='$case_id' AND attempt_id='$attempt' AND operation_id='$operation' AND hook_id='$hook' AND phase='$phase' AND nonce='$nonce' AND implementation_revision='$revision' AND activation_sha256='$activation_sha')"
shape_match="(SELECT COUNT(*) FROM root WHERE root_ref='root-02')=$header_count AND (SELECT COUNT(*) FROM root_member WHERE root_ref='root-02')=$member_count AND (SELECT COUNT(*) FROM root_ancestry WHERE root_ref='root-02')=$ancestry_count"
predicate="$subject AND $activation_match AND $shape_match"
ddl="CREATE TRIGGER \"$trigger\" $event WHEN $predicate BEGIN SELECT RAISE(ROLLBACK, '$literal'); END;"

ddl_sha=$(printf '%s\n' "$ddl" | sha256sum | awk '{ print $1 }')
literal_sha=$(printf '%s\n' "$literal" | sha256sum | awk '{ print $1 }')
predicate_sha=$(printf '%s\n' "$predicate" | sha256sum | awk '{ print $1 }')

sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
BEGIN IMMEDIATE;
INSERT INTO fault_configuration VALUES (
    '$trigger','$run','$namespace','$assertion','$case_id','$attempt',
    '$operation','$hook','$phase','$nonce','$revision','$activation_sha',
    '$error_id','$marker','$literal',$header_count,$member_count,$ancestry_count
);
$ddl
COMMIT;
"

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tconfigured\n' \
    "$run" "$namespace" "$assertion" "$case_id" "$hook" "$phase" "$nonce" \
    "$revision" "$activation_sha" "$trigger" "$ddl_sha" "$literal_sha" \
    "$predicate_sha"
printf 'pragma\tforeign-keys\t1\n' >&2
