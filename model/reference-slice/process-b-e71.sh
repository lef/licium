#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
db=$1
test -f "$db"
"$here/slice.sh" seed-e71-current-and-replay "$db"
