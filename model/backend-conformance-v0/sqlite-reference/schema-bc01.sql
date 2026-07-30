PRAGMA foreign_keys = ON;

CREATE TABLE delivery (
    delivery_ref TEXT PRIMARY KEY,
    occurrence_ref TEXT NOT NULL,
    subject TEXT NOT NULL,
    logical_value TEXT NOT NULL
) STRICT;

CREATE TABLE association_occurrence (
    occurrence_ref TEXT PRIMARY KEY,
    delivery_ref TEXT NOT NULL REFERENCES delivery(delivery_ref),
    subject TEXT NOT NULL,
    logical_value TEXT NOT NULL
) STRICT;

CREATE TABLE logical_association (
    association_ref INTEGER PRIMARY KEY,
    subject TEXT NOT NULL,
    logical_value TEXT NOT NULL
) STRICT;
