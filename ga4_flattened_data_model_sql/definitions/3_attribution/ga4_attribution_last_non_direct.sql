config {
    type: "table",
    schema: "ga4_flattened",
    description: "Model atrybucji Last Non Direct - 100% wartości konwersji do ostatniej niebezpośredniej sesji."
}

WITH user_paths AS (
    SELECT
        user_pseudo_id,
        session_key,
        final_session_source,
        final_session_medium,
        session_start_timestamp,
        -- Sorter dla sesji wg czasu
        ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY session_start_timestamp DESC) as reverse_session_rank
    FROM
        ${ref("ga4_sessions")}
)

SELECT
    user_pseudo_id,
    session_key,
    final_session_source,
    final_session_medium,
    1.0 AS attribution_weight
FROM
    user_paths
WHERE
    -- Ze względu na fakt, że nasza tabela ga4_sessions już przepisała ruch non-direct na sesje directowe,
    -- możemy teraz bezpiecznie wziąć po prostu ostatnią sesję u danego usera do tego klasycznego modelu.
    reverse_session_rank = 1
