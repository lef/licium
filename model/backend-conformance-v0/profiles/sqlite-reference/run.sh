#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
base_dir=$(CDPATH= cd -- "$script_dir/../.." && pwd)
digest="$base_dir/runner/closure-digest.sh"
sut="$base_dir/sqlite-reference/sut-bc06.sh"
schema="$base_dir/sqlite-reference/schema-bc06.sql"
inventory_bc06="$script_dir/inventory-bc06.sh"
observe_bc06="$script_dir/observe-bc06.sh"
sut_bc02="$base_dir/sqlite-reference/sut-bc02.sh"
schema_bc02="$base_dir/sqlite-reference/schema-bc02.sql"
inventory_bc02="$script_dir/inventory-bc02.sh"
resolution_bc02="$script_dir/resolution-bc02.sh"
configure_fault_bc02="$base_dir/sqlite-reference/configure-fault-bc02.sh"
sut_bc01="$base_dir/sqlite-reference/sut-bc01.sh"
schema_bc01="$base_dir/sqlite-reference/schema-bc01.sql"
inventory_bc01="$script_dir/inventory-bc01.sh"
observe_bc01="$script_dir/observe-bc01.sh"
sut_bc03="$base_dir/sqlite-reference/sut-bc03.sh"
schema_bc03="$base_dir/sqlite-reference/schema-bc03.sql"
inventory_bc03="$script_dir/inventory-bc03.sh"
observe_bc03="$script_dir/observe-bc03.sh"
sut_bc04="$base_dir/sqlite-reference/sut-bc04.sh"
schema_bc04="$base_dir/sqlite-reference/schema-bc04.sql"
inventory_bc04="$script_dir/inventory-bc04.sh"
observe_bc04="$script_dir/observe-bc04.sh"
sut_bc05="$base_dir/sqlite-reference/sut-bc05.sh"
schema_bc05="$base_dir/sqlite-reference/schema-bc05.sql"
inventory_bc05="$script_dir/inventory-bc05.sh"
observe_bc05="$script_dir/observe-bc05.sh"
sut_bc07="$base_dir/sqlite-reference/sut-bc07.sh"
schema_bc07="$base_dir/sqlite-reference/schema-bc07.sql"
inventory_bc07="$script_dir/inventory-bc07.sh"
observe_bc07="$script_dir/observe-bc07.sh"
sut_bc08="$base_dir/sqlite-reference/sut-bc08.sh"
schema_bc08="$base_dir/sqlite-reference/schema-bc08.sql"
inventory_bc08="$script_dir/inventory-bc08.sh"
observe_bc08="$script_dir/observe-bc08.sh"
fault_bc08="$base_dir/sqlite-reference/fault-bc08.sh"
sut_bc09="$base_dir/sqlite-reference/sut-bc09.sh"
schema_bc09="$base_dir/sqlite-reference/schema-bc09.sql"
inventory_bc09="$script_dir/inventory-bc09.sh"
observe_bc09="$script_dir/observe-bc09.sh"
fault_bc09="$base_dir/sqlite-reference/fault-bc09.sh"
sut_bc10="$base_dir/sqlite-reference/sut-bc10.sh"
schema_bc10="$base_dir/sqlite-reference/schema-bc10.sql"
observe_bc10="$script_dir/observe-bc10.sh"
sut_bc11="$base_dir/sqlite-reference/sut-bc11.sh"
schema_bc11="$base_dir/sqlite-reference/schema-bc11.sql"
observe_bc11="$script_dir/observe-bc11.sh"
sut_bc12="$base_dir/sqlite-reference/sut-bc12.sh"
schema_bc12="$base_dir/sqlite-reference/schema-bc12.sql"
observe_bc12="$script_dir/observe-bc12.sh"

token() {
    case "$1" in
        ''|*[!a-zA-Z0-9._-]*) return 1 ;;
        *) return 0 ;;
    esac
}

path_token() {
    case "$1" in
        ''|-*|*[!a-zA-Z0-9._/-]*|*..*) return 1 ;;
        *) return 0 ;;
    esac
}

describe() {
    printf 'meta\tglobal\tprofile-id\tsqlite-reference-v0\n'
    printf 'meta\tglobal\tbackend-kind\tsqlite\n'
    printf 'meta\tglobal\texecution-status\tbc01-bc12-supported\n'
    printf 'meta\truntime\tsqlite-version\t%s\n' "$(sqlite3 --version)"
    sequence=0
    sqlite3 :memory: 'PRAGMA compile_options;' | LC_ALL=C sort |
        while IFS= read -r option
        do
            sequence=$((sequence + 1))
            printf 'meta\truntime\tsqlite-compile-option-%04d\t%s\n' \
                "$sequence" "$option"
        done
    for role in adapter profile runner sut
    do
        value=$("$digest" "closure-manifests/$role.paths")
        printf 'binding\tclosure\t%s\t%s\n' "$role" "$value"
    done
}

[ "$#" -ge 1 ] || {
    echo "usage: run.sh VERB [FIXED ARGS...]" >&2
    exit 2
}

verb=$1
shift
case "$verb" in
    describe)
        [ "$#" -eq 0 ] || exit 2
        describe
        ;;
    create)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc02)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc02"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc01)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc01"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc03)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc03"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc04)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc04"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc05)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc05"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc07)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc07"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc08)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc08"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc09)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc09"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc10)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc10"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc11)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc11"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    create-bc12)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        [ ! -e "$db" ] || exit 2
        sqlite3 -batch -bail "$db" <"$schema_bc12"
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\tcreate\taccepted\t%s\n' "$namespace"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    destroy)
        [ "$#" -eq 2 ] && token "$1" && path_token "$2" || exit 2
        namespace=$1
        db=$2
        rm -f -- "$db"
        [ ! -e "$db" ] || exit 1
        printf 'status\tdestroy\taccepted\t%s\n' "$namespace"
        ;;
    reopen)
        [ "$#" -eq 4 ] && path_token "$1" || exit 2
        db=$1
        shift
        for value in "$@"; do token "$value" || exit 2; done
        [ -f "$db" ] || exit 2
        value=$(sqlite3 -batch -bail -noheader "$db" \
            'PRAGMA foreign_keys=ON; PRAGMA foreign_keys;')
        [ "$value" = "1" ] || exit 1
        printf 'status\treopen\taccepted\t%s\n' "$3"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    operation)
        [ "$#" -eq 8 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        operation=$4
        mode=$5
        occurrence=$6
        nonce=$7
        case "$assertion" in BC06_*) ;; *) exit 2 ;; esac
        case "$operation" in
            sut-setup-bc06)
                [ "$mode" = "ordinary" ] &&
                    [ "$occurrence" = "setup" ] || exit 2
                ;;
            sut-evaluate-pure)
                case "$mode" in
                    ordinary|mutant-state-write|mutant-result-write|\
mutant-observation-write|mutant-all-three-axis-write|\
mutant-repository-drift|mutant-noop)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                case "$occurrence" in occurrence-1|occurrence-2) ;; *) exit 2 ;; esac
                ;;
            *)
                printf 'status\toperation\tplanned\tprofile-operation-unimplemented\n'
                exit 3
                ;;
        esac
        "$sut" "$db" "$run" "$namespace" "$assertion" "$operation" \
            "$mode" "$occurrence" "$nonce"
        ;;
    operation-bc02)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        case_id=$4
        operation=$5
        mode=$6
        attempt=$7
        nonce=$8
        case "$assertion:$case_id" in
            BC02_COMPLETE_AVAILABLE:case-bc02-complete|\
            BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-missing|\
            BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-substitution|\
            BC02_HEALTHY_RETRY:case-bc02-incomplete-corrected|\
            BC02_PARTIAL_RESIDUE:case-bc02-after-root-header|\
            BC02_PARTIAL_RESIDUE:case-bc02-after-root-member|\
            BC02_ROLLBACK_COMPLETE:case-bc02-after-root-header|\
            BC02_ROLLBACK_COMPLETE:case-bc02-after-root-member|\
            BC02_POISONED_RETRY:case-bc02-after-root-header|\
            BC02_POISONED_RETRY:case-bc02-after-root-member)
                ;;
            *)
                exit 2
                ;;
        esac
        case "$operation" in
            sut-setup-bc02)
                [ "$mode" = "ordinary" ] &&
                    [ "$attempt" = "setup" ] || exit 2
                ;;
            sut-form-root)
                case "$mode" in
                    ordinary|mutant-complete-unavailable|\
mutant-complete-as-unavailable|mutant-incomplete-as-complete|\
mutant-count-only-completeness|fault-injected)
                        ;;
                    *) exit 2 ;;
                esac
                case "$case_id:$attempt" in
                    case-bc02-complete:attempt-complete|\
                    case-bc02-incomplete-missing:attempt-initial|\
                    case-bc02-incomplete-corrected:attempt-initial|\
                    case-bc02-incomplete-substitution:attempt-initial|\
                    case-bc02-after-root-header:attempt-fault-header|\
                    case-bc02-after-root-member:attempt-fault-member)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                ;;
            sut-correct-root-input)
                [ "$case_id" = "case-bc02-incomplete-corrected" ] &&
                    [ "$attempt" = "correction-correction-02" ] || exit 2
                case "$mode" in
                    ordinary|mutant-correction-cleans-root|\
mutant-correction-forbidden-write)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                ;;
            sut-retry-root)
                [ "$attempt" = "attempt-retry" ] || exit 2
                case "$mode" in
                    ordinary|mutant-retry-rejected|mutant-partial-residue|\
mutant-poisoned-retry|mutant-incomplete-rollback)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                case "$assertion:$case_id" in
                    BC02_HEALTHY_RETRY:case-bc02-incomplete-corrected|\
                    BC02_PARTIAL_RESIDUE:case-bc02-after-root-header|\
                    BC02_PARTIAL_RESIDUE:case-bc02-after-root-member|\
                    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-header|\
                    BC02_ROLLBACK_COMPLETE:case-bc02-after-root-member|\
                    BC02_POISONED_RETRY:case-bc02-after-root-header|\
                    BC02_POISONED_RETRY:case-bc02-after-root-member)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                ;;
            *)
                exit 2
                ;;
        esac
        "$sut_bc02" "$db" "$run" "$namespace" "$assertion" "$case_id" \
            "$operation" "$mode" "$attempt" "$nonce"
        ;;
    operation-bc03)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        case_id=$4
        operation=$5
        mode=$6
        occurrence=$7
        nonce=$8
        case "$assertion:$case_id" in
            BC03_ACCEPTED_HEAD:case-bc03-accepted)
                scenario=bc03-accepted-head--case-bc03-accepted
                ;;
            BC03_PUBLICATION_SEPARATE:case-bc03-accepted)
                scenario=bc03-publication-separate--case-bc03-accepted
                ;;
            BC03_REJECTED_IS_HEAD:case-bc03-rejected)
                scenario=bc03-rejected-is-head--case-bc03-rejected
                ;;
            BC03_STORED_IS_HEAD:case-bc03-stored)
                scenario=bc03-stored-is-head--case-bc03-stored
                ;;
            BC03_STORED_ROOT_SEPARATE:case-bc03-stored)
                scenario=bc03-stored-root-separate--case-bc03-stored
                ;;
            BC03_WRONG_AUTHORITY_HEAD:case-bc03-wrong-authority)
                scenario=bc03-wrong-authority-head--case-bc03-wrong-authority
                ;;
            *)
                exit 2
                ;;
        esac
        case "$operation" in
            sut-setup-bc03)
                [ "$mode" = ordinary ] &&
                    [ "$occurrence" = setup ] || exit 2
                ;;
            sut-publish-root)
                case "$case_id:$mode" in
                    case-bc03-accepted:ordinary|\
                    case-bc03-accepted:mutant-accepted-head-omission|\
                    case-bc03-accepted:mutant-publication-root-collapse|\
                    case-bc03-rejected:ordinary|\
                    case-bc03-rejected:mutant-rejected-head-inclusion)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                [ "$occurrence" = action ] || exit 2
                ;;
            sut-store-root)
                [ "$case_id" = case-bc03-stored ] || exit 2
                case "$mode" in
                    ordinary|mutant-stored-root-head-inclusion|\
                    mutant-stored-root-publication-collapse)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                [ "$occurrence" = action ] || exit 2
                ;;
            sut-derive-heads)
                [ "$case_id" = case-bc03-wrong-authority ] || exit 2
                case "$mode" in
                    ordinary|mutant-wrong-authority-head-inclusion)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                [ "$occurrence" = action ] || exit 2
                ;;
            *)
                exit 2
                ;;
        esac
        "$sut_bc03" "$db" "$run" "$namespace" "$scenario" "$case_id" \
            "$operation" "$mode" "$occurrence" "$nonce"
        ;;
    operation-bc04)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        case_id=$4
        operation=$5
        mode=$6
        occurrence=$7
        nonce=$8
        case "$assertion:$case_id" in
            BC04_AMBIENT_FALLBACK:case-bc04-ambient)
                scenario=bc04-ambient-fallback--case-bc04-ambient
                ;;
            BC04_EXACT_PUBLISHED_COLLAPSE:case-bc04-collapse)
                scenario=bc04-exact-published-collapse--case-bc04-collapse
                ;;
            BC04_EXACT_READ:case-bc04-exact)
                scenario=bc04-exact-read--case-bc04-exact
                ;;
            BC04_PUBLISHED_READ:case-bc04-published)
                scenario=bc04-published-read--case-bc04-published
                ;;
            BC04_UNACCEPTED_AVAILABLE:case-bc04-unaccepted)
                scenario=bc04-unaccepted-available--case-bc04-unaccepted
                ;;
            *)
                exit 2
                ;;
        esac
        case "$operation" in
            sut-setup-bc04)
                [ "$mode" = ordinary ] &&
                    [ "$occurrence" = setup ] || exit 2
                ;;
            sut-read-exact)
                [ "$case_id" = case-bc04-exact ] &&
                    [ "$occurrence" = action ] || exit 2
                case "$mode" in
                    ordinary|mutant-exact-read-substitution) ;;
                    *) exit 2 ;;
                esac
                ;;
            sut-read-published)
                [ "$occurrence" = action ] || exit 2
                case "$mode" in
                    ordinary|mutant-ambient-read-fallback|\
mutant-read-mode-collapse|mutant-published-read-substitution|\
mutant-unaccepted-read-availability)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                ;;
            *)
                exit 2
                ;;
        esac
        "$sut_bc04" "$db" "$run" "$namespace" "$scenario" "$case_id" \
            "$operation" "$mode" "$occurrence" "$nonce"
        ;;
    operation-bc05)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        case_id=$4
        operation=$5
        mode=$6
        occurrence=$7
        nonce=$8
        case "$assertion:$case_id" in
            BC05_AMBIENT_ADVANCE:case-bc05-ambient)
                scenario=bc05-ambient-advance--case-bc05-ambient ;;
            BC05_BINDING_OMISSION:case-bc05-binding)
                scenario=bc05-binding-omission--case-bc05-binding ;;
            BC05_COMPLETE_CLOSURE:case-bc05-complete)
                scenario=bc05-complete-closure--case-bc05-complete ;;
            BC05_DEFINITION_OMISSION:case-bc05-definition)
                scenario=bc05-definition-omission--case-bc05-definition ;;
            BC05_MISSING_AS_EMPTY:case-bc05-empty)
                scenario=bc05-missing-as-empty--case-bc05-empty ;;
            BC05_PINNED_KNOWLEDGE_CUT:case-bc05-cut)
                scenario=bc05-pinned-knowledge-cut--case-bc05-cut ;;
            BC05_ROOT_OMISSION:case-bc05-root)
                scenario=bc05-root-omission--case-bc05-root ;;
            BC05_SEMANTICS_OMISSION:case-bc05-semantics)
                scenario=bc05-semantics-omission--case-bc05-semantics ;;
            BC05_TRANSITIVE_OMISSION:case-bc05-transitive)
                scenario=bc05-transitive-omission--case-bc05-transitive ;;
            *)
                exit 2 ;;
        esac
        case "$operation" in
            sut-setup-bc05)
                [ "$mode" = ordinary ] &&
                    [ "$occurrence" = setup ] || exit 2
                ;;
            sut-resolve-pinned-closure)
                [ "$occurrence" = action ] || exit 2
                case "$mode" in
                    ordinary|mutant-binding-omission|\
mutant-incomplete-closure-success|mutant-definition-omission|\
mutant-missing-as-empty|mutant-root-omission|\
mutant-semantics-omission|mutant-transitive-omission)
                        ;;
                    *)
                        exit 2 ;;
                esac
                ;;
            sut-advance-and-resolve)
                [ "$occurrence" = action ] || exit 2
                case "$mode" in
                    ordinary|mutant-ambient-closure-substitution|\
mutant-knowledge-cut-drift)
                        ;;
                    *)
                        exit 2 ;;
                esac
                ;;
            *)
                exit 2 ;;
        esac
        "$sut_bc05" "$db" "$run" "$namespace" "$scenario" "$case_id" \
            "$operation" "$mode" "$occurrence" "$nonce"
        ;;
    operation-bc07)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        case_id=$4
        operation=$5
        mode=$6
        occurrence=$7
        nonce=$8
        case "$assertion:$case_id" in
            BC07_EFFECT_101:case-bc07-effect)
                scenario=bc07-effect-101--case-bc07-effect ;;
            BC07_OBSERVATION_WITHOUT_TRANSITION:case-bc07-orphan)
                scenario=bc07-observation-without-transition--case-bc07-orphan ;;
            BC07_ORDINARY_000:case-bc07-ordinary)
                scenario=bc07-ordinary-000--case-bc07-ordinary ;;
            BC07_RECORD_IMPLIES_EFFECT:case-bc07-record-effect)
                scenario=bc07-record-implies-effect--case-bc07-record-effect ;;
            BC07_RECORD_ONLY_010:case-bc07-record)
                scenario=bc07-record-only-010--case-bc07-record ;;
            BC07_RESULT_REWRITE:case-bc07-rewrite)
                scenario=bc07-result-rewrite--case-bc07-rewrite ;;
            *) exit 2 ;;
        esac
        case "$operation" in
            sut-setup-bc07)
                [ "$mode" = ordinary ] &&
                    [ "$occurrence" = setup ] || exit 2
                ;;
            sut-evaluate-pure)
                [ "$case_id" = case-bc07-ordinary ] &&
                    [ "$occurrence" = action ] || exit 2
                case "$mode" in
                    ordinary|mutant-ordinary-axis-write) ;;
                    *) exit 2 ;;
                esac
                ;;
            sut-record-result)
                [ "$occurrence" = action ] || exit 2
                case "$mode" in
                    ordinary|mutant-record-state-effect|\
mutant-record-axis-mismatch)
                        ;;
                    *) exit 2 ;;
                esac
                ;;
            sut-apply-effect)
                [ "$occurrence" = action ] || exit 2
                case "$mode" in
                    ordinary|mutant-effect-axis-mismatch|\
mutant-orphan-observation|mutant-effect-result-rewrite)
                        ;;
                    *) exit 2 ;;
                esac
                ;;
            *) exit 2 ;;
        esac
        "$sut_bc07" "$db" "$run" "$namespace" "$scenario" "$case_id" \
            "$operation" "$mode" "$occurrence" "$nonce"
        ;;
    operation-bc08)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        case_id=$4
        operation=$5
        mode=$6
        occurrence=$7
        nonce=$8
        case "$assertion:$case_id" in
            BC08_COMPLETE_EFFECT:case-bc08-complete)
                scenario=bc08-complete-effect--case-bc08-complete ;;
            BC08_MID_BOUNDARY_FAILURE:case-bc08-boundary)
                scenario=bc08-mid-boundary-failure--case-bc08-boundary ;;
            BC08_MISSING_CURRENT:case-bc08-current)
                scenario=bc08-missing-current--case-bc08-current ;;
            BC08_MISSING_OBSERVATION:case-bc08-observation)
                scenario=bc08-missing-observation--case-bc08-observation ;;
            BC08_MISSING_RESULT:case-bc08-result)
                scenario=bc08-missing-result--case-bc08-result ;;
            BC08_MISSING_TRANSITION:case-bc08-transition)
                scenario=bc08-missing-transition--case-bc08-transition ;;
            BC08_MISSING_VIEW:case-bc08-view)
                scenario=bc08-missing-view--case-bc08-view ;;
            *) exit 2 ;;
        esac
        case "$operation" in
            sut-setup-bc08)
                [ "$mode" = ordinary ] && [ "$occurrence" = setup ] ||
                    exit 2
                ;;
            sut-apply-effect)
                case "$mode" in
                    ordinary|retry|fault|mutant-incomplete-effect-set|\
mutant-mid-boundary-partial-effect|mutant-missing-current|\
mutant-missing-observation|mutant-missing-result|\
mutant-missing-transition|mutant-missing-view) ;;
                    *) exit 2 ;;
                esac
                case "$occurrence" in
                    action|retry|fault-action|healthy-action) ;;
                    *) exit 2 ;;
                esac
                ;;
            *) exit 2 ;;
        esac
        "$sut_bc08" "$db" "$run" "$namespace" "$scenario" "$case_id" \
            "$operation" "$mode" "$occurrence" "$nonce"
        ;;
    operation-bc09)
        [ "$#" -eq 10 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        case_id=$4
        operation=$5
        mode=$6
        delivery=$7
        nonce=$8
        attempt=$9
        case "$assertion:$case_id" in
            BC09_DIAGNOSTIC_EPHEMERAL:case-duplicate|\
            BC09_DIAGNOSTIC_EPHEMERAL:case-fault|\
            BC09_DIAGNOSTIC_EPHEMERAL:case-incomplete|\
            BC09_DIAGNOSTIC_EPHEMERAL:case-rejected|\
            BC09_DIAGNOSTIC_EPHEMERAL:case-stale|\
            BC09_DUPLICATE_PERSISTS:case-duplicate|\
            BC09_FAILPOINT_PERSISTS:case-duplicate|\
            BC09_FAILPOINT_PERSISTS:case-fault|\
            BC09_FAILPOINT_PERSISTS:case-incomplete|\
            BC09_FAILPOINT_PERSISTS:case-rejected|\
            BC09_FAILPOINT_PERSISTS:case-stale|\
            BC09_FAILURE_NO_PERSISTENT_ARTIFACT:case-duplicate|\
            BC09_FAILURE_NO_PERSISTENT_ARTIFACT:case-fault|\
            BC09_FAILURE_NO_PERSISTENT_ARTIFACT:case-incomplete|\
            BC09_FAILURE_NO_PERSISTENT_ARTIFACT:case-rejected|\
            BC09_FAILURE_NO_PERSISTENT_ARTIFACT:case-stale|\
            BC09_INCOMPLETE_PERSISTS:case-incomplete|\
            BC09_REJECTED_PERSISTS:case-rejected|\
            BC09_STALE_PERSISTS:case-stale) ;;
            *)
                exit 2
                ;;
        esac
        case "$operation" in
            sut-setup-bc09)
                case "$mode" in ordinary|healthy) ;; *) exit 2 ;; esac
                [ "$delivery" = setup ] && [ "$attempt" = setup ] ||
                    exit 2
                ;;
            sut-apply-effect)
                case "$mode" in
                    ordinary|fault|healthy|mutant-persistent) ;;
                    *) exit 2 ;;
                esac
                case "$delivery" in delivery-1|delivery-2) ;; *) exit 2 ;; esac
                case "$attempt" in attempt-1|attempt-2|healthy) ;; *) exit 2 ;; esac
                ;;
            *)
                exit 2
                ;;
        esac
        "$sut_bc09" "$db" "$run" "$namespace" "$assertion" "$case_id" \
            "$operation" "$mode" "$delivery" "$nonce" "$attempt"
        ;;
    operation-bc10)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        scenario=$3
        assertion=$4
        surface=$5
        operation=$6
        mode=$7
        nonce=$8
        case "$assertion:$surface:$operation" in
            BC10_RESULT_CLOSED:result:sut-evaluate-output|\
            BC10_RESULT_LEAK:result:sut-evaluate-output|\
            BC10_VIEW_CLOSED:view:sut-materialize-view|\
            BC10_VIEW_LEAK:view:sut-materialize-view|\
            BC10_REPLAY_CLOSED:replay:sut-replay-result|\
            BC10_REPLAY_LEAK:replay:sut-replay-result|\
            BC10_EXPLANATION_CLOSED:explanation:sut-explain-result|\
            BC10_EXPLANATION_LEAK:explanation:sut-explain-result) ;;
            BC10_*:setup:sut-setup-bc10)
                [ "$mode" = ordinary ] || exit 2
                ;;
            *) exit 2 ;;
        esac
        case "$mode" in
            ordinary|mutant-result-closure-loss|\
mutant-result-secret-leak|mutant-view-member-loss|\
mutant-view-provenance-loss|mutant-view-secret-leak|\
mutant-replay-closure-loss|mutant-replay-executor-metadata|\
mutant-explanation-member-loss|mutant-explanation-secret-leak) ;;
            *) exit 2 ;;
        esac
        "$sut_bc10" "$db" "$run" "$namespace" "$scenario" "$assertion" \
            "$surface" "$operation" "$mode" "$nonce"
        ;;
    operation-bc11)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        scenario=$3
        assertion=$4
        surface=$5
        operation=$6
        mode=$7
        nonce=$8
        case "$assertion:$surface:$operation" in
            BC11_EXPLANATION_CLOSURE:explanation:sut-explain-result|\
            BC11_FINDING_CROSS_LINK:integrity:sut-validate-integrity|\
            BC11_FINDING_DANGLING:integrity:sut-validate-integrity|\
            BC11_LATEST_SUBSTITUTION:replay:sut-replay-result|\
            BC11_MISSING_AS_EMPTY:replay:sut-replay-result|\
            BC11_REPLAY_RESULT:replay:sut-replay-result|\
            BC11_SILENT_CROSS_LINK:integrity:sut-validate-integrity|\
            BC11_SILENT_DANGLING:integrity:sut-validate-integrity) ;;
            BC11_*:setup:sut-setup-bc11)
                [ "$mode" = ordinary ] || exit 2
                ;;
            *) exit 2 ;;
        esac
        case "$mode" in
            ordinary|mutant-detect-explanation-member-loss|\
mutant-detect-missing-cross-link-finding|mutant-detect-missing-dangling-finding|\
mutant-detect-latest-replay-substitution|mutant-detect-replay-missing-as-empty|\
mutant-detect-replay-result-drift|mutant-detect-silent-cross-link-repair|\
mutant-detect-silent-dangling-repair) ;;
            *) exit 2 ;;
        esac
        "$sut_bc11" "$db" "$run" "$namespace" "$scenario" "$assertion" \
            "$surface" "$operation" "$mode" "$nonce"
        ;;
    operation-bc12)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        scenario=$3
        assertion=$4
        surface=$5
        operation=$6
        mode=$7
        nonce=$8
        case "$assertion:$surface:$operation" in
            BC12_*:placement:sut-evaluate-placement) ;;
            BC12_*:setup:sut-setup-bc12)
                [ "$mode" = ordinary ] || exit 2
                ;;
            *) exit 2 ;;
        esac
        case "$mode" in
            ordinary|mutant-detect-archive-state-bypass|\
mutant-detect-placement-inventory-change|\
mutant-detect-decision-provenance-loss|\
mutant-detect-protection-derivation-loss|\
mutant-detect-eligibility-as-delete|\
mutant-detect-forget-bypass|\
mutant-detect-unconsumed-forget|\
mutant-detect-noop-placement-evaluator|\
mutant-detect-placement-decision-loss|\
mutant-detect-protection-bypass-witness|\
mutant-detect-protection-bypass-conflict|\
mutant-detect-protection-bypass-publication|\
mutant-detect-policy-window-bypass) ;;
            *) exit 2 ;;
        esac
        "$sut_bc12" "$db" "$run" "$namespace" "$scenario" "$assertion" \
            "$surface" "$operation" "$mode" "$nonce"
        ;;
    operation-bc01)
        [ "$#" -eq 9 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        case_id=$4
        operation=$5
        mode=$6
        occurrence=$7
        nonce=$8
        case "$assertion:$case_id" in
            BC01_ASSOCIATION_IDEMPOTENT:case-bc01-retry)
                scenario=bc01-association-idempotent--case-bc01-retry
                ;;
            BC01_DISTINCT_OCCURRENCE:case-bc01-distinct)
                scenario=bc01-distinct-occurrence--case-bc01-distinct
                ;;
            BC01_OCCURRENCE_COLLAPSE:case-bc01-distinct)
                scenario=bc01-occurrence-collapse--case-bc01-distinct
                ;;
            BC01_PAYLOAD_COLLISION:case-bc01-payload-collision)
                scenario=bc01-payload-collision--case-bc01-payload-collision
                ;;
            BC01_RETRY_DUPLICATION:case-bc01-retry)
                scenario=bc01-retry-duplication--case-bc01-retry
                ;;
            *)
                exit 2
                ;;
        esac
        case "$operation" in
            sut-setup-bc01)
                [ "$mode" = "ordinary" ] &&
                    [ "$occurrence" = "setup" ] || exit 2
                ;;
            sut-retry-delivery)
                [ "$case_id" = "case-bc01-retry" ] || exit 2
                case "$mode" in
                    ordinary|mutant-association-duplication|\
mutant-retry-duplication)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                [ "$occurrence" = "action" ] || exit 2
                ;;
            sut-deliver-distinct)
                [ "$case_id" = "case-bc01-distinct" ] || exit 2
                case "$mode" in
                    ordinary|mutant-distinct-collapse|\
mutant-occurrence-collapse)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                [ "$occurrence" = "action" ] || exit 2
                ;;
            sut-deliver-collision)
                [ "$case_id" = "case-bc01-payload-collision" ] ||
                    exit 2
                case "$mode" in
                    ordinary|mutant-payload-collision-acceptance)
                        ;;
                    *)
                        exit 2
                        ;;
                esac
                [ "$occurrence" = "action" ] || exit 2
                ;;
            *)
                exit 2
                ;;
        esac
        "$sut_bc01" "$db" "$run" "$namespace" "$scenario" "$case_id" \
            "$operation" "$mode" "$occurrence" "$nonce"
        ;;
    configure-fault-bc02)
        [ "$#" -eq 11 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        "$configure_fault_bc02" "$db" "$@"
        ;;
    fault-bc08)
        [ "$#" -eq 7 ] && path_token "$1" || exit 2
        db=$1
        shift
        for value in "$@"; do token "$value" || exit 2; done
        "$fault_bc08" "$db" "$@"
        ;;
    fault-bc09)
        [ "$#" -eq 7 ] && path_token "$1" || exit 2
        db=$1
        shift
        for value in "$@"; do token "$value" || exit 2; done
        "$fault_bc09" "$db" "$@"
        ;;
    fault-operation)
        [ "$#" -eq 6 ] || exit 2
        path_token "$1" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        printf 'status\tfault-operation\tplanned\tprofile-operation-unimplemented\n'
        exit 3
        ;;
    observe)
        [ "$#" -eq 6 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        relation=$4
        phase=$5
        case "$assertion" in BC06_*) ;; *) exit 2 ;; esac
        [ "$relation" = "raw-bc06-observation" ] || exit 2
        "$observe_bc06" "$db" "$assertion" "$phase"
        ;;
    inventory)
        [ "$#" -eq 5 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        phase=$4
        case "$assertion" in BC06_*) ;; *) exit 2 ;; esac
        case "$phase" in before|after) ;; *) exit 2 ;; esac
        "$inventory_bc06" "$db" "$assertion"
        ;;
    inventory-bc02)
        [ "$#" -eq 2 ] && path_token "$1" && token "$2" || exit 2
        "$inventory_bc02" "$1" "$2"
        ;;
    inventory-bc03)
        [ "$#" -eq 4 ] && path_token "$1" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC03_ACCEPTED_HEAD:case-bc03-accepted)
                scenario=bc03-accepted-head--case-bc03-accepted
                ;;
            BC03_PUBLICATION_SEPARATE:case-bc03-accepted)
                scenario=bc03-publication-separate--case-bc03-accepted
                ;;
            BC03_REJECTED_IS_HEAD:case-bc03-rejected)
                scenario=bc03-rejected-is-head--case-bc03-rejected
                ;;
            BC03_STORED_IS_HEAD:case-bc03-stored)
                scenario=bc03-stored-is-head--case-bc03-stored
                ;;
            BC03_STORED_ROOT_SEPARATE:case-bc03-stored)
                scenario=bc03-stored-root-separate--case-bc03-stored
                ;;
            BC03_WRONG_AUTHORITY_HEAD:case-bc03-wrong-authority)
                scenario=bc03-wrong-authority-head--case-bc03-wrong-authority
                ;;
            *)
                exit 2
                ;;
        esac
        case "$stage" in before|after|reopened) ;; *) exit 2 ;; esac
        "$inventory_bc03" "$db" "$scenario"
        ;;
    observe-bc03)
        [ "$#" -eq 4 ] && path_token "$1" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC03_ACCEPTED_HEAD:case-bc03-accepted)
                scenario=bc03-accepted-head--case-bc03-accepted
                ;;
            BC03_PUBLICATION_SEPARATE:case-bc03-accepted)
                scenario=bc03-publication-separate--case-bc03-accepted
                ;;
            BC03_REJECTED_IS_HEAD:case-bc03-rejected)
                scenario=bc03-rejected-is-head--case-bc03-rejected
                ;;
            BC03_STORED_IS_HEAD:case-bc03-stored)
                scenario=bc03-stored-is-head--case-bc03-stored
                ;;
            BC03_STORED_ROOT_SEPARATE:case-bc03-stored)
                scenario=bc03-stored-root-separate--case-bc03-stored
                ;;
            BC03_WRONG_AUTHORITY_HEAD:case-bc03-wrong-authority)
                scenario=bc03-wrong-authority-head--case-bc03-wrong-authority
                ;;
            *)
                exit 2
                ;;
        esac
        [ "$stage" = after ] || exit 2
        "$observe_bc03" "$db" "$scenario" "$case_id"
        ;;
    inventory-bc04)
        [ "$#" -eq 4 ] && path_token "$1" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC04_AMBIENT_FALLBACK:case-bc04-ambient)
                scenario=bc04-ambient-fallback--case-bc04-ambient ;;
            BC04_EXACT_PUBLISHED_COLLAPSE:case-bc04-collapse)
                scenario=bc04-exact-published-collapse--case-bc04-collapse ;;
            BC04_EXACT_READ:case-bc04-exact)
                scenario=bc04-exact-read--case-bc04-exact ;;
            BC04_PUBLISHED_READ:case-bc04-published)
                scenario=bc04-published-read--case-bc04-published ;;
            BC04_UNACCEPTED_AVAILABLE:case-bc04-unaccepted)
                scenario=bc04-unaccepted-available--case-bc04-unaccepted ;;
            *) exit 2 ;;
        esac
        case "$stage" in before|after|reopened) ;; *) exit 2 ;; esac
        "$inventory_bc04" "$db" "$scenario"
        ;;
    observe-bc04)
        [ "$#" -eq 5 ] && path_token "$1" && path_token "$5" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        receipt=$5
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC04_AMBIENT_FALLBACK:case-bc04-ambient)
                scenario=bc04-ambient-fallback--case-bc04-ambient ;;
            BC04_EXACT_PUBLISHED_COLLAPSE:case-bc04-collapse)
                scenario=bc04-exact-published-collapse--case-bc04-collapse ;;
            BC04_EXACT_READ:case-bc04-exact)
                scenario=bc04-exact-read--case-bc04-exact ;;
            BC04_PUBLISHED_READ:case-bc04-published)
                scenario=bc04-published-read--case-bc04-published ;;
            BC04_UNACCEPTED_AVAILABLE:case-bc04-unaccepted)
                scenario=bc04-unaccepted-available--case-bc04-unaccepted ;;
            *) exit 2 ;;
        esac
        [ "$stage" = after ] || exit 2
        "$observe_bc04" "$db" "$scenario" "$case_id" "$receipt"
        ;;
    inventory-bc05)
        [ "$#" -eq 4 ] && path_token "$1" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC05_AMBIENT_ADVANCE:case-bc05-ambient)
                scenario=bc05-ambient-advance--case-bc05-ambient ;;
            BC05_BINDING_OMISSION:case-bc05-binding)
                scenario=bc05-binding-omission--case-bc05-binding ;;
            BC05_COMPLETE_CLOSURE:case-bc05-complete)
                scenario=bc05-complete-closure--case-bc05-complete ;;
            BC05_DEFINITION_OMISSION:case-bc05-definition)
                scenario=bc05-definition-omission--case-bc05-definition ;;
            BC05_MISSING_AS_EMPTY:case-bc05-empty)
                scenario=bc05-missing-as-empty--case-bc05-empty ;;
            BC05_PINNED_KNOWLEDGE_CUT:case-bc05-cut)
                scenario=bc05-pinned-knowledge-cut--case-bc05-cut ;;
            BC05_ROOT_OMISSION:case-bc05-root)
                scenario=bc05-root-omission--case-bc05-root ;;
            BC05_SEMANTICS_OMISSION:case-bc05-semantics)
                scenario=bc05-semantics-omission--case-bc05-semantics ;;
            BC05_TRANSITIVE_OMISSION:case-bc05-transitive)
                scenario=bc05-transitive-omission--case-bc05-transitive ;;
            *) exit 2 ;;
        esac
        case "$stage" in before|after|reopened) ;; *) exit 2 ;; esac
        "$inventory_bc05" "$db" "$scenario"
        ;;
    observe-bc05)
        [ "$#" -eq 5 ] && path_token "$1" && path_token "$5" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        receipt=$5
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC05_AMBIENT_ADVANCE:case-bc05-ambient)
                scenario=bc05-ambient-advance--case-bc05-ambient ;;
            BC05_BINDING_OMISSION:case-bc05-binding)
                scenario=bc05-binding-omission--case-bc05-binding ;;
            BC05_COMPLETE_CLOSURE:case-bc05-complete)
                scenario=bc05-complete-closure--case-bc05-complete ;;
            BC05_DEFINITION_OMISSION:case-bc05-definition)
                scenario=bc05-definition-omission--case-bc05-definition ;;
            BC05_MISSING_AS_EMPTY:case-bc05-empty)
                scenario=bc05-missing-as-empty--case-bc05-empty ;;
            BC05_PINNED_KNOWLEDGE_CUT:case-bc05-cut)
                scenario=bc05-pinned-knowledge-cut--case-bc05-cut ;;
            BC05_ROOT_OMISSION:case-bc05-root)
                scenario=bc05-root-omission--case-bc05-root ;;
            BC05_SEMANTICS_OMISSION:case-bc05-semantics)
                scenario=bc05-semantics-omission--case-bc05-semantics ;;
            BC05_TRANSITIVE_OMISSION:case-bc05-transitive)
                scenario=bc05-transitive-omission--case-bc05-transitive ;;
            *) exit 2 ;;
        esac
        [ "$stage" = after ] || exit 2
        "$observe_bc05" "$db" "$scenario" "$case_id" "$receipt"
        ;;
    inventory-bc07)
        [ "$#" -eq 4 ] && path_token "$1" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC07_EFFECT_101:case-bc07-effect)
                scenario=bc07-effect-101--case-bc07-effect ;;
            BC07_OBSERVATION_WITHOUT_TRANSITION:case-bc07-orphan)
                scenario=bc07-observation-without-transition--case-bc07-orphan ;;
            BC07_ORDINARY_000:case-bc07-ordinary)
                scenario=bc07-ordinary-000--case-bc07-ordinary ;;
            BC07_RECORD_IMPLIES_EFFECT:case-bc07-record-effect)
                scenario=bc07-record-implies-effect--case-bc07-record-effect ;;
            BC07_RECORD_ONLY_010:case-bc07-record)
                scenario=bc07-record-only-010--case-bc07-record ;;
            BC07_RESULT_REWRITE:case-bc07-rewrite)
                scenario=bc07-result-rewrite--case-bc07-rewrite ;;
            *) exit 2 ;;
        esac
        case "$stage" in before|after|reopened) ;; *) exit 2 ;; esac
        "$inventory_bc07" "$db" "$scenario"
        ;;
    observe-bc07)
        [ "$#" -eq 6 ] && path_token "$1" && path_token "$5" &&
            path_token "$6" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        before=$5
        receipt=$6
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC07_EFFECT_101:case-bc07-effect)
                scenario=bc07-effect-101--case-bc07-effect ;;
            BC07_OBSERVATION_WITHOUT_TRANSITION:case-bc07-orphan)
                scenario=bc07-observation-without-transition--case-bc07-orphan ;;
            BC07_ORDINARY_000:case-bc07-ordinary)
                scenario=bc07-ordinary-000--case-bc07-ordinary ;;
            BC07_RECORD_IMPLIES_EFFECT:case-bc07-record-effect)
                scenario=bc07-record-implies-effect--case-bc07-record-effect ;;
            BC07_RECORD_ONLY_010:case-bc07-record)
                scenario=bc07-record-only-010--case-bc07-record ;;
            BC07_RESULT_REWRITE:case-bc07-rewrite)
                scenario=bc07-result-rewrite--case-bc07-rewrite ;;
            *) exit 2 ;;
        esac
        [ "$stage" = after ] || exit 2
        "$observe_bc07" "$db" "$scenario" "$before" "$receipt"
        ;;
    inventory-bc08)
        [ "$#" -eq 3 ] && path_token "$1" || exit 2
        db=$1
        subject=$2
        stage=$3
        token "$subject" && token "$stage" || exit 2
        case "$stage" in
            before|after|reopened|setup|rollback|healthy) ;;
            *) exit 2 ;;
        esac
        "$inventory_bc08" "$db" "$subject"
        ;;
    inventory-bc09)
        [ "$#" -eq 3 ] && path_token "$1" || exit 2
        db=$1
        case_id=$2
        stage=$3
        token "$case_id" && token "$stage" || exit 2
        case "$case_id" in
            case-duplicate|case-fault|case-incomplete|case-rejected|case-stale)
                ;;
            *)
                exit 2
                ;;
        esac
        case "$stage" in before|after|reopened|setup|rollback|healthy) ;;
            *) exit 2 ;;
        esac
        "$inventory_bc09" "$db" "$case_id"
        ;;
    observe-bc09)
        [ "$#" -eq 8 ] || exit 2
        scenario=$1
        case_id=$2
        actions=$3
        before=$4
        after=$5
        reopened=$6
        trigger_count=$7
        output=$8
        token "$scenario" && token "$case_id" &&
            token "$trigger_count" || exit 2
        for path in "$actions" "$before" "$after" "$reopened" "$output"
        do
            path_token "$path" || exit 2
        done
        "$observe_bc09" "$scenario" "$case_id" "$actions" "$before" \
            "$after" "$reopened" "$trigger_count" "$output"
        printf 'pragma\tforeign-keys\t1\n' >&2
        ;;
    observe-bc10)
        [ "$#" -eq 3 ] && path_token "$1" &&
            token "$2" && token "$3" || exit 2
        db=$1
        scenario=$2
        surface=$3
        [ -f "$db" ] || exit 2
        "$observe_bc10" "$db" "$scenario" "$surface"
        ;;
    observe-bc11)
        [ "$#" -eq 3 ] && path_token "$1" &&
            token "$2" && token "$3" || exit 2
        db=$1
        scenario=$2
        surface=$3
        [ -f "$db" ] || exit 2
        "$observe_bc11" "$db" "$scenario" "$surface"
        ;;
    observe-bc12)
        [ "$#" -eq 3 ] && path_token "$1" &&
            token "$2" && token "$3" || exit 2
        db=$1
        scenario=$2
        surface=$3
        [ -f "$db" ] || exit 2
        "$observe_bc12" "$db" "$scenario" "$surface"
        ;;
    observe-bc08)
        [ "$#" -eq 6 ] && path_token "$1" && path_token "$3" &&
            path_token "$4" || exit 2
        db=$1
        scenario=$2
        receipt=$3
        retry_receipt=$4
        triggered_hooks=$5
        stage=$6
        token "$scenario" && token "$triggered_hooks" && token "$stage" ||
            exit 2
        [ "$stage" = after ] || exit 2
        "$observe_bc08" "$db" "$scenario" "$receipt" "$retry_receipt" \
            "$triggered_hooks"
        ;;
    inventory-bc01)
        [ "$#" -eq 4 ] && path_token "$1" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC01_ASSOCIATION_IDEMPOTENT:case-bc01-retry)
                scenario=bc01-association-idempotent--case-bc01-retry
                ;;
            BC01_DISTINCT_OCCURRENCE:case-bc01-distinct)
                scenario=bc01-distinct-occurrence--case-bc01-distinct
                ;;
            BC01_OCCURRENCE_COLLAPSE:case-bc01-distinct)
                scenario=bc01-occurrence-collapse--case-bc01-distinct
                ;;
            BC01_PAYLOAD_COLLISION:case-bc01-payload-collision)
                scenario=bc01-payload-collision--case-bc01-payload-collision
                ;;
            BC01_RETRY_DUPLICATION:case-bc01-retry)
                scenario=bc01-retry-duplication--case-bc01-retry
                ;;
            *)
                exit 2
                ;;
        esac
        case "$stage" in before|after|reopened) ;; *) exit 2 ;; esac
        "$inventory_bc01" "$db" "$scenario"
        ;;
    observe-bc01)
        [ "$#" -eq 4 ] && path_token "$1" || exit 2
        db=$1
        assertion=$2
        case_id=$3
        stage=$4
        token "$assertion" && token "$case_id" && token "$stage" || exit 2
        case "$assertion:$case_id" in
            BC01_ASSOCIATION_IDEMPOTENT:case-bc01-retry)
                scenario=bc01-association-idempotent--case-bc01-retry
                ;;
            BC01_DISTINCT_OCCURRENCE:case-bc01-distinct)
                scenario=bc01-distinct-occurrence--case-bc01-distinct
                ;;
            BC01_OCCURRENCE_COLLAPSE:case-bc01-distinct)
                scenario=bc01-occurrence-collapse--case-bc01-distinct
                ;;
            BC01_PAYLOAD_COLLISION:case-bc01-payload-collision)
                scenario=bc01-payload-collision--case-bc01-payload-collision
                ;;
            BC01_RETRY_DUPLICATION:case-bc01-retry)
                scenario=bc01-retry-duplication--case-bc01-retry
                ;;
            *)
                exit 2
                ;;
        esac
        case "$stage" in before|after) ;; *) exit 2 ;; esac
        "$observe_bc01" "$db" "$scenario" "$case_id" "$stage"
        ;;
    resolution-bc02)
        [ "$#" -eq 6 ] || exit 2
        db=$1
        path_token "$db" || exit 2
        shift
        for value in "$@"; do token "$value" || exit 2; done
        run=$1
        namespace=$2
        assertion=$3
        case_id=$4
        stage=$5
        case "$assertion:$case_id" in
            BC02_COMPLETE_AVAILABLE:case-bc02-complete)
                case "$stage" in success|reopened) ;; *) exit 2 ;; esac
                ;;
            BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-missing|\
            BC02_INCOMPLETE_AS_COMPLETE:case-bc02-incomplete-substitution)
                case "$stage" in unavailable|reopened) ;; *) exit 2 ;; esac
                ;;
            BC02_HEALTHY_RETRY:case-bc02-incomplete-corrected)
                case "$stage" in
                    unavailable|retry-success|reopened) ;;
                    *) exit 2 ;;
                esac
                ;;
            BC02_PARTIAL_RESIDUE:case-bc02-after-root-header|\
            BC02_PARTIAL_RESIDUE:case-bc02-after-root-member|\
            BC02_ROLLBACK_COMPLETE:case-bc02-after-root-header|\
            BC02_ROLLBACK_COMPLETE:case-bc02-after-root-member)
                case "$stage" in unavailable|reopened) ;; *) exit 2 ;; esac
                ;;
            BC02_POISONED_RETRY:case-bc02-after-root-header|\
            BC02_POISONED_RETRY:case-bc02-after-root-member)
                case "$stage" in
                    unavailable|retry-success|reopened) ;;
                    *) exit 2 ;;
                esac
                ;;
            *)
                exit 2
                ;;
        esac
        "$resolution_bc02" "$db" "$run" "$namespace" "$assertion" \
            "$case_id" "$stage"
        ;;
    lifecycle-sentinel)
        [ "$#" -eq 4 ] && path_token "$1" || exit 2
        root=$1
        action=$2
        namespace=$3
        sentinel=$4
        token "$action" && token "$namespace" && token "$sentinel" || exit 2
        [ -d "$root/$namespace" ] && [ ! -L "$root/$namespace" ] || exit 2
        sentinel_path="$root/$namespace/$sentinel"
        case "$action" in
            put)
                [ ! -e "$sentinel_path" ] || exit 2
                : >"$sentinel_path"
                printf 'status\tlifecycle-sentinel\tput\t%s\t%s\n' \
                    "$namespace" "$sentinel"
                ;;
            observe)
                status=absent
                [ ! -f "$sentinel_path" ] || status=present
                [ ! -L "$sentinel_path" ] || exit 1
                printf '%s\tlifecycle-sentinel\t%s\t%s\n' \
                    "$namespace" "$sentinel" "$status"
                ;;
            *)
                exit 2
                ;;
        esac
        ;;
    *)
        echo "unknown profile verb" >&2
        exit 2
        ;;
esac
