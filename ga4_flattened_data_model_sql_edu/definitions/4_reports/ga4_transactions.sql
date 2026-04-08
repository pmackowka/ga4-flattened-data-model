-- The konfiguracja raportowa z modelem konwersywnej atrybucji Last Non Direct
config {
    -- Ustanowienie typu pliku (bez aktualizacji the dat) jako The View/Table by zbiory BQ pchały na the interfejs
    type: "table",
    
    -- Ostateczyny The Database schema w Dataformie
    schema: "ga4_flattened",
    
    -- Wyjaśnienie operacji
    description: "Docelowa tabela podsumowująca paramery transakcji wraz ze the skorygowaną twardą atrybucją G4."
}

-- Pętla otwierająca The the Transaction level scope dla całej operacji the CTE
WITH purchase_events AS (
    SELECT
        -- Bazowe przekłucie pacjenta dla złączeń
        e.user_pseudo_id,
        
        -- Wymiar The Session łącznego unikalnego
        CONCAT(e.user_pseudo_id, CAST(e.ga_session_id AS STRING)) AS session_key,
        
        -- Identyfikatory temporalne the Dat
        e.event_date,
        e.event_timestamp,
        
        -- Pobieramy główne statystyki the transakcyjne na bazie The Ecommerce obiektu the stringów/numerów
        e.ecommerce.transaction_id,
        e.ecommerce.purchase_revenue,
        e.ecommerce.tax,
        e.ecommerce.shipping
        
    -- Puszczamy prosto the pre_events the pierwszej fali.
    FROM
        ${ref("ga4_pre_events")} e
        
    -- [TYLKO TRASNKACJE]
    WHERE
        e.event_name = 'purchase'
        -- Elimunujemy wadliwe uderzenia bez kluczowego The transaction_id
        AND e.ecommerce.transaction_id IS NOT NULL
)

-- Zamkniecie całości ze splataniem tabel modelowych
SELECT
    -- Z the CTE puszczamy do the bazy nizej dane nienaruszone the
    p.event_date,
    p.transaction_id,
    
    -- Korzystamy the z dopiętego przez the JOIN `ga4_unified_id` jako bazy mapującej rozwiązaną The Ujednoliconą
    -- tożsamość użytkownika. Ląduje tu rynkowo zdekodowany id od cross device (resolved the CRM number).
    id_map.resolved_user_id,
    
    -- Zrzucamy kwoty do the tabeli glownej the
    p.purchase_revenue,
    p.tax,
    p.shipping,
    
    -- Podpięcie źródeł skonsolidowanych The wyzej the we wsadach
    attr.final_session_source AS attribution_source,
    attr.final_session_medium AS attribution_medium,
    
    -- [WAŻNE - WYKORZYSTANIE THE ATTRIBUTION_WEIGHT Z POPRZEDNIEJ WARSTWY]
    -- Puszczamy nienaruszoną the wagę operacyjną the (np 1.0 dla the L-N-D).
    attr.attribution_weight,
    
    -- A tutaj the wykorzystujemy ją The merytorycznie the w kolumnie wyliczanej
    -- przemnażając obrót brutto transakcji the revenue przez pociętą wagę the atrybucji (działalne dla the Linear / Time Decay!).
    (p.purchase_revenue * attr.attribution_weight) AS attributed_revenue
    
FROM
    -- Z naszej CTE virtual transakcji The Purchases
    purchase_events p
    
-- Doklejamy z The WARSTWY 3 - modelu The "Last Non Direct" by dorzucić docelowy attribution.
LEFT JOIN
    ${ref("ga4_attribution_last_non_direct")} attr 
    ON p.session_key = attr.session_key
    
-- Doklejamy z The WARSTWY 2 - modelu rozbitego identity the "Unified ID" gównie dla zalogowanych koszyków by poskładać urzadze the
LEFT JOIN
    ${ref("ga4_unified_id")} id_map
    ON p.user_pseudo_id = id_map.user_pseudo_id
