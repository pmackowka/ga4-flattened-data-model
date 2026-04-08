config {
    type: "table",
    schema: "ga4_flattened",
    description: "Model atrybucji First Click - 100% wartości konwersji do pierwszej sesji na ścieżce."
}

WITH user_paths AS (
    SELECT
        user_pseudo_id,
        session_key,
        final_session_source,
        final_session_medium,
        session_start_timestamp,
        ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY session_start_timestamp ASC) as session_rank
    FROM
        ${ref("ga4_sessions")}
)

SELECT
    user_pseudo_id,
    session_key,
    final_session_source,
    final_session_medium,
    -- 1.0 oznacza 100% udziału dla wybranej sesji
    1.0 AS attribution_weight
FROM
    user_paths
WHERE
    session_rank = 1
