SELECT
    'pinned-closure' AS case_id,
    'closure' AS kind,
    name,
    value
FROM (
    SELECT 'bindings_ref' AS name, bindings_ref AS value
    FROM evaluation_pin
    WHERE root_ref = 'root-auth-v1'
    UNION ALL
    SELECT 'context_ref', context_ref
    FROM evaluation_pin
    WHERE root_ref = 'root-auth-v1'
    UNION ALL
    SELECT 'definition_ref', definition_ref
    FROM evaluation_pin
    WHERE root_ref = 'root-auth-v1'
    UNION ALL
    SELECT 'profile_ref', profile_ref
    FROM evaluation_pin
    WHERE root_ref = 'root-auth-v1'
    UNION ALL
    SELECT 'root_ref', root_ref
    FROM evaluation_pin
    WHERE root_ref = 'root-auth-v1'
    UNION ALL
    SELECT 'semantics_ref', semantics_ref
    FROM evaluation_pin
    WHERE root_ref = 'root-auth-v1'
)
ORDER BY name COLLATE BINARY, value COLLATE BINARY;
