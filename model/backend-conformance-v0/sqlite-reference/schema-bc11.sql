PRAGMA foreign_keys=ON;

CREATE TABLE source_object (
    object_ref TEXT PRIMARY KEY,
    object_role TEXT NOT NULL,
    object_value TEXT NOT NULL
);

CREATE TABLE root (
    root_ref TEXT PRIMARY KEY,
    completeness TEXT NOT NULL
);

CREATE TABLE root_member (
    root_ref TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    object_ref TEXT NOT NULL,
    selected INTEGER NOT NULL,
    PRIMARY KEY (root_ref, ordinal),
    FOREIGN KEY (root_ref) REFERENCES root(root_ref),
    FOREIGN KEY (object_ref) REFERENCES source_object(object_ref)
);

CREATE TABLE ambient_current (
    slot TEXT PRIMARY KEY,
    root_ref TEXT NOT NULL,
    FOREIGN KEY (root_ref) REFERENCES root(root_ref)
);

CREATE TABLE evaluation_request (
    request_ref TEXT PRIMARY KEY,
    subject_ref TEXT NOT NULL
);

CREATE TABLE evaluation_input (
    request_ref TEXT NOT NULL,
    input_role TEXT NOT NULL,
    input_ref TEXT NOT NULL,
    PRIMARY KEY (request_ref, input_role),
    FOREIGN KEY (request_ref) REFERENCES evaluation_request(request_ref)
);

CREATE TABLE result_output (
    result_ref TEXT PRIMARY KEY,
    request_ref TEXT NOT NULL,
    source_root_ref TEXT NOT NULL,
    definition_ref TEXT NOT NULL,
    selected_member_ref TEXT NOT NULL,
    selected_value TEXT NOT NULL,
    completeness TEXT NOT NULL,
    FOREIGN KEY (request_ref) REFERENCES evaluation_request(request_ref),
    FOREIGN KEY (source_root_ref) REFERENCES root(root_ref)
);

CREATE TABLE replay_output (
    replay_ref TEXT PRIMARY KEY,
    original_result_ref TEXT NOT NULL,
    request_ref TEXT NOT NULL,
    source_root_ref TEXT NOT NULL,
    definition_ref TEXT NOT NULL,
    selected_value TEXT NOT NULL,
    disposition TEXT NOT NULL
);

CREATE TABLE view_output (
    view_ref TEXT PRIMARY KEY,
    source_root_ref TEXT NOT NULL,
    definition_ref TEXT NOT NULL,
    completeness TEXT NOT NULL,
    FOREIGN KEY (source_root_ref) REFERENCES root(root_ref)
);

CREATE TABLE replay_omission (
    replay_ref TEXT NOT NULL,
    omitted_role TEXT NOT NULL,
    input_role TEXT NOT NULL,
    input_status TEXT NOT NULL,
    disposition TEXT NOT NULL,
    difference_count INTEGER NOT NULL,
    PRIMARY KEY (replay_ref, omitted_role, input_role)
);

CREATE TABLE explanation_output (
    explanation_ref TEXT PRIMARY KEY,
    completeness TEXT NOT NULL
);

CREATE TABLE explanation_edge (
    explanation_ref TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    edge_role TEXT NOT NULL,
    target_ref TEXT NOT NULL,
    PRIMARY KEY (explanation_ref, ordinal),
    FOREIGN KEY (explanation_ref) REFERENCES explanation_output(explanation_ref)
);

-- Integrity subjects deliberately retain references that may be dangling or
-- cross-root. They are source evidence to validate, not foreign keys for
-- SQLite to repair or reject.
CREATE TABLE integrity_subject (
    subject_ref TEXT PRIMARY KEY,
    subject_kind TEXT NOT NULL,
    source_root_ref TEXT NOT NULL,
    target_kind TEXT NOT NULL,
    target_ref TEXT NOT NULL,
    target_root_ref TEXT NOT NULL,
    member_ref TEXT NOT NULL
);

CREATE TABLE integrity_finding (
    validation_ref TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    finding_kind TEXT NOT NULL,
    source_ref TEXT NOT NULL,
    target_ref TEXT NOT NULL,
    PRIMARY KEY (validation_ref, ordinal)
);

CREATE TABLE validation_inventory (
    validation_ref TEXT PRIMARY KEY,
    before_digest TEXT NOT NULL,
    after_digest TEXT NOT NULL,
    repair_count INTEGER NOT NULL
);
