WITH source(
    kind, field_1, field_2, field_3, field_4, field_5, field_6
) AS (
    SELECT 'evaluation_pin', root_ref, definition_ref, profile_ref,
           context_ref, semantics_ref, bindings_ref
    FROM evaluation_pin
    UNION ALL
    SELECT 'selected_relation', root_ref, stable_protocol_account_key,
           name, target, CAST(selected AS TEXT), ''
    FROM selected_relation
    UNION ALL
    SELECT 'selected_value', root_ref, stable_protocol_account_key,
           name, value, CAST(selected AS TEXT), ''
    FROM selected_value
)
SELECT kind, field_1, field_2, field_3, field_4, field_5, field_6
FROM source
ORDER BY kind COLLATE BINARY, field_1 COLLATE BINARY,
         field_2 COLLATE BINARY, field_3 COLLATE BINARY,
         field_4 COLLATE BINARY, field_5 COLLATE BINARY,
         field_6 COLLATE BINARY;
