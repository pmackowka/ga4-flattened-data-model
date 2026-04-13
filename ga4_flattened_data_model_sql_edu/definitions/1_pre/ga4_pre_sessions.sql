-- Blok konfiguracyjny modelu Dataform
config {
    -- Rodzaj operacji w BD – tabela inkrementalna
    type: "incremental",
    -- Nazwa bazy (schematu) wynikowej
    schema: "ga4_flattened",
    -- Meta-opis dostępności w BigQuery
    description: "Agregacja zdarzeń do poziomu sesji - określenie pierwszego i ostatniego źródła w sesji.",
    -- Klucz warunkujący, używany do upewnienia się, że nie dublujemy tych samych wyliczonych sesji
    uniqueKey: ["session_key"]
}

-- Otwieramy nasze CTE grupujące zdarzenia po kluczu
WITH session_events AS (
    -- Wybieramy odpowiednie wiersze...
    SELECT
        -- Generujemy unikalny pełny identyfikator sesji poprzez złączenie Cookie ID usera
        -- z ga_session_id (które samodzielnie nie jest unikalne globalnie, a tylko per użytkownik).
        session_key,
        
        -- Przekazujemy identyfikator użytkownika z wyliczeń pre_events
        user_pseudo_id,
        
        -- Przekazujemy sam w sobie parametr identyfikatora sesji
        ga_session_id,
        
        -- Przekazujemy dokładny czas wykonania akcji z pre_events, kluczowy do ustawienia zdarzeń w kolejności
        event_timestamp,
        
        -- Przekazujemy naprawione w skryptach pre_events źródło wyjściowe ze wsparciem UTM
        fixed_traffic_source,
        
        -- Przekazujemy naprawione medium
        fixed_traffic_medium,
        
        -- Przekazujemy naprawioną kampanię
        fixed_traffic_campaign
        
    -- Odwołujemy z jakiej przygotowanej tabeli to zbieramy z warstwy pierwszej
    FROM
        ${ref("ga4_pre_events")}
        
    -- Ustawiamy warunki dla tabeli roboczej sesji
    WHERE
        -- Interesują nas jedynie eventy, do których przypisano w GA4 unikalne ga_session_id
        ga_session_id IS NOT NULL
        -- Tutaj nie dodajemy już sztywnego filtra event_date, ponieważ dziedziczymy go 
        -- operując wyłącznie na tabelce ga4_pre_events, która wycięła to już na wejściu.
)

-- Wybieramy docelowo zebrane argumenty celem ich docelowego zagregowania
SELECT
    -- Identyfikator sesji z bazy, pod który grupujemy wszystkie jej zdarzenia
    session_key,
    
    -- Identyfikator urządzenia przypisany do tejże sesji
    user_pseudo_id,
    
    -- Odseparowany numer sesji per user
    ga_session_id,
    
    -- FUNKCJA AGREGACJI: Z dużej puli eventów grupowanych w linijce `GROUP BY session_key` 
    -- wyciągamy tylko jeden wiersz odpowiadający za moment rozpoczęcia (minimalny czas timestamp z eventów)
    MIN(event_timestamp) AS session_start_timestamp,
    
    -- [ZAAWANSOWANE: PARTITION BY] FUNKCJA OKNA 'FIRST_VALUE' dla PIERWSZEGO źródła atrybucji ruchu:
    -- 1. Bierze źródło 'fixed_traffic_source' pomijając wartości NULL w dacie (IGNORE NULLS).
    -- 2. PARTITION BY session_key -> Uważa, że operuje tylko na danych przypisanych do jednej unikalnej sesji (dzieli wiersze na "kawałki tortu" sesji).
    -- 3. ORDER BY event_timestamp ASC -> ustawia sobie w tym oknie sesji zdarzenia w sposób rosnący według czasu od najstarszego (początku).
    -- 4. FIRST_VALUE(...) przypisuje do całego wyniku wartość tej kolumny z absolutnie PIERWSZEGO wiersza w okienku.
    FIRST_VALUE(fixed_traffic_source IGNORE NULLS) OVER (PARTITION BY session_key ORDER BY event_timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS session_first_source,
    
-- Analogiczna sprawa dla pierwszego zidentyfikowanego medium w czasie życia sesji (ASC).
    FIRST_VALUE(fixed_traffic_medium IGNORE NULLS) OVER (PARTITION BY session_key ORDER BY event_timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS session_first_medium,

    -- [ZAAWANSOWANE: PARTITION BY] FUNKCJA OKNA 'LAST_VALUE' dla OSTATNIEGO przypisywanego źródła w trakcie trwania tej samej sesji:
    -- Logika w nawiasie OVER jest identyczna w układzie podziału i kierunku ułożenia, ale komenda 'LAST_VALUE' weźmie na końcu wartość pola z OSTATNIEGO wiersza sesji.
    -- (Opcjonalnie GA4 rzuca UTM na wejście do sesji i ewentualnie gdy coś nadpisuje UTM w jej trakcie to będzie tu widoczne).
    LAST_VALUE(fixed_traffic_source IGNORE NULLS) OVER (PARTITION BY session_key ORDER BY event_timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS session_last_source,
    
    -- Analogiczne zachowanie dla ostatniego dostrzeżonego medium.
    LAST_VALUE(fixed_traffic_medium IGNORE NULLS) OVER (PARTITION BY session_key ORDER BY event_timestamp ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS session_last_medium

-- Powyższe zapytanie bazuje ma podzbiorze session_events
FROM
    session_events
-- Agregujemy wyniki zapytania tylko i wyłącznie do tych kolumn w sposób docelowy 
-- aby wynikiem per każdy wyliczony wiersz okna była jedna wartość na każdy uniqueKey.
GROUP BY
    session_key,
    user_pseudo_id,
    ga_session_id,
    fixed_traffic_source,
    fixed_traffic_medium,
    event_timestamp
