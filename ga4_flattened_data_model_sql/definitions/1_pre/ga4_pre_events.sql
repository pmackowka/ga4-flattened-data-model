config {
    type: "incremental",
    schema: "ga4_flattened",
    description: "Preprocessing events: wyciąganie parametrów, standaryzacja źródła (w tym z URL/tagów) oraz ID zdarzeń.",
    uniqueKey: ["event_id"]
}

WITH base AS (
    SELECT
        -- Unikalny identyfikator zdarzenia
        CONCAT(user_pseudo_id, CAST(event_timestamp AS STRING), event_name, CAST(event_bundle_sequence_id AS STRING), CAST(event_server_timestamp_offset AS STRING)) AS event_id,
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        user_id,
        -- Podstawowe wyciąganie zagnieżdżonych parametrów sesji i URL strony
        (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
        CONCAT(user_pseudo_id, CAST(ga_session_id AS STRING)) AS session_key,
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign') AS param_campaign,
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS param_source,
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS param_medium,
        
        -- Domyślne dane ruchu
        collected_traffic_source.manual_campaign.source AS collected_source,
        collected_traffic_source.manual_campaign.medium AS collected_medium,
        collected_traffic_source.manual_campaign.campaign_name AS collected_campaign,
        
        session_traffic_source_last_click.manual_campaign.source AS session_fallback_source,
        session_traffic_source_last_click.manual_campaign.medium AS session_fallback_medium,
        session_traffic_source_last_click.manual_campaign.campaign_name AS session_fallback_campaign,
        
        ecommerce,
        items
    FROM
        ${ref("events_*")}
    WHERE 
        -- Inkrementalny filtr daty
        ${when(incremental(), "event_date >= FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY))")}
)

SELECT
    event_id,
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    event_timestamp,
    event_name,
    user_pseudo_id,
    user_id,
    ga_session_id,
    
    -- Szerokie przypisanie źródeł (najpierw z URL/UTM, potem event params, potem zebrane przez GA4)
    COALESCE(
        REGEXP_EXTRACT(page_location, r'[?&]utm_source=([^&]+)'),
        param_source,
        collected_source,
        session_fallback_source
    ) AS fixed_traffic_source,
    
    COALESCE(
        REGEXP_EXTRACT(page_location, r'[?&]utm_medium=([^&]+)'),
        param_medium,
        collected_medium,
        session_fallback_medium
    ) AS fixed_traffic_medium,
    
    COALESCE(
        REGEXP_EXTRACT(page_location, r'[?&]utm_campaign=([^&]+)'),
        param_campaign,
        collected_campaign,
        session_fallback_campaign
    ) AS fixed_traffic_campaign,
    
    -- Dane ecommerce
    ecommerce,
    items
FROM base
