#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
db=$1
"$here/prepare-e69.sh" "$db"
"$here/slice.sh" apply-effect "$db" effect-1 state-0 result-1 transition-1 observation-1 state-1 view-effect-1 none >/dev/null
