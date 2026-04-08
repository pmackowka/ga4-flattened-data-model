config {
    type: "table",
    schema: "ga4_flattened",
    description: "Tabela wynikowa sesji po deduplikacji oraz nadpisaniu logicznego SESSION_LAST_NON_DIRECT."
}

-- Usuwamy duplikaty powielone przez analityczne funkcje w ga4_pre_sessions
WITH deduplicated_sessions AS (
    SELECT DISTINCT
        session_key,
        user_pseudo_id,
        ga_session_id,
        session_start_timestamp,
        session_first_source,
        session_first_medium,
        session_last_source,
        session_last_medium
    FROM
        ${ref("ga4_pre_sessions")}
),

-- Logika przepisywania ostatniego niebezpośredniego źródła za pomocą window function i partition po użytkowniku
last_non_direct_logic AS (
    SELECT 
        *,
        -- Zabezpieczamy 'direct' / '(none)'. Jeśli trafimy direct, poszukaj ostatniego nie zerowego
        LAST_VALUE(NULLIF(IF(session_first_source = '(direct)', NULL, session_first_source), NULL) IGNORE NULLS) OVER(
            PARTITION BY user_pseudo_id
            ORDER BY session_start_timestamp 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS session_last_non_direct_source,
        
        LAST_VALUE(NULLIF(IF(session_first_medium = '(none)', NULL, session_first_medium), NULL) IGNORE NULLS) OVER(
            PARTITION BY user_pseudo_id
            ORDER BY session_start_timestamp 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS session_last_non_direct_medium

    FROM deduplicated_sessions
)

SELECT 
    session_key,
    user_pseudo_id,
    ga_session_id,
    session_start_timestamp,
    session_first_source,
    session_last_source,
    -- Spadochron bezpieczeństwa wpisujący direct jeżeli pierwsze źródła nie zostały odnalezione
    COALESCE(session_last_non_direct_source, '(direct)') AS final_session_source,
    COALESCE(session_last_non_direct_medium, '(none)')  AS final_session_medium
FROM
    last_non_direct_logic
