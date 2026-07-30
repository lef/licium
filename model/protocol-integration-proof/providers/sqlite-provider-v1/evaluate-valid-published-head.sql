WITH authenticated(stable_protocol_account_key) AS (
    SELECT stable_protocol_account_key
    FROM credential
    WHERE login_identifier = 'login-alice'
      AND synthetic_proof = 'toy-password-v1'
),
selected_root(root_ref) AS (
    SELECT root_ref
    FROM publication
    WHERE publication_ref = 'publication-auth-v2'
      AND scope_ref = 'identity-login-scope-v1'
),
rows(kind, name, value) AS (
    SELECT 'envelope', 'context_ref', pin.context_ref
    FROM evaluation_pin AS pin
    JOIN selected_root USING (root_ref)
    UNION ALL
    SELECT 'envelope', 'credential_authority_ref', 'cred-auth-v1'
    UNION ALL
    SELECT 'envelope', 'credential_store_revision', 'credential-store-v1'
    UNION ALL
    SELECT 'envelope', 'definition_ref', pin.definition_ref
    FROM evaluation_pin AS pin
    JOIN selected_root USING (root_ref)
    UNION ALL
    SELECT 'envelope', 'disposition', 'accepted'
    UNION ALL
    SELECT 'envelope', 'outcome_persistence', 'ephemeral'
    UNION ALL
    SELECT 'envelope', 'profile_ref', pin.profile_ref
    FROM evaluation_pin AS pin
    JOIN selected_root USING (root_ref)
    UNION ALL
    SELECT 'envelope', 'root_ref', root_ref
    FROM selected_root
    UNION ALL
    SELECT 'envelope', 'stable_protocol_account_key',
           stable_protocol_account_key
    FROM authenticated
    UNION ALL
    SELECT 'value', value.name, value.value
    FROM selected_value AS value
    JOIN selected_root USING (root_ref)
    JOIN authenticated USING (stable_protocol_account_key)
    WHERE value.selected = 1
)
SELECT kind, name, value
FROM rows
ORDER BY kind COLLATE BINARY, name COLLATE BINARY, value COLLATE BINARY;
