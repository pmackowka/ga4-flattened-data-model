config {
    type: "table",
    schema: "ga4_flattened",
    description: "Docelowa tabela podsumowująca paramery transakcji wraz ze skorygowaną atrybucją."
}

WITH purchase_events AS (
    SELECT
        e.user_pseudo_id,
        CONCAT(e.user_pseudo_id, CAST(e.ga_session_id AS STRING)) AS session_key,
        e.event_date,
        e.event_timestamp,
        e.ecommerce.transaction_id,
        e.ecommerce.purchase_revenue,
        e.ecommerce.tax,
        e.ecommerce.shipping
    FROM
        ${ref("ga4_pre_events")} e
    WHERE
        e.event_name = 'purchase'
        AND e.ecommerce.transaction_id IS NOT NULL
)

SELECT
    p.event_date,
    p.transaction_id,
    id_map.resolved_user_id,
    p.purchase_revenue,
    p.tax,
    p.shipping,
    -- Podpięcie źródeł z modelu atrybucji (klasyczny Last Non Direct)
    attr.final_session_source AS attribution_source,
    attr.final_session_medium AS attribution_medium,
    -- Waga modelu (dla Linear można byłoby to przemnożyć tak, aby rozłożyć kwotę na różne źródła per ten sam trans_id)
    attr.attribution_weight,
    (p.purchase_revenue * attr.attribution_weight) AS attributed_revenue
FROM
    purchase_events p
LEFT JOIN
    ${ref("ga4_attribution_last_non_direct")} attr 
    ON p.session_key = attr.session_key
LEFT JOIN
    ${ref("ga4_unified_id")} id_map
    ON p.user_pseudo_id = id_map.user_pseudo_id
