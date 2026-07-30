#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
correction_guard="$script_dir/correction-guard-bc02.sql"

[ "$#" -eq 9 ] || {
    echo "usage: sut-bc02.sh DB RUN NS ASSERTION CASE OP MODE ATTEMPT NONCE" >&2
    exit 2
}

db=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
operation=$6
mode=$7
attempt=$8
nonce=$9

pragma_receipt()
{
    printf 'pragma\tforeign-keys\t1\n' >&2
}

sql()
{
    sqlite3 -batch -bail -noheader -tabs "$db" \
        "PRAGMA foreign_keys=ON; $1"
}

case "$assertion:$case_id" in
    BC02_COMPLETE_AVAILABLE:case-bc02-complete|\
    BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-missing|\
    BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-substitution)
        ;;
    BC02_HEALTHY_RETRY:case-bc02-incomplete-corrected)
        ;;
    BC02_PARTIAL_RESIDUE:case-bc02-after-root-header|\
    BC02_PARTIAL_RESIDUE:case-bc02-after-root-member|\
    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-header|\
    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-member|\
    BC02_POISONED_RETRY:case-bc02-after-root-header|\
    BC02_POISONED_RETRY:case-bc02-after-root-member)
        ;;
    *)
        exit 2
        ;;
esac

case "$operation" in
    sut-setup-bc02)
        [ "$mode" = "ordinary" ] && [ "$attempt" = "setup" ] || exit 2
        case "$case_id" in
            case-bc02-complete|case-bc02-after-root-header|\
            case-bc02-after-root-member)
                source_sql="
INSERT INTO source_object VALUES ('object-a','pair','value-a');
INSERT INTO source_object VALUES ('object-b','pair','value-b');
INSERT INTO source_object VALUES ('object-c','pair','value-c');"
                ;;
            case-bc02-incomplete-missing|case-bc02-incomplete-corrected)
                source_sql="
INSERT INTO source_object VALUES ('object-a','pair','value-a');
INSERT INTO source_object VALUES ('object-b','pair','value-b');"
                ;;
            case-bc02-incomplete-substitution)
                source_sql="
INSERT INTO source_object VALUES ('object-a','pair','value-a');
INSERT INTO source_object VALUES ('object-b','pair','value-b');
INSERT INTO source_object VALUES ('object-x','pair','value-x');"
                ;;
        esac
        sql "
BEGIN IMMEDIATE;
$source_sql
INSERT INTO root_request VALUES ('request-02','root-02','genesis-02');
INSERT INTO root_required_member VALUES ('request-02',1,'object-a');
INSERT INTO root_required_member VALUES ('request-02',2,'object-b');
INSERT INTO root_required_member VALUES ('request-02',3,'object-c');
COMMIT;
"
        printf 'status\tsetup\taccepted\t%s\n' "$assertion"
        pragma_receipt
        ;;
    sut-form-root)
        case "$case_id:$attempt" in
            case-bc02-complete:attempt-complete|\
            case-bc02-incomplete-missing:attempt-initial|\
            case-bc02-incomplete-corrected:attempt-initial|\
            case-bc02-incomplete-substitution:attempt-initial|\
            case-bc02-after-root-header:attempt-fault-header|\
            case-bc02-after-root-member:attempt-fault-member)
                ;;
            *)
                exit 2
                ;;
        esac
        case "$mode" in
            ordinary)
                if [ "$case_id" = "case-bc02-complete" ]; then
                    sql "
BEGIN IMMEDIATE;
INSERT INTO root VALUES ('root-02','forming','request-02');
INSERT INTO root_member
SELECT 'root-02', required.ordinal, required.object_ref
FROM root_required_member AS required
JOIN source_object AS source
  ON source.object_ref = required.object_ref
WHERE required.request_ref = 'request-02'
ORDER BY required.ordinal;
INSERT INTO root_ancestry
SELECT 'root-02', request.ancestry_boundary_ref, 'genesis'
FROM root_request AS request
WHERE request.request_ref = 'request-02';
UPDATE root SET status='complete' WHERE root_ref='root-02';
COMMIT;
"
                    printf '%s\t%s\t%s\t%s\t%s\t%s\tcomplete\trequest-02\troot-02\t3\t3\t3\tgenesis-02\tcommitted\t%s\t-\t-\t-\t-\n' \
                        "$run" "$namespace" "$assertion" "$case_id" \
                        "$attempt" "$operation" "$nonce"
                else
                    set +e
                    error=$(
                        printf '%s\n' "
PRAGMA foreign_keys=ON;
BEGIN IMMEDIATE;
INSERT INTO root VALUES ('root-02','forming','request-02');
INSERT INTO root_member
SELECT 'root-02', required.ordinal, required.object_ref
FROM root_required_member AS required
JOIN source_object AS source
  ON source.object_ref = required.object_ref
WHERE required.request_ref = 'request-02'
ORDER BY required.ordinal;
INSERT INTO root_ancestry
SELECT 'root-02', request.ancestry_boundary_ref, 'genesis'
FROM root_request AS request
WHERE request.request_ref = 'request-02';
UPDATE root SET status='complete' WHERE root_ref='root-02';
ROLLBACK;
" | sqlite3 -batch -noheader -tabs "$db" 2>&1
                    )
                    status=$?
                    set -e
                    [ "$status" -ne 0 ] || exit 1
                    case "$error" in
                        *LICIUM_BC02_ROOT_INCOMPLETE*) ;;
                        *) exit 1 ;;
                    esac
                    counts=$(
                        sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT
  (SELECT COUNT(*) FROM root_required_member
   WHERE request_ref='request-02'),
  (SELECT COUNT(*)
   FROM root_required_member AS required
   JOIN source_object AS source
     ON source.object_ref=required.object_ref
   WHERE required.request_ref='request-02'),
  (SELECT object_ref
   FROM root_required_member
   WHERE request_ref='request-02'
     AND object_ref NOT IN (SELECT object_ref FROM source_object)
   ORDER BY ordinal
   LIMIT 1);
"
                    )
                    expected_count=$(printf '%s\n' "$counts" | cut -f1)
                    input_count=$(printf '%s\n' "$counts" | cut -f2)
                    missing_ref=$(printf '%s\n' "$counts" | cut -f3)
                    printf '%s\t%s\t%s\t%s\t%s\t%s\troot-unavailable\trequest-02\troot-02\t%s\t%s\t0\t-\trolled-back\t%s\terror-bc02-incomplete\tLICIUM_BC02_ROOT_INCOMPLETE\t%s\tmissing-required-member\n' \
                        "$run" "$namespace" "$assertion" "$case_id" \
                        "$attempt" "$operation" "$expected_count" \
                        "$input_count" "$nonce" "$missing_ref"
                fi
                ;;
            mutant-complete-unavailable|mutant-complete-as-unavailable)
                printf '%s\t%s\t%s\t%s\t%s\t%s\troot-unavailable\trequest-02\troot-02\t3\t3\t0\t-\trolled-back\t%s\t-\t-\troot-02\t%s\n' \
                    "$run" "$namespace" "$assertion" "$case_id" "$attempt" \
                    "$operation" "$nonce" "$mode"
                ;;
            mutant-incomplete-as-complete)
                [ "$case_id" = "case-bc02-incomplete-missing" ] || exit 2
                sql "
BEGIN IMMEDIATE;
INSERT INTO root VALUES ('root-02','complete','request-02');
INSERT INTO root_member VALUES ('root-02',1,'object-a');
INSERT INTO root_member VALUES ('root-02',2,'object-b');
INSERT INTO root_ancestry
VALUES ('root-02','genesis-02','genesis');
COMMIT;
"
                printf '%s\t%s\t%s\t%s\t%s\t%s\tcomplete\trequest-02\troot-02\t3\t2\t2\tgenesis-02\tcommitted\t%s\t-\t-\tobject-c\tmutant-incomplete-as-complete\n' \
                    "$run" "$namespace" "$assertion" "$case_id" "$attempt" \
                    "$operation" "$nonce"
                ;;
            mutant-count-only-completeness)
                [ "$case_id" = "case-bc02-incomplete-substitution" ] ||
                    exit 2
                sql "
BEGIN IMMEDIATE;
INSERT INTO root VALUES ('root-02','complete','request-02');
INSERT INTO root_member VALUES ('root-02',1,'object-a');
INSERT INTO root_member VALUES ('root-02',2,'object-b');
INSERT INTO root_member VALUES ('root-02',3,'object-x');
INSERT INTO root_ancestry
VALUES ('root-02','genesis-02','genesis');
COMMIT;
"
                printf '%s\t%s\t%s\t%s\t%s\t%s\tcomplete\trequest-02\troot-02\t3\t3\t3\tgenesis-02\tcommitted\t%s\t-\t-\t-\tmutant-count-only-completeness\n' \
                    "$run" "$namespace" "$assertion" "$case_id" "$attempt" \
                    "$operation" "$nonce"
                ;;
            fault-injected)
                case "$case_id:$attempt" in
                    case-bc02-after-root-header:attempt-fault-header)
                        hook=hook-bc02-after-root-header
                        phase=after-root-header
                        member_sql=
                        ;;
                    case-bc02-after-root-member:attempt-fault-member)
                        hook=hook-bc02-after-root-member
                        phase=after-root-member
                        member_sql="
INSERT INTO root_member VALUES ('root-02',1,'object-a');"
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                config=$(
                    sqlite3 -batch -bail -noheader -tabs "$db" "
PRAGMA foreign_keys=ON;
SELECT implementation_revision,activation_sha256,error_id,error_marker,
       error_literal,transient_header_count,transient_member_count,
       transient_ancestry_count
FROM fault_configuration
WHERE run_id='$run'
  AND namespace_id='$namespace'
  AND assertion_id='$assertion'
  AND case_id='$case_id'
  AND attempt_id='$attempt'
  AND operation_id='$operation'
  AND hook_id='$hook'
  AND phase='$phase'
  AND nonce='$nonce';
"
                )
                [ -n "$config" ] || exit 1
                [ "$(printf '%s\n' "$config" | wc -l | tr -d ' ')" -eq 1 ] ||
                    exit 1
                revision=$(printf '%s\n' "$config" | cut -f1)
                activation_sha=$(printf '%s\n' "$config" | cut -f2)
                error_id=$(printf '%s\n' "$config" | cut -f3)
                marker=$(printf '%s\n' "$config" | cut -f4)
                literal=$(printf '%s\n' "$config" | cut -f5)
                header_count=$(printf '%s\n' "$config" | cut -f6)
                member_count=$(printf '%s\n' "$config" | cut -f7)
                ancestry_count=$(printf '%s\n' "$config" | cut -f8)
                case "$case_id" in
                    case-bc02-after-root-header)
                        [ "$error_id" = "error-bc02-after-root-header" ] &&
                            [ "$marker" = "LICIUM_BC02_FAULT_AFTER_ROOT_HEADER" ] &&
                            [ "$header_count:$member_count:$ancestry_count" = "1:0:0" ] ||
                            exit 1
                        ;;
                    case-bc02-after-root-member)
                        [ "$error_id" = "error-bc02-after-root-member" ] &&
                            [ "$marker" = "LICIUM_BC02_FAULT_AFTER_ROOT_MEMBER" ] &&
                            [ "$header_count:$member_count:$ancestry_count" = "1:1:0" ] ||
                            exit 1
                        ;;
                esac
                expected_literal="$marker|$run|$namespace|$assertion|$case_id|$attempt|$operation|$hook|$phase|$nonce|$revision|$activation_sha|$header_count|$member_count|$ancestry_count"
                [ "$literal" = "$expected_literal" ] || exit 1
                tmp=$(mktemp -d)
                trap 'rm -rf "$tmp"' EXIT HUP INT TERM
                set +e
                sqlite3 -batch -noheader -tabs "$db" >"$tmp/stdout" \
                    2>"$tmp/stderr" <<EOF
PRAGMA foreign_keys=ON;
BEGIN IMMEDIATE;
INSERT INTO fault_activation VALUES (
    '$run','$namespace','$assertion','$case_id','$attempt','$operation',
    '$hook','$phase','$nonce','$revision','$activation_sha'
);
INSERT INTO root VALUES ('root-02','forming','request-02');
$member_sql
SELECT 'health','ok',
       (SELECT COUNT(*) FROM fault_activation),
       (SELECT COUNT(*) FROM root WHERE root_ref='root-02'),
       (SELECT COUNT(*) FROM root_member WHERE root_ref='root-02'),
       (SELECT COUNT(*) FROM root_ancestry WHERE root_ref='root-02');
EOF
                sqlite_status=$?
                set -e
                [ "$sqlite_status" -ne 0 ] || exit 1
                [ "$(cat "$tmp/stdout")" = "health	ok	0	0	0	0" ] ||
                    exit 1
                [ "$(awk -v literal="$literal" '
                    index($0, literal) { count++ }
                    END { print count + 0 }
                ' "$tmp/stderr")" -eq 1 ] ||
                    exit 1
                raw_stderr_sha=$(
                    sha256sum "$tmp/stderr" | awk '{ print $1 }'
                )
                parsed_literal_sha=$(
                    printf '%s\n' "$literal" | sha256sum | awk '{ print $1 }'
                )
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\t%s\t%s\t%s\tok\t%s\t%s\t%s\t%s\tinjected-rollback\n' \
                    "$run" "$namespace" "$assertion" "$case_id" "$attempt" \
                    "$operation" "$hook" "$phase" "$nonce" "$revision" \
                    "$activation_sha" "$header_count" "$member_count" \
                    "$ancestry_count" "$error_id" "$marker" \
                    "$raw_stderr_sha" "$parsed_literal_sha"
                cat "$tmp/stderr" >&2
                pragma_receipt
                exit 70
                ;;
            *)
                exit 2
                ;;
        esac
        pragma_receipt
        ;;
    sut-correct-root-input)
        [ "$case_id" = "case-bc02-incomplete-corrected" ] &&
            [ "$attempt" = "correction-correction-02" ] || exit 2
        case "$mode" in
            ordinary)
                correction_mutation=
                ;;
            mutant-correction-cleans-root)
                correction_mutation="
             DELETE FROM root WHERE root_ref='does-not-exist';"
                ;;
            mutant-correction-forbidden-write)
                correction_mutation="
             UPDATE root_request
             SET target_root_ref=target_root_ref
             WHERE request_ref='request-02';"
                ;;
            *)
                exit 2
                ;;
        esac
        sqlite3 -batch -bail -noheader -tabs "$db" \
            ".read $correction_guard" \
            ".trace --plain stderr" \
            "PRAGMA foreign_keys=ON;
             BEGIN IMMEDIATE;
$correction_mutation
             INSERT INTO source_object
             VALUES ('object-c','pair','value-c');
             COMMIT;"
        printf '%s\t%s\t%s\t%s\t%s\t%s\tapplied\tobject-c\trequest-02\troot-02\t%s\n' \
            "$run" "$namespace" "$assertion" "$case_id" "$attempt" \
            "$operation" "$nonce"
        pragma_receipt
        ;;
    sut-retry-root)
        [ "$attempt" = "attempt-retry" ] || exit 2
        case "$assertion:$case_id" in
            BC02_HEALTHY_RETRY:case-bc02-incomplete-corrected|\
            BC02_PARTIAL_RESIDUE:case-bc02-after-root-header|\
            BC02_PARTIAL_RESIDUE:case-bc02-after-root-member|\
            BC02_ROLLBACK_COMPLETE:case-bc02-after-root-header|\
            BC02_ROLLBACK_COMPLETE:case-bc02-after-root-member|\
            BC02_POISONED_RETRY:case-bc02-after-root-header|\
            BC02_POISONED_RETRY:case-bc02-after-root-member)
                ;;
            *)
                exit 2
                ;;
        esac
        case "$mode" in
        ordinary)
            sql "
BEGIN IMMEDIATE;
INSERT INTO root VALUES ('root-02','forming','request-02');
INSERT INTO root_member
SELECT 'root-02', required.ordinal, required.object_ref
FROM root_required_member AS required
JOIN source_object AS source
  ON source.object_ref = required.object_ref
WHERE required.request_ref = 'request-02'
ORDER BY required.ordinal;
INSERT INTO root_ancestry
SELECT 'root-02', request.ancestry_boundary_ref, 'genesis'
FROM root_request AS request
WHERE request.request_ref = 'request-02';
UPDATE root SET status='complete' WHERE root_ref='root-02';
COMMIT;
"
            printf '%s\t%s\t%s\t%s\t%s\t%s\tcomplete\trequest-02\troot-02\t3\t3\t3\tgenesis-02\tcommitted\t%s\t-\t-\t-\t-\n' \
                "$run" "$namespace" "$assertion" "$case_id" "$attempt" \
                "$operation" "$nonce"
            ;;
        mutant-retry-rejected|mutant-poisoned-retry)
            printf '%s\t%s\t%s\t%s\t%s\t%s\troot-unavailable\trequest-02\troot-02\t3\t3\t0\t-\trolled-back\t%s\t-\t-\troot-02\t%s\n' \
                "$run" "$namespace" "$assertion" "$case_id" "$attempt" \
                "$operation" "$nonce" "$mode"
            ;;
        mutant-partial-residue)
            [ "$assertion" = "BC02_PARTIAL_RESIDUE" ] || exit 2
            sql "
BEGIN IMMEDIATE;
INSERT INTO root VALUES ('root-02','forming','request-02');
INSERT INTO root_member VALUES ('root-02',1,'object-a');
COMMIT;
"
            printf '%s\t%s\t%s\t%s\t%s\t%s\tpartial\trequest-02\troot-02\t3\t3\t1\t-\tcommitted\t%s\t-\t-\t-\tmutant-partial-residue\n' \
                "$run" "$namespace" "$assertion" "$case_id" "$attempt" \
                "$operation" "$nonce"
            ;;
        mutant-incomplete-rollback)
            [ "$assertion" = "BC02_ROLLBACK_COMPLETE" ] || exit 2
            sql "
BEGIN IMMEDIATE;
INSERT INTO root VALUES ('root-02','forming','request-02');
COMMIT;
"
            printf '%s\t%s\t%s\t%s\t%s\t%s\tpartial\trequest-02\troot-02\t3\t3\t0\t-\tcommitted\t%s\t-\t-\t-\tmutant-incomplete-rollback\n' \
                "$run" "$namespace" "$assertion" "$case_id" "$attempt" \
                "$operation" "$nonce"
            ;;
        *)
            exit 2
            ;;
        esac
        pragma_receipt
        ;;
    *)
        exit 2
        ;;
esac
