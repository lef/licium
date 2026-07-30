PRAGMA foreign_keys = ON;

CREATE TABLE evaluation_request (
    request_ref TEXT PRIMARY KEY,
    pinned_input_ref TEXT NOT NULL,
    request_kind TEXT NOT NULL
) STRICT;

CREATE TABLE evaluation_result (
    result_ref TEXT PRIMARY KEY,
    request_ref TEXT NOT NULL REFERENCES evaluation_request(request_ref),
    result_payload TEXT NOT NULL,
    result_digest TEXT NOT NULL
) STRICT;

CREATE TABLE authoritative_state (
    scope_ref TEXT PRIMARY KEY,
    revision_ref TEXT NOT NULL,
    state_payload TEXT NOT NULL
) STRICT;

CREATE TABLE effect_request (
    effect_ref TEXT PRIMARY KEY,
    result_ref TEXT NOT NULL REFERENCES evaluation_result(result_ref),
    expected_revision_ref TEXT NOT NULL
) STRICT;

CREATE TABLE state_transition (
    transition_ref TEXT PRIMARY KEY,
    scope_ref TEXT NOT NULL REFERENCES authoritative_state(scope_ref),
    before_revision_ref TEXT NOT NULL,
    after_revision_ref TEXT NOT NULL,
    effect_ref TEXT NOT NULL UNIQUE REFERENCES effect_request(effect_ref)
) STRICT;

CREATE TABLE decision_observation (
    observation_ref TEXT PRIMARY KEY,
    transition_ref TEXT NOT NULL,
    result_ref TEXT NOT NULL REFERENCES evaluation_result(result_ref),
    effect_ref TEXT NOT NULL UNIQUE REFERENCES effect_request(effect_ref)
) STRICT;
