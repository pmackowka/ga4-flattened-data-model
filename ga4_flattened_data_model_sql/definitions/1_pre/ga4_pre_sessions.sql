config {
    type: "incremental",
    schema: "ga4_flattened",
    description: "Agregacja zdarzeń do poziomu sesji - określenie piewszego i ostatniego źródła w sesji.",
    uniqueKey: ["session_key"]
}

WITH session_events AS (
    SELECT
        CONCAT(user_pseudo_id, CAST(ga_session_id AS STRING)) AS session_key,
        user_pseudo_id,
        ga_session_id,
        event_timestamp,
        fixed_traffic_source,
        fixed_traffic_medium,
        fixed_traffic_campaign
    FROM
        ${ref("ga4_pre_events")}
    WHERE
        ga_session_id IS NOT NULL
        ${when(incremental(), "AND event_date >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY))")}
)

SELECT
    session_key,
    user_pseudo_id,
    ga_session_id,
    
    -- Wyznacz czas startu sesji
    MIN(event_timestamp) AS session_start_timestamp,
    
    -- Źródło pierwszego zdarzenia w sesji
    FIRST_VALUE(fixed_traffic_source IGNORE NULLS) OVER (PARTITION BY session_key ORDER BY event_timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS session_first_source,
    FIRST_VALUE(fixed_traffic_medium IGNORE NULLS) OVER (PARTITION BY session_key ORDER BY event_timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS session_first_medium,
    
    -- Źródło ostatniego przydzielonego zdarzenia w sesji
    LAST_VALUE(fixed_traffic_source IGNORE NULLS) OVER (PARTITION BY session_key ORDER BY event_timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS session_last_source,
    LAST_VALUE(fixed_traffic_medium IGNORE NULLS) OVER (PARTITION BY session_key ORDER BY event_timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS session_last_medium

FROM
    session_events
GROUP BY
    session_key,
    user_pseudo_id,
    ga_session_id,
    fixed_traffic_source,
    fixed_traffic_medium,
    event_timestamp
