#!/bin/sh
# shellcheck disable=SC1007
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(CDPATH= cd -- "$script_dir/../.." && pwd)
public_repo="$repo/../licium"
if git -C "$public_repo" rev-parse HEAD >/dev/null 2>&1
then
    observed_repo=$public_repo
else
    observed_repo=$repo
fi
state="$script_dir/cases/promotion-state/state.tsv"
verifier="$script_dir/verify-promotion-state-separation.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

public_before=$(
    printf '%s\t%s\t%s\n' \
        "$(git -C "$observed_repo" rev-parse HEAD)" \
        "$(git -C "$observed_repo" rev-parse 'HEAD^{tree}')" \
        "$(git -C "$observed_repo" status --porcelain --untracked-files=all)"
)
"$verifier" >"$tmp/baseline.out" 2>"$tmp/baseline.err"
if [ -s "$tmp/baseline.err" ] ||
    ! grep -F -x -q PROMOTION_STATE_SEPARATION_VALID "$tmp/baseline.out"
then
    echo PI_N12_BASELINE_INVALID >&2
    exit 1
fi
echo 'ok BASELINE'

mkdir "$tmp/home" "$tmp/seed"
git -C "$tmp/seed" init -q
printf 'baseline\n' >"$tmp/seed/artifact.txt"
git -C "$tmp/seed" add artifact.txt
git -C "$tmp/seed" \
    -c user.name=licium-fixture -c user.email=fixture@invalid \
    commit -q -m baseline
git clone -q --bare "$tmp/seed" "$tmp/remote.git"
before=$(git --git-dir="$tmp/remote.git" rev-parse HEAD)
git clone -q "$tmp/remote.git" "$tmp/work"
printf 'mutated\n' >>"$tmp/work/artifact.txt"
git -C "$tmp/work" add artifact.txt
git -C "$tmp/work" \
    -c user.name=licium-fixture -c user.email=fixture@invalid \
    commit -q -m mutation

cat >"$tmp/mutant-workflow.sh" <<'MUTANT'
#!/bin/sh
set -eu
state=$1
work=$2
if [ "$(awk -F '\t' '$1 == "roadmap_acceptance" { print $2 }' \
    "$state")" = accepted ]
then
    git -C "$work" push -q origin HEAD:main
    : >"$PI_N12_REACHABILITY_MARKER"
fi
MUTANT
chmod +x "$tmp/mutant-workflow.sh"
env -i \
    PATH="$PATH" \
    HOME="$tmp/home" \
    LC_ALL=C \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_SYSTEM=/dev/null \
    GIT_CONFIG_GLOBAL=/dev/null \
    GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS=/bin/false \
    PI_N12_REACHABILITY_MARKER="$tmp/reached" \
    "$tmp/mutant-workflow.sh" "$state" "$tmp/work"
after=$(git --git-dir="$tmp/remote.git" rev-parse refs/heads/main)
[ -f "$tmp/reached" ] && [ "$before" != "$after" ] || {
    echo PI_N12_MUTANT_NOT_REACHED >&2
    exit 1
}

set +e
"$verifier" "$state" "$before" "$after" \
    >"$tmp/mutant.out" 2>"$tmp/mutant.err"
inner_status=$?
set -e
[ "$inner_status" -ne 0 ] || {
    echo PI_N12_MUTANT_NOT_REJECTED >&2
    exit 1
}
[ "$(grep -F -x -c PROMOTION_STATE_COLLAPSE \
    "$tmp/mutant.err")" -eq 1 ] || {
    echo PI_N12_TARGET_MARKER_INVALID >&2
    exit 1
}
[ ! -s "$tmp/mutant.out" ] || {
    echo PI_N12_UNEXPECTED_MUTANT_STDOUT >&2
    exit 1
}

public_after=$(
    printf '%s\t%s\t%s\n' \
        "$(git -C "$observed_repo" rev-parse HEAD)" \
        "$(git -C "$observed_repo" rev-parse 'HEAD^{tree}')" \
        "$(git -C "$observed_repo" status --porcelain --untracked-files=all)"
)
[ "$public_before" = "$public_after" ] || {
    echo PI_N12_REAL_PUBLIC_STATE_CHANGED >&2
    exit 1
}

printf '%s\n' \
    "receipt control=PI-N12 class=workflow mutation=roadmap-acceptance-authorizes-push inner_status=$inner_status marker=PROMOTION_STATE_COLLAPSE marker_count=1 target_gate=yes reachability=isolated-remote-head-advanced observed_repository_unchanged=yes isolated_remote_only=yes external_network_used=no credentials=isolated-home" \
    'ok PI-N12' \
    'PI_N12_SELF_TEST_VALID 1 baseline 1 control'
