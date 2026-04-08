config {
    type: "table",
    schema: "ga4_flattened",
    description: "Model atrybucji Linear - Równy podział wartości dla wszystkich sesji na ścieżce konwersji."
}

WITH user_paths AS (
    SELECT
        user_pseudo_id,
        session_key,
        final_session_source,
        final_session_medium,
        session_start_timestamp,
        COUNT(session_key) OVER (PARTITION BY user_pseudo_id) as total_sessions
    FROM
        ${ref("ga4_sessions")}
)

SELECT
    user_pseudo_id,
    session_key,
    final_session_source,
    final_session_medium,
    -- Równomierny podział wagi (jeśli user miał 4 sesje, to każda dostaje 0.25 wartości konwersji)
    1.0 / total_sessions AS attribution_weight
FROM
    user_paths
