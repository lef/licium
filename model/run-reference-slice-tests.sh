#!/bin/sh
set -eu
root=$(CDPATH= cd "$(dirname "$0")" && pwd)
for e in 67 68 69 70 71 72
do
    case $e in
        67) name=durable-lifecycle ;;
        68) name=published-evaluation ;;
        69) name=pure-read-view ;;
        70) name=observed-effect ;;
        71) name=restart-replay ;;
        72) name=recovery-explanation ;;
    esac
    sh "$root/test-e$e-$name.sh"
    sh "$root/self-test-e$e-$name.sh"
done
echo '6 reference-slice targeted tests and 25 negative identities passed'
