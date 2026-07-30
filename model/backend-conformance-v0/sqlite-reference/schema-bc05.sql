PRAGMA foreign_keys = ON;

CREATE TABLE logical_object (
    object_ref TEXT PRIMARY KEY,
    object_kind TEXT NOT NULL CHECK (
        object_kind IN (
            'root', 'definition', 'semantics', 'binding', 'dependency'
        )
    ),
    payload TEXT NOT NULL
) STRICT;

CREATE TABLE closure_request (
    request_ref TEXT PRIMARY KEY,
    root_ref TEXT NOT NULL,
    definition_ref TEXT NOT NULL,
    semantics_ref TEXT NOT NULL,
    binding_ref TEXT NOT NULL,
    cut_ref TEXT NOT NULL
) STRICT;

CREATE TABLE cut_closure (
    definition_ref TEXT NOT NULL,
    cut_ref TEXT NOT NULL,
    closure_ref TEXT NOT NULL,
    PRIMARY KEY (definition_ref, cut_ref)
) STRICT;

CREATE TABLE dependency_edge (
    parent_ref TEXT NOT NULL,
    child_ref TEXT NOT NULL,
    dependency_kind TEXT NOT NULL CHECK (
        dependency_kind IN ('direct', 'transitive')
    ),
    PRIMARY KEY (parent_ref, child_ref)
) STRICT;

CREATE TABLE binding_value (
    binding_ref TEXT NOT NULL,
    selected_value TEXT NOT NULL,
    PRIMARY KEY (binding_ref, selected_value)
) STRICT;

CREATE TABLE closure_selection (
    closure_ref TEXT NOT NULL,
    selected_value TEXT NOT NULL,
    PRIMARY KEY (closure_ref, selected_value)
) STRICT;

CREATE TABLE ambient_cut (
    scope_ref TEXT PRIMARY KEY,
    cut_ref TEXT NOT NULL
) STRICT;

CREATE TABLE result_store (
    result_ref TEXT PRIMARY KEY,
    request_ref TEXT NOT NULL
) STRICT;
