config {
    type: "table",
    schema: "ga4_flattened",
    description: "Tabela raportowa dla produktów (bazująca na spłaszczeniu wymiaru items z eventu zakupowego)."
}

WITH purchases AS (
    SELECT
        e.user_pseudo_id,
        e.session_key,
        e.event_timestamp,
        e.event_date,
        e.ecommerce.transaction_id,
        items
    FROM
        ${ref("ga4_pre_events")} e
    WHERE
        e.event_name = 'purchase'
        AND e.ecommerce.transaction_id IS NOT NULL
),

unnested_items AS (
    SELECT
        p.session_key,
        p.event_date,
        p.transaction_id,
        i.item_id,
        i.item_name,
        i.item_category,
        i.price,
        i.quantity,
        COALESCE(i.item_revenue, (i.price * i.quantity)) AS item_revenue
    FROM
        purchases p,
        UNNEST(p.items) as i
)

SELECT
    u.event_date,
    u.transaction_id,
    u.item_id,
    u.item_name,
    u.item_category,
    u.price,
    u.quantity,
    u.item_revenue,
    -- Podpięcie pod model atrybucji domyślny (tutaj przykładowo wzięto logikę z Last Non Direct)
    attr.final_session_source AS attribution_source,
    attr.final_session_medium AS attribution_medium,
    attr.attribution_weight
FROM
    unnested_items u
LEFT JOIN
    ${ref("ga4_attribution_last_non_direct")} attr 
    ON u.session_key = attr.session_key
