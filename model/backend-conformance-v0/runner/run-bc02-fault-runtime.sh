#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc02.sh"
oracle="$script_dir/oracle-bc02.sh"
gate_materializer="$script_dir/materialize-bc02-gates.sh"
verifier="$script_dir/verify-bc02-runtime.sh"
registry="$base_dir/bc02-runtime-artifacts.tsv"

[ "$#" -eq 6 ] || {
    echo "usage: run-bc02-fault-runtime.sh ARTIFACT_DIR RUN NS ASSERTION CASE MODE" >&2
    exit 2
}

artifact_dir=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
mode=$6

case "$assertion" in
    BC02_PARTIAL_RESIDUE)
        scenario_prefix=bc02-partial-residue
        poisoned=0
        case "$mode" in ordinary|mutant-partial-residue) ;; *) exit 2 ;; esac
        ;;
    BC02_ROLLBACK_COMPLETE)
        scenario_prefix=bc02-rollback-complete
        poisoned=0
        case "$mode" in ordinary|mutant-incomplete-rollback) ;; *) exit 2 ;; esac
        ;;
    BC02_POISONED_RETRY)
        scenario_prefix=bc02-poisoned-retry
        poisoned=1
        case "$mode" in ordinary|mutant-poisoned-retry) ;; *) exit 2 ;; esac
        ;;
    *)
        exit 2
        ;;
esac

case "$case_id" in
    case-bc02-after-root-header)
        hook=hook-bc02-after-root-header
        phase=after-root-header
        attempt=attempt-fault-header
        error_id=error-bc02-after-root-header
        error_marker=LICIUM_BC02_FAULT_AFTER_ROOT_HEADER
        ;;
    case-bc02-after-root-member)
        hook=hook-bc02-after-root-member
        phase=after-root-member
        attempt=attempt-fault-member
        error_id=error-bc02-after-root-member
        error_marker=LICIUM_BC02_FAULT_AFTER_ROOT_MEMBER
        ;;
    *)
        exit 2
        ;;
esac

scenario="$scenario_prefix--$case_id"
fault_nonce=fault-nonce
implementation_revision=$(
    sha256sum "$base_dir/sqlite-reference/sut-bc02.sh" | awk '{ print $1 }'
)
observer=observer-01
observer_process=observer-process-01
connection_nonce=observer-connection-01

mkdir -p "$artifact_dir"
db="$artifact_dir/$namespace.db"
tmp=$(mktemp -d)
observer_pid=
observer_open=0

cleanup()
{
    if [ "$observer_open" -eq 1 ]; then
        printf '.quit\n' >&3 2>/dev/null || :
        exec 3>&- 4>&-
        observer_open=0
    fi
    if [ -n "$observer_pid" ]; then
        wait "$observer_pid" 2>/dev/null || :
    fi
    rm -rf "$tmp"
    rm -f "$db"
}
trap cleanup EXIT HUP INT TERM

while IFS='	' read -r name fields cardinality kind source; do
    : > "$artifact_dir/$name"
done < "$registry"

command_receipts="$artifact_dir/command-receipts.tsv"
pragma="$artifact_dir/pragma.tsv"
transcript="$tmp/observer-transcript.tsv"
: > "$transcript"

argv_digest()
{
    for argument in "$@"; do
        if [ "$argument" = "$adapter" ]; then
            printf '%s\n' '{adapter-entrypoint}'
        elif [ "$argument" = "$db" ]; then
            printf '%s\n' '{database-path}'
        else
            printf '%s\n' "$argument"
        fi
    done | sha256sum | awk '{ print $1 }'
}

record_command()
{
    command_phase=$1
    operation=$2
    command_mode=$3
    status=$4
    stdout=$5
    stderr=$6
    shift 6
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$assertion" "$command_phase" "$operation" \
        "$command_mode" "$status" \
        "$(sha256sum "$stdout" | awk '{ print $1 }')" \
        "$(wc -c < "$stdout" | tr -d ' ')" \
        "$(sha256sum "$stderr" | awk '{ print $1 }')" \
        "$(wc -c < "$stderr" | tr -d ' ')" \
        "$(argv_digest "$@")" >> "$command_receipts"
}

invoke()
{
    command_phase=$1
    operation=$2
    command_mode=$3
    expected_status=$4
    stdout=$5
    stderr=$6
    shift 6

    set +e
    "$@" > "$stdout" 2> "$stderr"
    status=$?
    set -e
    record_command "$command_phase" "$operation" "$command_mode" "$status" \
        "$stdout" "$stderr" "$@"
    [ "$status" -eq "$expected_status" ] || {
        cat "$stderr" >&2
        exit "$status"
    }

    if [ "$command_phase" != "destroy" ]; then
        [ "$(tail -n 1 "$stderr")" = "pragma	foreign-keys	1" ] || {
            echo BC02_PRAGMA_EVIDENCE_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$command_phase" >> "$pragma"
    elif [ -s "$stderr" ]; then
        echo BC02_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

observer_start()
{
    input_fifo="$tmp/observer.in"
    output_fifo="$tmp/observer.out"
    mkfifo "$input_fifo" "$output_fifo"
    exec 3<> "$input_fifo"
    exec 4<> "$output_fifo"
    sqlite3 -batch -noheader -tabs "$db" < "$input_fifo" > "$output_fifo" \
        2> "$tmp/observer-process.err" &
    observer_pid=$!
    observer_open=1
    printf "PRAGMA foreign_keys=ON;\nSELECT 'observer-ready';\n" >&3
    IFS= read -r ready <&4
    [ "$ready" = "observer-ready" ] || exit 1
}

observer_query()
{
    query_phase=$1
    sequence=$2
    receipt=$3
    query_stdout=$4
    query_stderr=$5
    frame="frame-$sequence"

    printf "SELECT 'begin-%s';\nPRAGMA foreign_keys;\nPRAGMA data_version;\nSELECT 'end-%s';\n" \
        "$frame" "$frame" >&3
    IFS= read -r begin <&4
    IFS= read -r foreign_keys <&4
    IFS= read -r data_version <&4
    IFS= read -r end <&4
    [ "$begin" = "begin-$frame" ] &&
        [ "$foreign_keys" = "1" ] &&
        [ "$end" = "end-$frame" ] || exit 1
    case "$data_version" in ''|*[!0-9]*) exit 1 ;; esac

    printf '%s\t%s\tforeign-keys\t%s\tdata-version\t%s\n' \
        "$sequence" "$query_phase" "$foreign_keys" "$data_version" \
        >> "$transcript"
    printf '%s\t%s\t%s\t%s\t%s\t%s\tdata-version\t%s\t%s\theld\n' \
        "$run" "$namespace" "$assertion" "$case_id" "$observer" \
        "$query_phase" "$data_version" "$sequence" > "$receipt"
    cp "$receipt" "$query_stdout"
    printf 'pragma\tforeign-keys\t1\n' > "$query_stderr"
    record_command "$query_phase" sqlite-data-version held 0 \
        "$query_stdout" "$query_stderr" \
        '{held-observer}' "$observer" "$observer_process" \
        "$connection_nonce" "$query_phase"
    cat "$receipt" >> "$artifact_dir/data-version-receipts.tsv"
    printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
        "$run" "$namespace" "$assertion" "$query_phase" >> "$pragma"
}

observer_stop()
{
    printf '.quit\n' >&3
    exec 3>&- 4>&-
    observer_open=0
    wait "$observer_pid"
    observer_pid=
    [ ! -s "$tmp/observer-process.err" ] || exit 1
}

invoke create profile-create-namespace normal 0 \
    "$tmp/create.out" "$tmp/create.err" \
    "$adapter" create-bc02 "$namespace" "$db"

invoke setup sut-setup-bc02 ordinary 0 \
    "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-setup-bc02 ordinary setup setup-nonce

printf '%s\t%s\t%s\t%s\t%s\tsut-form-root\t%s\t%s\t%s\t%s\n' \
    "$run" "$namespace" "$assertion" "$case_id" "$attempt" "$hook" \
    "$phase" "$fault_nonce" "$implementation_revision" \
    > "$artifact_dir/fault-activation-receipts.tsv"
activation_sha=$(
    sha256sum "$artifact_dir/fault-activation-receipts.tsv" |
        awk '{ print $1 }'
)

invoke configure-before-baseline "$hook" ordinary 0 \
    "$artifact_dir/fault-configuration-receipts.tsv" "$tmp/configure.err" \
    "$adapter" configure-fault-bc02 "$db" "$run" "$namespace" \
    "$assertion" "$case_id" "$hook" "$phase" "$attempt" "$fault_nonce" \
    "$implementation_revision" "$activation_sha"

invoke setup-before runner-bind-evidence ordinary 0 \
    "$artifact_dir/inventory-setup-before.tsv" "$tmp/setup-before.err" \
    "$adapter" inventory-bc02 "$db" "$scenario"

observer_start
observer_query fault-before 001 "$tmp/data-version-before.tsv" \
    "$tmp/fault-before.out" "$tmp/fault-before.err"
fault_before=$(cut -f8 "$tmp/data-version-before.tsv")

invoke fault sut-form-root fault-injected 70 \
    "$artifact_dir/fault-trigger-receipts.tsv" "$tmp/fault.err" \
    "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" sut-form-root fault-injected "$attempt" "$fault_nonce"

awk -F '	' -v run="$run" -v namespace_id="$namespace" \
    -v assertion="$assertion" -v case_id="$case_id" -v attempt="$attempt" \
    -v hook="$hook" -v phase="$phase" -v nonce="$fault_nonce" \
    -v revision="$implementation_revision" -v activation="$activation_sha" \
    -v error_id="$error_id" -v marker="$error_marker" '
    NF != 21 || $1 != run || $2 != namespace_id || $3 != assertion ||
        $4 != case_id || $5 != attempt || $6 != "sut-form-root" ||
        $7 != hook || $8 != phase || $9 != nonce || $10 != revision ||
        $11 != activation || $12 != "true" || $16 != "ok" ||
        $17 != error_id || $18 != marker || $21 != "injected-rollback" {
        exit 1
    }
    END { if (NR != 1) exit 1 }
' "$artifact_dir/fault-trigger-receipts.tsv"

observer_query fault-after 002 "$tmp/data-version-after.tsv" \
    "$tmp/fault-after.out" "$tmp/fault-after.err"
fault_after=$(cut -f8 "$tmp/data-version-after.tsv")

case "$mode" in
    mutant-partial-residue|mutant-incomplete-rollback)
        invoke mutant-residue sut-retry-root "$mode" 0 \
            "$artifact_dir/action-receipts.tsv" "$tmp/mutant-residue.err" \
            "$adapter" operation-bc02 "$db" "$run" "$namespace" \
            "$assertion" "$case_id" sut-retry-root "$mode" \
            attempt-retry mutant-residue-nonce
        ;;
esac

invoke rollback-after runner-bind-evidence ordinary 0 \
    "$artifact_dir/inventory-rollback-after.tsv" "$tmp/rollback-after.err" \
    "$adapter" inventory-bc02 "$db" "$scenario"

invoke unavailable runner-bind-evidence ordinary 0 \
    "$tmp/resolution-unavailable.tsv" "$tmp/unavailable.err" \
    "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" unavailable
cat "$tmp/resolution-unavailable.tsv" \
    >> "$artifact_dir/resolution-receipts.tsv"

if [ "$poisoned" -eq 1 ]; then
    invoke retry-reopen profile-reopen-namespace ordinary 0 \
        "$tmp/retry-reopen.out" "$tmp/retry-reopen.err" \
        "$adapter" reopen "$db" "$run" "$namespace" "$assertion"

    retry_mode=ordinary
    [ "$mode" != "mutant-poisoned-retry" ] || retry_mode=$mode
    invoke retry sut-retry-root "$retry_mode" 0 \
        "$artifact_dir/action-receipts.tsv" "$tmp/retry.err" \
        "$adapter" operation-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" sut-retry-root "$retry_mode" attempt-retry retry-nonce

    invoke retry-after runner-bind-evidence ordinary 0 \
        "$artifact_dir/inventory-retry-after.tsv" "$tmp/retry-after.err" \
        "$adapter" inventory-bc02 "$db" "$scenario"

    observer_query retry-commit 003 "$tmp/data-version-retry.tsv" \
        "$tmp/retry-commit.out" "$tmp/retry-commit.err"
    retry_version=$(cut -f8 "$tmp/data-version-retry.tsv")

    invoke retry-success runner-bind-evidence ordinary 0 \
        "$tmp/resolution-retry.tsv" "$tmp/retry-success.err" \
        "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
        "$case_id" retry-success
    cat "$tmp/resolution-retry.tsv" \
        >> "$artifact_dir/resolution-receipts.tsv"
fi

observer_stop
retry_sequence=-
[ "$poisoned" -eq 0 ] || retry_sequence=003
transcript_sha=$(sha256sum "$transcript" | awk '{ print $1 }')
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\tbefore-fault\t001\t002\t%s\t%s\theld-through-required-stages\n' \
    "$run" "$namespace" "$assertion" "$case_id" "$observer" \
    "$observer_process" "$connection_nonce" "$retry_sequence" \
    "$transcript_sha" > "$artifact_dir/observer-custody-receipts.tsv"

invoke durability-reopen profile-reopen-namespace ordinary 0 \
    "$tmp/reopen.out" "$tmp/reopen.err" \
    "$adapter" reopen "$db" "$run" "$namespace" "$assertion"

invoke reopened runner-bind-evidence ordinary 0 \
    "$tmp/resolution-reopened.tsv" "$tmp/reopened.err" \
    "$adapter" resolution-bc02 "$db" "$run" "$namespace" "$assertion" \
    "$case_id" reopened
cat "$tmp/resolution-reopened.tsv" \
    >> "$artifact_dir/resolution-receipts.tsv"

invoke destroy profile-destroy-namespace normal 0 \
    "$tmp/destroy.out" "$tmp/destroy.err" \
    "$adapter" destroy "$namespace" "$db"

activation_sha=$(sha256sum \
    "$artifact_dir/fault-activation-receipts.tsv" | awk '{ print $1 }')
configuration_sha=$(sha256sum \
    "$artifact_dir/fault-configuration-receipts.tsv" | awk '{ print $1 }')
trigger_sha=$(sha256sum \
    "$artifact_dir/fault-trigger-receipts.tsv" | awk '{ print $1 }')
awk -F '	' '$4 == "fault"' "$command_receipts" > "$tmp/fault-command.tsv"
command_sha=$(sha256sum "$tmp/fault-command.tsv" | awk '{ print $1 }')
before_inventory_sha=$(sha256sum \
    "$artifact_dir/inventory-setup-before.tsv" | awk '{ print $1 }')
after_inventory_sha=$(sha256sum \
    "$artifact_dir/inventory-rollback-after.tsv" | awk '{ print $1 }')
resolution_sha=$(sha256sum "$tmp/resolution-unavailable.tsv" |
    awk '{ print $1 }')
data_before_sha=$(sha256sum "$tmp/data-version-before.tsv" |
    awk '{ print $1 }')
data_after_sha=$(sha256sum "$tmp/data-version-after.tsv" |
    awk '{ print $1 }')

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$run" "$namespace" "$assertion" "$case_id" "$attempt" "$fault_nonce" \
    "$activation_sha" "$configuration_sha" "$trigger_sha" "$command_sha" \
    "$before_inventory_sha" "$after_inventory_sha" "$resolution_sha" \
    "$data_before_sha" "$data_after_sha" "$error_id" "$error_marker" \
    > "$artifact_dir/evidence-binding-receipts.tsv"

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\ttrue\t%s\t%s\n' \
    "$assertion" "$run" "$case_id" "$namespace" "$fault_nonce" \
    "$implementation_revision" "$hook" "$phase" \
    "$before_inventory_sha" "$after_inventory_sha" \
    > "$artifact_dir/fault-markers.tsv"

logical_count()
{
    relation=$1
    awk -F '	' -v relation="$relation" '
        $2 == relation && $3 != "@relation" { seen[$3] = 1 }
        END {
            for (key in seen) count++
            print count + 0
        }
    ' "$artifact_dir/inventory-rollback-after.tsv"
}

header_count=$(logical_count root)
member_count=$(logical_count root-member)
ancestry_count=$(logical_count root-ancestry)
target_artifact_count=$((header_count + member_count + ancestry_count))
triggered=$(cut -f12 "$artifact_dir/fault-trigger-receipts.tsv")
transient_header=$(cut -f13 "$artifact_dir/fault-trigger-receipts.tsv")
transient_member=$(cut -f14 "$artifact_dir/fault-trigger-receipts.tsv")
transient_ancestry=$(cut -f15 "$artifact_dir/fault-trigger-receipts.tsv")
connection_health=$(cut -f16 "$artifact_dir/fault-trigger-receipts.tsv")
trigger_error_id=$(cut -f17 "$artifact_dir/fault-trigger-receipts.tsv")
trigger_error_marker=$(cut -f18 "$artifact_dir/fault-trigger-receipts.tsv")
error_kind=$(cut -f21 "$artifact_dir/fault-trigger-receipts.tsv")
ddl_sha=$(cut -f11 "$artifact_dir/fault-configuration-receipts.tsv")
literal_sha=$(cut -f12 "$artifact_dir/fault-configuration-receipts.tsv")
predicate_sha=$(cut -f13 "$artifact_dir/fault-configuration-receipts.tsv")

raw="$artifact_dir/raw-observations.tsv"
{
    printf '%s\traw-activation-01\tfault-activation-receipt\tfault\thook/attempt\t%s/%s\n' \
        "$scenario" "$hook" "$attempt"
    printf '%s\traw-ancestry-residue-01\tinventory-repository\trollback-after\troot-ancestry/semantic-row-count\t%s\n' \
        "$scenario" "$ancestry_count"
    if [ "$poisoned" -eq 1 ]; then
        printf '%s\traw-attempt-identity-01\tfault-trigger-receipt\tfault\tattempt/request/root\t%s/request-02/root-02\n' \
            "$scenario" "$attempt"
        printf '%s\traw-attempt-identity-02\taction-receipt\tretry\tattempt/request/root\t%s/%s/%s\n' \
            "$scenario" \
            "$(cut -f5 "$artifact_dir/action-receipts.tsv")" \
            "$(cut -f8 "$artifact_dir/action-receipts.tsv")" \
            "$(cut -f9 "$artifact_dir/action-receipts.tsv")"
    fi
    printf '%s\traw-command-status-01\tcommand-receipt\tfault\tattempt/status\t%s/70\n' \
        "$scenario" "$attempt"
    printf '%s\traw-error-identity-01\tfault-trigger-receipt\tfault\tfault-error/%s\t%s/%s\n' \
        "$scenario" "$attempt" "$trigger_error_id" "$trigger_error_marker"
    printf '%s\traw-failing-connection-health-01\tfault-trigger-receipt\tfault\tsame-connection-health\t%s\n' \
        "$scenario" "$connection_health"
    if [ "$poisoned" -eq 1 ]; then
        printf '%s\traw-fault-availability-01\tresolution-receipt\tunavailable\tavailability/root-02\tunavailable/0\n' \
            "$scenario"
    else
        printf '%s\traw-availability-01\tresolution-receipt\tunavailable\tavailability/root-02\tunavailable/0\n' \
            "$scenario"
    fi
    printf '%s\traw-fault-outcome-01\tfault-trigger-receipt\tfault\terror-kind\t%s\n' \
        "$scenario" "$error_kind"
    printf '%s\traw-fault-outcome-02\tinventory-repository\trollback-after\ttarget-root-artifact-count\t%s\n' \
        "$scenario" "$target_artifact_count"
    printf '%s\traw-header-residue-01\tinventory-repository\trollback-after\troot-header/semantic-row-count\t%s\n' \
        "$scenario" "$header_count"
    printf '%s\traw-member-residue-01\tinventory-repository\trollback-after\troot-member/semantic-row-count\t%s\n' \
        "$scenario" "$member_count"
    printf '%s\traw-no-commit-01\tdata-version-receipt\tfault-before\tobserver-01/data-version\t%s\n' \
        "$scenario" "$fault_before"
    printf '%s\traw-no-commit-02\tdata-version-receipt\tfault-after\tobserver-01/data-version\t%s\n' \
        "$scenario" "$fault_after"
    printf '%s\traw-no-commit-03\tobserver-custody-receipt\tfault-before-to-fault-after\tobserver-01/status\theld-through-required-stages\n' \
        "$scenario"
    printf '%s\traw-reopened-resolution-01\tresolution-receipt\treopened\tresolution/root-02\t%s\n' \
        "$scenario" "$([ "$poisoned" -eq 1 ] && printf 'available/1' || printf 'unavailable/0')"
    if [ "$poisoned" -eq 1 ]; then
        printf '%s\traw-retry-ancestry-01\tresolution-receipt\tretry-success\tancestry/root-02\tbound/%s\n' \
            "$scenario" "$(awk -F '	' '$5=="retry-success"{print $10}' "$artifact_dir/resolution-receipts.tsv")"
        printf '%s\traw-retry-availability-01\tresolution-receipt\tretry-success\tavailability/root-02\tavailable/1\n' \
            "$scenario"
        printf '%s\traw-retry-commit-01\tdata-version-receipt\tfault-after\tobserver-01/data-version\t%s\n' \
            "$scenario" "$fault_after"
        printf '%s\traw-retry-commit-02\tdata-version-receipt\tretry-commit\tobserver-01/data-version\t%s\n' \
            "$scenario" "$retry_version"
        printf '%s\traw-retry-commit-03\tobserver-custody-receipt\tfault-after-to-retry-commit\tobserver-01/status\theld-through-required-stages\n' \
            "$scenario"
        printf '%s\traw-retry-formation-01\taction-receipt\tretry\tattempt/outcome/root\t%s/%s/%s\n' \
            "$scenario" \
            "$(cut -f5 "$artifact_dir/action-receipts.tsv")" \
            "$(cut -f7 "$artifact_dir/action-receipts.tsv")" \
            "$(cut -f9 "$artifact_dir/action-receipts.tsv")"
        printf '%s\traw-retry-hook-01\tcommand-receipt\tretry\treviewed-argv/hook-phase-count\t0\n' \
            "$scenario"
        printf '%s\traw-retry-membership-01\tresolution-receipt\tretry-success\tmembership/root-02\tcomplete/%s\n' \
            "$scenario" "$(awk -F '	' '$5=="retry-success"{print $9}' "$artifact_dir/resolution-receipts.tsv")"
        printf '%s\traw-rollback-01\tinventory-repository\tsetup-before\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$before_inventory_sha"
        printf '%s\traw-rollback-02\tinventory-repository\trollback-after\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$after_inventory_sha"
    elif [ "$assertion" = "BC02_ROLLBACK_COMPLETE" ]; then
        printf '%s\traw-rollback-01\tinventory-repository\tsetup-before\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$before_inventory_sha"
        printf '%s\traw-rollback-02\tinventory-repository\trollback-after\tsemantic-inventory-sha256\t%s\n' \
            "$scenario" "$after_inventory_sha"
    fi
    printf '%s\traw-trigger-01\tfault-activation-receipt\tfault\thook/attempt\t%s/%s\n' \
        "$scenario" "$hook" "$attempt"
    printf '%s\traw-trigger-02\tfault-trigger-receipt\tfault\ttriggered\t%s\n' \
        "$scenario" "$triggered"
    printf '%s\traw-trigger-03\tfault-trigger-receipt\tfault\ttransient-header-count\t%s\n' \
        "$scenario" "$transient_header"
    printf '%s\traw-trigger-04\tfault-trigger-receipt\tfault\ttransient-member-count\t%s\n' \
        "$scenario" "$transient_member"
    printf '%s\traw-trigger-05\tfault-trigger-receipt\tfault\ttransient-ancestry-count\t%s\n' \
        "$scenario" "$transient_ancestry"
    printf '%s\traw-trigger-06\tfault-configuration-receipt\tconfigure-before-baseline\tddl/error-literal/when-predicate-digests\t%s/%s/%s\n' \
        "$scenario" "$ddl_sha" "$literal_sha" "$predicate_sha"
    printf '%s\traw-trigger-07\tevidence-binding-receipt\tfault\tactivation/configuration/trigger/command-digests\t%s/%s/%s/%s\n' \
        "$scenario" "$activation_sha" "$configuration_sha" \
        "$trigger_sha" "$command_sha"
} | LC_ALL=C sort > "$raw"

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
if [ "$poisoned" -eq 1 ]; then
    receipt_sources="action-receipts.tsv
$receipt_sources
inventory-retry-after.tsv"
fi
receipt_set="$tmp/receipt-set.tsv"
printf '%s\n' "$receipt_sources" | LC_ALL=C sort |
while IFS= read -r source; do
    file="$artifact_dir/$source"
    printf '%s\t%s\t%s\n' "$source" \
        "$(sha256sum "$file" | awk '{ print $1 }')" \
        "$(wc -c < "$file" | tr -d ' ')"
done > "$receipt_set"

printf '%s\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
    raw-observations.tsv \
    "$(sha256sum "$raw" | awk '{ print $1 }')" \
    "$(wc -c < "$raw" | tr -d ' ')" \
    "$run" "$namespace" "$scenario" \
    "$(sha256sum "$receipt_set" | awk '{ print $1 }')" \
    > "$artifact_dir/raw-seal.tsv"

"$normalizer" "$raw" "$scenario" \
    > "$artifact_dir/normalized-observations.tsv"

awk -F '	' 'BEGIN { OFS = "\t" }
    {
        observation = $2
        sub(/^raw-/, "obs-", observation)
        sub(/-[0-9][0-9]$/, "", observation)
        print $1, $2, "record", $1, observation, "all"
    }
' "$raw" > "$artifact_dir/coverage.tsv"

"$oracle" "$artifact_dir" "$scenario" \
    > "$artifact_dir/oracle-result.tsv"

gate_revision=$(sha256sum "$gate_materializer" | awk '{ print $1 }')
"$gate_materializer" "$artifact_dir" "$scenario" "$gate_revision" \
    > "$artifact_dir/gate-results.tsv"

while IFS='	' read -r name fields cardinality kind source; do
    chmod 644 "$artifact_dir/$name"
done < "$registry"

"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" "$case_id" \
    >/dev/null
