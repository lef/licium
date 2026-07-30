#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
    echo "usage: normalize-bc02.sh RAW_OBSERVATIONS SCENARIO" >&2
    exit 2
}

raw=$1
scenario=$2

awk -F '	' -v scenario="$scenario" 'BEGIN { OFS = "\t" }
    $1 != scenario { exit 1 }
    $2 == "raw-ancestry-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-ancestry", "ancestry", key[2], value[1], value[2]
        next
    }
    $2 == "raw-ancestry-persistence-01" {
        status = ($6 + 0) > 0 ? "committed" : "rolled-back"
        print $1, "obs-ancestry-persistence", "persistence",
            "root-ancestry", status, $6
        next
    }
    $2 == "raw-availability-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-availability", "availability",
            key[2], value[1], value[2]
        next
    }
    $2 == "raw-formation-01" {
        split($6, value, "/")
        print $1, "obs-formation", "formation",
            value[1], value[2], value[3]
        next
    }
    $2 == "raw-failure-reason-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-failure-reason", "failure",
            key[1], value[1], value[2]
        next
    }
    $2 ~ /^raw-attempt-identity-/ {
        split($6, value, "/")
        attempts[++attempt_count] = value[1]
        attempt_request = value[2]
        attempt_root = value[3]
        attempt_scenario = $1
        next
    }
    $2 == "raw-correction-01" {
        split($6, value, "/")
        correction_scenario = $1
        correction_object = value[1]
        correction_outcome = value[2]
        next
    }
    $2 == "raw-correction-02" {
        correction_before = $6
        next
    }
    $2 == "raw-correction-03" {
        correction_after = $6
        next
    }
    $2 == "raw-correction-isolation-01" {
        isolation_scenario = $1
        next
    }
    $2 == "raw-correction-isolation-02" {
        protected_before = $6
        next
    }
    $2 == "raw-correction-isolation-03" {
        protected_after = $6
        next
    }
    $2 == "raw-error-identity-01" {
        split($5, key, "/")
        split($6, value, "/")
        if ($3 == "fault-trigger-receipt") {
            print $1, "obs-error-identity", "fault-error",
                key[2], value[1], value[2]
        } else {
            print $1, "obs-error-identity", "failure",
                key[1], value[1], value[2]
        }
        next
    }
    $2 == "raw-activation-01" {
        split($6, value, "/")
        fault_scenario = $1
        fault_hook = value[1]
        fault_attempt = value[2]
        print $1, "obs-activation", "fault",
            value[1], "armed", value[2]
        next
    }
    $2 ~ /^raw-(ancestry|header|member)-residue-01$/ {
        split($5, key, "/")
        observation = $2
        sub(/^raw-/, "obs-", observation)
        sub(/-01$/, "", observation)
        print $1, observation, "residue", key[1],
            ($6 == 0 ? "absent" : "present"), $6
        next
    }
    $2 == "raw-command-status-01" {
        split($6, value, "/")
        print $1, "obs-command-status", "fault-command",
            value[1], (value[2] + 0 != 0 ? "nonzero" : "zero"), value[2]
        next
    }
    $2 == "raw-failing-connection-health-01" {
        print $1, "obs-failing-connection-health", "sqlite-profile",
            "failing-connection", ($6 == "ok" ? "healthy" : "unhealthy"),
            ($6 == "ok" ? 1 : 0)
        next
    }
    $2 == "raw-fault-availability-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-fault-availability", "availability",
            key[2], value[1], value[2]
        next
    }
    $2 == "raw-fault-outcome-01" {
        fault_outcome_scenario = $1
        fault_error_kind = $6
        next
    }
    $2 == "raw-fault-outcome-02" {
        fault_outcome_scenario = $1
        fault_artifact_count = $6
        next
    }
    $2 ~ /^raw-no-commit-0[12]$/ {
        no_commit_scenario = $1
        split($5, key, "/")
        if ($2 == "raw-no-commit-01") no_commit_before = $6
        else no_commit_after = $6
        next
    }
    $2 == "raw-no-commit-03" {
        no_commit_scenario = $1
        no_commit_custody = $6
        next
    }
    $2 ~ /^raw-retry-commit-0[12]$/ {
        retry_commit_scenario = $1
        if ($2 == "raw-retry-commit-01") retry_commit_before = $6
        else retry_commit_after = $6
        next
    }
    $2 == "raw-retry-commit-03" {
        retry_commit_scenario = $1
        retry_commit_custody = $6
        next
    }
    $2 == "raw-retry-hook-01" {
        split($6, value, "/")
        print $1, "obs-retry-hook", "fault", "retry-hook",
            (value[2] == 0 ? "absent" : "present"),
            (value[2] == 0 ? 1 : 0)
        next
    }
    $2 ~ /^raw-trigger-0[1-7]$/ {
        trigger_scenario = $1
        if ($2 == "raw-trigger-01") {
            split($6, value, "/")
            trigger_hook = value[1]
            trigger_attempt = value[2]
        } else if ($2 == "raw-trigger-02") {
            trigger_true = $6
        } else if ($2 == "raw-trigger-03") {
            trigger_header = $6
        } else if ($2 == "raw-trigger-04") {
            trigger_member = $6
        } else if ($2 == "raw-trigger-05") {
            trigger_ancestry = $6
        } else if ($2 == "raw-trigger-06") {
            trigger_configuration = $6
        } else if ($2 == "raw-trigger-07") {
            trigger_binding = $6
        }
        next
    }
    $2 == "raw-initial-availability-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-initial-availability", "availability",
            key[2], value[1], value[2]
        next
    }
    $2 == "raw-initial-formation-01" {
        split($6, value, "/")
        print $1, "obs-initial-formation", "formation",
            value[1], value[2], value[3]
        next
    }
    $2 == "raw-initial-membership-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-initial-membership", key[1],
            key[2], value[1], value[2] "/" value[3]
        next
    }
    $2 == "raw-initial-rollback-01" {
        initial_rollback_scenario = $1
        initial_setup_sha = $6
        next
    }
    $2 == "raw-initial-rollback-02" {
        initial_rollback_scenario = $1
        initial_rollback_sha = $6
        next
    }
    $2 == "raw-retry-ancestry-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-retry-ancestry", "ancestry",
            key[2], value[1], value[2]
        next
    }
    $2 == "raw-retry-availability-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-retry-availability", "availability",
            key[2], value[1], value[2]
        next
    }
    $2 == "raw-retry-formation-01" {
        split($6, value, "/")
        print $1, "obs-retry-formation", "formation",
            value[1], value[2], value[3]
        next
    }
    $2 == "raw-retry-membership-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-retry-membership", "membership",
            key[2], value[1], value[2] "/" value[3]
        next
    }
    $2 == "raw-header-persistence-01" {
        status = ($6 + 0) > 0 ? "committed" : "rolled-back"
        print $1, "obs-header-persistence", "persistence",
            "root-header", status, $6
        next
    }
    $2 == "raw-member-persistence-01" {
        status = ($6 + 0) > 0 ? "committed" : "rolled-back"
        print $1, "obs-member-persistence", "persistence",
            "root-member", status, $6
        next
    }
    $2 == "raw-membership-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-membership", key[1],
            key[2], value[1], value[2] "/" value[3]
        next
    }
    $2 == "raw-input-shape-01" {
        split($5, key, "/")
        print $1, "obs-input-shape", "input",
            key[1], key[2], $6
        next
    }
    $2 == "raw-reopened-resolution-01" {
        split($5, key, "/")
        split($6, value, "/")
        print $1, "obs-reopened-resolution", "resolution",
            key[2], value[1], value[2]
        next
    }
    $2 == "raw-rollback-01" {
        rollback_scenario = $1
        setup_sha = $6
        next
    }
    $2 == "raw-rollback-02" {
        rollback_scenario = $1
        rollback_sha = $6
        next
    }
    $2 == "raw-source-cardinality-01" {
        split($5, key, "/")
        print $1, "obs-source-cardinality", "input",
            key[1], key[2], $6
        next
    }
    { exit 1 }
    END {
        if (attempt_count > 0) {
            if (attempt_count != 2 || attempts[1] == attempts[2]) exit 1
            print attempt_scenario, "obs-attempt-identity", "provenance",
                attempts[1] "/" attempts[2], "distinct",
                attempt_request "/" attempt_root
        }
        if (correction_scenario != "") {
            if (correction_before == "" || correction_after == "") exit 1
            print correction_scenario, "obs-correction", "correction",
                correction_object, correction_outcome,
                "exact-source-object-delta"
        }
        if (isolation_scenario != "") {
            if (protected_before == "" || protected_after == "") exit 1
            print isolation_scenario, "obs-correction-isolation", "correction",
                "root-request-required-attempt",
                (protected_before == protected_after ? "unchanged" : "changed"),
                (protected_before == protected_after ? 1 : 0)
        }
        if (initial_setup_sha != "" || initial_rollback_sha != "") {
            if (initial_setup_sha == "" || initial_rollback_sha == "") exit 1
            initial_equal = initial_setup_sha == initial_rollback_sha
            print initial_rollback_scenario, "obs-initial-rollback", "rollback",
                "repository",
                (initial_equal ? "unchanged" : "changed"),
                (initial_equal ? 1 : 0)
        }
        if (fault_outcome_scenario != "") {
            if (fault_attempt == "" || fault_error_kind != "injected-rollback" ||
                fault_artifact_count == "") exit 1
            print fault_outcome_scenario, "obs-fault-outcome", "formation",
                fault_attempt, "fault-rollback", "root-02"
        }
        if (no_commit_scenario != "") {
            if (no_commit_before == "" || no_commit_after == "" ||
                no_commit_custody != "held-through-required-stages") exit 1
            print no_commit_scenario, "obs-no-commit", "sqlite-profile",
                "data-version",
                (no_commit_before == no_commit_after ? "unchanged" : "changed"),
                (no_commit_before == no_commit_after ? 1 : 0)
        }
        if (retry_commit_scenario != "") {
            if (retry_commit_before == "" || retry_commit_after == "" ||
                retry_commit_custody != "held-through-required-stages") exit 1
            retry_changed = retry_commit_before != retry_commit_after
            print retry_commit_scenario, "obs-retry-commit", "sqlite-profile",
                "data-version",
                (retry_changed ? "changed" : "unchanged"),
                (retry_changed ? 1 : 0)
        }
        if (trigger_scenario != "") {
            if (trigger_true != "true" || trigger_hook == "" ||
                trigger_attempt == "" || trigger_header == "" ||
                trigger_member == "" || trigger_ancestry == "" ||
                trigger_configuration == "" || trigger_binding == "") exit 1
            phase = trigger_hook
            sub(/^hook-bc02-/, "", phase)
            print trigger_scenario, "obs-trigger", "fault", phase,
                "triggered",
                trigger_header "/" trigger_member "/" trigger_ancestry
        }
        if (setup_sha != "" || rollback_sha != "") {
            if (setup_sha == "" || rollback_sha == "") exit 1
            print rollback_scenario, "obs-rollback", "rollback",
                "repository",
                (setup_sha == rollback_sha ? "unchanged" : "changed"),
                (setup_sha == rollback_sha ? 1 : 0)
        }
    }
' "$raw" | LC_ALL=C sort
