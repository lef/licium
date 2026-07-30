#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$script_dir/../.." && pwd)
state=${1:-"$script_dir/cases/promotion-state/state.tsv"}
if [ "$#" -ge 2 ]
then
    before=$2
elif git -C "$repo/../licium" rev-parse refs/remotes/origin/main \
    >/dev/null 2>&1
then
    before=$(git -C "$repo/../licium" rev-parse refs/remotes/origin/main)
else
    before=$(git -C "$repo" rev-parse HEAD)
fi
after=${3:-$before}

awk -F '\t' '
    NF != 2 || $1 == "" || $2 == "" { exit 1 }
    seen[$1]++ { exit 1 }
    END {
        if (NR != 5) exit 1
        if (!seen["roadmap_acceptance"] ||
            !seen["artifact_countersign"] ||
            !seen["local_preparation_authorized"] ||
            !seen["local_commit_reviewed"] ||
            !seen["public_push_authorized"]) exit 1
    }
' "$state" || {
    echo PROMOTION_STATE_INVALID >&2
    exit 1
}
value()
{
    awk -F '\t' -v key="$1" '$1 == key { print $2 }' "$state"
}
[ "$(value roadmap_acceptance)" = accepted ] || {
    echo PROMOTION_STATE_INVALID >&2
    exit 1
}
for key in artifact_countersign local_preparation_authorized \
    local_commit_reviewed public_push_authorized
do
    [ "$(value "$key")" = no ] || {
        echo PROMOTION_STATE_INVALID >&2
        exit 1
    }
done
if [ "$before" != "$after" ]
then
    echo PROMOTION_STATE_COLLAPSE >&2
    exit 1
fi

echo PROMOTION_STATE_SEPARATION_VALID
