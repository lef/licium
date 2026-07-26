#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
db=$1
"$here/slice.sh" apply-effect "$db" effect-1 state-0 result-1 transition-1 observation-1 state-1 view-effect-1 none
"$here/slice.sh" apply-effect "$db" effect-1 state-0 result-1 transition-retry observation-retry state-2 view-retry none
"$here/slice.sh" apply-effect "$db" effect-incomplete state-1 result-incomplete transition-incomplete observation-incomplete state-2 view-incomplete none
"$here/slice.sh" apply-effect "$db" effect-stale state-0 result-1 transition-stale observation-stale state-2 view-stale none
