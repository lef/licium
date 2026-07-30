#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
capabilities="$base_dir/capability-registry.tsv"
faults="$base_dir/fault-hooks.tsv"
operations="$base_dir/operation-registry.tsv"

fail() {
    echo "$1" >&2
    exit 1
}

[ "$#" -eq 1 ] || {
    echo "usage: verify-profile.sh PROFILE_DIR" >&2
    exit 2
}

profile_dir=$1
profile=${LICIUM_PROFILE_FILE:-"$profile_dir/profile.tsv"}
adapter="$profile_dir/run.sh"

[ -f "$profile" ] || fail "PROFILE_MISSING"
[ -x "$adapter" ] || fail "PROFILE_ENTRYPOINT_MISSING"

LC_ALL=C sort -c "$profile" 2>/dev/null || fail "PROFILE_ORDER_INVALID"

awk -F '	' '
    NF != 4 { exit 1 }
    $1 !~ /^(capability|closure|fault-hook|lifecycle|pragma|profile|tool)$/ { exit 1 }
    $2 !~ /^[a-z0-9][a-z0-9-]*$/ { exit 1 }
    $3 !~ /^[a-z0-9][a-z0-9-]*$/ { exit 1 }
    $4 == "" { exit 1 }
    seen[$1 SUBSEP $2 SUBSEP $3]++ { exit 1 }
' "$profile" || fail "PROFILE_SHAPE_INVALID"

awk -F '	' '
    NR == FNR { required[$1] = 1; next }
    $1 == "capability" {
        if ($3 != "status" ||
            ($4 != "planned" && $4 != "supported" && $4 != "unsupported"))
            exit 1
        if (!($2 in required) || seen[$2]++) exit 1
        count++
    }
    END {
        if (count != 12) exit 1
        for (id in required) if (seen[id] != 1) exit 1
    }
' "$capabilities" "$profile" || fail "PROFILE_CAPABILITY_INVENTORY_INVALID"

awk -F '	' '
    NR == FNR { required[$1] = 1; next }
    $1 == "fault-hook" {
        if ($3 != "status" || ($4 != "planned" && $4 != "supported")) exit 1
        if (!($2 in required) || seen[$2]++) exit 1
        count++
    }
    END {
        if (count != 12) exit 1
        for (id in required) if (seen[id] != 1) exit 1
    }
' "$faults" "$profile" || fail "PROFILE_FAULT_INVENTORY_INVALID"

awk -F '	' '
    $1 == "profile" { actual[$2 SUBSEP $3 SUBSEP $4] = 1; count++ }
    END {
        required["backend-kind" SUBSEP "value" SUBSEP "sqlite"] = 1
        required["entrypoint" SUBSEP "value" SUBSEP "run.sh"] = 1
        required["execution-mode" SUBSEP "value" SUBSEP "test-only-single-host"] = 1
        required["profile-id" SUBSEP "value" SUBSEP "sqlite-reference-v0"] = 1
        required["schema-version" SUBSEP "value" SUBSEP "0"] = 1
        if (count != 5) exit 1
        for (row in required) if (actual[row] != 1) exit 1
        for (row in actual) if (!(row in required)) exit 1
    }
' "$profile" || fail "PROFILE_METADATA_INVALID"

awk -F '	' '
    $1 == "closure" { actual[$2 SUBSEP $3 SUBSEP $4] = 1; count++ }
    END {
        required["adapter" SUBSEP "manifest" SUBSEP "closure-manifests/adapter.paths"] = 1
        required["profile" SUBSEP "manifest" SUBSEP "closure-manifests/profile.paths"] = 1
        required["runner" SUBSEP "manifest" SUBSEP "closure-manifests/runner.paths"] = 1
        required["sut" SUBSEP "manifest" SUBSEP "closure-manifests/sut.paths"] = 1
        if (count != 4) exit 1
        for (row in required) if (actual[row] != 1) exit 1
        for (row in actual) if (!(row in required)) exit 1
    }
' "$profile" || fail "PROFILE_CLOSURE_INVENTORY_INVALID"

awk -F '	' '
    NR == FNR { owner[$1] = $2; next }
    $1 == "lifecycle" {
        if ($3 != "operation" || !($4 in owner) || owner[$4] != "profile") exit 1
        seen[$2]++
    }
    END {
        required["create-namespace"] = 1
        required["destroy-namespace"] = 1
        required["reopen-namespace"] = 1
        if (seen["create-namespace"] != 1 ||
            seen["destroy-namespace"] != 1 ||
            seen["reopen-namespace"] != 1 ||
            seen["run-scenario"] != 1) exit 1
    }
' "$operations" "$profile" || fail "PROFILE_LIFECYCLE_INVALID"

awk -F '	' '
    $1 == "pragma" && $2 == "foreign-keys" && $3 == "value" && $4 == "on" {
        found++
    }
    END { if (found != 1) exit 1 }
' "$profile" || fail "PROFILE_PRAGMA_INVALID"

awk -F '	' '
    $1 == "tool" {
        if ($3 != "command") exit 1
        required[$2] = $4
        count++
    }
    END {
        if (count != 18 ||
            required["awk"] != "awk" ||
            required["cat"] != "cat" ||
            required["chmod"] != "chmod" ||
            required["cmp"] != "cmp" ||
            required["cp"] != "cp" ||
            required["dirname"] != "dirname" ||
            required["find"] != "find" ||
            required["ln"] != "ln" ||
            required["mkdir"] != "mkdir" ||
            required["mktemp"] != "mktemp" ||
            required["rm"] != "rm" ||
            required["sed"] != "sed" ||
            required["sh"] != "sh" ||
            required["sha256sum"] != "sha256sum" ||
            required["sort"] != "sort" ||
            required["sqlite3"] != "sqlite3" ||
            required["tr"] != "tr" ||
            required["wc"] != "wc") exit 1
    }
' "$profile" || fail "PROFILE_TOOL_INVENTORY_INVALID"

for tool in awk cat chmod cmp cp dirname find ln mkdir mktemp rm sed sh sha256sum sort sqlite3 tr wc
do
    command -v "$tool" >/dev/null 2>&1 || fail "PROFILE_REQUIRED_TOOL_MISSING"
done

closure_tmp=$(mktemp -d)
trap 'rm -rf "$closure_tmp"' EXIT HUP INT TERM
cat \
    "$base_dir/closure-manifests/adapter.paths" \
    "$base_dir/closure-manifests/profile.paths" \
    "$base_dir/closure-manifests/runner.paths" \
    "$base_dir/closure-manifests/sut.paths" |
    LC_ALL=C sort >"$closure_tmp/declared"
{
    printf '%s\n' "$base_dir/report-schema.tsv"
    find \
        "$base_dir/profiles/sqlite-reference" \
        "$base_dir/runner" \
        "$base_dir/sqlite-reference" \
        \( -type f -o -type l \) -print
} |
    while IFS= read -r file
    do
        printf '%s\n' "${file#"$base_dir/"}"
    done |
    LC_ALL=C sort >"$closure_tmp/actual"
cmp -s "$closure_tmp/declared" "$closure_tmp/actual" ||
    fail "PROFILE_CLOSURE_COVERAGE_INVALID"

adapter_digest=$("$script_dir/closure-digest.sh" "closure-manifests/adapter.paths") ||
    fail "PROFILE_CLOSURE_INVALID"
profile_digest=$("$script_dir/closure-digest.sh" "closure-manifests/profile.paths") ||
    fail "PROFILE_CLOSURE_INVALID"
runner_digest=$("$script_dir/closure-digest.sh" "closure-manifests/runner.paths") ||
    fail "PROFILE_CLOSURE_INVALID"
sut_digest=$("$script_dir/closure-digest.sh" "closure-manifests/sut.paths") ||
    fail "PROFILE_CLOSURE_INVALID"

description="$closure_tmp/description.tsv"
"$adapter" describe >"$description" || fail "PROFILE_DESCRIBE_FAILED"

awk -F '	' \
    -v adapter_digest="$adapter_digest" \
    -v profile_digest="$profile_digest" \
    -v runner_digest="$runner_digest" \
    -v sut_digest="$sut_digest" '
    NF != 4 { exit 1 }
    $1 != "meta" && $1 != "binding" { exit 1 }
    seen[$1 SUBSEP $2 SUBSEP $3]++ { exit 1 }
    { value[$1 SUBSEP $2 SUBSEP $3] = $4 }
    $1 == "binding" && ($2 != "closure" || $4 !~ /^[0-9a-f]{64}$/) { exit 1 }
    END {
        if (seen["meta" SUBSEP "global" SUBSEP "profile-id"] != 1 ||
            seen["meta" SUBSEP "global" SUBSEP "backend-kind"] != 1 ||
            seen["meta" SUBSEP "global" SUBSEP "execution-status"] != 1 ||
            seen["meta" SUBSEP "runtime" SUBSEP "sqlite-version"] != 1 ||
            seen["binding" SUBSEP "closure" SUBSEP "adapter"] != 1 ||
            seen["binding" SUBSEP "closure" SUBSEP "profile"] != 1 ||
            seen["binding" SUBSEP "closure" SUBSEP "runner"] != 1 ||
            seen["binding" SUBSEP "closure" SUBSEP "sut"] != 1) exit 1
        if (value["meta" SUBSEP "global" SUBSEP "profile-id"] != "sqlite-reference-v0" ||
            value["meta" SUBSEP "global" SUBSEP "backend-kind"] != "sqlite" ||
            value["meta" SUBSEP "global" SUBSEP "execution-status"] != "bc01-bc12-supported" ||
            value["meta" SUBSEP "runtime" SUBSEP "sqlite-version"] == "" ||
            value["binding" SUBSEP "closure" SUBSEP "adapter"] != adapter_digest ||
            value["binding" SUBSEP "closure" SUBSEP "profile"] != profile_digest ||
            value["binding" SUBSEP "closure" SUBSEP "runner"] != runner_digest ||
            value["binding" SUBSEP "closure" SUBSEP "sut"] != sut_digest) exit 1
        compile_options = 0
        for (key in seen)
            if (key ~ /^meta/ &&
                key ~ /runtime/ &&
                key ~ /sqlite-compile-option-/)
                compile_options++
        if (compile_options == 0) exit 1
    }
' "$description" || fail "PROFILE_DESCRIPTION_INVALID"

echo "PROFILE_STRUCTURALLY_VALID"
