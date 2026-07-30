#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
registry="$base_dir/bc02-runtime-artifacts.tsv"
cardinality="$base_dir/bc02-artifact-cardinality.tsv"

[ "$#" -eq 5 ] || {
    echo "usage: verify-bc02-fault-runtime.sh ARTIFACT_DIR RUN NS ASSERTION CASE" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
case_id=$5

fail()
{
    echo "$1" >&2
    exit 1
}

case "$case_id" in
    case-bc02-after-root-header)
        hook=hook-bc02-after-root-header
        phase=after-root-header
        attempt=attempt-fault-header
        trigger=trigger-bc02-after-root-header
        error_id=error-bc02-after-root-header
        error_marker=LICIUM_BC02_FAULT_AFTER_ROOT_HEADER
        header_count=1
        member_count=0
        ;;
    case-bc02-after-root-member)
        hook=hook-bc02-after-root-member
        phase=after-root-member
        attempt=attempt-fault-member
        trigger=trigger-bc02-after-root-member
        error_id=error-bc02-after-root-member
        error_marker=LICIUM_BC02_FAULT_AFTER_ROOT_MEMBER
        header_count=1
        member_count=1
        ;;
    *)
        fail BC02_FAULT_RUNTIME_IDENTITY_INVALID
        ;;
esac

case "$assertion" in
    BC02_PARTIAL_RESIDUE)
        scenario=bc02-partial-residue--"$case_id"
        oracle_id=oracle-bc02-partial-residue
        retry=false
        ;;
    BC02_POISONED_RETRY)
        scenario=bc02-poisoned-retry--"$case_id"
        oracle_id=oracle-bc02-poisoned-retry
        retry=true
        ;;
    BC02_ROLLBACK_COMPLETE)
        scenario=bc02-rollback-complete--"$case_id"
        oracle_id=oracle-bc02-rollback-complete
        retry=false
        ;;
    *)
        fail BC02_FAULT_RUNTIME_IDENTITY_INVALID
        ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

# A runtime result is exactly the registered artifact set.  Database files,
# sidecars, and unregistered evidence are not accepted as hidden inputs.
cut -f1 "$registry" | LC_ALL=C sort > "$tmp/expected-layout"
find "$artifact_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' |
    LC_ALL=C sort > "$tmp/actual-layout"
cmp -s "$tmp/expected-layout" "$tmp/actual-layout" ||
    fail BC02_FAULT_RUNTIME_LAYOUT_INVALID

while IFS='	' read -r name fields cardinality_class kind source; do
    file="$artifact_dir/$name"
    [ -f "$file" ] && [ ! -L "$file" ] ||
        fail BC02_FAULT_REQUIRED_ARTIFACT_MISSING
    [ "$(stat -c '%a' "$file")" = "644" ] ||
        fail BC02_FAULT_RUNTIME_ARTIFACT_MODE_INVALID
    expected_rows=$(awk -F '	' -v scenario="$scenario" -v name="$name" '
        $1 == scenario && $2 == name { print $4 }
    ' "$cardinality")
    [ "$expected_rows" != "" ] ||
        fail BC02_FAULT_RUNTIME_CARDINALITY_MISSING
    [ "$(wc -l < "$file" | tr -d ' ')" = "$expected_rows" ] ||
        fail BC02_FAULT_RUNTIME_ARTIFACT_SHAPE_INVALID
    if [ "$expected_rows" -gt 0 ]; then
        awk -F '	' -v fields="$fields" 'NF != fields { exit 1 }' "$file" ||
            fail BC02_FAULT_RUNTIME_ARTIFACT_SHAPE_INVALID
    fi
done < "$registry"

# Stage inventories are compared with independently frozen fixtures, not only
# with one another.
for stage in setup-before rollback-after; do
    template=$(awk -F '	' -v assertion="$assertion" \
        -v case_id="$case_id" -v stage="$stage" '
        $1 == assertion && $2 == case_id && $3 == stage { print $5 }
    ' "$base_dir/bc02-inventory-map.tsv")
    [ "$template" != "" ] || fail BC02_FAULT_RUNTIME_INVENTORY_INVALID
    sed "s/{scenario}/$scenario/g" "$base_dir/$template" \
        > "$tmp/inventory-$stage.expected"
    cmp -s "$tmp/inventory-$stage.expected" \
        "$artifact_dir/inventory-$stage.tsv" ||
        fail BC02_FAULT_RUNTIME_INVENTORY_INVALID
done
if [ "$assertion" = "BC02_ROLLBACK_COMPLETE" ]; then
    cmp -s "$artifact_dir/inventory-setup-before.tsv" \
        "$artifact_dir/inventory-rollback-after.tsv" ||
        fail BC02_FAULT_ROLLBACK_EQUALITY_INVALID
fi
if [ "$retry" = true ]; then
    template=$(awk -F '	' -v assertion="$assertion" \
        -v case_id="$case_id" '
        $1 == assertion && $2 == case_id && $3 == "retry-after" { print $5 }
    ' "$base_dir/bc02-inventory-map.tsv")
    sed "s/{scenario}/$scenario/g" "$base_dir/$template" \
        > "$tmp/inventory-retry-after.expected"
    cmp -s "$tmp/inventory-retry-after.expected" \
        "$artifact_dir/inventory-retry-after.tsv" ||
        fail BC02_FAULT_RETRY_INVENTORY_INVALID
fi

configuration="$artifact_dir/fault-configuration-receipts.tsv"
activation="$artifact_dir/fault-activation-receipts.tsv"
trigger_receipt="$artifact_dir/fault-trigger-receipts.tsv"
binding="$artifact_dir/evidence-binding-receipts.tsv"
commands="$artifact_dir/command-receipts.tsv"
data_versions="$artifact_dir/data-version-receipts.tsv"
custody="$artifact_dir/observer-custody-receipts.tsv"
resolutions="$artifact_dir/resolution-receipts.tsv"

# Validate the reviewed static fault construction independently from the
# receipt digests emitted by the profile.
IFS='	' read -r c_run c_ns c_assertion c_case c_hook c_phase c_nonce \
    revision activation_sha c_trigger ddl_sha literal_sha predicate_sha \
    configured < "$configuration"
[ "$c_run" = "$run" ] && [ "$c_ns" = "$namespace" ] &&
    [ "$c_assertion" = "$assertion" ] && [ "$c_case" = "$case_id" ] &&
    [ "$c_hook" = "$hook" ] && [ "$c_phase" = "$phase" ] &&
    [ "$c_trigger" = "$trigger" ] && [ "$configured" = configured ] ||
    fail BC02_FAULT_CONFIGURATION_INVALID
[ "$revision" = \
    "$(sha256sum "$base_dir/sqlite-reference/sut-bc02.sh" |
        awk '{ print $1 }')" ] ||
    fail BC02_FAULT_IMPLEMENTATION_REVISION_INVALID
for digest in "$activation_sha" "$ddl_sha" "$literal_sha" "$predicate_sha"; do
    case "$digest" in
        *[!0-9a-f]*|'') fail BC02_FAULT_CONFIGURATION_INVALID ;;
    esac
    [ "${#digest}" -eq 64 ] || fail BC02_FAULT_CONFIGURATION_INVALID
done

operation=sut-form-root
ancestry_count=0
literal="$error_marker|$run|$namespace|$assertion|$case_id|$attempt|$operation|$hook|$phase|$c_nonce|$revision|$activation_sha|$header_count|$member_count|$ancestry_count"
if [ "$phase" = after-root-header ]; then
    event="AFTER INSERT ON root"
    subject="NEW.root_ref='root-02' AND NEW.request_ref='request-02' AND NEW.status='forming'"
else
    event="AFTER INSERT ON root_member"
    subject="NEW.root_ref='root-02' AND NEW.ordinal=1 AND NEW.object_ref='object-a'"
fi
activation_match="EXISTS(SELECT 1 FROM fault_activation WHERE run_id='$run' AND namespace_id='$namespace' AND assertion_id='$assertion' AND case_id='$case_id' AND attempt_id='$attempt' AND operation_id='$operation' AND hook_id='$hook' AND phase='$phase' AND nonce='$c_nonce' AND implementation_revision='$revision' AND activation_sha256='$activation_sha')"
shape_match="(SELECT COUNT(*) FROM root WHERE root_ref='root-02')=$header_count AND (SELECT COUNT(*) FROM root_member WHERE root_ref='root-02')=$member_count AND (SELECT COUNT(*) FROM root_ancestry WHERE root_ref='root-02')=$ancestry_count"
predicate="$subject AND $activation_match AND $shape_match"
ddl="CREATE TRIGGER \"$trigger\" $event WHEN $predicate BEGIN SELECT RAISE(ROLLBACK, '$literal'); END;"
[ "$(printf '%s\n' "$ddl" | sha256sum | awk '{ print $1 }')" = "$ddl_sha" ] &&
    [ "$(printf '%s\n' "$literal" | sha256sum | awk '{ print $1 }')" = "$literal_sha" ] &&
    [ "$(printf '%s\n' "$predicate" | sha256sum | awk '{ print $1 }')" = "$predicate_sha" ] ||
    fail BC02_FAULT_CONFIGURATION_DIGEST_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" \
    -v case_id="$case_id" -v attempt="$attempt" -v hook="$hook" \
    -v phase="$phase" -v nonce="$c_nonce" -v revision="$revision" '
    NF != 10 || $1 != run || $2 != ns || $3 != assertion ||
        $4 != case_id || $5 != attempt || $6 != "sut-form-root" ||
        $7 != hook || $8 != phase || $9 != nonce || $10 != revision {
        exit 1
    }
    END { if (NR != 1) exit 1 }
' "$activation" || fail BC02_FAULT_ACTIVATION_INVALID
[ "$(sha256sum "$activation" | awk '{ print $1 }')" = "$activation_sha" ] ||
    fail BC02_FAULT_ACTIVATION_DIGEST_INVALID

awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" \
    -v case_id="$case_id" -v attempt="$attempt" -v hook="$hook" \
    -v phase="$phase" -v nonce="$c_nonce" -v revision="$revision" \
    -v activation_sha="$activation_sha" -v header="$header_count" \
    -v member="$member_count" -v error_id="$error_id" \
    -v marker="$error_marker" -v literal_sha="$literal_sha" '
    NF != 21 || $1 != run || $2 != ns || $3 != assertion ||
        $4 != case_id || $5 != attempt || $6 != "sut-form-root" ||
        $7 != hook || $8 != phase || $9 != nonce || $10 != revision ||
        $11 != activation_sha || $12 != "true" || $13 != header ||
        $14 != member || $15 != 0 || $16 != "ok" ||
        $17 != error_id || $18 != marker ||
        $19 !~ /^[0-9a-f]{64}$/ || $20 != literal_sha ||
        $21 != "injected-rollback" { exit 1 }
    END { if (NR != 1) exit 1 }
' "$trigger_receipt" || fail BC02_FAULT_TRIGGER_INVALID

# The fault command is the sole accepted non-zero command.  Its stdout is the
# direct trigger receipt; all other command rows must succeed.
awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" \
    -v trigger_sha="$(sha256sum "$trigger_receipt" | awk '{ print $1 }')" \
    -v trigger_bytes="$(wc -c < "$trigger_receipt" | tr -d ' ')" '
    NF != 12 || $1 != run || $2 != ns || $3 != assertion { exit 1 }
    $4 == "fault" {
        faults++
        if ($5 != "sut-form-root" || $6 != "fault-injected" ||
            $7 != 70 || $8 != trigger_sha || $9 != trigger_bytes ||
            $10 !~ /^[0-9a-f]{64}$/ || $11 <= 0 ||
            $12 !~ /^[0-9a-f]{64}$/) exit 1
        next
    }
    $7 != 0 { exit 1 }
    END { if (faults != 1) exit 1 }
' "$commands" || fail BC02_FAULT_COMMAND_CUSTODY_INVALID

argv_digest()
{
    for argument in "$@"; do
        if [ "$argument" = "$base_dir/profiles/sqlite-reference/run.sh" ]; then
            printf '%s\n' '{adapter-entrypoint}'
        elif [ "$argument" = "$artifact_dir/$namespace.db" ]; then
            printf '%s\n' '{database-path}'
        else
            printf '%s\n' "$argument"
        fi
    done | sha256sum | awk '{ print $1 }'
}

adapter="$base_dir/profiles/sqlite-reference/run.sh"
db="$artifact_dir/$namespace.db"
command_identity()
{
    identity_phase=$1
    identity_operation=$2
    identity_mode=$3
    identity_status=$4
    shift 4
    printf '%s\t%s\t%s\t%s\t%s\n' "$identity_phase" \
        "$identity_operation" "$identity_mode" "$identity_status" \
        "$(argv_digest "$@")"
}
{
    command_identity create profile-create-namespace normal 0 \
        "$adapter" create-bc02 "$namespace" "$db"
    command_identity setup sut-setup-bc02 ordinary 0 \
        "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" sut-setup-bc02 ordinary setup setup-nonce
    command_identity configure-before-baseline "$hook" ordinary 0 \
        "$adapter" configure-fault-bc02 "$db" "$run" "$namespace" \
        "$assertion" "$case_id" "$hook" "$phase" "$attempt" "$c_nonce" \
        "$revision" "$activation_sha"
    command_identity setup-before runner-bind-evidence ordinary 0 \
        "$adapter" inventory-bc02 "$db" "$scenario"
    command_identity fault-before sqlite-data-version held 0 \
        '{held-observer}' observer-01 observer-process-01 \
        observer-connection-01 fault-before
    command_identity fault sut-form-root fault-injected 70 \
        "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" sut-form-root fault-injected "$attempt" "$c_nonce"
    command_identity fault-after sqlite-data-version held 0 \
        '{held-observer}' observer-01 observer-process-01 \
        observer-connection-01 fault-after
    command_identity rollback-after runner-bind-evidence ordinary 0 \
        "$adapter" inventory-bc02 "$db" "$scenario"
    command_identity unavailable runner-bind-evidence ordinary 0 \
        "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" unavailable
    if [ "$retry" = true ]; then
        command_identity retry-reopen profile-reopen-namespace ordinary 0 \
            "$adapter" reopen "$db" "$run" "$namespace" "$assertion"
        command_identity retry sut-retry-root ordinary 0 \
            "$adapter" operation-bc02 "$db" "$run" "$namespace" \
            "$assertion" "$case_id" sut-retry-root ordinary \
            attempt-retry retry-nonce
        command_identity retry-after runner-bind-evidence ordinary 0 \
            "$adapter" inventory-bc02 "$db" "$scenario"
        command_identity retry-commit sqlite-data-version held 0 \
            '{held-observer}' observer-01 observer-process-01 \
            observer-connection-01 retry-commit
        command_identity retry-success runner-bind-evidence ordinary 0 \
            "$adapter" resolution-bc02 "$db" "$run" "$namespace" \
            "$assertion" "$case_id" retry-success
    fi
    command_identity durability-reopen profile-reopen-namespace ordinary 0 \
        "$adapter" reopen "$db" "$run" "$namespace" "$assertion"
    command_identity reopened runner-bind-evidence ordinary 0 \
        "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" reopened
    command_identity destroy profile-destroy-namespace normal 0 \
        "$adapter" destroy "$namespace" "$db"
} > "$tmp/command-identities.expected"

awk -F '	' '
    NR == FNR {
        expected[$1] = $2 SUBSEP $3 SUBSEP $4 SUBSEP $5
        expected_count++
        next
    }
    {
        value = $5 SUBSEP $6 SUBSEP $7 SUBSEP $12
        if (!($4 in expected) || value != expected[$4] || seen[$4]++ ||
            $8 !~ /^[0-9a-f][0-9a-f]*$/ || $9 !~ /^[0-9]+$/ ||
            $10 !~ /^[0-9a-f][0-9a-f]*$/ || $11 !~ /^[0-9]+$/) exit 1
        count++
    }
    END {
        if (count != expected_count) exit 1
        for (phase in expected) if (seen[phase] != 1) exit 1
    }
' "$tmp/command-identities.expected" "$commands" ||
    fail BC02_FAULT_COMMAND_CUSTODY_INVALID

printf 'pragma\tforeign-keys\t1\n' > "$tmp/pragma.stderr"
: > "$tmp/empty.stderr"
printf 'status\tcreate\taccepted\t%s\n' "$namespace" > "$tmp/create.stdout"
printf 'status\tsetup\taccepted\t%s\n' "$assertion" > "$tmp/setup.stdout"
printf 'status\treopen\taccepted\t%s\n' "$assertion" > "$tmp/reopen.stdout"
printf 'status\tdestroy\taccepted\t%s\n' "$namespace" > "$tmp/destroy.stdout"
awk -F '	' '$6 == "fault-before"' "$data_versions" > "$tmp/fault-before.stdout"
awk -F '	' '$6 == "fault-after"' "$data_versions" > "$tmp/fault-after.stdout"
awk -F '	' '$6 == "retry-commit"' "$data_versions" > "$tmp/retry-commit.stdout"
awk -F '	' '$5 == "unavailable"' "$resolutions" > "$tmp/unavailable.stdout"
awk -F '	' '$5 == "retry-success"' "$resolutions" > "$tmp/retry-success.stdout"
awk -F '	' '$5 == "reopened"' "$resolutions" > "$tmp/reopened.stdout"
error_line=7
[ "$phase" != after-root-member ] || error_line=9
printf 'Runtime error near line %s: %s (19)\n' "$error_line" "$literal" \
    > "$tmp/fault-raw.stderr"
cat "$tmp/fault-raw.stderr" "$tmp/pragma.stderr" > "$tmp/fault.stderr"
[ "$(sha256sum "$tmp/fault-raw.stderr" | awk '{ print $1 }')" = \
    "$(cut -f19 "$trigger_receipt")" ] ||
    fail BC02_FAULT_COMMAND_CUSTODY_INVALID

command_content()
{
    content_phase=$1
    content_stdout=$2
    content_stderr=$3
    printf '%s\t%s\t%s\t%s\t%s\n' "$content_phase" \
        "$(sha256sum "$content_stdout" | awk '{ print $1 }')" \
        "$(wc -c < "$content_stdout" | tr -d ' ')" \
        "$(sha256sum "$content_stderr" | awk '{ print $1 }')" \
        "$(wc -c < "$content_stderr" | tr -d ' ')"
}
{
    command_content create "$tmp/create.stdout" "$tmp/pragma.stderr"
    command_content setup "$tmp/setup.stdout" "$tmp/pragma.stderr"
    command_content configure-before-baseline "$configuration" \
        "$tmp/pragma.stderr"
    command_content setup-before "$artifact_dir/inventory-setup-before.tsv" \
        "$tmp/pragma.stderr"
    command_content fault-before "$tmp/fault-before.stdout" \
        "$tmp/pragma.stderr"
    command_content fault "$trigger_receipt" "$tmp/fault.stderr"
    command_content fault-after "$tmp/fault-after.stdout" "$tmp/pragma.stderr"
    command_content rollback-after \
        "$artifact_dir/inventory-rollback-after.tsv" "$tmp/pragma.stderr"
    command_content unavailable "$tmp/unavailable.stdout" "$tmp/pragma.stderr"
    if [ "$retry" = true ]; then
        command_content retry-reopen "$tmp/reopen.stdout" "$tmp/pragma.stderr"
        command_content retry "$artifact_dir/action-receipts.tsv" \
            "$tmp/pragma.stderr"
        command_content retry-after "$artifact_dir/inventory-retry-after.tsv" \
            "$tmp/pragma.stderr"
        command_content retry-commit "$tmp/retry-commit.stdout" \
            "$tmp/pragma.stderr"
        command_content retry-success "$tmp/retry-success.stdout" \
            "$tmp/pragma.stderr"
    fi
    command_content durability-reopen "$tmp/reopen.stdout" \
        "$tmp/pragma.stderr"
    command_content reopened "$tmp/reopened.stdout" "$tmp/pragma.stderr"
    command_content destroy "$tmp/destroy.stdout" "$tmp/empty.stderr"
} > "$tmp/command-content.expected"

awk -F '	' '
    NR == FNR {
        expected[$1] = $2 SUBSEP $3 SUBSEP $4 SUBSEP $5
        next
    }
    {
        value = $8 SUBSEP $9 SUBSEP $10 SUBSEP $11
        if (!($4 in expected) || value != expected[$4] || seen[$4]++) exit 1
    }
    END {
        for (phase in expected) if (seen[phase] != 1) exit 1
    }
' "$tmp/command-content.expected" "$commands" ||
    fail BC02_FAULT_COMMAND_CUSTODY_INVALID

# The registered pragma relation is evidence, not an unchecked duplicate of
# command stderr.  Reconstruct its exact ordered phase projection.
{
    for pragma_phase in \
        create \
        setup \
        configure-before-baseline \
        setup-before \
        fault-before \
        fault \
        fault-after \
        rollback-after \
        unavailable
    do
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$pragma_phase"
    done
    if [ "$retry" = true ]; then
        for pragma_phase in \
            retry-reopen \
            retry \
            retry-after \
            retry-commit \
            retry-success
        do
            printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
                "$run" "$namespace" "$assertion" "$pragma_phase"
        done
    fi
    for pragma_phase in durability-reopen reopened
    do
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$pragma_phase"
    done
} > "$tmp/pragma.expected"
cmp -s "$tmp/pragma.expected" "$artifact_dir/pragma.tsv" ||
    fail BC02_FAULT_PRAGMA_INVALID

# Held-observer evidence must be one ordered identity.  A failed transaction
# cannot change data_version; a successful retry must change it.
awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" \
    -v case_id="$case_id" -v retry="$retry" '
    NF != 10 || $1 != run || $2 != ns || $3 != assertion ||
        $4 != case_id || $5 != "observer-01" ||
        $7 != "data-version" || $8 !~ /^[0-9]+$/ || $10 != "held" {
        exit 1
    }
    $6 == "fault-before" && $9 == "001" { before=$8; seen_before++ }
    $6 == "fault-after" && $9 == "002" { after=$8; seen_after++ }
    $6 == "retry-commit" && $9 == "003" { retried=$8; seen_retry++ }
    END {
        if (seen_before != 1 || seen_after != 1 || before != after) exit 1
        if (retry == "true") {
            if (seen_retry != 1 || retried == after) exit 1
        } else if (seen_retry) exit 1
    }
' "$data_versions" || fail BC02_FAULT_DATA_VERSION_INVALID

awk -F '	' 'BEGIN { OFS = "\t" }
    { print $9, $6, "foreign-keys", "1", "data-version", $8 }
' "$data_versions" > "$tmp/observer-transcript.tsv"
transcript_sha=$(sha256sum "$tmp/observer-transcript.tsv" | awk '{ print $1 }')
awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" \
    -v case_id="$case_id" -v retry="$retry" -v transcript="$transcript_sha" '
    NF != 13 || $1 != run || $2 != ns || $3 != assertion ||
        $4 != case_id || $5 != "observer-01" ||
        $6 != "observer-process-01" || $7 != "observer-connection-01" ||
        $8 != "before-fault" || $9 != "001" || $10 != "002" ||
        $12 != transcript || $13 != "held-through-required-stages" {
        exit 1
    }
    retry == "true" && $11 != "003" { exit 1 }
    retry != "true" && $11 != "-" { exit 1 }
    END { if (NR != 1) exit 1 }
' "$custody" || fail BC02_FAULT_OBSERVER_CUSTODY_INVALID

# Post-action binding is recomputed from the sealed source files.  The command
# digest is the exact fault command row, not an unrelated command.
awk -F '	' '$4 == "fault"' "$commands" > "$tmp/fault-command.tsv"
awk -F '	' '$5 == "unavailable"' "$resolutions" > "$tmp/unavailable.tsv"
awk -F '	' '$6 == "fault-before"' "$data_versions" > "$tmp/dv-before.tsv"
awk -F '	' '$6 == "fault-after"' "$data_versions" > "$tmp/dv-after.tsv"
awk -F '	' -v run="$run" -v ns="$namespace" -v assertion="$assertion" \
    -v case_id="$case_id" -v attempt="$attempt" -v nonce="$c_nonce" \
    -v activation_sha="$activation_sha" \
    -v configuration_sha="$(sha256sum "$configuration" | awk '{ print $1 }')" \
    -v trigger_sha="$(sha256sum "$trigger_receipt" | awk '{ print $1 }')" \
    -v command_sha="$(sha256sum "$tmp/fault-command.tsv" | awk '{ print $1 }')" \
    -v before_sha="$(sha256sum "$artifact_dir/inventory-setup-before.tsv" | awk '{ print $1 }')" \
    -v after_sha="$(sha256sum "$artifact_dir/inventory-rollback-after.tsv" | awk '{ print $1 }')" \
    -v resolution_sha="$(sha256sum "$tmp/unavailable.tsv" | awk '{ print $1 }')" \
    -v dv_before_sha="$(sha256sum "$tmp/dv-before.tsv" | awk '{ print $1 }')" \
    -v dv_after_sha="$(sha256sum "$tmp/dv-after.tsv" | awk '{ print $1 }')" \
    -v error_id="$error_id" -v marker="$error_marker" '
    NF != 17 || $1 != run || $2 != ns || $3 != assertion ||
        $4 != case_id || $5 != attempt || $6 != nonce ||
        $7 != activation_sha || $8 != configuration_sha ||
        $9 != trigger_sha || $10 != command_sha ||
        $11 != before_sha || $12 != after_sha ||
        $13 != resolution_sha || $14 != dv_before_sha ||
        $15 != dv_after_sha || $16 != error_id || $17 != marker {
        exit 1
    }
    END { if (NR != 1) exit 1 }
' "$binding" || fail BC02_FAULT_EVIDENCE_BINDING_INVALID

# Marker is a mechanical projection of the linked receipts and inventories.
before_sha=$(sha256sum "$artifact_dir/inventory-setup-before.tsv" | awk '{ print $1 }')
after_sha=$(sha256sum "$artifact_dir/inventory-rollback-after.tsv" | awk '{ print $1 }')
awk -F '	' -v assertion="$assertion" -v run="$run" \
    -v case_id="$case_id" -v ns="$namespace" -v nonce="$c_nonce" \
    -v revision="$revision" -v hook="$hook" -v phase="$phase" \
    -v before_sha="$before_sha" -v after_sha="$after_sha" '
    NF != 11 || $1 != assertion || $2 != run || $3 != case_id ||
        $4 != ns || $5 != nonce || $6 != revision || $7 != hook ||
        $8 != phase || $9 != "true" || $10 != before_sha ||
        $11 != after_sha { exit 1 }
    END { if (NR != 1) exit 1 }
' "$artifact_dir/fault-markers.tsv" || fail BC02_FAULT_MARKER_INVALID

# Resolution and optional retry action are exact template projections.
awk -F '	' -v OFS='	' -v run="$run" -v ns="$namespace" \
    -v assertion="$assertion" -v case_id="$case_id" '
    $3 == assertion && $4 == case_id { $1=run; $2=ns; print }
' "$base_dir/bc02-resolution-receipt-template.tsv" > "$tmp/resolution.expected"
cmp -s "$tmp/resolution.expected" "$resolutions" ||
    fail BC02_FAULT_RESOLUTION_INVALID
if [ "$retry" = true ]; then
    awk -F '	' -v OFS='	' -v run="$run" -v ns="$namespace" \
        -v assertion="$assertion" -v case_id="$case_id" '
        $3 == assertion && $4 == case_id {
            $1=run; $2=ns; gsub(/\{nonce-retry\}/, "retry-nonce", $15); print
        }
    ' "$base_dir/bc02-root-action-receipt-template.tsv" \
        > "$tmp/action.expected"
    cmp -s "$tmp/action.expected" "$artifact_dir/action-receipts.tsv" ||
        fail BC02_FAULT_RETRY_ACTION_INVALID
fi

# Raw evidence is sealed before normalization.  The seal binds the actual raw
# bytes and a deterministic receipt-set manifest supplied by the runner.
seal="$artifact_dir/raw-seal.tsv"
raw="$artifact_dir/raw-observations.tsv"
receipt_sources="command-receipts.tsv
data-version-receipts.tsv
evidence-binding-receipts.tsv
fault-activation-receipts.tsv
fault-configuration-receipts.tsv
fault-trigger-receipts.tsv
inventory-rollback-after.tsv
inventory-setup-before.tsv
observer-custody-receipts.tsv
resolution-receipts.tsv"
if [ "$retry" = true ]; then
    receipt_sources="action-receipts.tsv
$receipt_sources
inventory-retry-after.tsv"
fi
printf '%s\n' "$receipt_sources" | LC_ALL=C sort |
while IFS= read -r source; do
    file="$artifact_dir/$source"
    printf '%s\t%s\t%s\n' "$source" \
        "$(sha256sum "$file" | awk '{ print $1 }')" \
        "$(wc -c < "$file" | tr -d ' ')"
done > "$tmp/receipt-set.tsv"
receipt_set_sha=$(sha256sum "$tmp/receipt-set.tsv" | awk '{ print $1 }')
awk -F '	' -v raw_sha="$(sha256sum "$raw" | awk '{ print $1 }')" \
    -v raw_bytes="$(wc -c < "$raw" | tr -d ' ')" \
    -v run="$run" -v ns="$namespace" -v scenario="$scenario" \
    -v receipt_set_sha="$receipt_set_sha" '
    NF != 9 || $1 != "raw-observations.tsv" || $2 != "100644" ||
        $3 != raw_sha || $4 != raw_bytes || $5 != run || $6 != ns ||
        $7 != scenario || $8 != receipt_set_sha ||
        $9 != "sealed-before-normalization" { exit 1 }
    END { if (NR != 1) exit 1 }
' "$seal" || fail BC02_FAULT_RAW_SEAL_INVALID

# The full raw relation is independently reconstructed from validated source
# artifacts.  Checking only endpoint IDs would permit a re-sealed dynamic-value
# forgery that normalization does not necessarily expose.
fault_before=$(awk -F '	' '$6 == "fault-before" { print $8 }' "$data_versions")
fault_after=$(awk -F '	' '$6 == "fault-after" { print $8 }' "$data_versions")
retry_after=$(awk -F '	' '$6 == "retry-commit" { print $8 }' "$data_versions")
awk -F '	' -v OFS='	' -v scenario="$scenario" \
    -v activation_sha="$activation_sha" \
    -v configuration_sha="$(sha256sum "$configuration" | awk '{ print $1 }')" \
    -v trigger_sha="$(sha256sum "$trigger_receipt" | awk '{ print $1 }')" \
    -v command_sha="$(sha256sum "$tmp/fault-command.tsv" | awk '{ print $1 }')" \
    -v ddl_sha="$ddl_sha" -v literal_sha="$literal_sha" \
    -v predicate_sha="$predicate_sha" \
    -v before_sha="$before_sha" -v after_sha="$after_sha" \
    -v fault_before="$fault_before" -v fault_after="$fault_after" \
    -v retry_after="$retry_after" '
    $1 == scenario {
        gsub(/\{activation-sha256\}/, activation_sha)
        gsub(/\{configuration-sha256\}/, configuration_sha)
        gsub(/\{trigger-sha256\}/, trigger_sha)
        gsub(/\{command-sha256\}/, command_sha)
        gsub(/\{ddl-sha256\}/, ddl_sha)
        gsub(/\{error-literal-sha256\}/, literal_sha)
        gsub(/\{when-predicate-sha256\}/, predicate_sha)
        gsub(/\{setup-before-sha256\}/, before_sha)
        gsub(/\{rollback-after-sha256\}/, after_sha)
        gsub(/\{fault-before-data-version\}/, fault_before)
        gsub(/\{fault-after-data-version\}/, fault_after)
        gsub(/\{retry-after-data-version\}/, retry_after)
        print
    }
' "$base_dir/bc02-raw-template.tsv" | LC_ALL=C sort > "$tmp/raw.expected"
cmp -s "$tmp/raw.expected" "$raw" || fail BC02_FAULT_RAW_INVALID

"$script_dir/normalize-bc02.sh" "$raw" "$scenario" \
    > "$tmp/normalized-from-raw.tsv"
cmp -s "$tmp/normalized-from-raw.tsv" \
    "$artifact_dir/normalized-observations.tsv" ||
    fail BC02_FAULT_NORMALIZATION_INVALID
for pair in \
    "bc02-normalized-contract.tsv:normalized-observations.tsv" \
    "bc02-coverage-template.tsv:coverage.tsv"
do
    contract=${pair%%:*}
    artifact=${pair#*:}
    awk -F '	' -v scenario="$scenario" '$1 == scenario' \
        "$base_dir/$contract" > "$tmp/$artifact.expected"
    cmp -s "$tmp/$artifact.expected" "$artifact_dir/$artifact" ||
        fail BC02_FAULT_SEMANTIC_ARTIFACT_INVALID
done

# Oracle result binds the exact comparison inputs and the reviewed evaluator.
expected_norm="$tmp/normalized-observations.tsv.expected"
oracle_revision=$(sha256sum "$script_dir/oracle-bc02.sh" | awk '{ print $1 }')
if [ "$assertion" = BC02_ROLLBACK_COMPLETE ]; then
    expected_oracle_sha=$(sha256sum "$artifact_dir/inventory-setup-before.tsv" |
        awk '{ print $1 }')
    actual_oracle_sha=$(sha256sum "$artifact_dir/inventory-rollback-after.tsv" |
        awk '{ print $1 }')
    oracle_kind=equality
    oracle_target=inventory-repository
else
    expected_oracle_sha=$(sha256sum "$expected_norm" | awk '{ print $1 }')
    actual_oracle_sha=$(sha256sum "$artifact_dir/normalized-observations.tsv" |
        awk '{ print $1 }')
    oracle_kind=exact
    oracle_target=norm-bc02-observation
fi
awk -F '	' -v scenario="$scenario" -v oracle="$oracle_id" \
    -v kind="$oracle_kind" -v target="$oracle_target" \
    -v expected="$expected_oracle_sha" -v actual="$actual_oracle_sha" \
    -v revision="$oracle_revision" '
    NF != 8 || $1 != scenario || $2 != oracle || $3 != kind ||
        $4 != target || $5 != expected || $6 != actual ||
        $7 != "PASS" || $8 != revision { exit 1 }
    END { if (NR != 1) exit 1 }
' "$artifact_dir/oracle-result.tsv" || fail BC02_FAULT_ORACLE_INVALID

# Gate rows must be the exact ordered gate set.  Each evidence digest is
# independently recomputed from its declared source list.
gate_revision=$(sha256sum "$script_dir/materialize-bc02-gates.sh" |
    awk '{ print $1 }')
awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc02-gate-results-template.tsv" > "$tmp/gates.template"
while IFS='	' read -r g_scenario g_set ordinal gate evidence placeholder \
    disposition reason placeholder_revision; do
    [ "$placeholder" = "{evidence-sha256}" ] &&
        [ "$disposition" = "PASS" ] &&
        [ "$reason" = "-" ] &&
        [ "$placeholder_revision" = "{evaluator-revision}" ] ||
        fail BC02_FAULT_GATE_RESULT_INVALID
    : > "$tmp/gate-evidence"
    printf '%s\n' "$evidence" | tr '+' '\n' > "$tmp/gate-sources"
    while IFS= read -r source; do
        [ -f "$artifact_dir/$source" ] || fail BC02_FAULT_GATE_RESULT_INVALID
        printf '%s\t%s\t%s\n' "$source" \
            "$(sha256sum "$artifact_dir/$source" | awk '{ print $1 }')" \
            "$(wc -c < "$artifact_dir/$source" | tr -d ' ')" \
            >> "$tmp/gate-evidence"
    done < "$tmp/gate-sources"
    evidence_sha=$(LC_ALL=C sort "$tmp/gate-evidence" | sha256sum |
        awk '{ print $1 }')
    printf '%s\t%s\t%s\t%s\t%s\t%s\tPASS\t-\t%s\n' \
        "$g_scenario" "$g_set" "$ordinal" "$gate" "$evidence" \
        "$evidence_sha" "$gate_revision"
done < "$tmp/gates.template" > "$tmp/gates.expected"
cmp -s "$tmp/gates.expected" "$artifact_dir/gate-results.tsv" ||
    fail BC02_FAULT_GATE_RESULT_INVALID

echo BC02_FAULT_RUNTIME_VALID
