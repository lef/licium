PRAGMA foreign_keys = ON;

CREATE TABLE stored_root (
    root_id TEXT PRIMARY KEY,
    availability TEXT NOT NULL CHECK (availability = 'complete')
) STRICT;

CREATE TABLE publication (
    publication_id TEXT PRIMARY KEY,
    authority_domain TEXT NOT NULL,
    proposed_root TEXT NOT NULL REFERENCES stored_root(root_id)
) STRICT;

CREATE TABLE publication_decision (
    publication_id TEXT PRIMARY KEY
        REFERENCES publication(publication_id),
    decision TEXT NOT NULL CHECK (decision IN ('accepted', 'rejected'))
) STRICT;
