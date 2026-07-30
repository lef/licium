#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
adapter="$base_dir/profiles/sqlite-reference/run.sh"
normalizer="$script_dir/normalize-bc12.sh"
oracle="$script_dir/oracle-bc12.sh"
verifier="$script_dir/verify-bc12-runtime.sh"

[ "$#" -ge 4 ] && [ "$#" -le 5 ] || exit 2
artifact_dir=$1
run=$2
namespace=$3
assertion=$4
mode=${5:-ordinary}

case_row=$(
    awk -F '	' -v assertion="$assertion" '
        $1 == assertion { print $3 FS $4; found++ }
        END { if (found != 1) exit 1 }
    ' "$base_dir/bc12-cases.tsv"
) || exit 2
surface=${case_row%%	*}
operation=${case_row#*	}
scenario=$(
    awk -F '	' -v assertion="$assertion" '
        $1 == assertion { print $3; found++ }
        END { if (found != 1) exit 1 }
    ' "$base_dir/bc12-scenario-ids.tsv"
) || exit 2

case "$assertion:$mode" in
    BC12_*:ordinary|\
    BC12_ARCHIVE_BYPASS:mutant-detect-archive-state-bypass|\
    BC12_CANONICAL_UNCHANGED:mutant-detect-placement-inventory-change|\
    BC12_DECISION_PROVENANCE:mutant-detect-decision-provenance-loss|\
    BC12_DERIVED_PROTECTION:mutant-detect-protection-derivation-loss|\
    BC12_ELIGIBILITY_DELETE:mutant-detect-eligibility-as-delete|\
    BC12_FORGET_BYPASS:mutant-detect-forget-bypass|\
    BC12_FORGET_CONSUMED:mutant-detect-unconsumed-forget|\
    BC12_NOOP_EVALUATOR:mutant-detect-noop-placement-evaluator|\
    BC12_PLACEMENT_DECISION:mutant-detect-placement-decision-loss|\
    BC12_PROTECTION_BYPASS:mutant-detect-protection-bypass-witness|\
    BC12_PROTECTION_BYPASS:mutant-detect-protection-bypass-conflict|\
    BC12_PROTECTION_BYPASS:mutant-detect-protection-bypass-publication|\
    BC12_WINDOW_BYPASS:mutant-detect-policy-window-bypass) ;;
    *) exit 2 ;;
esac

[ ! -e "$artifact_dir" ] || {
    echo BC12_RUNTIME_NOT_FRESH >&2
    exit 1
}
mkdir -p "$artifact_dir"
db="$artifact_dir/$namespace.db"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; rm -f "$db"' EXIT HUP INT TERM

: >"$artifact_dir/command-receipts.tsv"
: >"$artifact_dir/pragma.tsv"
: >"$artifact_dir/exclusions.tsv"
: >"$artifact_dir/fault-markers.tsv"

invoke()
{
    phase=$1
    command_operation=$2
    command_mode=$3
    stdout=$4
    stderr=$5
    shift 5
    argv_sha=$(
        for argument in "$@"
        do
            case "$argument" in
                "$adapter") printf '%s\n' '{adapter-entrypoint}' ;;
                "$db") printf '%s\n' '{database-path}' ;;
                "$artifact_dir/"*)
                    printf '%s\n' "{artifact-path:${argument##*/}}" ;;
                "$tmp/"*)
                    printf '%s\n' "{temporary-path:${argument##*/}}" ;;
                *) printf '%s\n' "$argument" ;;
            esac
        done | sha256sum | awk '{ print $1 }'
    )
    set +e
    "$@" >"$stdout" 2>"$stderr"
    status=$?
    set -e
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$run" "$namespace" "$assertion" "$phase" "$command_operation" \
        "$command_mode" "$status" \
        "$(sha256sum "$stdout" | awk '{ print $1 }')" \
        "$(wc -c <"$stdout" | tr -d ' ')" \
        "$(sha256sum "$stderr" | awk '{ print $1 }')" \
        "$(wc -c <"$stderr" | tr -d ' ')" "$argv_sha" \
        >>"$artifact_dir/command-receipts.tsv"
    [ "$status" -eq 0 ] || {
        sed -n '1,$p' "$stderr" >&2
        exit "$status"
    }
    if [ "$phase" != destroy ]; then
        [ "$(cat "$stderr")" = "pragma	foreign-keys	1" ] || {
            echo BC12_PRAGMA_EVIDENCE_INVALID >&2
            exit 1
        }
        printf '%s\t%s\t%s\t%s\tforeign-keys\t1\n' \
            "$run" "$namespace" "$assertion" "$phase" \
            >>"$artifact_dir/pragma.tsv"
    elif [ -s "$stderr" ]; then
        echo BC12_COMMAND_CUSTODY_INVALID >&2
        exit 1
    fi
}

invoke create profile-create-namespace normal "$tmp/create.out" \
    "$tmp/create.err" "$adapter" create-bc12 "$namespace" "$db"
invoke setup sut-setup-bc12 ordinary "$tmp/setup.out" "$tmp/setup.err" \
    "$adapter" operation-bc12 "$db" "$run" "$namespace" "$scenario" \
    "$assertion" setup sut-setup-bc12 ordinary "setup-$run"
invoke action "$operation" "$mode" \
    "$artifact_dir/action-receipts.tsv" "$tmp/action.err" \
    "$adapter" operation-bc12 "$db" "$run" "$namespace" "$scenario" \
    "$assertion" "$surface" "$operation" "$mode" "action-$run"
invoke reopen profile-reopen-namespace normal "$tmp/reopen.out" \
    "$tmp/reopen.err" "$adapter" reopen "$db" "$run" "$namespace" \
    "$assertion"
invoke observe profile-observe-bc12 ordinary \
    "$artifact_dir/raw-observations.tsv" "$tmp/observe.err" \
    "$adapter" observe-bc12 "$db" "$scenario" "$surface"

chmod 0644 "$artifact_dir/action-receipts.tsv" \
    "$artifact_dir/raw-observations.tsv"
raw_sha=$(sha256sum "$artifact_dir/raw-observations.tsv" | awk '{ print $1 }')
raw_bytes=$(wc -c <"$artifact_dir/raw-observations.tsv" | tr -d ' ')
receipt_sha=$(sha256sum "$artifact_dir/action-receipts.tsv" |
    awk '{ print $1 }')
printf 'raw-observations.tsv\t100644\t%s\t%s\t%s\t%s\t%s\t%s\tsealed-before-normalization\n' \
    "$raw_sha" "$raw_bytes" "$run" "$namespace" "$scenario" \
    "$receipt_sha" >"$artifact_dir/raw-seal.tsv"

invoke destroy profile-destroy-namespace normal "$tmp/destroy.out" \
    "$tmp/destroy.err" "$adapter" destroy "$namespace" "$db"

"$normalizer" "$artifact_dir/raw-observations.tsv" "$scenario" \
    >"$artifact_dir/normalized-observations.tsv"
awk -F '	' 'BEGIN { OFS=FS }
    {
        normalized=$2
        sub(/^raw-/, "obs-", normalized)
        print $1,$2,"record",$1,normalized,"all"
    }
' "$artifact_dir/raw-observations.tsv" >"$artifact_dir/coverage.tsv"

"$oracle" "$artifact_dir/normalized-observations.tsv" "$assertion" \
    "$scenario" "$mode" "$artifact_dir/oracle-result.tsv"

chmod 0644 "$artifact_dir"/*.tsv
"$verifier" "$artifact_dir" "$run" "$namespace" "$assertion" "$scenario"
echo BC12_RUNTIME_VALID
