#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
db=$1
"$here/prepare-e67.sh" "$db"
"$here/slice.sh" seed-e68 "$db"
