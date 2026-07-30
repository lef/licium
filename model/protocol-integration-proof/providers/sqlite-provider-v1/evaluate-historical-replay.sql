BEGIN IMMEDIATE;
UPDATE publication
SET root_ref = 'root-auth-v1'
WHERE scope_ref = 'identity-login-scope-v1';
UPDATE publication
SET root_ref = 'root-auth-v2'
WHERE scope_ref = 'identity-login-scope-v1';
COMMIT;

WITH target(kind, root_ref) AS (
    SELECT 'current', root_ref
    FROM publication
    WHERE scope_ref = 'identity-login-scope-v1'
    UNION ALL
    SELECT 'historical', 'root-auth-v1'
),
rows(case_id, kind, name, value) AS (
    SELECT 'historical-replay', kind, 'root_ref', root_ref
    FROM target
    UNION ALL
    SELECT 'historical-replay', target.kind,
           'display-name', value.value
    FROM target
    JOIN selected_value AS value
      ON value.root_ref = target.root_ref
    WHERE value.stable_protocol_account_key = 'account-alice'
      AND value.name = 'display-name'
      AND value.selected = 1
)
SELECT case_id, kind, name, value
FROM rows
ORDER BY case_id COLLATE BINARY, kind COLLATE BINARY,
         name COLLATE BINARY, value COLLATE BINARY;
