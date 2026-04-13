-- Konfiguracja raportowa z modelem konwersyjnej atrybucji Last Non Direct
config {
    -- Ustanowienie typu pliku (bez aktualizacji danych) jako tabela by zbiory BQ pchały na interfejs
    type: "table",
    
    -- Ostateczna schemat bazy w Dataformie
    schema: "ga4_flattened",
    
    -- Wyjaśnienie operacji
    description: "Docelowa tabela podsumowująca parametry transakcji wraz ze skorygowaną twardą atrybucją G4."
}

-- Pętla otwierająca poziom transakcji dla całej operacji CTE
WITH purchase_events AS (
    SELECT
        -- Bazowe przekłucie pacjenta dla złączeń
        e.user_pseudo_id,
        
        -- Wymiar sesji łącznego unikalnego
        e.session_key,
        
        -- Identyfikatory temporalne daty
        e.event_date,
        e.event_timestamp,
        
        -- Pobieramy główne statystyki transakcyjne na bazie obiektu ecommerce (stringów/numerów)
        e.ecommerce.transaction_id,
        e.ecommerce.purchase_revenue,
        e.ecommerce.tax,
        e.ecommerce.shipping
        
    -- Puszczamy prosto pre_events pierwszej fali.
    FROM
        ${ref("ga4_pre_events")} e
        
    -- [TYLKO TRANSAKCJE]
    WHERE
        e.event_name = 'purchase'
        -- Eliminujemy wadliwe uderzenia bez kluczowego transaction_id
        AND e.ecommerce.transaction_id IS NOT NULL
)

-- Zamknięcie całości ze splataniem tabel modelowych
SELECT
    -- Z CTE puszczamy do bazy niżej dane nienaruszone
    p.event_date,
    p.transaction_id,
    
    -- Korzystamy z dopiętego przez JOIN `ga4_unified_id` jako bazy mapującej rozwiązaną tożsamość
    -- użytkownika. Ląduje tu rynkowo zdekodowany id od cross device (rozwiązany CRM number).
    id_map.resolved_user_id,
    
    -- Zrzucamy kwoty do tabeli głównej
    p.purchase_revenue,
    p.tax,
    p.shipping,
    
    -- Podpięcie źródeł skonsolidowanych wyżej w wsadach
    attr.final_session_source AS attribution_source,
    attr.final_session_medium AS attribution_medium,
    
    -- [WAŻNE - WYKORZYSTANIE ATTRIBUTION_WEIGHT Z POPRZEDNIEJ WARSTWY]
    -- Puszczamy nienaruszoną wagę operacyjną (np 1.0 dla L-N-D).
    attr.attribution_weight,
    
    -- A tutaj wykorzystujemy ją merytorycznie w kolumnie wyliczanej
    -- przemnażając obrót brutto transakcji revenue przez pociętą wagę atrybucji (działalne dla Linear / Time Decay!).
    (p.purchase_revenue * attr.attribution_weight) AS attributed_revenue
    
FROM
    -- Z naszej wirtualnej CTE transakcji Purchases
    purchase_events p
    
-- Doklejamy z WARSTWY 3 - modelu "Last Non Direct" by dorzucić docelowy attribution.
LEFT JOIN
    ${ref("ga4_attribution_last_non_direct")} attr 
    ON p.session_key = attr.session_key
    
-- Doklejamy z WARSTWY 2 - modelu rozbitego identity "Unified ID" głównie dla zalogowanych koszyków by poskładać urządzenia
LEFT JOIN
    ${ref("ga4_unified_id")} id_map
    ON p.user_pseudo_id = id_map.user_pseudo_id
