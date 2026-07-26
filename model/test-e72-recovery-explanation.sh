#!/bin/sh
set -eu
root=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec "$root/reference-slice/run-e72-recovery-explanation.sh"
