#!/bin/sh
set -eu

[ "$#" -eq 3 ] || {
    echo "usage: normalize-bc04.sh RAW_TSV RECEIPTS_TSV SCENARIO" >&2
    exit 2
}

raw=$1
receipts=$2
scenario=$3

LC_ALL=C awk -F '	' -v OFS='	' -v scenario="$scenario" '
    FILENAME == ARGV[1] {
        if (NF != 6 || $1 != scenario || seen[$2]++) exit 1
        source[$2] = $3
        reference[$2] = $4
        key[$2] = $5
        value[$2] = $6
        next
    }
    FILENAME == ARGV[2] {
        if (NF != 13 || $3 != scenario) exit 1
        if ($5 == "sut-setup-bc04") setup++
        else action++
        next
    }
    END {
        if (setup != 1 || action != 1 || value["raw-001"] == "") exit 1
        if (scenario ~ /ambient-fallback/) {
            print scenario,"obs-001","execution",value["raw-003"],
                  "result",value["raw-001"]
            print scenario,"obs-002","read-mode","request","mode",
                  value["raw-002"]
            print scenario,"obs-003","ambient-candidate",value["raw-004"],
                  "availability","complete"
            print scenario,"obs-004","published-result",value["raw-003"],
                  "root",value["raw-005"]
            print scenario,"obs-005","ambient-fallback",key["raw-006"],
                  "presence",value["raw-006"]
            print scenario,"obs-006","persistent-effect","repository",
                  "unchanged",0
            exit
        }
        if (scenario ~ /exact-published-collapse/) {
            print scenario,"obs-001","execution","authority-main",
                  "result",value["raw-001"]
            print scenario,"obs-002","read-mode","request","mode",
                  value["raw-002"]
            print scenario,"obs-003","exact-candidate",
                  substr(source["raw-003"],17),"value",value["raw-003"]
            print scenario,"obs-004","published-result",value["raw-004"],
                  "value",value["raw-005"]
            print scenario,"obs-005","separation","exact-published",
                  "equality",value["raw-006"] == "distinct" ? "false" : "true"
            print scenario,"obs-006","persistent-effect","repository",
                  "unchanged",0
            exit
        }
        if (scenario ~ /exact-read/) {
            print scenario,"obs-001","execution",value["raw-003"],
                  "result",value["raw-001"]
            print scenario,"obs-002","read-mode","request","mode",
                  value["raw-002"]
            print scenario,"obs-003","read-result",value["raw-004"],
                  "value",value["raw-005"]
            print scenario,"obs-004","read-source",key["raw-006"],
                  "publication-state",value["raw-006"]
            print scenario,"obs-005","cardinality","read-rows","exact",
                  value["raw-001"] == "available" ? 1 : 0
            print scenario,"obs-006","persistent-effect","repository",
                  "unchanged",0
            exit
        }
        if (scenario ~ /published-read/) {
            print scenario,"obs-001","execution",value["raw-003"],
                  "result",value["raw-001"]
            print scenario,"obs-002","read-mode","request","mode",
                  value["raw-002"]
            print scenario,"obs-003","read-result",value["raw-004"],
                  "value",value["raw-005"]
            print scenario,"obs-004","read-source",value["raw-004"],
                  "publication-state",value["raw-006"]
            print scenario,"obs-005","cardinality","read-rows","exact",
                  value["raw-001"] == "available" ? 1 : 0
            print scenario,"obs-006","persistent-effect","repository",
                  "unchanged",0
            exit
        }
        if (scenario ~ /unaccepted-available/) {
            print scenario,"obs-001","execution",value["raw-003"],
                  "result",value["raw-001"]
            print scenario,"obs-002","read-mode","request","mode",
                  value["raw-002"]
            print scenario,"obs-003","stored-root",key["raw-004"],
                  "availability",value["raw-004"]
            print scenario,"obs-004","publication-decision","root-private",
                  "state",value["raw-005"]
            print scenario,"obs-005","published-result",value["raw-003"],
                  "root",value["raw-006"]
            print scenario,"obs-006","published-secret-leaks","result",
                  "exact",value["raw-007"]
            exit
        }
        exit 1
    }
' "$raw" "$receipts"
