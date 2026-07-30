#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$script_dir/../.." && pwd)
public_repo="$repo/../licium"
roadmap_readme="$repo/publication/protocol-integration-roadmap/source/README.md"
if [ -f "$roadmap_readme" ]
then
    layout=private-roadmap
    readme=$roadmap_readme
else
    layout=public-sample
    readme="$repo/README.md"
fi
verifier="$script_dir/verify-public-claim-ceiling.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

candidate_before=$(sha256sum "$readme" | cut -d' ' -f1)
if [ "$layout" = private-roadmap ]
then
    public_before=$(
        printf '%s\t%s\t%s\n' \
            "$(git -C "$public_repo" rev-parse HEAD)" \
            "$(git -C "$public_repo" rev-parse refs/remotes/origin/main)" \
            "$(git -C "$public_repo" status --porcelain --untracked-files=all)"
    )
else
    public_before=$candidate_before
fi
"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q PUBLIC_CLAIM_CEILING_VALID "$tmp/baseline.out"
then
    echo PI_N10_N11_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

awk '
    $0 == "- The planned milestone is not a production IdP commitment." {
        print "- The planned milestone is a production-ready OIDC-certified IdP."
        changed = 1
        next
    }
    $0 == "- This remains a synthetic, disposable, non-production slice. It does not make" {
        print "- This finite sample is a production-ready OIDC-certified IdP."
        changed = 1
        next
    }
    { print }
    END { exit !changed }
' "$readme" >"$tmp/pi-n10.md"
grep -E -q \
    'planned milestone is a production-ready|finite sample is a production-ready' \
    "$tmp/pi-n10.md" || {
    echo PI_N10_MUTANT_NOT_BUILT >&2
    exit 1
}
set +e
"$verifier" "$tmp/pi-n10.md" >"$tmp/pi-n10.out" 2>"$tmp/pi-n10.err"
n10_status=$?
set -e
[ "$n10_status" -ne 0 ] &&
    [ "$(grep -F -x -c PUBLIC_OVERCLAIM "$tmp/pi-n10.err")" -eq 1 ] &&
    [ ! -s "$tmp/pi-n10.out" ] || {
    echo PI_N10_MUTANT_NOT_REJECTED >&2
    exit 1
}
echo 'ok PI-N10'

awk '
    {
        if ($0 ~ /^- Rust is a future replacement/) {
            sub(/Rust is a future replacement/, "Rust is a current implementation")
            changed = 1
        }
        if ($0 == "  establish arbitrary-backend portability, or implement Spanner or Rust.") {
            print "  establish arbitrary-backend portability, or implements Spanner and is a current Rust implementation."
            changed = 1
            next
        }
        print
    }
    END { exit !changed }
' "$readme" >"$tmp/pi-n11.md"
grep -E -q 'Rust is a current implementation|current Rust implementation' \
    "$tmp/pi-n11.md" || {
    echo PI_N11_MUTANT_NOT_BUILT >&2
    exit 1
}
set +e
"$verifier" "$tmp/pi-n11.md" >"$tmp/pi-n11.out" 2>"$tmp/pi-n11.err"
n11_status=$?
set -e
[ "$n11_status" -ne 0 ] &&
    [ "$(grep -F -x -c RUST_EXISTENCE_OVERCLAIM \
        "$tmp/pi-n11.err")" -eq 1 ] &&
    [ ! -s "$tmp/pi-n11.out" ] || {
    echo PI_N11_MUTANT_NOT_REJECTED >&2
    exit 1
}
echo 'ok PI-N11'

candidate_after=$(sha256sum "$readme" | cut -d' ' -f1)
if [ "$layout" = private-roadmap ]
then
    public_after=$(
        printf '%s\t%s\t%s\n' \
            "$(git -C "$public_repo" rev-parse HEAD)" \
            "$(git -C "$public_repo" rev-parse refs/remotes/origin/main)" \
            "$(git -C "$public_repo" status --porcelain --untracked-files=all)"
    )
else
    public_after=$candidate_after
fi
[ "$candidate_before" = "$candidate_after" ] &&
    [ "$public_before" = "$public_after" ] || {
    echo PI_N10_N11_REAL_PUBLIC_STATE_CHANGED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N10 class=prose mutation=production-oidc-certified-claim inner_status=$n10_status marker=PUBLIC_OVERCLAIM marker_count=1 target_gate=yes reachability=exact-roadmap-paragraph public_state_unchanged=yes" \
    "receipt control=PI-N11 class=prose mutation=current-rust-implementation-claim inner_status=$n11_status marker=RUST_EXISTENCE_OVERCLAIM marker_count=1 target_gate=yes reachability=exact-roadmap-paragraph public_state_unchanged=yes" \
    'PI_N10_N11_SELF_TEST_VALID 1 baseline 2 controls'
