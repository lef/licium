WITH authenticated(stable_protocol_account_key) AS (
    SELECT stable_protocol_account_key
    FROM credential
    WHERE login_identifier =
              COALESCE(@login_identifier, 'login-alice')
      AND synthetic_proof =
              COALESCE(@synthetic_proof, 'toy-password-v1')
),
pin AS (
    SELECT *
    FROM evaluation_pin
    WHERE root_ref = 'root-auth-v1'
),
rows(kind, name, value) AS (
    SELECT 'envelope', 'context_ref',
           COALESCE(@context_ref, pin.context_ref)
    FROM authenticated, pin
    UNION ALL
    SELECT 'envelope', 'credential_authority_ref', 'cred-auth-v1'
    FROM authenticated, pin
    UNION ALL
    SELECT 'envelope', 'credential_store_revision', 'credential-store-v1'
    FROM authenticated, pin
    UNION ALL
    SELECT 'envelope', 'definition_ref', pin.definition_ref
    FROM authenticated, pin
    UNION ALL
    SELECT 'envelope', 'disposition', 'accepted'
    FROM authenticated, pin
    UNION ALL
    SELECT 'envelope', 'outcome_persistence', 'ephemeral'
    FROM authenticated, pin
    UNION ALL
    SELECT 'envelope', 'profile_ref', pin.profile_ref
    FROM authenticated, pin
    UNION ALL
    SELECT 'envelope', 'root_ref', pin.root_ref
    FROM authenticated, pin
    UNION ALL
    SELECT 'envelope', 'stable_protocol_account_key',
           authenticated.stable_protocol_account_key
    FROM authenticated, pin
    UNION ALL
    SELECT 'value', value.name, value.value
    FROM authenticated
    JOIN selected_value AS value
      ON value.stable_protocol_account_key =
         authenticated.stable_protocol_account_key
    WHERE value.root_ref = 'root-auth-v1'
      AND value.selected = 1
    UNION ALL
    SELECT 'relation', relation.name, relation.target
    FROM authenticated
    JOIN selected_relation AS relation
      ON relation.stable_protocol_account_key =
         authenticated.stable_protocol_account_key
    WHERE relation.root_ref = 'root-auth-v1'
      AND relation.selected = 1
)
SELECT kind, name, value
FROM rows
ORDER BY kind COLLATE BINARY, name COLLATE BINARY, value COLLATE BINARY;
