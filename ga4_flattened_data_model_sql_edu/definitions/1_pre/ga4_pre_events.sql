-- Blok konfiguracji Dataform dla tabeli.
-- Ze względu na fakt, że plik ma rozszerzenie .sql (dla czytelności), składnia config{} 
-- jest potraktowana jako meta-dane.
config {
    -- Ustawiamy typ jako incremental, co pozwala dodawać do tabeli jedynie nowe wiersze z każdego dnia
    type: "incremental",
    
    -- Tabela trafi do schematu ga4_flattened
    schema: "ga4_flattened",
    
    -- Opis tabeli widoczny w dokumentacji Dataform / BigQuery
    description: "Preprocessing events: wyciąganie parametrów, standaryzacja źródła (w tym z URL/tagów) oraz ID zdarzeń.",
    
    -- Unikalny klucz wymagany do operacji przyrostowych bez nadmiarowego powielania wierszy
    uniqueKey: ["event_id"]
}

-- Otwieramy klauzulę WITH, tworząc wirtualną tabelę (CTE) o nazwie 'base'
WITH base AS (
    -- Wybiermy docelowe kolumny i obliczamy nowe pola
    SELECT
        -- Generujemy unikalny identyfikator zdarzenia. Sklejamy user_pseudo_id, znacznik czasu, nazwę eventu
        -- oraz hash (FARM_FINGERPRINT) całego stringu JSON z parametrami zdarzenia, aby zagwarantować unikalność.
        CONCAT(user_pseudo_id, CAST(event_timestamp AS STRING), event_name, CAST(FARM_FINGERPRINT(TO_JSON_STRING(event_params)) AS STRING)) AS event_id,
        
        -- Wyciągamy na wierzch datę zdarzenia (oryginalnie YYYYMMDD string)
        event_date,
        
        -- Wyciągamy na wierzch dokładny znacznik czasu (w mikrosekundach)
        event_timestamp,
        
        -- Wyciągamy na wierzch nazwę zdarzenia (np. page_view, add_to_cart)
        event_name,
        
        -- Identyfikator urządzenia/przeglądarki (tzw. Google Analytics Cookie ID)
        user_pseudo_id,
        
        -- Identyfikator zalogowanego użytkownika (jeśli został przesłany do GA4)
        user_id,
        
        -- Wyciągamy z zagnieżdżonej tablicy (UNNEST) event_params identyfikator sesji ga_session_id.
        -- Ta flaga to liczba całkowita (int_value).
        (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
        CONCAT(user_pseudo_id, CAST(ga_session_id AS STRING)) AS session_key,
        
        -- Wyciągamy pełen URL strony na której wywołano zdarzenie z parametru page_location (łańcuch tekstowy)
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
        
        -- Przechwytujemy ręcznie zapisaną kampanię z parametrów utm_campaign w event_params 
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign') AS param_campaign,
        
        -- Przechwytujemy ręcznie zapisane źródło z parametrów utm_source
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source') AS param_source,
        
        -- Przechwytujemy ręcznie zapisane medium z parametrów utm_medium
        (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium') AS param_medium,
        
        -- Jeśli chcesz wiedzieć, skąd dokładnie przyszedł ruch dla tego eventu, używasz collected_traffic_source.
        collected_traffic_source.manual_campaign.source AS collected_source,
        collected_traffic_source.manual_campaign.medium AS collected_medium,
        collected_traffic_source.manual_campaign.campaign_name AS collected_campaign,

        -- Kiedy chcesz mieć pewność, że każde zdarzenie ma przypisany jakikolwiek source/medium/campaign, nawet jeśli event nie ma jawnie ustawionych wartości.
        session_traffic_source_last_click.manual_campaign.source AS session_fallback_source,
        session_traffic_source_last_click.manual_campaign.medium AS session_fallback_medium,
        session_traffic_source_last_click.manual_campaign.campaign_name AS session_fallback_campaign,
        
        -- Pobieramy cały nienaruszony blok danych e-commerce (np. id transakcji, kwota)
        ecommerce,
        
        -- Pobieramy całą tablicę produktów ze zdarzenia koszyka lub zakupu
        items
        
    -- Definiujemy, że pobieramy te informacje ze zbioru tabel events_ zadeklarowanego w Dataform
    FROM
        ${ref("events_*")}
        
    -- Warunek WHERE filtrujący pobierane wiersze
    WHERE 
        -- RYGORYSTYCZNY FILTR testowy - pobieramy dynamicznie dane tylko z jednego, konretnego dnia:
        -- dokładnie 7 dni wstecz od bieżącej daty (CURRENT_DATE).
        -- Formatujemy uzyskaną datę z powrotem na 'YYYYMMDD', aby system BigQuery odczytał partycje.
        event_date = FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY))
)

-- Otwieramy główne zapytanie oparte o wirtualną tabelę 'base' przygotowaną powyżej
SELECT
    -- Przekazujemy identyfikator eventu
    event_id,
    -- Przekazujemy datę
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    -- Przekazujemy czas
    event_timestamp,
    -- Przekazujemy nazwę akcji
    event_name,
    -- Przekazujemy id z ciastka
    user_pseudo_id,
    -- Przekazujemy id logowania
    user_id,
    -- Przekazujemy identyfikator sesji GA4
    ga_session_id,
    
    -- SZEROKIE PRZYPISANIE ŹRÓDŁA:
    -- Funkcja COALESCE zwraca pierwszą napotkaną w nawiasie wartość, która nie jest pusta (NULL).
    -- Krok 1: Przeszukujemy (używając wyrażeń regularnych regex) 'page_location' w poszukiwaniu 'utm_source='.
    -- Krok 2: Jeśli w linku nie było UTM, używamy wyciągniętego 'param_source'
    -- Krok 3: Jeśli on również jest pusty, bierzemy systemowe 'collected_source' natywnie z GA4
    COALESCE(
        REGEXP_EXTRACT(page_location, r'[?&]utm_source=([^&]+)'),
        param_source,
        collected_source,
        session_fallback_source
    ) AS fixed_traffic_source,
    
    -- Szerokie przypisywanie twardego MEDIUM
    -- Wykonujemy idenczyczną kaskadę spadania (COALESCE) szukając 'utm_medium='
    COALESCE(
        REGEXP_EXTRACT(page_location, r'[?&]utm_medium=([^&]+)'),
        param_medium,
        collected_medium,
        session_fallback_medium
    ) AS fixed_traffic_medium,
    
    -- Szerokie przypisywanie docelowej KAMPANII
    -- Kaskada (COALESCE) na rzecz parametru 'utm_campaign='
    COALESCE(
        REGEXP_EXTRACT(page_location, r'[?&]utm_campaign=([^&]+)'),
        param_campaign,
        collected_campaign,
        session_fallback_campaign
    ) AS fixed_traffic_campaign,
    
    -- Blok danych ecommerce idący paczką
    ecommerce,
    
    -- Blok zagnieżdżonych produktów idący tablicą
    items
-- Zamykamy wybór odwołując się z którego cte korzystamy
FROM base
