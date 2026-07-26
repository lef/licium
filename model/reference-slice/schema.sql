PRAGMA foreign_keys=ON;

CREATE TABLE repository_object (
    object_ref TEXT PRIMARY KEY,
    object_kind TEXT NOT NULL,
    exact_representation TEXT NOT NULL
);

CREATE TABLE pair_payload (
    object_ref TEXT PRIMARY KEY REFERENCES repository_object(object_ref),
    logical_key TEXT NOT NULL,
    logical_value TEXT NOT NULL,
    occurrence_ref TEXT NOT NULL UNIQUE
);

CREATE TABLE definition_payload (
    object_ref TEXT PRIMARY KEY REFERENCES repository_object(object_ref),
    definition_ref TEXT NOT NULL,
    definition_value TEXT NOT NULL
);

CREATE TABLE definition_current (
    scope_ref TEXT PRIMARY KEY,
    definition_ref TEXT NOT NULL
);

CREATE TABLE delivery_attempt (
    delivery_ref TEXT PRIMARY KEY,
    occurrence_ref TEXT NOT NULL,
    outcome TEXT NOT NULL CHECK (outcome IN ('inserted','duplicate'))
);

CREATE TABLE root (
    root_ref TEXT PRIMARY KEY,
    completeness TEXT NOT NULL CHECK (completeness='complete')
);

CREATE TABLE root_member (
    root_ref TEXT NOT NULL REFERENCES root(root_ref),
    ordinal INTEGER NOT NULL,
    object_ref TEXT NOT NULL REFERENCES repository_object(object_ref),
    PRIMARY KEY (root_ref,ordinal),
    UNIQUE (root_ref,object_ref)
);

CREATE TABLE publication (
    publication_ref TEXT PRIMARY KEY,
    authority_ref TEXT NOT NULL,
    root_ref TEXT NOT NULL REFERENCES root(root_ref),
    disposition TEXT NOT NULL,
    reason TEXT NOT NULL
);

CREATE TABLE head (
    authority_ref TEXT PRIMARY KEY,
    root_ref TEXT NOT NULL REFERENCES root(root_ref),
    publication_ref TEXT NOT NULL REFERENCES publication(publication_ref)
);

CREATE TABLE evaluation_request (
    request_ref TEXT PRIMARY KEY,
    source_mode TEXT NOT NULL,
    subject_ref TEXT NOT NULL
);

CREATE TABLE evaluation_input (
    request_ref TEXT NOT NULL REFERENCES evaluation_request(request_ref),
    input_role TEXT NOT NULL,
    input_ref TEXT NOT NULL,
    PRIMARY KEY (request_ref,input_role)
);

CREATE TABLE evaluation_result (
    result_ref TEXT PRIMARY KEY,
    request_ref TEXT NOT NULL REFERENCES evaluation_request(request_ref),
    persistence TEXT NOT NULL,
    completeness TEXT NOT NULL,
    disposition TEXT NOT NULL,
    selected_value TEXT NOT NULL,
    source_root_ref TEXT NOT NULL REFERENCES root(root_ref)
);

CREATE TABLE evaluation_run (
    evaluation_ref TEXT PRIMARY KEY,
    request_ref TEXT NOT NULL REFERENCES evaluation_request(request_ref),
    persistence TEXT NOT NULL,
    result_ref TEXT REFERENCES evaluation_result(result_ref)
);

CREATE TABLE state_current (
    scope_ref TEXT PRIMARY KEY,
    state_ref TEXT NOT NULL,
    view_ref TEXT NOT NULL
);

CREATE TABLE state_transition (
    transition_ref TEXT PRIMARY KEY,
    scope_ref TEXT NOT NULL,
    prior_state_ref TEXT NOT NULL,
    new_state_ref TEXT NOT NULL,
    result_ref TEXT NOT NULL REFERENCES evaluation_result(result_ref),
    effect_ref TEXT NOT NULL UNIQUE
);

CREATE TABLE decision_observation (
    observation_ref TEXT PRIMARY KEY,
    transition_ref TEXT NOT NULL UNIQUE REFERENCES state_transition(transition_ref),
    result_ref TEXT NOT NULL REFERENCES evaluation_result(result_ref),
    source_root_ref TEXT NOT NULL REFERENCES root(root_ref)
);

CREATE TABLE view_publication (
    view_ref TEXT PRIMARY KEY,
    source_root_ref TEXT NOT NULL REFERENCES root(root_ref),
    source_head_ref TEXT NOT NULL,
    definition_ref TEXT NOT NULL,
    status TEXT NOT NULL
);

CREATE TABLE view_row (
    view_ref TEXT NOT NULL REFERENCES view_publication(view_ref),
    subject_ref TEXT NOT NULL,
    attribute_value TEXT NOT NULL,
    PRIMARY KEY (view_ref,subject_ref,attribute_value)
);
