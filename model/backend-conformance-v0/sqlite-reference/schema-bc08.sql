PRAGMA foreign_keys = ON;

CREATE TABLE evaluation_result (
    result_ref TEXT PRIMARY KEY,
    request_ref TEXT NOT NULL,
    source_root_ref TEXT NOT NULL,
    result_payload TEXT NOT NULL,
    result_digest TEXT NOT NULL,
    completeness TEXT NOT NULL CHECK (completeness IN ('complete','incomplete'))
) STRICT;

CREATE TABLE authoritative_state (
    scope_ref TEXT PRIMARY KEY,
    revision_ref TEXT NOT NULL,
    state_payload TEXT NOT NULL
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
    scope_ref TEXT NOT NULL,
    before_revision_ref TEXT NOT NULL,
    after_revision_ref TEXT NOT NULL
) STRICT;

CREATE TABLE decision_observation (
    observation_ref TEXT PRIMARY KEY,
    effect_ref TEXT NOT NULL UNIQUE,
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
    completeness TEXT NOT NULL CHECK (completeness IN ('building','complete'))
) STRICT;

CREATE TABLE view_row (
    view_ref TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    attribute_ref TEXT NOT NULL,
    value_ref TEXT NOT NULL,
    PRIMARY KEY (view_ref, ordinal)
) STRICT;

CREATE TABLE current_view (
    scope_ref TEXT PRIMARY KEY,
    view_ref TEXT NOT NULL,
    revision_ref TEXT NOT NULL
) STRICT;

CREATE TABLE fault_activation (
    fault_nonce TEXT PRIMARY KEY,
    hook_id TEXT NOT NULL,
    phase TEXT NOT NULL,
    effect_ref TEXT NOT NULL,
    implementation_revision TEXT NOT NULL,
    armed INTEGER NOT NULL CHECK (armed IN (0,1))
) STRICT;

CREATE TRIGGER trigger_bc08_after_transition
AFTER INSERT ON state_transition
WHEN EXISTS (
    SELECT 1 FROM fault_activation
     WHERE armed = 1
       AND effect_ref = NEW.effect_ref
       AND hook_id = 'hook-bc08-after-transition'
       AND phase = 'after-transition'
)
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC08_FAULT_AFTER_TRANSITION');
END;

CREATE TRIGGER trigger_bc08_after_observation
AFTER INSERT ON decision_observation
WHEN EXISTS (
    SELECT 1 FROM fault_activation
     WHERE armed = 1
       AND effect_ref = NEW.effect_ref
       AND hook_id = 'hook-bc08-after-observation'
       AND phase = 'after-observation'
)
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC08_FAULT_AFTER_OBSERVATION');
END;

CREATE TRIGGER trigger_bc08_after_view_header
AFTER INSERT ON view_header
WHEN EXISTS (
    SELECT 1 FROM fault_activation
     WHERE armed = 1
       AND effect_ref = NEW.effect_ref
       AND hook_id = 'hook-bc08-after-view-header'
       AND phase = 'after-view-header'
)
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC08_FAULT_AFTER_VIEW_HEADER');
END;

CREATE TRIGGER trigger_bc08_after_view_row
AFTER INSERT ON view_row
WHEN EXISTS (
    SELECT 1 FROM fault_activation
     WHERE armed = 1
       AND effect_ref = (
           SELECT effect_ref FROM view_header
            WHERE view_ref = NEW.view_ref
       )
       AND hook_id = 'hook-bc08-after-view-row'
       AND phase = 'after-view-row'
)
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC08_FAULT_AFTER_VIEW_ROW');
END;

CREATE TRIGGER trigger_bc08_before_current_update
BEFORE INSERT ON current_view
WHEN EXISTS (
    SELECT 1 FROM fault_activation
     WHERE armed = 1
       AND effect_ref = (
           SELECT effect_ref FROM view_header
            WHERE view_ref = NEW.view_ref
       )
       AND hook_id = 'hook-bc08-before-current-update'
       AND phase = 'before-current-update'
)
BEGIN
    SELECT RAISE(ABORT, 'LICIUM_BC08_FAULT_BEFORE_CURRENT_UPDATE');
END;
