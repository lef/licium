#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

[ "$#" -eq 6 ] || exit 2
artifact_dir=$1
run=$2
namespace=$3
assertion=$4
case_id=$5
scenario=$6

case "$assertion" in
    BC05_AMBIENT_ADVANCE)
        marker=BC05_AMBIENT_ADVANCE_DETECTED ;;
    BC05_BINDING_OMISSION)
        marker=BC05_BINDING_OMISSION_DETECTED ;;
    BC05_COMPLETE_CLOSURE)
        marker=BC05_INCOMPLETE_CLOSURE_ACCEPTED ;;
    BC05_DEFINITION_OMISSION)
        marker=BC05_DEFINITION_OMISSION_DETECTED ;;
    BC05_MISSING_AS_EMPTY)
        marker=BC05_MISSING_AS_EMPTY_DETECTED ;;
    BC05_PINNED_KNOWLEDGE_CUT)
        marker=BC05_KNOWLEDGE_CUT_DRIFT_DETECTED ;;
    BC05_ROOT_OMISSION)
        marker=BC05_ROOT_OMISSION_DETECTED ;;
    BC05_SEMANTICS_OMISSION)
        marker=BC05_SEMANTICS_OMISSION_DETECTED ;;
    BC05_TRANSITIVE_OMISSION)
        marker=BC05_TRANSITIVE_OMISSION_DETECTED ;;
    *)
        exit 2 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for stage in before after reopened
do
    awk -F '	' -v scenario="$scenario" '$1 == scenario' \
        "$base_dir/bc05-inventory-$stage.tsv" | LC_ALL=C sort \
        >"$tmp/inventory-$stage.expected"
    LC_ALL=C sort "$artifact_dir/inventory-$stage.tsv" \
        >"$tmp/inventory-$stage.actual"
    cmp -s "$tmp/inventory-$stage.expected" \
        "$tmp/inventory-$stage.actual" || {
            echo "$marker" >&2
            exit 1
        }
done

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc05-raw-template.tsv" | LC_ALL=C sort >"$tmp/raw.expected"
LC_ALL=C sort "$artifact_dir/raw-observations.tsv" >"$tmp/raw.actual"
cmp -s "$tmp/raw.expected" "$tmp/raw.actual" || {
    echo "$marker" >&2
    exit 1
}

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc05-normalized-contract.tsv" | LC_ALL=C sort \
    >"$tmp/normalized.expected"
LC_ALL=C sort "$artifact_dir/normalized-observations.tsv" \
    >"$tmp/normalized.actual"
cmp -s "$tmp/normalized.expected" "$tmp/normalized.actual" || {
    echo "$marker" >&2
    exit 1
}

awk -F '	' -v run="$run" -v ns="$namespace" -v scenario="$scenario" \
    -v case_id="$case_id" '
    NF != 13 || $1 != run || $2 != ns || $3 != scenario ||
        $4 != case_id { exit 1 }
    $5 == "sut-setup-bc05" { setup++; next }
    { action++ }
    END { if (setup != 1 || action != 1) exit 1 }
' "$artifact_dir/action-receipts.tsv" || {
    echo "$marker" >&2
    exit 1
}

printf '%s\toracle-%s\tPASS\tnorm-bc05-observation\tnormal\t-\n' \
    "$assertion" "$(printf '%s' "$assertion" |
        tr '[:upper:]_' '[:lower:]-')"
