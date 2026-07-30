WITH authenticated(stable_protocol_account_key) AS (
    SELECT stable_protocol_account_key
    FROM credential
    WHERE login_identifier = 'login-alice'
      AND synthetic_proof = 'toy-password-v1'
),
pin AS (
    SELECT *
    FROM evaluation_pin
    WHERE root_ref = 'root-auth-v1'
),
rows(case_id, kind, name, value) AS (
    SELECT 'ephemeral-provenance', 'outcome',
           'outcome_ref', 'outcome-valid-v1'
    FROM authenticated, pin
    UNION ALL
    SELECT 'ephemeral-provenance', 'outcome',
           'persistence', 'ephemeral'
    FROM authenticated, pin
    UNION ALL
    SELECT 'ephemeral-provenance', 'persistence',
           'persisted_result_count', CAST(count(*) AS TEXT)
    FROM authenticated, pin, persisted_result
    UNION ALL
    SELECT 'ephemeral-provenance', 'projection',
           'context_ref', context_ref
    FROM authenticated, pin
    UNION ALL
    SELECT 'ephemeral-provenance', 'projection',
           'definition_ref', definition_ref
    FROM authenticated, pin
    UNION ALL
    SELECT 'ephemeral-provenance', 'projection',
           'profile_ref', profile_ref
    FROM authenticated, pin
    UNION ALL
    SELECT 'ephemeral-provenance', 'projection',
           'projection_receipt_ref', 'projection-receipt-v1'
    FROM authenticated, pin
    UNION ALL
    SELECT 'ephemeral-provenance', 'projection',
           'root_ref', root_ref
    FROM authenticated, pin
)
SELECT case_id, kind, name, value
FROM rows
ORDER BY case_id COLLATE BINARY, kind COLLATE BINARY,
         name COLLATE BINARY, value COLLATE BINARY;
