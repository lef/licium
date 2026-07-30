PRAGMA foreign_keys = ON;

CREATE TABLE source_pair (
    object_ref TEXT PRIMARY KEY,
    logical_id TEXT NOT NULL,
    logical_value TEXT NOT NULL
) STRICT;

CREATE TABLE evaluation_request (
    request_ref TEXT PRIMARY KEY,
    request_kind TEXT NOT NULL,
    source_object_ref TEXT NOT NULL REFERENCES source_pair(object_ref)
) STRICT;

CREATE TABLE authoritative_state (
    scope_ref TEXT PRIMARY KEY,
    state_ref TEXT NOT NULL
) STRICT;

CREATE TABLE result_store (
    result_ref TEXT PRIMARY KEY,
    request_ref TEXT NOT NULL REFERENCES evaluation_request(request_ref)
) STRICT;

CREATE TABLE decision_observation (
    observation_ref TEXT PRIMARY KEY,
    request_ref TEXT NOT NULL REFERENCES evaluation_request(request_ref)
) STRICT;
