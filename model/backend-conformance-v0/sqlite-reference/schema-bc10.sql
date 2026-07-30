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

CREATE TABLE publication (
    publication_ref TEXT PRIMARY KEY,
    authority_ref TEXT NOT NULL,
    root_ref TEXT NOT NULL,
    disposition TEXT NOT NULL,
    FOREIGN KEY (root_ref) REFERENCES root(root_ref)
);

CREATE TABLE authority_head (
    authority_ref TEXT PRIMARY KEY,
    root_ref TEXT NOT NULL,
    publication_ref TEXT NOT NULL,
    FOREIGN KEY (root_ref) REFERENCES root(root_ref),
    FOREIGN KEY (publication_ref) REFERENCES publication(publication_ref)
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

CREATE TABLE view_output (
    view_ref TEXT PRIMARY KEY,
    source_root_ref TEXT NOT NULL,
    source_head_ref TEXT NOT NULL,
    definition_ref TEXT NOT NULL,
    completeness TEXT NOT NULL,
    FOREIGN KEY (source_root_ref) REFERENCES root(root_ref)
);

CREATE TABLE view_row (
    view_ref TEXT NOT NULL,
    ordinal INTEGER NOT NULL,
    member_ref TEXT NOT NULL,
    selected_value TEXT NOT NULL,
    PRIMARY KEY (view_ref, ordinal),
    FOREIGN KEY (view_ref) REFERENCES view_output(view_ref)
);

CREATE TABLE replay_output (
    replay_ref TEXT PRIMARY KEY,
    original_result_ref TEXT NOT NULL,
    request_ref TEXT NOT NULL,
    source_root_ref TEXT NOT NULL,
    definition_ref TEXT NOT NULL,
    selected_value TEXT NOT NULL,
    completeness TEXT NOT NULL,
    FOREIGN KEY (original_result_ref) REFERENCES result_output(result_ref),
    FOREIGN KEY (request_ref) REFERENCES evaluation_request(request_ref),
    FOREIGN KEY (source_root_ref) REFERENCES root(root_ref)
);

CREATE TABLE replay_metadata (
    replay_ref TEXT NOT NULL,
    metadata_class TEXT NOT NULL,
    metadata_value TEXT NOT NULL,
    PRIMARY KEY (replay_ref, metadata_class),
    FOREIGN KEY (replay_ref) REFERENCES replay_output(replay_ref)
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
