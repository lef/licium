PRAGMA foreign_keys = ON;

CREATE TABLE source_object (
    object_ref TEXT PRIMARY KEY,
    object_kind TEXT NOT NULL,
    logical_value TEXT NOT NULL
) STRICT;

CREATE TABLE root_request (
    request_ref TEXT PRIMARY KEY,
    target_root_ref TEXT NOT NULL,
    ancestry_boundary_ref TEXT NOT NULL
) STRICT;

CREATE TABLE root_required_member (
    request_ref TEXT NOT NULL REFERENCES root_request(request_ref),
    ordinal INTEGER NOT NULL CHECK (ordinal > 0),
    object_ref TEXT NOT NULL,
    PRIMARY KEY (request_ref, ordinal),
    UNIQUE (request_ref, object_ref)
) STRICT;

CREATE TABLE root (
    root_ref TEXT PRIMARY KEY,
    status TEXT NOT NULL CHECK (status IN ('forming', 'complete')),
    request_ref TEXT NOT NULL UNIQUE REFERENCES root_request(request_ref)
) STRICT;

CREATE TABLE root_member (
    root_ref TEXT NOT NULL REFERENCES root(root_ref),
    ordinal INTEGER NOT NULL CHECK (ordinal > 0),
    object_ref TEXT NOT NULL REFERENCES source_object(object_ref),
    PRIMARY KEY (root_ref, ordinal),
    UNIQUE (root_ref, object_ref)
) STRICT;

CREATE TABLE root_ancestry (
    root_ref TEXT PRIMARY KEY REFERENCES root(root_ref),
    boundary_ref TEXT NOT NULL,
    boundary_kind TEXT NOT NULL CHECK (boundary_kind = 'genesis')
) STRICT;

CREATE TABLE fault_configuration (
    trigger_name TEXT PRIMARY KEY,
    run_id TEXT NOT NULL,
    namespace_id TEXT NOT NULL,
    assertion_id TEXT NOT NULL,
    case_id TEXT NOT NULL,
    attempt_id TEXT NOT NULL,
    operation_id TEXT NOT NULL,
    hook_id TEXT NOT NULL,
    phase TEXT NOT NULL,
    nonce TEXT NOT NULL,
    implementation_revision TEXT NOT NULL,
    activation_sha256 TEXT NOT NULL,
    error_id TEXT NOT NULL,
    error_marker TEXT NOT NULL,
    error_literal TEXT NOT NULL,
    transient_header_count INTEGER NOT NULL,
    transient_member_count INTEGER NOT NULL,
    transient_ancestry_count INTEGER NOT NULL
) STRICT;

CREATE TABLE fault_activation (
    run_id TEXT NOT NULL,
    namespace_id TEXT NOT NULL,
    assertion_id TEXT NOT NULL,
    case_id TEXT NOT NULL,
    attempt_id TEXT NOT NULL,
    operation_id TEXT NOT NULL,
    hook_id TEXT NOT NULL,
    phase TEXT NOT NULL,
    nonce TEXT NOT NULL,
    implementation_revision TEXT NOT NULL,
    activation_sha256 TEXT NOT NULL,
    PRIMARY KEY (run_id, namespace_id, assertion_id, case_id, attempt_id)
) STRICT;

CREATE TRIGGER root_complete_guard
BEFORE UPDATE OF status ON root
WHEN NEW.status = 'complete'
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM root_request AS request
            WHERE request.request_ref = NEW.request_ref
              AND request.target_root_ref = NEW.root_ref
        )
        OR NOT EXISTS (
            SELECT 1
            FROM root_required_member AS required
            WHERE required.request_ref = NEW.request_ref
        )
        OR EXISTS (
            SELECT 1
            FROM root_required_member AS required
            LEFT JOIN root_member AS member
              ON member.root_ref = NEW.root_ref
             AND member.ordinal = required.ordinal
             AND member.object_ref = required.object_ref
            WHERE required.request_ref = NEW.request_ref
              AND member.root_ref IS NULL
        )
        OR EXISTS (
            SELECT 1
            FROM root_member AS member
            LEFT JOIN root_required_member AS required
              ON required.request_ref = NEW.request_ref
             AND required.ordinal = member.ordinal
             AND required.object_ref = member.object_ref
            WHERE member.root_ref = NEW.root_ref
              AND required.request_ref IS NULL
        )
        OR (
            SELECT COUNT(*)
            FROM root_ancestry AS ancestry
            JOIN root_request AS request
              ON request.request_ref = NEW.request_ref
             AND request.ancestry_boundary_ref = ancestry.boundary_ref
            WHERE ancestry.root_ref = NEW.root_ref
              AND ancestry.boundary_kind = 'genesis'
        ) <> 1
        THEN RAISE(ABORT, 'LICIUM_BC02_ROOT_INCOMPLETE')
    END;
END;
