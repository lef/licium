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
    BC04_AMBIENT_FALLBACK)
        marker=BC04_AMBIENT_FALLBACK_DETECTED ;;
    BC04_EXACT_PUBLISHED_COLLAPSE)
        marker=BC04_EXACT_PUBLISHED_COLLAPSE_DETECTED ;;
    BC04_EXACT_READ)
        marker=BC04_EXACT_READ_SUBSTITUTED ;;
    BC04_PUBLISHED_READ)
        marker=BC04_PUBLISHED_READ_SUBSTITUTED ;;
    BC04_UNACCEPTED_AVAILABLE)
        marker=BC04_UNACCEPTED_AVAILABLE_DETECTED ;;
    *)
        exit 2 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

for stage in before after reopened
do
    awk -F '	' -v scenario="$scenario" '$1 == scenario' \
        "$base_dir/bc04-inventory-$stage.tsv" | LC_ALL=C sort \
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
    "$base_dir/bc04-raw-template.tsv" | LC_ALL=C sort >"$tmp/raw.expected"
LC_ALL=C sort "$artifact_dir/raw-observations.tsv" >"$tmp/raw.actual"
cmp -s "$tmp/raw.expected" "$tmp/raw.actual" || {
    echo "$marker" >&2
    exit 1
}

awk -F '	' -v scenario="$scenario" '$1 == scenario' \
    "$base_dir/bc04-normalized-contract.tsv" | LC_ALL=C sort \
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
    $5 == "sut-setup-bc04" { setup++; next }
    { action++ }
    END { if (setup != 1 || action != 1) exit 1 }
' "$artifact_dir/action-receipts.tsv" || {
    echo "$marker" >&2
    exit 1
}

printf '%s\toracle-%s\tPASS\tnorm-bc04-observation\tnormal\t-\n' \
    "$assertion" "$(printf '%s' "$assertion" |
        tr '[:upper:]_' '[:lower:]-')"
