config {
    type: "table",
    schema: "ga4_flattened",
    description: "Tabela rozwiązywania tożsamości cross-device dla użytkowników (Identity resolution). Lookback window: 30 dni."
}

-- Pobieramy wszystkie wystąpienia gdzie user_id było przypisane na tle user_pseudo_id na przestrzeni 30 dni
WITH id_matches AS (
    SELECT
        user_pseudo_id,
        user_id,
        MIN(event_timestamp) AS first_seen_with_id
    FROM
        ${ref("ga4_pre_events")}
    WHERE
        user_id IS NOT NULL 
        -- Ustawione lookback window (np zapuszczając na bieżąco analizę ostatnich 30 dni aktywności)
        -- Ze względu na wydajność w BigQuery, warto byłoby tutaj operować inkrementalnie, ale w tym modelu budujemy całościowo
        AND event_date >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
    GROUP BY
        user_pseudo_id,
        user_id
)

SELECT
    user_pseudo_id,
    user_id AS resolved_user_id
FROM
    id_matches
-- Usunięcie potencjalnych konfliktów przypisując pierwsze rozpoznane ID
QUALIFY ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY first_seen_with_id) = 1
