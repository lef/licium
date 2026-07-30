PRAGMA foreign_keys = ON;

CREATE TABLE credential (
    login_identifier TEXT NOT NULL PRIMARY KEY,
    stable_protocol_account_key TEXT NOT NULL,
    synthetic_proof TEXT NOT NULL
) STRICT;

CREATE TABLE evaluation_pin (
    root_ref TEXT NOT NULL PRIMARY KEY,
    definition_ref TEXT NOT NULL,
    profile_ref TEXT NOT NULL,
    context_ref TEXT NOT NULL,
    semantics_ref TEXT NOT NULL,
    bindings_ref TEXT NOT NULL
) STRICT;

CREATE TABLE authentication_request (
    case_id TEXT NOT NULL PRIMARY KEY,
    login_identifier TEXT NOT NULL,
    synthetic_proof TEXT NOT NULL
) STRICT;

CREATE TABLE selected_value (
    root_ref TEXT NOT NULL,
    stable_protocol_account_key TEXT NOT NULL,
    name TEXT NOT NULL,
    value TEXT NOT NULL,
    selected INTEGER NOT NULL CHECK (selected IN (0, 1)),
    PRIMARY KEY (root_ref, stable_protocol_account_key, name, value)
) STRICT;

CREATE TABLE selected_relation (
    root_ref TEXT NOT NULL,
    stable_protocol_account_key TEXT NOT NULL,
    name TEXT NOT NULL,
    target TEXT NOT NULL,
    selected INTEGER NOT NULL CHECK (selected IN (0, 1)),
    PRIMARY KEY (root_ref, stable_protocol_account_key, name, target)
) STRICT;

CREATE TABLE write_receipt (
    receipt_ref TEXT NOT NULL PRIMARY KEY,
    exact_root_ref TEXT NOT NULL
) STRICT;

CREATE TABLE publication (
    publication_ref TEXT NOT NULL PRIMARY KEY,
    scope_ref TEXT NOT NULL UNIQUE,
    root_ref TEXT NOT NULL
) STRICT;

CREATE TABLE repository_transition (
    transition_ref TEXT NOT NULL PRIMARY KEY
) STRICT;

CREATE TABLE persisted_result (
    result_ref TEXT NOT NULL PRIMARY KEY
) STRICT;

CREATE TABLE decision_observation (
    observation_ref TEXT NOT NULL PRIMARY KEY
) STRICT;

INSERT INTO credential VALUES
    ('login-alice', 'account-alice', 'toy-password-v1'),
    ('login-bob', 'account-bob', 'toy-password-bob-v1');

INSERT INTO authentication_request VALUES
    ('malformed-request', '', 'toy-password-v1'),
    ('unknown-login', 'login-unknown', 'toy-password-v1'),
    ('wrong-proof', 'login-alice', 'toy-password-wrong');

INSERT INTO evaluation_pin VALUES
    ('root-auth-v1', 'definition-auth-v1', 'profile-login-v1',
     'context-claims-v1', 'semantics-v1', 'bindings-v1'),
    ('root-auth-v2', 'definition-auth-v1', 'profile-login-v1',
     'context-claims-v1', 'semantics-v1', 'bindings-v1');

INSERT INTO selected_value VALUES
    ('root-auth-v1', 'account-alice', 'display-name', 'Alice Example', 1),
    ('root-auth-v1', 'account-alice', 'private-secret',
     'secret-never-project-v1', 0),
    ('root-auth-v1', 'account-bob', 'display-name', 'Bob Example', 1),
    ('root-auth-v2', 'account-alice', 'display-name', 'Alice Updated', 1),
    ('root-auth-v2', 'account-alice', 'private-secret',
     'secret-never-project-v1', 0);

INSERT INTO selected_relation VALUES
    ('root-auth-v1', 'account-alice', 'member-of', 'team-blue', 1);

INSERT INTO write_receipt VALUES
    ('write-receipt-v1', 'root-auth-v1');

INSERT INTO publication VALUES
    ('publication-auth-v2', 'identity-login-scope-v1', 'root-auth-v2');
