WITH counts(name, value) AS (
    SELECT 'decision_observation', count(*)
    FROM decision_observation
    UNION ALL
    SELECT 'persisted_result', count(*)
    FROM persisted_result
    UNION ALL
    SELECT 'repository_transition', count(*)
    FROM repository_transition
)
SELECT name, value
FROM counts
ORDER BY name COLLATE BINARY;
