#!/bin/sh
exec "$(CDPATH= cd "$(dirname "$0")" && pwd)/reference-slice/self-test-negative.sh" E67
