#!/bin/sh
set -eu

[ "$#" -eq 3 ] || {
    echo "usage: normalize-bc01.sh RAW_TSV RECEIPTS_TSV SCENARIO" >&2
    exit 2
}

raw=$1
receipts=$2
scenario=$3

LC_ALL=C awk -F '	' -v OFS='	' -v scenario="$scenario" '
    FILENAME == ARGV[1] {
        if (NF != 6 || $1 != scenario || raw_seen[$2]++) exit 1
        relation[$2] = $3
        phase[$2] = $4
        key[$2] = $5
        value[$2] = $6
        if ($3 == "association-projection" && $4 == "after")
            association_count++
        if ($3 == "delivery" && $4 == "after")
            delivery_count++
        if ($3 == "occurrence" && $4 == "after")
            occurrence_count++
        if ($3 == "occurrence-subject" && $4 == "after")
            occurrence_subject[$5] = $6
        if ($3 == "occurrence-logical-value" && $4 == "after")
            occurrence_value[$5] = $6
        next
    }
    FILENAME == ARGV[2] {
        if (NF != 13 || $1 == "" || $2 == "" || $3 != scenario) exit 1
        if ($5 == "sut-setup-bc01") {
            setup_count++
            next
        }
        action_count++
        action_operation = $5
        action_outcome = $6
        action_error = $7
        action_delivery = $8
        action_occurrence = $9
        action_subject = $10
        action_value = $11
        action_effect = $12
        next
    }
    END {
        if (setup_count != 1 || action_count != 1) exit 1

        if (scenario ~ /association-idempotent|retry-duplication/) {
            print scenario,"obs-001","execution",action_delivery,
                  action_outcome,action_operation
            print scenario,"obs-002","cardinality","logical-association",
                  "exact",association_count
            print scenario,"obs-003","cardinality","accepted-occurrence",
                  "exact",occurrence_count
            print scenario,"obs-004","cardinality","accepted-delivery",
                  "exact",delivery_count
            print scenario,"obs-005","provenance",key["raw-009"],
                  "bound",value["raw-009"]
            print scenario,"obs-006","persistent-effect","repository",
                  action_effect,action_effect == "unchanged" ? 0 : 1
            exit 0
        }

        if (scenario ~ /distinct-occurrence|occurrence-collapse/) {
            pair_count = 0
            for (occurrence in occurrence_subject)
                if (occurrence_subject[occurrence] == "alice" &&
                    occurrence_value[occurrence] == "public-a")
                    pair_count++
            print scenario,"obs-001","execution",action_delivery,
                  action_outcome,action_operation
            print scenario,"obs-002","cardinality","logical-association",
                  "exact",association_count
            print scenario,"obs-003","cardinality","accepted-occurrence",
                  "exact",occurrence_count
            print scenario,"obs-004","cardinality","accepted-delivery",
                  "exact",delivery_count
            print scenario,"obs-005","provenance",key["raw-011"],
                  "bound",value["raw-011"]
            print scenario,"obs-006","provenance",key["raw-012"],
                  "bound",value["raw-012"]
            print scenario,"obs-007","multiplicity","alice-public-a",
                  "exact",pair_count
            print scenario,"obs-008","persistent-effect",
                  "accepted-occurrence",action_effect,
                  action_effect == "inserted" ? 1 : 0
            exit 0
        }

        if (scenario ~ /payload-collision/) {
            print scenario,"obs-001","execution",action_delivery,
                  action_outcome,action_operation
            print scenario,"obs-002","error",action_delivery,
                  action_error,"action"
            print scenario,"obs-003","cardinality","logical-association",
                  "exact",association_count
            print scenario,"obs-004","cardinality","accepted-occurrence",
                  "exact",occurrence_count
            print scenario,"obs-005","cardinality","accepted-delivery",
                  "exact",delivery_count
            print scenario,"obs-006","provenance",key["raw-010"],
                  "bound",value["raw-010"]
            print scenario,"obs-007","accepted-collision",key["raw-011"],
                  value["raw-011"] == 0 ? "empty" : "present",
                  value["raw-011"]
            print scenario,"obs-008","persistent-effect","repository",
                  action_effect,action_effect == "unchanged" ? 0 : 1
            print scenario,"obs-009","payload",key["raw-012"],
                  "preserved",value["raw-012"]
            exit 0
        }
        exit 1
    }
' "$raw" "$receipts"
