#!/bin/sh
set -eu
here=$(CDPATH= cd "$(dirname "$0")" && pwd)
db=$1
"$here/prepare-e68.sh" "$db"
"$here/slice.sh" seed-e69 "$db"
"$here/slice.sh" seed-e70 "$db"
