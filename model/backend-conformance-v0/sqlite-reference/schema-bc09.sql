PRAGMA foreign_keys = ON;

CREATE TABLE evaluation_result (
    result_ref TEXT PRIMARY KEY,
    result_payload TEXT NOT NULL,
    completeness TEXT NOT NULL
        CHECK (completeness IN ('complete','incomplete')),
    disposition TEXT NOT NULL
        CHECK (disposition IN ('accepted','rejected'))
) STRICT;

CREATE TABLE authoritative_state (
    scope_ref TEXT PRIMARY KEY,
    revision_ref TEXT NOT NULL
) STRICT;

CREATE TABLE effect_request (
    effect_ref TEXT PRIMARY KEY,
    result_ref TEXT NOT NULL,
    scope_ref TEXT NOT NULL,
    expected_revision_ref TEXT NOT NULL
) STRICT;

CREATE TABLE state_transition (
    transition_ref TEXT PRIMARY KEY,
    effect_ref TEXT NOT NULL UNIQUE,
    before_revision_ref TEXT NOT NULL,
    after_revision_ref TEXT NOT NULL
) STRICT;

CREATE TABLE decision_observation (
    observation_ref TEXT PRIMARY KEY,
    transition_ref TEXT NOT NULL,
    result_ref TEXT NOT NULL,
    source_root_ref TEXT NOT NULL,
    view_ref TEXT NOT NULL
) STRICT;

CREATE TABLE view_header (
    view_ref TEXT PRIMARY KEY,
    effect_ref TEXT NOT NULL UNIQUE,
    result_ref TEXT NOT NULL,
    source_root_ref TEXT NOT NULL,
    revision_ref TEXT NOT NULL,
    completeness TEXT NOT NULL CHECK (completeness = 'complete'),
    row_count INTEGER NOT NULL CHECK (row_count >= 0)
) STRICT;

CREATE TABLE current_view (
    scope_ref TEXT PRIMARY KEY,
    view_ref TEXT NOT NULL,
    revision_ref TEXT NOT NULL
) STRICT;

-- This table exists only as a mutation target.  A conforming Effect operation
-- leaves it empty; the inventory observer exposes any row as Repository data.
CREATE TABLE attempt_artifact (
    attempt_ref TEXT PRIMARY KEY,
    effect_ref TEXT NOT NULL,
    disposition TEXT NOT NULL,
    reason TEXT NOT NULL
) STRICT;

-- Harness state is deliberately outside the Repository inventory projection.
CREATE TABLE fault_activation (
    fault_nonce TEXT PRIMARY KEY,
    hook_id TEXT NOT NULL,
    phase TEXT NOT NULL,
    effect_ref TEXT NOT NULL,
    implementation_revision TEXT NOT NULL,
    armed INTEGER NOT NULL CHECK (armed IN (0,1))
) STRICT;

CREATE TRIGGER trigger_bc09_accepted_write
AFTER UPDATE OF revision_ref ON authoritative_state
WHEN EXISTS (
    SELECT 1 FROM fault_activation
     WHERE armed = 1
       AND effect_ref = 'effect-1'
       AND hook_id = 'hook-bc09-accepted-write'
       AND phase = 'accepted-write'
)
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC09_FAULT_ACCEPTED_WRITE');
END;

CREATE TRIGGER trigger_bc09_rejection_stale
BEFORE UPDATE OF armed ON fault_activation
WHEN OLD.armed = 1
 AND OLD.hook_id = 'hook-bc09-rejection-stale'
 AND OLD.phase = 'rejection-stale'
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC09_FAULT_REJECTION_STALE');
END;

CREATE TRIGGER trigger_bc09_rejection_incomplete
BEFORE UPDATE OF armed ON fault_activation
WHEN OLD.armed = 1
 AND OLD.hook_id = 'hook-bc09-rejection-incomplete'
 AND OLD.phase = 'rejection-incomplete'
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC09_FAULT_REJECTION_INCOMPLETE');
END;

CREATE TRIGGER trigger_bc09_rejection_rejected
BEFORE UPDATE OF armed ON fault_activation
WHEN OLD.armed = 1
 AND OLD.hook_id = 'hook-bc09-rejection-rejected'
 AND OLD.phase = 'rejection-rejected'
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC09_FAULT_REJECTION_REJECTED');
END;

CREATE TRIGGER trigger_bc09_rejection_duplicate
BEFORE UPDATE OF armed ON fault_activation
WHEN OLD.armed = 1
 AND OLD.hook_id = 'hook-bc09-rejection-duplicate'
 AND OLD.phase = 'rejection-duplicate'
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC09_FAULT_REJECTION_DUPLICATE');
END;
