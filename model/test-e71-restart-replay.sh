#!/bin/sh
set -eu
root=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec "$root/reference-slice/run-e71-restart-replay.sh"
