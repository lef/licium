WITH target(case_id, source_mode, root_ref, evidence_name, evidence_ref) AS (
    SELECT @case_id, 'exact_root', exact_root_ref,
           'write_receipt_ref', receipt_ref
    FROM write_receipt
    WHERE @case_id = 'exact-root'
      AND receipt_ref = 'write-receipt-v1'
    UNION ALL
    SELECT @case_id, 'published_head', root_ref,
           'publication_ref', publication_ref
    FROM publication
    WHERE @case_id = 'published-head'
      AND scope_ref = 'identity-login-scope-v1'
),
rows(case_id, kind, name, value) AS (
    SELECT case_id, 'envelope', 'root_ref', root_ref
    FROM target
    UNION ALL
    SELECT case_id, 'envelope', 'source_mode', source_mode
    FROM target
    UNION ALL
    SELECT case_id, 'envelope', evidence_name, evidence_ref
    FROM target
    UNION ALL
    SELECT target.case_id, 'value', value.name, value.value
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
