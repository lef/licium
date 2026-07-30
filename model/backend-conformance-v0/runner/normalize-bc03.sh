#!/bin/sh
set -eu

[ "$#" -eq 3 ] || {
    echo "usage: normalize-bc03.sh RAW_TSV RECEIPTS_TSV SCENARIO" >&2
    exit 2
}

raw=$1
receipts=$2
scenario=$3

LC_ALL=C awk -F '	' -v OFS='	' -v scenario="$scenario" '
    FILENAME == ARGV[1] {
        if (NF != 6 || $1 != scenario || seen[$2]++) exit 1
        source[$2] = $3
        key[$2] = $5
        value[$2] = $6
        next
    }
    FILENAME == ARGV[2] {
        if (NF != 13 || $3 != scenario) exit 1
        if ($5 == "sut-setup-bc03") {
            setup++
            next
        }
        action++
        action_operation = $5
        action_root = $8
        action_publication = $9
        action_authority = $10
        next
    }
    END {
        if (setup != 1 || action != 1 || value["raw-001"] == "") exit 1

        if (scenario ~ /accepted-head|publication-separate/) {
            print scenario,"obs-001","execution",value["raw-004"],
                  "result",value["raw-001"]
            print scenario,"obs-002","stored-root",value["raw-002"],
                  "availability",value["raw-003"]
            print scenario,"obs-003","publication",value["raw-004"],
                  "authority-domain",value["raw-005"]
            print scenario,"obs-004","publication",value["raw-004"],
                  "proposed-root",value["raw-006"]
            print scenario,"obs-005","publication-decision",value["raw-004"],
                  "state",value["raw-007"]
            if (value["raw-008"] == "present")
                print scenario,"obs-006","authority-head",
                      substr(source["raw-008"], 14),
                      "root",key["raw-008"]
            print scenario,"obs-007","separation",value["raw-002"],
                  "object-kind","stored-root"
            print scenario,"obs-008","separation",value["raw-004"],
                  "object-kind","publication"
            exit 0
        }

        if (scenario ~ /rejected-is-head/) {
            print scenario,"obs-001","execution",value["raw-004"],
                  "result",value["raw-001"]
            print scenario,"obs-002","stored-root",value["raw-002"],
                  "availability",value["raw-003"]
            print scenario,"obs-003","publication",value["raw-004"],
                  "authority-domain",value["raw-005"]
            print scenario,"obs-004","publication",value["raw-004"],
                  "proposed-root",value["raw-006"]
            print scenario,"obs-005","publication-decision",value["raw-004"],
                  "state",value["raw-007"]
            print scenario,"obs-006","authority-head-exclusion",
                  substr(source["raw-008"], 14),"root",key["raw-008"]
            print scenario,"obs-007","authority-head-exclusion",
                  key["raw-008"],"presence",value["raw-008"]
            print scenario,"obs-008","cardinality",
                  "authority-main-heads","exact",
                  value["raw-008"] == "present" ? 1 : 0
            exit 0
        }

        if (scenario ~ /stored-is-head/) {
            print scenario,"obs-001","execution",value["raw-002"],
                  "result",value["raw-001"]
            print scenario,"obs-002","stored-root",value["raw-002"],
                  "availability",value["raw-003"]
            print scenario,"obs-003","publication-by-root",key["raw-004"],
                  "presence",value["raw-004"]
            print scenario,"obs-004","authority-head-exclusion",
                  substr(source["raw-005"], 14),"root",key["raw-005"]
            print scenario,"obs-005","authority-head-exclusion",
                  key["raw-005"],"presence",value["raw-005"]
            exit 0
        }

        if (scenario ~ /stored-root-separate/) {
            print scenario,"obs-001","execution",value["raw-002"],
                  "result",value["raw-001"]
            print scenario,"obs-002","stored-root",value["raw-002"],
                  "availability",value["raw-003"]
            print scenario,"obs-003","publication-by-root",key["raw-004"],
                  "presence",value["raw-004"]
            print scenario,"obs-004","separation",value["raw-002"],
                  "object-kind","stored-root"
            print scenario,"obs-005","separation",value["raw-002"],
                  "publication-count",
                  value["raw-004"] == "present" ? 1 : 0
            exit 0
        }

        if (scenario ~ /wrong-authority-head/) {
            print scenario,"obs-001","execution",action_authority,
                  "result",value["raw-001"]
            print scenario,"obs-002","stored-root",value["raw-002"],
                  "availability",value["raw-003"]
            print scenario,"obs-003","publication",value["raw-004"],
                  "authority-domain",value["raw-005"]
            print scenario,"obs-004","publication",value["raw-004"],
                  "proposed-root",value["raw-006"]
            print scenario,"obs-005","publication-decision",value["raw-004"],
                  "state",value["raw-007"]
            if (value["raw-008"] == "present")
                print scenario,"obs-006","authority-head",
                      substr(source["raw-008"], 14),
                      "root",key["raw-008"]
            print scenario,"obs-007","authority-head-exclusion",
                  substr(source["raw-009"], 14),"root",key["raw-009"]
            print scenario,"obs-008","authority-head-exclusion",
                  key["raw-009"],"presence",value["raw-009"]
            print scenario,"obs-009","cardinality",
                  "authority-main-heads","exact",
                  value["raw-009"] == "present" ? 1 : 0
            exit 0
        }
        exit 1
    }
' "$raw" "$receipts"
