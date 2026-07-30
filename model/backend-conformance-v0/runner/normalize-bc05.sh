#!/bin/sh
set -eu

[ "$#" -eq 3 ] || {
    echo "usage: normalize-bc05.sh RAW_TSV RECEIPTS_TSV SCENARIO" >&2
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
        if ($5 == "sut-setup-bc05") setup++
        else action++
        next
    }
    function emit(id, relation, subject, attribute, result) {
        print scenario,id,relation,subject,attribute,result
    }
    function present_kind(id, expected) {
        return value[id] == expected ? "present" : "missing"
    }
    END {
        if (setup != 1 || action != 1 || value["raw-001"] == "") exit 1
        if (scenario ~ /ambient-advance/) {
            emit("obs-001","execution","request-ambient","result",
                 value["raw-001"])
            emit("obs-002","pinned-input","request-ambient","cut",
                 value["raw-002"])
            emit("obs-003","ambient-state","scope-main","cut-before",
                 value["raw-003"])
            emit("obs-004","ambient-state","scope-main","cut-after",
                 value["raw-004"])
            emit("obs-005","closure-selection","closure-a",
                 "selected-value",value["raw-005"])
            emit("obs-006","closure-substitution","closure-a",
                 "ambient-member-count",value["raw-006"])
            emit("obs-007","pinned-ambient-comparison","request-ambient",
                 "equality",value["raw-007"])
            emit("obs-008","persistent-effect","repository",
                 "closure-result-writes",value["raw-008"])
            exit
        }
        if (scenario ~ /binding-omission/) {
            emit("obs-001","execution","request-binding-missing","result",
                 value["raw-001"])
            emit("obs-002","input-resolution","root-a","root",
                 present_kind("raw-002","root"))
            emit("obs-003","input-resolution","definition-a","definition",
                 present_kind("raw-003","definition"))
            emit("obs-004","input-resolution","semantics-a","semantics",
                 present_kind("raw-004","semantics"))
            emit("obs-005","input-resolution","bindings-missing","binding",
                 value["raw-005"])
            emit("obs-006","missing-input","bindings-missing","role",
                 value["raw-006"])
            emit("obs-007","ambient-fallback","bindings-missing","presence",
                 value["raw-007"])
            emit("obs-008","persistent-effect","repository",
                 "closure-result-writes",value["raw-008"])
            exit
        }
        if (scenario ~ /complete-closure/) {
            emit("obs-001","execution","request-complete","result",
                 value["raw-001"])
            emit("obs-002","input-resolution","root-a","root",
                 present_kind("raw-002","root"))
            emit("obs-003","input-resolution","definition-a","definition",
                 present_kind("raw-003","definition"))
            emit("obs-004","input-resolution","semantics-a","semantics",
                 present_kind("raw-004","semantics"))
            emit("obs-005","input-resolution","bindings-main","binding",
                 value["raw-005"])
            emit("obs-006","dependency-resolution","dependency-direct",
                 "direct",present_kind("raw-006","direct"))
            emit("obs-007","dependency-resolution","dependency-leaf",
                 "transitive",present_kind("raw-007","transitive"))
            emit("obs-008","closure-selection","closure-a",
                 "selected-value",value["raw-008"])
            emit("obs-009","persistent-effect","repository",
                 "closure-result-writes",value["raw-009"])
            exit
        }
        if (scenario ~ /definition-omission/) {
            emit("obs-001","execution","request-definition-missing",
                 "result",value["raw-001"])
            emit("obs-002","input-resolution","root-a","root",
                 present_kind("raw-002","root"))
            emit("obs-003","input-resolution","definition-missing",
                 "definition",value["raw-003"])
            emit("obs-004","input-resolution","semantics-a","semantics",
                 present_kind("raw-004","semantics"))
            emit("obs-005","input-resolution","bindings-main","binding",
                 value["raw-005"])
            emit("obs-006","missing-input","definition-missing","role",
                 value["raw-006"])
            emit("obs-007","ambient-fallback","definition-missing",
                 "presence",value["raw-007"])
            emit("obs-008","persistent-effect","repository",
                 "closure-result-writes",value["raw-008"])
            exit
        }
        if (scenario ~ /missing-as-empty/) {
            emit("obs-001","execution","request-empty","result",
                 value["raw-001"])
            emit("obs-002","input-resolution","bindings-empty","binding",
                 value["raw-002"])
            emit("obs-003","closure-selection","request-empty",
                 "selected-count",value["raw-003"])
            emit("obs-004","execution","request-missing","result",
                 value["raw-004"])
            emit("obs-005","input-resolution","bindings-missing","binding",
                 value["raw-005"])
            emit("obs-006","closure-selection","request-missing",
                 "selected-count",value["raw-006"])
            emit("obs-007","empty-missing-comparison","request-pair",
                 "equality",value["raw-007"])
            emit("obs-008","persistent-effect","repository",
                 "closure-result-writes",value["raw-008"])
            exit
        }
        if (scenario ~ /pinned-knowledge-cut/) {
            emit("obs-001","execution","request-cut-a","result",
                 value["raw-001"])
            emit("obs-002","pinned-input","request-cut-a","cut",
                 value["raw-002"])
            emit("obs-003","ambient-state","scope-main","cut-after",
                 value["raw-003"])
            emit("obs-004","closure-resolution","request-cut-a","closure",
                 value["raw-004"])
            emit("obs-005","closure-selection","closure-a",
                 "selected-value",value["raw-005"])
            emit("obs-006","ambient-candidate","closure-b",
                 "selected-value",value["raw-006"])
            emit("obs-007","closure-substitution","request-cut-a",
                 "ambient-member-count",value["raw-007"])
            emit("obs-008","pinned-result","request-cut-a",
                 "selected-value",value["raw-008"])
            emit("obs-009","persistent-effect","repository",
                 "closure-result-writes",value["raw-009"])
            exit
        }
        if (scenario ~ /root-omission/) {
            emit("obs-001","execution","request-root-missing","result",
                 value["raw-001"])
            emit("obs-002","input-resolution","root-missing","root",
                 value["raw-002"])
            emit("obs-003","input-resolution","definition-a","definition",
                 present_kind("raw-003","definition"))
            emit("obs-004","input-resolution","semantics-a","semantics",
                 present_kind("raw-004","semantics"))
            emit("obs-005","input-resolution","bindings-main","binding",
                 value["raw-005"])
            emit("obs-006","missing-input","root-missing","role",
                 value["raw-006"])
            emit("obs-007","ambient-fallback","root-missing","presence",
                 value["raw-007"])
            emit("obs-008","persistent-effect","repository",
                 "closure-result-writes",value["raw-008"])
            exit
        }
        if (scenario ~ /semantics-omission/) {
            emit("obs-001","execution","request-semantics-missing",
                 "result",value["raw-001"])
            emit("obs-002","input-resolution","root-a","root",
                 present_kind("raw-002","root"))
            emit("obs-003","input-resolution","definition-a","definition",
                 present_kind("raw-003","definition"))
            emit("obs-004","input-resolution","semantics-missing",
                 "semantics",value["raw-004"])
            emit("obs-005","input-resolution","bindings-main","binding",
                 value["raw-005"])
            emit("obs-006","missing-input","semantics-missing","role",
                 value["raw-006"])
            emit("obs-007","ambient-fallback","semantics-missing",
                 "presence",value["raw-007"])
            emit("obs-008","persistent-effect","repository",
                 "closure-result-writes",value["raw-008"])
            exit
        }
        if (scenario ~ /transitive-omission/) {
            emit("obs-001","execution","request-transitive-missing",
                 "result",value["raw-001"])
            emit("obs-002","input-resolution","root-a","root",
                 present_kind("raw-002","root"))
            emit("obs-003","input-resolution","definition-a","definition",
                 present_kind("raw-003","definition"))
            emit("obs-004","input-resolution","semantics-a","semantics",
                 present_kind("raw-004","semantics"))
            emit("obs-005","input-resolution","bindings-main","binding",
                 value["raw-005"])
            emit("obs-006","dependency-resolution","dependency-direct",
                 "direct",present_kind("raw-006","direct"))
            emit("obs-007","dependency-resolution","dependency-missing",
                 "transitive",value["raw-007"])
            emit("obs-008","missing-input","dependency-missing","role",
                 value["raw-008"])
            emit("obs-009","persistent-effect","repository",
                 "closure-result-writes",value["raw-009"])
            exit
        }
        exit 1
    }
' "$raw" "$receipts"
