PRAGMA foreign_keys=ON;

CREATE TABLE root (
    root_ref TEXT PRIMARY KEY
);

CREATE TABLE canonical_object (
    root_ref TEXT NOT NULL,
    object_ref TEXT NOT NULL,
    PRIMARY KEY (root_ref, object_ref),
    FOREIGN KEY (root_ref) REFERENCES root(root_ref)
);

CREATE TABLE witness (
    witness_ref TEXT PRIMARY KEY,
    root_ref TEXT NOT NULL,
    reason TEXT NOT NULL,
    witness_state TEXT NOT NULL,
    FOREIGN KEY (root_ref) REFERENCES root(root_ref)
);

CREATE TABLE conflict (
    conflict_ref TEXT PRIMARY KEY,
    root_ref TEXT NOT NULL,
    conflict_state TEXT NOT NULL,
    FOREIGN KEY (root_ref) REFERENCES root(root_ref)
);

CREATE TABLE publication (
    publication_ref TEXT PRIMARY KEY,
    root_ref TEXT NOT NULL,
    publication_state TEXT NOT NULL,
    FOREIGN KEY (root_ref) REFERENCES root(root_ref)
);

CREATE TABLE forget_event (
    event_ref TEXT PRIMARY KEY,
    root_ref TEXT NOT NULL,
    event_state TEXT NOT NULL,
    FOREIGN KEY (root_ref) REFERENCES root(root_ref)
);

CREATE TABLE archive_state (
    archive_ref TEXT PRIMARY KEY,
    root_ref TEXT NOT NULL,
    archive_status TEXT NOT NULL,
    FOREIGN KEY (root_ref) REFERENCES root(root_ref)
);

CREATE TABLE policy_phase (
    phase TEXT PRIMARY KEY
);

CREATE TABLE derived_protection (
    root_ref TEXT NOT NULL,
    reason TEXT NOT NULL,
    source_kind TEXT NOT NULL,
    source_ref TEXT NOT NULL,
    PRIMARY KEY (root_ref, reason, source_kind, source_ref)
);

CREATE TABLE placement_decision (
    phase TEXT NOT NULL,
    root_ref TEXT NOT NULL,
    decision TEXT NOT NULL,
    blocker TEXT NOT NULL,
    PRIMARY KEY (phase, root_ref)
);

CREATE TABLE decision_provenance (
    phase TEXT NOT NULL,
    root_ref TEXT NOT NULL,
    source_kind TEXT NOT NULL,
    source_ref TEXT NOT NULL,
    PRIMARY KEY (phase, root_ref, source_kind, source_ref)
);

CREATE TABLE inventory_validation (
    validation_ref TEXT PRIMARY KEY,
    before_digest TEXT NOT NULL,
    after_digest TEXT NOT NULL,
    difference_count INTEGER NOT NULL
);
